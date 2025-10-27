# AITB Staging Environment Runbook

## Overview
This runbook covers deployment procedures for the AITB staging environment using host-native services.

## Environment Details
- **Environment**: Staging
- **Host**: Windows Server (host-native)
- **Services Location**: `D:\apps\aitb\`
- **Configuration**: `D:\configs\aitb\`
- **Logs**: `D:\logs\aitb\`

## Pre-Deployment Checklist

### Prerequisites
- [ ] Verify staging environment is accessible
- [ ] Ensure all required directories exist
- [ ] Validate service definitions in `ci-cd\service_defs\`
- [ ] Confirm backup of current version
- [ ] Check disk space availability (min 5GB free)

### Service Dependencies
1. **Infrastructure Services** (start first)
   - InfluxDB (port 8086)
   - PostgreSQL (port 5432)
   - SQL Server (port 1433)

2. **Application Services** (start in order)
   - Inference Service (port 8001)
   - Trading Bot (no external port)
   - Web Application (port 5000)
   - Dashboard (port 8501)
   - Notifier (no external port)

## Deployment Process

### Step 1: Environment Preparation
```powershell
# Stop all AITB services
.\scripts\stop-all-services.ps1

# Backup current version
robocopy "D:\apps\aitb" "D:\backups\aitb\backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')" /E /COPY:DAT

# Clean logs older than 30 days
Get-ChildItem "D:\logs\aitb" -Recurse | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-30)} | Remove-Item -Force
```

### Step 2: Service Deployment
```powershell
# Deploy new version
$version = "v1.0.0"
foreach ($service in @("webapp", "inference", "bot", "notifier", "dashboard")) {
    # Create versioned directory
    New-Item -Path "D:\apps\aitb\$service\$version" -ItemType Directory -Force
    
    # Deploy service files
    robocopy ".\build\$service" "D:\apps\aitb\$service\$version" /E /COPY:DAT
    
    # Update service configuration
    Copy-Item ".\configs\staging\$service\*" "D:\configs\aitb\$service\" -Force
}
```

### Step 3: Service Installation
```powershell
# Install services using service definitions
foreach ($service in @("inference", "bot", "webapp", "dashboard", "notifier")) {
    .\scripts\install-service.ps1 -ServiceName $service -DefinitionPath ".\ci-cd\service_defs\$service.json"
}
```

### Step 4: Service Startup
```powershell
# Start services in dependency order
$services = @("inference", "bot", "webapp", "dashboard", "notifier")
foreach ($service in $services) {
    Start-Service "AITB-$service"
    Start-Sleep -Seconds 30
    
    # Verify service health
    .\scripts\check-service-health.ps1 -ServiceName $service
}
```

## Health Checks

### Automated Health Verification
```powershell
# Run comprehensive health check
.\scripts\staging-health-check.ps1

# Check individual endpoints
$endpoints = @(
    "http://localhost:8001/health",     # Inference
    "http://localhost:5000",            # WebApp
    "http://localhost:8501/health"      # Dashboard (when wired)
)

foreach ($url in $endpoints) {
    try {
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 10
        Write-Host "$url - Status: $($response.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "$url - Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
```

### Manual Verification Steps
- [ ] Verify all services are running: `Get-Service AITB-*`
- [ ] Check service logs for errors: `Get-Content D:\logs\aitb\*\*-stderr.log -Tail 50`
- [ ] Test bot heartbeat: Verify `D:\logs\aitb\bot\bot-heartbeat.log` updated within 60 seconds
- [ ] Validate web interface: Browse to `http://localhost:5000`
- [ ] Check dashboard access: Browse to `http://localhost:8501`

## Troubleshooting

### Common Issues

#### Service Won't Start
1. Check service definition JSON syntax
2. Verify application directory exists: `D:\apps\aitb\{service}\v1.0.0`
3. Check log files for specific errors
4. Ensure dependencies are running

#### Port Conflicts
1. Check port availability: `netstat -an | findstr "5000 8001 8501"`
2. Kill conflicting processes if necessary
3. Verify firewall rules allow required ports

#### Bot Heartbeat Missing
1. Check bot service status: `Get-Service AITB-bot`
2. Review bot logs: `Get-Content D:\logs\aitb\bot\bot-stderr.log -Tail 100`
3. Verify inference service connectivity

## Rollback Procedure
If issues occur, execute immediate rollback:
```powershell
# Stop current services
.\scripts\stop-all-services.ps1

# Restore previous version
.\scripts\rollback-services.ps1 -BackupPath "D:\backups\aitb\backup-YYYYMMDD-HHMMSS"

# Restart services
.\scripts\start-all-services.ps1
```

## Post-Deployment Tasks
- [ ] Update deployment log with version and timestamp
- [ ] Monitor service logs for 1 hour post-deployment
- [ ] Verify trading operations resume normally
- [ ] Update staging status dashboard
- [ ] Notify team of deployment completion

## Contact Information
- **DevOps Team**: devops@aitb.local
- **Trading Team**: trading@aitb.local
- **Emergency Contact**: +1-XXX-XXX-XXXX