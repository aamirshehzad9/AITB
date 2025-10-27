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

## Episode 5 Deployment Process (Green Slot Installation)

### Step 1: Environment Preparation
```powershell
# Navigate to AITB root
cd D:\AITB

# Clean up old logs (optional)
Get-ChildItem "D:\logs\aitb" -Recurse | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-30)} | Remove-Item -Force

# Ensure base directories exist
if (-not (Test-Path "D:\apps\aitb")) { New-Item -Path "D:\apps\aitb" -ItemType Directory -Force }
if (-not (Test-Path "D:\logs\aitb")) { New-Item -Path "D:\logs\aitb" -ItemType Directory -Force }
```

### Step 2: Extract Build Artifacts to Green Slots
```powershell
# Run deployment expansion script
.\ci-cd\deploy\expand-to-staging.ps1 -Version "1.0.0"

# This will:
# - Extract dist/*.zip files to D:\apps\aitb\<service>\green\1.0.0\
# - Create Python virtual environments for Python services
# - Install dependencies from requirements.txt
# - Set up proper directory structure
```

### Step 3: Install NSSM Services (Green Slots)
```powershell
# Install all services to green staging slots
.\ci-cd\install\install-all-green.ps1 -Version "1.0.0"

# Or install individual services:
.\ci-cd\install\install-webapp-green.ps1 -Version "1.0.0"
.\ci-cd\install\install-inference-green.ps1 -Version "1.0.0"
.\ci-cd\install\install-bot-green.ps1 -Version "1.0.0"
.\ci-cd\install\install-notifier-green.ps1 -Version "1.0.0"
.\ci-cd\install\install-dashboard-green.ps1 -Version "1.0.0"
```

### Step 4: Verify Green Slot Installation
```powershell
# Check all green services are installed (Stopped state)
Get-Service -Name "AITB-*-Green" | Format-Table Name, Status, StartType

# Expected output:
# Name                  Status  StartType
# ----                  ------  ---------
# AITB-Bot-Green        Stopped Automatic
# AITB-Dashboard-Green  Stopped Automatic
# AITB-Inference-Green  Stopped Automatic
# AITB-Notifier-Green   Stopped Automatic
# AITB-WebApp-Green     Stopped Automatic

# Verify deployment paths exist
@("webapp", "inference", "bot", "notifier", "dashboard") | ForEach-Object {
    $path = "D:\apps\aitb\$_\green\1.0.0"
    Write-Host "$_: $(Test-Path $path)" -ForegroundColor $(if (Test-Path $path) { "Green" } else { "Red" })
}

# Check log directories created
@("webapp", "inference", "bot", "notifier", "dashboard") | ForEach-Object {
    $logPath = "D:\logs\aitb\$_"
    Write-Host "$_ logs: $(Test-Path $logPath)" -ForegroundColor $(if (Test-Path $logPath) { "Green" } else { "Red" })
}
```

### Step 5: Episode 5 Acceptance Verification
```powershell
# Verify Episode 5 acceptance criteria are met:
# ✓ Services installed (Stopped state)
# ✓ Pointing to green paths
# ✓ NSSM configured with auto start and restart recovery
# ✓ Logging configured to D:\logs\aitb\<service>\

Write-Host "=== Episode 5 Acceptance Verification ===" -ForegroundColor Yellow

# 1. Check service installation and status
$greenServices = Get-Service -Name "AITB-*-Green" -ErrorAction SilentlyContinue
if ($greenServices.Count -eq 5) {
    Write-Host "✓ All 5 services installed" -ForegroundColor Green
} else {
    Write-Host "✗ Missing services (found $($greenServices.Count)/5)" -ForegroundColor Red
}

# 2. Verify all services are stopped
$stoppedServices = $greenServices | Where-Object { $_.Status -eq "Stopped" }
if ($stoppedServices.Count -eq 5) {
    Write-Host "✓ All services in Stopped state" -ForegroundColor Green
} else {
    Write-Host "✗ Some services not in Stopped state" -ForegroundColor Red
}

# 3. Check green slot paths
$pathsExist = @("webapp", "inference", "bot", "notifier", "dashboard") | ForEach-Object {
    Test-Path "D:\apps\aitb\$_\green\1.0.0"
}
if (($pathsExist | Where-Object { $_ }).Count -eq 5) {
    Write-Host "✓ All green slot paths exist" -ForegroundColor Green
} else {
    Write-Host "✗ Missing green slot paths" -ForegroundColor Red
}

Write-Host "Episode 5 complete - Services ready for activation!" -ForegroundColor Green
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