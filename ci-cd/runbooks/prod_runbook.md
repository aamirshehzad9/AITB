# AITB Production Environment Runbook

## Overview
This runbook covers blue/green deployment procedures for the AITB production environment using IIS/nginx proxy switching for zero-downtime deployments.

## Environment Architecture

### Blue/Green Setup
- **Blue Environment** (Live): `D:\apps\aitb\blue\`
- **Green Environment** (Staging): `D:\apps\aitb\green\`
- **Proxy Configuration**: IIS/nginx routes traffic between environments
- **Switch Mechanism**: Configuration-based routing change

### Service Ports
- **Blue Environment**:
  - WebApp: 5000 (behind proxy)
  - Inference: 8001
  - Dashboard: 8501
- **Green Environment**:
  - WebApp: 5002 (behind proxy)
  - Inference: 8003
  - Dashboard: 8503

## Pre-Deployment Checklist

### Prerequisites
- [ ] Production maintenance window scheduled
- [ ] Blue environment health verified
- [ ] Green environment prepared and validated
- [ ] Database migrations tested (if applicable)
- [ ] Rollback plan confirmed
- [ ] Monitoring alerts configured
- [ ] Team standby confirmed

### Critical Validations
- [ ] Trading session timing verified (avoid market hours)
- [ ] Bot positions recorded for continuity
- [ ] Backup of current blue environment completed
- [ ] Configuration differences documented

## Blue/Green Deployment Process

### Phase 1: Green Environment Preparation

#### Step 1: Deploy to Green Environment
```powershell
# Set environment variables
$GreenPath = "D:\apps\aitb\green"
$Version = "v1.0.0"

# Stop green services if running
Get-Service "AITB-*-Green" | Stop-Service -Force

# Deploy new version to green
foreach ($service in @("webapp", "inference", "bot", "notifier", "dashboard")) {
    # Create versioned directory in green
    $ServicePath = "$GreenPath\$service\$Version"
    New-Item -Path $ServicePath -ItemType Directory -Force
    
    # Deploy service files
    robocopy ".\build\$service" $ServicePath /E /COPY:DAT
    
    # Copy production configuration
    Copy-Item ".\configs\production\$service\*" "D:\configs\aitb\green\$service\" -Force
}
```

#### Step 2: Configure Green Services
```powershell
# Update service definitions for green environment
foreach ($service in @("webapp", "inference", "bot", "notifier", "dashboard")) {
    $ConfigPath = ".\ci-cd\service_defs\$service-green.json"
    
    # Modify ports and paths for green environment
    $Config = Get-Content $ConfigPath | ConvertFrom-Json
    $Config.appDirectory = "$GreenPath\$service\$Version"
    $Config.logging.stdOut = "D:\logs\aitb\green\$service\$service-stdout.log"
    $Config.logging.stdErr = "D:\logs\aitb\green\$service\$service-stderr.log"
    
    # Update ports for non-conflicting green deployment
    switch ($service) {
        "webapp" { $Config.environment.ASPNETCORE_URLS = "http://localhost:5002" }
        "inference" { $Config.environment.INFERENCE_PORT = "8003" }
        "dashboard" { $Config.environment.STREAMLIT_SERVER_PORT = "8503" }
    }
    
    $Config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath
}
```

#### Step 3: Start Green Services
```powershell
# Install and start green services
$GreenServices = @("inference", "bot", "webapp", "dashboard", "notifier")
foreach ($service in $GreenServices) {
    # Install green service
    .\scripts\install-service.ps1 -ServiceName "$service-Green" -DefinitionPath ".\ci-cd\service_defs\$service-green.json"
    
    # Start service
    Start-Service "AITB-$service-Green"
    Start-Sleep -Seconds 30
    
    # Health check
    Write-Host "Checking health of $service-Green..."
    .\scripts\check-service-health.ps1 -ServiceName "$service-Green"
}
```

### Phase 2: Green Environment Validation

#### Comprehensive Health Checks
```powershell
# Validate green environment endpoints
$GreenEndpoints = @(
    "http://localhost:8003/health",     # Green Inference
    "http://localhost:5002",            # Green WebApp
    "http://localhost:8503/health"      # Green Dashboard
)

foreach ($url in $GreenEndpoints) {
    try {
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-Host "$url - ✓ Healthy" -ForegroundColor Green
        } else {
            Write-Host "$url - ⚠ Status: $($response.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "$url - ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
        throw "Green environment validation failed"
    }
}
```

#### Trading Bot Validation
```powershell
# Verify green bot connectivity and data flow
Write-Host "Validating green bot..."

# Check bot heartbeat
$HeartbeatFile = "D:\logs\aitb\green\bot\bot-heartbeat.log"
if (Test-Path $HeartbeatFile) {
    $LastHeartbeat = (Get-Item $HeartbeatFile).LastWriteTime
    $HeartbeatAge = (Get-Date) - $LastHeartbeat
    
    if ($HeartbeatAge.TotalSeconds -le 120) {
        Write-Host "Green bot heartbeat: ✓ Current ($($HeartbeatAge.TotalSeconds)s ago)" -ForegroundColor Green
    } else {
        Write-Host "Green bot heartbeat: ⚠ Stale ($($HeartbeatAge.TotalSeconds)s ago)" -ForegroundColor Yellow
    }
}

# Test inference connectivity from green bot
Write-Host "Testing green bot -> inference connectivity..."
# Additional validation steps here
```

### Phase 3: Traffic Switching (Blue to Green)

#### IIS Configuration Switch
```powershell
# Backup current IIS configuration
.\scripts\backup-iis-config.ps1

# Update IIS URL rewrite rules to point to green environment
$IISConfigPath = "C:\inetpub\wwwroot\web.config"
$BackupPath = "C:\inetpub\wwwroot\web.config.blue.backup"

# Backup current config
Copy-Item $IISConfigPath $BackupPath

# Update rewrite rules for green environment
$Config = [xml](Get-Content $IISConfigPath)
$RewriteRule = $Config.configuration.system.webServer.rewrite.rules.rule | Where-Object {$_.name -eq "AITB-WebApp"}
$RewriteRule.action.url = "http://localhost:5002/{R:1}"

# Save updated configuration
$Config.Save($IISConfigPath)

# Test IIS configuration
iisreset /noforce
```

#### Nginx Configuration Switch (Alternative)
```bash
# If using nginx instead of IIS
# Update upstream configuration
sudo cp /etc/nginx/sites-available/aitb.conf /etc/nginx/sites-available/aitb.conf.blue.backup

# Switch upstream to green
sudo sed -i 's/server 127.0.0.1:5000/server 127.0.0.1:5002/' /etc/nginx/sites-available/aitb.conf

# Test and reload nginx
sudo nginx -t && sudo nginx -s reload
```

### Phase 4: Production Validation

#### Live Traffic Validation
```powershell
# Monitor production traffic on green environment
Write-Host "Monitoring live traffic switching to green environment..."

# Check production endpoint health
for ($i = 1; $i -le 10; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "https://aitb.production.com/health" -TimeoutSec 5
        Write-Host "Production health check $i/10: Status $($response.StatusCode)" -ForegroundColor Green
        Start-Sleep -Seconds 30
    } catch {
        Write-Host "Production health check $i/10: Failed - $($_.Exception.Message)" -ForegroundColor Red
    }
}
```

#### Trading Operations Validation
```powershell
# Verify trading operations continue seamlessly
Write-Host "Validating trading operations..."

# Check for new trades in the last 5 minutes
$TradeLogQuery = "SELECT COUNT(*) FROM trades WHERE timestamp > NOW() - INTERVAL 5 MINUTE"
# Execute query and validate results

# Monitor bot performance metrics
# Check inference service response times
# Validate notification service functionality
```

### Phase 5: Blue Environment Cleanup

#### Post-Switch Cleanup (After 24h Validation)
```powershell
# After 24 hours of successful green operation, clean up blue
Write-Host "Performing blue environment cleanup..."

# Stop blue services
Get-Service "AITB-*" | Where-Object {$_.Name -notlike "*-Green"} | Stop-Service -Force

# Archive blue environment
$ArchivePath = "D:\archives\blue-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
robocopy "D:\apps\aitb\blue" $ArchivePath /E /COPY:DAT

# Rename green to blue for next deployment cycle
Move-Item "D:\apps\aitb\green" "D:\apps\aitb\blue"
```

## Monitoring and Alerting

### Critical Metrics to Monitor
- **Response Times**: Web app and API response times
- **Error Rates**: HTTP 5xx errors, application exceptions
- **Trading Performance**: Trade execution latency, success rates
- **Resource Usage**: CPU, memory, disk I/O
- **Bot Heartbeat**: Continuous monitoring of bot health

### Alert Thresholds
- Response time > 5 seconds
- Error rate > 1%
- Bot heartbeat missing > 2 minutes
- Memory usage > 80%
- Disk space < 10% free

## Emergency Procedures

### Immediate Rollback Trigger Conditions
- Critical trading system failure
- Data corruption detected
- Security breach identified
- Performance degradation > 50%
- Multiple service failures

### Emergency Rollback Process
```powershell
# EMERGENCY: Immediate switch back to blue
Write-Host "EMERGENCY ROLLBACK INITIATED" -ForegroundColor Red

# Restore IIS configuration
Copy-Item "C:\inetpub\wwwroot\web.config.blue.backup" "C:\inetpub\wwwroot\web.config" -Force
iisreset /noforce

# Verify blue services are running
Get-Service "AITB-*" | Where-Object {$_.Name -notlike "*-Green"} | Start-Service

# Notify team immediately
.\scripts\send-emergency-alert.ps1 -Message "Production rollback executed"
```

## Post-Deployment Tasks

### Success Criteria Validation
- [ ] All production services healthy for 24 hours
- [ ] Trading operations normal performance
- [ ] No critical alerts triggered
- [ ] User-facing features functional
- [ ] Data integrity maintained

### Documentation Updates
- [ ] Update production deployment log
- [ ] Document any issues encountered
- [ ] Update monitoring baselines
- [ ] Schedule next deployment window
- [ ] Team retrospective scheduled

## Contact Information
- **Production Support**: production@aitb.local
- **Emergency Hotline**: +1-XXX-XXX-XXXX
- **DevOps Lead**: devops-lead@aitb.local
- **Trading Desk**: trading-desk@aitb.local