# AITB Rollback Procedures

## Overview
This document provides comprehensive rollback procedures for the AITB trading system across all environments. Rollbacks can be triggered for various reasons including system failures, performance issues, data corruption, or security concerns.

## Rollback Decision Matrix

### Trigger Conditions

#### **IMMEDIATE ROLLBACK** (No Questions Asked)
- Trading bot execution errors affecting live positions
- Data corruption in financial records
- Security breach or unauthorized access
- Critical service failures during market hours
- Performance degradation >75% during trading sessions

#### **PLANNED ROLLBACK** (Coordinated)
- Feature rollback after user feedback
- Performance issues outside trading hours
- Non-critical service instability
- Configuration issues causing minor problems

#### **EMERGENCY ROLLBACK** (All Hands)
- Complete system failure
- Data loss events
- Regulatory compliance violations
- Exchange connectivity loss

## Environment-Specific Rollback Procedures

### Development Environment

#### Quick Development Rollback
```powershell
# Simple git-based rollback for development
cd D:\AITB
git log --oneline -10  # Find target commit
git reset --hard <commit-hash>

# Restart development services
docker-compose down
docker-compose up -d
```

### Staging Environment Rollback

#### Staging Service Rollback
```powershell
# Stop all staging services
Get-Service "AITB-*" | Stop-Service -Force

# Restore from backup
$BackupPath = "D:\backups\aitb\backup-YYYYMMDD-HHMMSS"  # Latest known good backup
$StagingPath = "D:\apps\aitb"

# Remove current version
Remove-Item "$StagingPath\*" -Recurse -Force

# Restore from backup
robocopy $BackupPath $StagingPath /E /COPY:DAT

# Restart services with previous configuration
foreach ($service in @("inference", "bot", "webapp", "dashboard", "notifier")) {
    Start-Service "AITB-$service"
    Start-Sleep -Seconds 30
    
    # Verify service health
    .\scripts\check-service-health.ps1 -ServiceName $service
}
```

### Production Environment Rollback

#### Blue/Green Rollback Strategy

##### **Immediate Blue/Green Switch** (< 5 minutes)
```powershell
# FASTEST: Switch proxy back to blue environment
Write-Host "EXECUTING IMMEDIATE PRODUCTION ROLLBACK" -ForegroundColor Red

# Method 1: IIS Configuration Rollback
$IISConfigPath = "C:\inetpub\wwwroot\web.config"
$BlueBackupPath = "C:\inetpub\wwwroot\web.config.blue.backup"

if (Test-Path $BlueBackupPath) {
    Copy-Item $BlueBackupPath $IISConfigPath -Force
    iisreset /noforce
    Write-Host "IIS configuration restored to blue environment" -ForegroundColor Green
} else {
    # Manual URL rewrite update
    $Config = [xml](Get-Content $IISConfigPath)
    $RewriteRule = $Config.configuration.system.webServer.rewrite.rules.rule | Where-Object {$_.name -eq "AITB-WebApp"}
    $RewriteRule.action.url = "http://localhost:5000/{R:1}"  # Blue port
    $Config.Save($IISConfigPath)
    iisreset /noforce
}

# Method 2: Nginx Configuration Rollback (if using nginx)
# sudo cp /etc/nginx/sites-available/aitb.conf.blue.backup /etc/nginx/sites-available/aitb.conf
# sudo nginx -s reload

# Verify blue services are running
$BlueServices = Get-Service "AITB-*" | Where-Object {$_.Name -notlike "*-Green"}
foreach ($service in $BlueServices) {
    if ($service.Status -ne "Running") {
        Start-Service $service.Name
        Write-Host "Started $($service.Name)" -ForegroundColor Yellow
    }
}

# Immediate health check
Start-Sleep -Seconds 30
Invoke-WebRequest -Uri "https://aitb.production.com/health" -TimeoutSec 10
```

##### **Full Production Rollback** (10-30 minutes)
```powershell
# Complete rollback with database restoration
Write-Host "EXECUTING FULL PRODUCTION ROLLBACK" -ForegroundColor Red

# Step 1: Stop green environment services
Get-Service "AITB-*-Green" | Stop-Service -Force

# Step 2: Restore blue environment from archive
$ArchivePath = "D:\archives\blue-YYYYMMDD-HHMMSS"  # Most recent blue archive
$ProductionPath = "D:\apps\aitb\blue"

if (Test-Path $ArchivePath) {
    # Remove current blue (corrupted/problematic)
    Remove-Item "$ProductionPath\*" -Recurse -Force
    
    # Restore from archive
    robocopy $ArchivePath $ProductionPath /E /COPY:DAT
    
    Write-Host "Blue environment restored from archive" -ForegroundColor Green
}

# Step 3: Database rollback (if required)
# Execute database rollback scripts
.\scripts\rollback-database.ps1 -TargetTimestamp "YYYY-MM-DD HH:MM:SS"

# Step 4: Restart blue services
$BlueServices = @("inference", "bot", "webapp", "dashboard", "notifier")
foreach ($service in $BlueServices) {
    Start-Service "AITB-$service"
    Start-Sleep -Seconds 45  # Longer wait for production
    
    # Health verification
    .\scripts\check-service-health.ps1 -ServiceName $service
}

# Step 5: Switch traffic back to blue
# (Already done in immediate rollback step above)

# Step 6: Verify trading operations
.\scripts\verify-trading-operations.ps1
```

## Database Rollback Procedures

### Point-in-Time Recovery
```sql
-- InfluxDB rollback (if supported)
-- Restore from specific timestamp
RESTORE DATABASE aitb_trading FROM BACKUP 'D:\backups\influxdb\backup-YYYYMMDD-HHMMSS'

-- PostgreSQL point-in-time recovery
-- pg_restore --clean --if-exists -d aitb_db D:\backups\postgres\backup-YYYYMMDD-HHMMSS.sql
```

### SQL Server Rollback
```powershell
# SQL Server database rollback
$BackupFile = "D:\backups\sqlserver\aitb_backup_YYYYMMDD_HHMMSS.bak"

sqlcmd -Q "RESTORE DATABASE AITB FROM DISK = '$BackupFile' WITH REPLACE, NORECOVERY"
sqlcmd -Q "RESTORE LOG AITB FROM DISK = '$LogBackupFile' WITH RECOVERY"
```

## Configuration Rollback

### Application Configuration
```powershell
# Rollback application configurations
$ConfigBackupPath = "D:\backups\configs\backup-YYYYMMDD-HHMMSS"
$CurrentConfigPath = "D:\configs\aitb"

# Restore all service configurations
robocopy $ConfigBackupPath $CurrentConfigPath /E /COPY:DAT

# Restart services to apply configuration
Get-Service "AITB-*" | Restart-Service
```

### Environment Variables
```powershell
# Restore environment variables from backup
$EnvBackupFile = "D:\backups\environment\env-backup-YYYYMMDD-HHMMSS.json"
$EnvVars = Get-Content $EnvBackupFile | ConvertFrom-Json

foreach ($var in $EnvVars.PSObject.Properties) {
    [Environment]::SetEnvironmentVariable($var.Name, $var.Value, "Machine")
}
```

## Data Recovery Procedures

### Trading Data Recovery
```powershell
# Restore critical trading data
Write-Host "Restoring trading data from parquet archives..." -ForegroundColor Yellow

# Restore recent candle data
$ParquetPath = "D:\archives\parquet"
$TargetDate = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")

# Import critical data for last 24 hours
.\scripts\import-parquet-data.ps1 -Date $TargetDate -DataTypes @("candles", "trades", "orderbook")

# Verify data integrity
.\scripts\verify-data-integrity.ps1
```

### Log Recovery
```powershell
# Restore log files for forensic analysis
$LogBackupPath = "D:\backups\logs\backup-YYYYMMDD-HHMMSS"
$CurrentLogPath = "D:\logs\aitb"

# Create forensic copy before rollback
robocopy $CurrentLogPath "D:\forensics\logs-$(Get-Date -Format 'yyyyMMdd-HHmmss')" /E /COPY:DAT

# Restore clean logs
robocopy $LogBackupPath $CurrentLogPath /E /COPY:DAT
```

## Verification Procedures

### Post-Rollback Health Checks

#### System Health Verification
```powershell
# Comprehensive post-rollback verification
Write-Host "Executing post-rollback verification..." -ForegroundColor Green

# 1. Service Health
Get-Service "AITB-*" | ForEach-Object {
    if ($_.Status -eq "Running") {
        Write-Host "✓ $($_.Name) - Running" -ForegroundColor Green
    } else {
        Write-Host "✗ $($_.Name) - $($_.Status)" -ForegroundColor Red
    }
}

# 2. Endpoint Health
$Endpoints = @(
    "http://localhost:8001/health",
    "http://localhost:5000",
    "http://localhost:8501/health"
)

foreach ($url in $Endpoints) {
    try {
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 10
        Write-Host "✓ $url - Status: $($response.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "✗ $url - Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 3. Bot Heartbeat
$HeartbeatFile = "D:\logs\aitb\bot\bot-heartbeat.log"
if (Test-Path $HeartbeatFile) {
    $LastHeartbeat = (Get-Item $HeartbeatFile).LastWriteTime
    $HeartbeatAge = (Get-Date) - $LastHeartbeat
    
    if ($HeartbeatAge.TotalSeconds -le 120) {
        Write-Host "✓ Bot heartbeat current ($($HeartbeatAge.TotalSeconds)s ago)" -ForegroundColor Green
    } else {
        Write-Host "⚠ Bot heartbeat stale ($($HeartbeatAge.TotalSeconds)s ago)" -ForegroundColor Yellow
    }
}
```

#### Trading Operations Verification
```powershell
# Verify trading system functionality
Write-Host "Verifying trading operations..." -ForegroundColor Yellow

# Check market data feed
.\scripts\test-market-data-feed.ps1

# Verify inference service responses
.\scripts\test-inference-service.ps1

# Test order simulation (paper trading)
.\scripts\test-order-simulation.ps1

# Check notification system
.\scripts\test-notification-system.ps1
```

## Communication Procedures

### Rollback Notifications

#### Team Communication Template
```plaintext
SUBJECT: [URGENT] AITB Production Rollback Executed

Team,

A production rollback has been executed for the AITB trading system.

DETAILS:
- Rollback Time: [TIMESTAMP]
- Trigger Reason: [REASON]
- Environment: [PRODUCTION/STAGING]
- Rollback Type: [IMMEDIATE/PLANNED/EMERGENCY]
- Previous Version: [VERSION]
- Current Version: [ROLLED_BACK_VERSION]

STATUS:
- Services: [RUNNING/DEGRADED/DOWN]
- Trading: [ACTIVE/SUSPENDED/PAPER_MODE]
- Data Integrity: [VERIFIED/CHECKING/COMPROMISED]

NEXT STEPS:
1. [ACTION_ITEM_1]
2. [ACTION_ITEM_2]
3. [ACTION_ITEM_3]

Team Lead: [NAME]
Incident Number: [INC_NUMBER]
```

#### Stakeholder Communication
- **Immediate**: Trading team, DevOps team, Management
- **Within 1 hour**: Compliance, Risk management, External partners
- **Within 4 hours**: Full incident report with root cause analysis

## Documentation and Lessons Learned

### Post-Rollback Documentation
1. **Incident Timeline**: Detailed chronology of events
2. **Root Cause Analysis**: What triggered the rollback
3. **Impact Assessment**: Financial and operational impact
4. **Recovery Time**: Actual vs. target recovery times
5. **Lessons Learned**: Process improvements identified

### Continuous Improvement
- Update rollback procedures based on lessons learned
- Improve monitoring and alerting to prevent future issues
- Enhance automated rollback capabilities
- Regular rollback drill exercises

## Emergency Contacts

### Immediate Response Team
- **DevOps Lead**: +1-XXX-XXX-XXXX
- **Trading Manager**: +1-XXX-XXX-XXXX
- **System Administrator**: +1-XXX-XXX-XXXX

### Escalation Contacts
- **CTO**: +1-XXX-XXX-XXXX
- **Risk Manager**: +1-XXX-XXX-XXXX
- **Compliance Officer**: +1-XXX-XXX-XXXX

### External Contacts
- **Exchange Support**: +1-XXX-XXX-XXXX
- **Cloud Provider**: +1-XXX-XXX-XXXX
- **Database Vendor**: +1-XXX-XXX-XXXX