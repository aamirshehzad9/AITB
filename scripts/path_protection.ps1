# AITB Path Protection Script
# ⚠️ MANDATORY: Agents MUST read /context/project_manifest.yaml before any action.
# Prevents duplicate directory creation and validates workspace integrity

$ErrorActionPreference = "Stop"
$root = "D:\AITB"
$wrong = "D:\GentleOmega\AITB"
$logFile = "D:\AITB\logs\path_validator.log"

# Ensure logs directory exists
if (!(Test-Path "D:\AITB\logs")) {
    New-Item -ItemType Directory -Path "D:\AITB\logs" -Force
}

# Log function
function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    Write-Host $logEntry
    Add-Content -Path $logFile -Value $logEntry
}

Write-Log "AITB Path Protection Starting..."

# Check for wrong path and remove if exists
if (Test-Path $wrong) {
    Write-Log "WARNING: Wrong path detected: $wrong"
    try {
        # Stop any running dotnet processes first
        Get-Process | Where-Object {$_.ProcessName -like "*dotnet*"} | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        
        Remove-Item -Recurse -Force $wrong -ErrorAction Stop
        Write-Log "SUCCESS: Removed duplicate directory: $wrong"
    }
    catch {
        Write-Log "ERROR: Failed to remove $wrong : $($_.Exception.Message)"
        Write-Host "WARNING: Manual cleanup required for $wrong"
    }
}

# Validate correct AITB root exists
if (!(Test-Path $root)) {
    Write-Log "ERROR: AITB root missing: $root"
    throw "AITB root directory missing - STOP BUILD"
}

# Validate required subdirectories
$requiredDirs = @(
    "AITB.WebApp",
    "config", 
    "services", 
    "data", 
    "docs", 
    "logs", 
    "scripts"
)

$missingDirs = @()
foreach ($dir in $requiredDirs) {
    $fullPath = Join-Path $root $dir
    if (!(Test-Path $fullPath)) {
        $missingDirs += $dir
        Write-Log "ERROR: Missing required directory: $dir"
    }
}

if ($missingDirs.Count -gt 0) {
    Write-Log "ERROR: Missing directories: $($missingDirs -join ', ')"
    throw "Required AITB directories missing - STOP BUILD"
}

# All validations passed
Write-Log "SUCCESS: All path validations passed"
Write-Log "SUCCESS: AITB workspace integrity confirmed"
Write-Log "Path Protection Complete"

return $true