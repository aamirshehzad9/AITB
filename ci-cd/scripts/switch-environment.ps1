# AITB Blue/Green Environment Switch Script
# Episode 7 - Atomic upstream switching for zero-downtime deployments

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("blue", "green")]
    [string]$TargetEnvironment,
    
    [Parameter(Mandatory=$false)]
    [string]$Version = "unknown",
    
    [Parameter(Mandatory=$false)]
    [string]$NginxPath = "C:\nginx",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [int]$HealthCheckRetries = 3
)

$ErrorActionPreference = "Stop"

Write-Host "=== AITB Blue/Green Environment Switch ===" -ForegroundColor Cyan
Write-Host "Target Environment: $TargetEnvironment" -ForegroundColor Yellow
Write-Host "Version: $Version" -ForegroundColor Yellow
Write-Host "Dry Run: $DryRun" -ForegroundColor Yellow
Write-Host ""

# Configuration
$EnvMappingPath = "$NginxPath\conf\conf.d\env-mapping.conf"
$BlueMapping = "D:\AITB\ci-cd\nginx\env-mapping-blue.conf"
$GreenMapping = "D:\AITB\ci-cd\nginx\env-mapping-green.conf"
$LogFile = "D:\logs\aitb\deployment\switch-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Ensure log directory exists
$LogDir = Split-Path $LogFile -Parent
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param($Message, $Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Write-Host $LogEntry
    $LogEntry | Add-Content $LogFile
}

function Test-ServiceHealth {
    param(
        [string]$ServiceName,
        [string]$Url,
        [int]$TimeoutSeconds = 10
    )
    
    try {
        $Response = Invoke-WebRequest -Uri $Url -TimeoutSec $TimeoutSeconds -UseBasicParsing
        if ($Response.StatusCode -eq 200) {
            Write-Log "✅ $ServiceName health check passed ($($Response.StatusCode))" "SUCCESS"
            return $true
        } else {
            Write-Log "⚠️ $ServiceName health check returned $($Response.StatusCode)" "WARN"
            return $false
        }
    } catch {
        Write-Log "❌ $ServiceName health check failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Get-CurrentEnvironment {
    try {
        if (Test-Path $EnvMappingPath) {
            $Content = Get-Content $EnvMappingPath -Raw
            if ($Content -match "webapp_blue") {
                return "blue"
            } elseif ($Content -match "webapp_green") {
                return "green"
            }
        }
        return "unknown"
    } catch {
        Write-Log "Failed to determine current environment: $_" "ERROR"
        return "unknown"
    }
}

function Test-NginxConfiguration {
    try {
        $TestResult = & "$NginxPath\nginx.exe" -t 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✅ Nginx configuration test passed" "SUCCESS"
            return $true
        } else {
            Write-Log "❌ Nginx configuration test failed: $TestResult" "ERROR"
            return $false
        }
    } catch {
        Write-Log "❌ Failed to test nginx configuration: $_" "ERROR"
        return $false
    }
}

function Restart-Nginx {
    try {
        Write-Log "Reloading nginx configuration..." "INFO"
        & "$NginxPath\nginx.exe" -s reload
        if ($LASTEXITCODE -eq 0) {
            Start-Sleep -Seconds 2  # Allow reload to complete
            Write-Log "✅ Nginx reloaded successfully" "SUCCESS"
            return $true
        } else {
            Write-Log "❌ Failed to reload nginx" "ERROR"
            return $false
        }
    } catch {
        Write-Log "❌ Failed to reload nginx: $_" "ERROR"
        return $false
    }
}

# Determine service ports based on target environment
if ($TargetEnvironment -eq "blue") {
    $WebAppPort = 5000
    $InferencePort = 8001
    $DashboardPort = 8501
    $SourceMapping = $BlueMapping
} else {
    $WebAppPort = 5002
    $InferencePort = 8003
    $DashboardPort = 8503
    $SourceMapping = $GreenMapping
}

# Pre-flight checks
Write-Log "=== Pre-flight Checks ===" "INFO"

# Check if nginx is running
$NginxProcess = Get-Process -Name "nginx" -ErrorAction SilentlyContinue
if (-not $NginxProcess) {
    Write-Log "❌ Nginx is not running" "ERROR"
    exit 1
}
Write-Log "✅ Nginx is running (PID: $($NginxProcess.Id -join ', '))" "SUCCESS"

# Check current environment
$CurrentEnv = Get-CurrentEnvironment
Write-Log "Current environment: $CurrentEnv" "INFO"

if ($CurrentEnv -eq $TargetEnvironment -and -not $Force) {
    Write-Log "❌ Already running $TargetEnvironment environment. Use -Force to override." "ERROR"
    exit 1
}

# Health check target environment services
Write-Log "=== Target Environment Health Checks ===" "INFO"

$HealthChecks = @(
    @{ Name = "WebApp"; Url = "http://localhost:$WebAppPort/health/live" },
    @{ Name = "Inference"; Url = "http://localhost:$InferencePort/health" },
    @{ Name = "Dashboard"; Url = "http://localhost:$DashboardPort/" }
)

$HealthyServices = 0
$TotalServices = $HealthChecks.Count

foreach ($Check in $HealthChecks) {
    $Healthy = $false
    for ($i = 1; $i -le $HealthCheckRetries; $i++) {
        Write-Log "Health check $i/$HealthCheckRetries for $($Check.Name)..." "INFO"
        $Healthy = Test-ServiceHealth -ServiceName $Check.Name -Url $Check.Url
        if ($Healthy) {
            $HealthyServices++
            break
        }
        if ($i -lt $HealthCheckRetries) {
            Start-Sleep -Seconds 5
        }
    }
    
    if (-not $Healthy -and -not $Force) {
        Write-Log "❌ $($Check.Name) failed all health checks. Use -Force to override." "ERROR"
        exit 1
    }
}

Write-Log "Health check summary: $HealthyServices/$TotalServices services healthy" "INFO"

if ($HealthyServices -lt $TotalServices -and -not $Force) {
    Write-Log "❌ Not all services are healthy. Use -Force to proceed anyway." "ERROR"
    exit 1
}

# Dry run mode - show what would be done
if ($DryRun) {
    Write-Log "=== DRY RUN MODE - No changes will be made ===" "INFO"
    Write-Log "Would switch from '$CurrentEnv' to '$TargetEnvironment'" "INFO"
    Write-Log "Would copy: $SourceMapping -> $EnvMappingPath" "INFO"
    Write-Log "Would reload nginx configuration" "INFO"
    Write-Log "=== DRY RUN COMPLETE ===" "SUCCESS"
    exit 0
}

# Perform the switch
Write-Log "=== Performing Environment Switch ===" "INFO"

# Backup current mapping
$BackupPath = "$EnvMappingPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $EnvMappingPath $BackupPath -Force
Write-Log "Current mapping backed up to: $BackupPath" "INFO"

# Update environment mapping with version and timestamp
$MappingContent = Get-Content $SourceMapping -Raw
$MappingContent = $MappingContent -replace "AUTO_GENERATED", (Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")
$MappingContent = $MappingContent -replace "DEPLOYMENT_VERSION", $Version
$MappingContent = $MappingContent -replace "SWITCH_TIMESTAMP", (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")

# Atomic switch - write to temp file then move
$TempMapping = "$EnvMappingPath.tmp"
$MappingContent | Set-Content $TempMapping -NoNewline

# Test configuration with new mapping
Copy-Item $TempMapping $EnvMappingPath -Force
$ConfigTest = Test-NginxConfiguration

if (-not $ConfigTest) {
    Write-Log "❌ Configuration test failed. Rolling back..." "ERROR"
    Copy-Item $BackupPath $EnvMappingPath -Force
    Remove-Item $TempMapping -Force
    exit 1
}

# Reload nginx
$ReloadSuccess = Restart-Nginx

if (-not $ReloadSuccess) {
    Write-Log "❌ Nginx reload failed. Rolling back..." "ERROR"
    Copy-Item $BackupPath $EnvMappingPath -Force
    Restart-Nginx
    Remove-Item $TempMapping -Force
    exit 1
}

# Clean up temp file
Remove-Item $TempMapping -Force

# Verify the switch
Start-Sleep -Seconds 3
$NewEnv = Get-CurrentEnvironment
if ($NewEnv -eq $TargetEnvironment) {
    Write-Log "✅ Environment switch completed successfully" "SUCCESS"
    Write-Log "Active environment: $NewEnv" "SUCCESS"
} else {
    Write-Log "❌ Environment switch verification failed" "ERROR"
    Write-Log "Expected: $TargetEnvironment, Got: $NewEnv" "ERROR"
    exit 1
}

# Post-switch health verification
Write-Log "=== Post-Switch Health Verification ===" "INFO"

$ProductionChecks = @(
    @{ Name = "Production WebApp"; Url = "http://localhost/health" },
    @{ Name = "Production Inference"; Url = "http://localhost/api/inference/health" },
    @{ Name = "Production Dashboard"; Url = "http://localhost/dashboard/" }
)

$PostSwitchHealthy = 0
foreach ($Check in $ProductionChecks) {
    if (Test-ServiceHealth -ServiceName $Check.Name -Url $Check.Url) {
        $PostSwitchHealthy++
    }
}

Write-Log "Post-switch health: $PostSwitchHealthy/$($ProductionChecks.Count) endpoints healthy" "INFO"

# Summary
Write-Log "=== Switch Summary ===" "INFO"
Write-Log "Previous environment: $CurrentEnv" "INFO"
Write-Log "New environment: $TargetEnvironment" "INFO"
Write-Log "Version: $Version" "INFO"
Write-Log "Switch completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')" "INFO"
Write-Log "Log file: $LogFile" "INFO"

# Create deployment status file
$StatusFile = "D:\logs\aitb\deployment\current-deployment.json"
$DeploymentStatus = @{
    environment = $TargetEnvironment
    version = $Version
    switchTime = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    previousEnvironment = $CurrentEnv
    healthyServices = $PostSwitchHealthy
    totalServices = $ProductionChecks.Count
    logFile = $LogFile
    backupFile = $BackupPath
} | ConvertTo-Json -Depth 3

$DeploymentStatus | Set-Content $StatusFile

Write-Log "=== ENVIRONMENT SWITCH COMPLETE ===" "SUCCESS"
Write-Host ""
Write-Host "🎯 Environment switched to: $TargetEnvironment" -ForegroundColor Green
Write-Host "📊 Health status: $PostSwitchHealthy/$($ProductionChecks.Count) services healthy" -ForegroundColor $(if ($PostSwitchHealthy -eq $ProductionChecks.Count) { "Green" } else { "Yellow" })
Write-Host "📝 Full log: $LogFile" -ForegroundColor Cyan
Write-Host ""