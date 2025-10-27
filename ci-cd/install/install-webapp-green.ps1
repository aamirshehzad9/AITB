#Requires -Version 5.1

<#
.SYNOPSIS
    Install AITB WebApp service to green staging slot using NSSM
    
.DESCRIPTION
    Episode 5 service installation script that:
    - Registers Windows service using NSSM
    - Points to versioned green slot deployment
    - Configures logging to D:\logs\aitb\webapp\
    - Sets StartMode=auto with restart recovery
    - Does NOT start the service (leaves in Stopped state)
    
.PARAMETER Version
    Version number for the deployment (e.g., "1.0.0")
    
.PARAMETER NSSMPath
    Path to nssm.exe (default: attempts to find in PATH or common locations)
    
.EXAMPLE
    .\install-webapp-green.ps1 -Version "1.0.0"
    
.EXAMPLE
    .\install-webapp-green.ps1 -Version "1.0.0" -NSSMPath "C:\Tools\nssm\nssm.exe"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    
    [Parameter(Mandatory = $false)]
    [string]$NSSMPath
)

# Configuration
$SERVICE_NAME = "AITB-WebApp-Green"
$SERVICE_DISPLAY_NAME = "AITB WebApp (Green Slot)"
$SERVICE_DESCRIPTION = "AI Trading Bot WebApp service running in green staging slot"

$AITB_ROOT = "D:\apps\aitb"
$LOGS_ROOT = "D:\logs\aitb"
$GREEN_SLOT = "green"

$SERVICE_PATH = Join-Path $AITB_ROOT "webapp\$GREEN_SLOT\$Version"
$EXECUTABLE_PATH = Join-Path $SERVICE_PATH "AITB.WebApp.exe"
$LOG_PATH = Join-Path $LOGS_ROOT "webapp"
$STDOUT_LOG = Join-Path $LOG_PATH "webapp-green-stdout.log"
$STDERR_LOG = Join-Path $LOG_PATH "webapp-green-stderr.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            default { "White" }
        }
    )
}

function Find-NSSM {
    # Try provided path first
    if ($NSSMPath -and (Test-Path $NSSMPath)) {
        return $NSSMPath
    }
    
    # Try PATH
    $nssmInPath = Get-Command "nssm.exe" -ErrorAction SilentlyContinue
    if ($nssmInPath) {
        return $nssmInPath.Source
    }
    
    # Try common locations
    $commonPaths = @(
        "C:\Tools\nssm\nssm.exe",
        "C:\Program Files\nssm\nssm.exe",
        "C:\nssm\nssm.exe",
        "$env:ProgramFiles\nssm\nssm.exe",
        "${env:ProgramFiles(x86)}\nssm\nssm.exe"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    return $null
}

function Test-ServiceExists {
    param([string]$ServiceName)
    
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        return $service -ne $null
    }
    catch {
        return $false
    }
}

function Remove-ExistingService {
    param([string]$ServiceName, [string]$NSSMExe)
    
    Write-Log "Removing existing service: $ServiceName"
    
    try {
        # Stop service if running
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq "Running") {
            Write-Log "Stopping running service: $ServiceName"
            Stop-Service -Name $ServiceName -Force
            Start-Sleep -Seconds 5
        }
        
        # Remove service using NSSM
        & $NSSMExe remove $ServiceName confirm
        if ($LASTEXITCODE -ne 0) {
            throw "NSSM remove failed with exit code $LASTEXITCODE"
        }
        
        Write-Log "Successfully removed existing service: $ServiceName" -Level "SUCCESS"
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Log "Failed to remove existing service: $_" -Level "ERROR"
        throw
    }
}

function Install-WebAppService {
    param([string]$NSSMExe)
    
    Write-Log "Installing AITB WebApp service using NSSM"
    
    try {
        # Install service
        Write-Log "Installing service: $SERVICE_NAME"
        & $NSSMExe install $SERVICE_NAME $EXECUTABLE_PATH
        if ($LASTEXITCODE -ne 0) {
            throw "NSSM install failed with exit code $LASTEXITCODE"
        }
        
        # Set service display name
        & $NSSMExe set $SERVICE_NAME DisplayName $SERVICE_DISPLAY_NAME
        
        # Set service description
        & $NSSMExe set $SERVICE_NAME Description $SERVICE_DESCRIPTION
        
        # Set working directory
        & $NSSMExe set $SERVICE_NAME AppDirectory $SERVICE_PATH
        
        # Configure logging
        & $NSSMExe set $SERVICE_NAME AppStdout $STDOUT_LOG
        & $NSSMExe set $SERVICE_NAME AppStderr $STDERR_LOG
        
        # Set startup type to automatic
        & $NSSMExe set $SERVICE_NAME Start SERVICE_AUTO_START
        
        # Configure restart policy
        & $NSSMExe set $SERVICE_NAME AppExit Default Restart
        & $NSSMExe set $SERVICE_NAME AppRestartDelay 5000  # 5 seconds
        & $NSSMExe set $SERVICE_NAME AppThrottle 10000     # 10 seconds throttle
        
        # Set environment variables (if needed)
        & $NSSMExe set $SERVICE_NAME AppEnvironmentExtra "ASPNETCORE_ENVIRONMENT=Staging"
        
        Write-Log "Service installed successfully: $SERVICE_NAME" -Level "SUCCESS"
        
        # Verify service exists but don't start it
        $service = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
        if ($service) {
            Write-Log "Service status: $($service.Status)" -Level "INFO"
            Write-Log "Service startup type: $($service.StartType)" -Level "INFO"
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to install service: $_" -Level "ERROR"
        return $false
    }
}

# Main execution
Write-Log "Starting AITB WebApp Green service installation"
Write-Log "Version: $Version"
Write-Log "Service name: $SERVICE_NAME"

# Validate version deployment exists
if (-not (Test-Path $SERVICE_PATH)) {
    Write-Log "Service deployment path does not exist: $SERVICE_PATH" -Level "ERROR"
    Write-Log "Please run expand-to-staging.ps1 first" -Level "ERROR"
    exit 1
}

if (-not (Test-Path $EXECUTABLE_PATH)) {
    Write-Log "Service executable not found: $EXECUTABLE_PATH" -Level "ERROR"
    exit 1
}

# Find NSSM
$nssmExe = Find-NSSM
if (-not $nssmExe) {
    Write-Log "NSSM not found. Please install NSSM or provide path with -NSSMPath" -Level "ERROR"
    Write-Log "Download from: https://nssm.cc/download" -Level "INFO"
    exit 1
}

Write-Log "Using NSSM: $nssmExe"

# Ensure log directory exists
if (-not (Test-Path $LOG_PATH)) {
    Write-Log "Creating log directory: $LOG_PATH"
    New-Item -ItemType Directory -Path $LOG_PATH -Force | Out-Null
}

# Check if service already exists
if (Test-ServiceExists -ServiceName $SERVICE_NAME) {
    Write-Log "Service already exists: $SERVICE_NAME" -Level "WARN"
    Remove-ExistingService -ServiceName $SERVICE_NAME -NSSMExe $nssmExe
}

# Install service
$success = Install-WebAppService -NSSMExe $nssmExe

if ($success) {
    Write-Log "`n=== INSTALLATION SUMMARY ===" -Level "SUCCESS"
    Write-Log "Service Name: $SERVICE_NAME"
    Write-Log "Display Name: $SERVICE_DISPLAY_NAME"
    Write-Log "Executable: $EXECUTABLE_PATH"
    Write-Log "Working Directory: $SERVICE_PATH"
    Write-Log "Stdout Log: $STDOUT_LOG"
    Write-Log "Stderr Log: $STDERR_LOG"
    Write-Log "Status: Installed (Stopped)"
    Write-Log "`nTo start the service: Start-Service -Name '$SERVICE_NAME'"
    Write-Log "To check status: Get-Service -Name '$SERVICE_NAME'"
    exit 0
} else {
    Write-Log "Service installation failed" -Level "ERROR"
    exit 1
}