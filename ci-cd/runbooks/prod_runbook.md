# AITB Production Environment Runbook

## Overview
This runbook covers blue/green deployment procedures for the AITB production environment using nginx proxy switching for zero-downtime deployments.

**Episode 7 Update**: Automated blue/green switching with atomic upstream switching and comprehensive rollback procedures.

## Episode 7: Blue/Green Switch Infrastructure

### Architecture Overview
- **Blue Environment**: Production-ready services on ports 5000, 8001, 8501
- **Green Environment**: Staging services on ports 5002, 8003, 8503  
- **Nginx Reverse Proxy**: Atomic switching between blue/green upstreams
- **Zero-Downtime Switch**: Configuration-based routing with immediate rollback capability

### Nginx Configuration
```bash
# Production endpoints (routes to active environment)
http://localhost/              → WebApp (blue or green)
http://localhost/api/inference/ → Inference API (blue or green) 
http://localhost/dashboard/     → Dashboard (blue or green)

# Direct environment access
http://localhost:8080/          → Blue environment direct access
http://localhost:8090/          → Green environment direct access

# Deployment status
http://localhost/admin/deployment-status → Current environment info
```

### Service Port Mapping
| Service | Blue Port | Green Port | Production URL |
|---------|-----------|------------|----------------|
| WebApp | 5000 | 5002 | `http://localhost/` |
| Inference | 8001 | 8003 | `http://localhost/api/inference/` |
| Dashboard | 8501 | 8503 | `http://localhost/dashboard/` |
| Bot | N/A | N/A | Internal service |
| Notifier | N/A | N/A | Internal service |

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

## Episode 7: Automated Blue/Green Deployment

### Automated Deployment Pipeline

#### Method 1: GitHub Actions Pipeline (Recommended)
```powershell
# Trigger automated blue/green deployment
# Via GitHub Actions workflow dispatch

# 1. Navigate to GitHub Actions
# 2. Select "AITB Blue/Green Promotion" workflow
# 3. Click "Run workflow"
# 4. Configure parameters:
#    - Version: e.g., "1.0.0"
#    - Target color: "auto" (auto-detect idle)
#    - Dry run: false (for actual deployment)

# Parameters:
# - version: Version to deploy (required)
# - target_color: auto/blue/green (default: auto)
# - skip_health_checks: false (for emergency deployments)
# - dry_run: false (true for testing)
```

#### Method 2: Local Automated Deployment
```powershell
# Local promotion pipeline execution
cd D:\AITB

# Step 1: Build and package (if not already done)
.\ci-cd\pipelines\build.yml -Version "1.0.0"

# Step 2: Run automated promotion
.\ci-cd\scripts\promote-local.ps1 -Version "1.0.0" -DryRun:$false

# Step 3: Monitor deployment
Get-Content "D:\logs\aitb\deployment\deploy-*.log" -Tail 50 -Wait
```

#### Method 3: Manual Step-by-Step (Emergency/Troubleshooting)
```powershell
# Complete manual deployment process

# 1. Determine current and target environments
$current = & "D:\AITB\ci-cd\scripts\get-current-environment.ps1"
$target = if ($current -eq "blue") { "green" } else { "blue" }

Write-Host "Current: $current, Target: $target"

# 2. Deploy to idle environment
.\ci-cd\scripts\deploy-to-idle.ps1 -Version "1.0.0" -TargetEnvironment $target

# 3. Start idle services
.\ci-cd\scripts\start-idle-services.ps1 -Environment $target

# 4. Run acceptance tests
.\ci-cd\scripts\run-acceptance-tests.ps1 -Environment $target

# 5. Switch traffic (atomic)
.\ci-cd\scripts\switch-environment.ps1 -TargetEnvironment $target -Version "1.0.0"
```

### Single-Command Deployment

#### Quick Production Deployment
```powershell
# One-command deployment with all safety checks
.\ci-cd\scripts\switch-environment.ps1 -TargetEnvironment auto -Version "1.0.0"

# This script will:
# ✅ Auto-detect idle environment
# ✅ Verify target environment health
# ✅ Perform atomic nginx upstream switch
# ✅ Verify production endpoints post-switch
# ✅ Log all actions for audit trail
```

#### Emergency Deployment (Skip Health Checks)
```powershell
# Emergency deployment with minimal checks
.\ci-cd\scripts\switch-environment.ps1 -TargetEnvironment green -Force -HealthCheckRetries 1
```

#### Dry Run Testing
```powershell
# Test deployment without making changes
.\ci-cd\scripts\switch-environment.ps1 -TargetEnvironment green -Version "1.0.0" -DryRun
```

### Rollback Procedures

#### Immediate Rollback (< 5 minutes)
```powershell
# Fastest rollback - switch back to previous environment
$previousEnv = if ((Get-CurrentEnvironment) -eq "blue") { "green" } else { "blue" }

.\ci-cd\scripts\switch-environment.ps1 -TargetEnvironment $previousEnv -Force

# This provides immediate rollback by switching nginx upstreams
# Previous environment services are still warm and ready
```

#### Rollback with Health Verification
```powershell
# Rollback with full health checks
$deploymentLog = Get-ChildItem "D:\logs\aitb\deployment\deploy-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$deployment = Get-Content $deploymentLog.FullName | ConvertFrom-Json
$previousEnv = $deployment.previousEnvironment

# Switch back with verification
.\ci-cd\scripts\switch-environment.ps1 -TargetEnvironment $previousEnv -Version $deployment.version
```

#### Service-Level Rollback
```powershell
# Rollback individual services if needed
$services = @("WebApp", "Inference", "Bot", "Dashboard", "Notifier")
$targetEnv = "blue"  # or "green"

foreach ($service in $services) {
    Stop-Service "AITB-$service-Green" -Force
    Start-Service "AITB-$service-$targetEnv" 
    Write-Host "Rolled back $service to $targetEnv"
}

# Then switch nginx upstreams
.\ci-cd\scripts\switch-environment.ps1 -TargetEnvironment $targetEnv -Force
```

### Monitoring and Verification

#### Real-Time Deployment Monitoring
```powershell
# Monitor deployment progress
$deploymentId = (Get-Date -Format "yyyyMMdd-HHmmss")
Get-Content "D:\logs\aitb\deployment\deploy-$deploymentId.log" -Tail 20 -Wait

# Monitor nginx access logs during switch
Get-Content "D:\logs\nginx\access.log" -Tail 50 -Wait

# Check service health across environments
.\tools\watchdog.ps1 -Environment "all" -CheckInterval 10
```

#### Post-Deployment Verification
```powershell
# Comprehensive post-deployment checks
$checks = @(
    "http://localhost/health",                    # Production health
    "http://localhost/api/inference/health",      # Inference API
    "http://localhost/dashboard/",                # Dashboard
    "http://localhost/admin/deployment-status"    # Deployment status
)

foreach ($url in $checks) {
    try {
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 5
        Write-Host "✅ $url - Status: $($response.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "❌ $url - Failed: $_" -ForegroundColor Red
    }
}
```

#### Trading Continuity Verification
```powershell
# Verify trading operations continue post-deployment
$botLogPath = "D:\logs\aitb\bot\bot.log"
$lastHeartbeat = Get-Content $botLogPath -Tail 10 | Where-Object { $_ -match "HEARTBEAT" } | Select-Object -Last 1

if ($lastHeartbeat) {
    Write-Host "✅ Bot heartbeat detected: $lastHeartbeat" -ForegroundColor Green
} else {
    Write-Host "⚠️ No recent bot heartbeat found" -ForegroundColor Yellow
}

# Check for trading errors
$errors = Get-Content $botLogPath -Tail 100 | Where-Object { $_ -match "ERROR|EXCEPTION" }
if ($errors) {
    Write-Host "⚠️ Recent errors detected:" -ForegroundColor Yellow
    $errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
} else {
    Write-Host "✅ No recent errors in bot logs" -ForegroundColor Green
}
```

## Legacy Blue/Green Deployment Process

### Phase 1: Green Environment Preparation (Manual Process)

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

#### Episode 6: Production Watchdog Monitoring
**Automated Health Monitoring for Production Environment**

```powershell
# Production Watchdog Setup - Critical for Zero-Downtime Operations
# Location: D:\AITB\tools\watchdog.ps1

# Production configuration with Telegram alerts
.\tools\watchdog.ps1 `
    -TelegramToken $env:PROD_TG_BOT_TOKEN `
    -TelegramChatId $env:PROD_TG_CHAT_ID `
    -CheckInterval 30 `
    -LogLevel "INFO"

# Blue/Green specific monitoring
# Monitor BLUE environment (production)
.\tools\watchdog.ps1 `
    -Environment "blue" `
    -TelegramToken $env:PROD_TG_BOT_TOKEN `
    -TelegramChatId $env:PROD_TG_CHAT_ID

# Monitor GREEN environment (staging)
.\tools\watchdog.ps1 `
    -Environment "green" `
    -TelegramToken $env:STAGING_TG_BOT_TOKEN `
    -TelegramChatId $env:STAGING_TG_CHAT_ID
```

**⚠️ CRITICAL PRODUCTION SAFETY FEATURE:**
```powershell
# The watchdog script includes TRADING HOURS PROTECTION
# It will NEVER automatically restart services during active trading sessions
# This prevents disruption of live trading operations
# Manual intervention required for service failures during trading hours
```

**Production Watchdog Features:**
- ✅ **Continuous health monitoring** - 30-second intervals for production
- ✅ **Telegram alerting** - Immediate notifications for production team
- ✅ **Blue/Green environment awareness** - Monitors both environments
- ✅ **Bot heartbeat validation** - Ensures trading bot stays active
- ✅ **Service state persistence** - Tracks changes between deployments
- ⚠️ **NO AUTO-RESTART during trading** - Critical safety mechanism
- ✅ **Comprehensive logging** - Full audit trail in production logs

**Setting Up Production Watchdog:**
```powershell
# 1. Configure production Telegram notifications
$env:PROD_TG_BOT_TOKEN = "PRODUCTION_BOT_TOKEN"
$env:PROD_TG_CHAT_ID = "PRODUCTION_CHAT_ID"
$env:STAGING_TG_BOT_TOKEN = "STAGING_BOT_TOKEN"  
$env:STAGING_TG_CHAT_ID = "STAGING_CHAT_ID"

# 2. Create production scheduled task for automatic monitoring
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-File D:\AITB\tools\watchdog.ps1 -Environment blue -TelegramToken $env:PROD_TG_BOT_TOKEN -TelegramChatId $env:PROD_TG_CHAT_ID -CheckInterval 30"
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName "AITB-Production-Watchdog" -Action $action -Trigger $trigger -User "SYSTEM"

# 3. Start production monitoring
Start-ScheduledTask -TaskName "AITB-Production-Watchdog"
```

**Watchdog Integration with Blue/Green Deployments:**
```powershell
# During deployment, watchdog will:
# 1. Monitor GREEN environment health during validation
# 2. Track BLUE environment stability during switch
# 3. Alert immediately if any service degrades post-deployment
# 4. Provide detailed health history for rollback decisions

# Pre-deployment: Start green environment monitoring
.\tools\watchdog.ps1 -Environment "green" -TelegramToken $env:STAGING_TG_BOT_TOKEN -TelegramChatId $env:STAGING_TG_CHAT_ID &

# Post-deployment: Verify production monitoring active
Get-ScheduledTask -TaskName "AITB-Production-Watchdog" | Get-ScheduledTaskInfo
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