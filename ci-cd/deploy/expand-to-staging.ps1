#Requires -Version 5.1

<#
.SYNOPSIS
    Expand dist/*.zip files to D:\apps\aitb\<service>\green\<version>\ staging slots
    
.DESCRIPTION
    Episode 5 deployment script that:
    - Extracts build artifacts to green staging slots
    - Creates proper directory structure
    - Sets up Python virtual environments for Python services
    - Prepares services for NSSM registration (without starting)
    
.PARAMETER Version
    Version number for the deployment (e.g., "1.0.0")
    
.PARAMETER DistPath
    Path to dist folder containing zip files (default: ".\dist")
    
.EXAMPLE
    .\expand-to-staging.ps1 -Version "1.0.0"
    
.EXAMPLE
    .\expand-to-staging.ps1 -Version "1.0.0" -DistPath "D:\AITB\dist"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    
    [Parameter(Mandatory = $false)]
    [string]$DistPath = ".\dist"
)

# Configuration
$AITB_ROOT = "D:\apps\aitb"
$LOGS_ROOT = "D:\logs\aitb"
$GREEN_SLOT = "green"

# Service definitions
$SERVICES = @(
    @{
        Name = "webapp"
        Type = "dotnet"
        Port = 5000
        ExecutablePath = "AITB.WebApp.exe"
    },
    @{
        Name = "inference"
        Type = "python"
        Port = 8001
        ExecutablePath = "main.py"
        Requirements = "requirements.txt"
    },
    @{
        Name = "bot"
        Type = "python"
        Port = $null
        ExecutablePath = "main.py"
        Requirements = "requirements.txt"
    },
    @{
        Name = "notifier"
        Type = "python"
        Port = $null
        ExecutablePath = "main.py"
        Requirements = "requirements.txt"
    },
    @{
        Name = "dashboard"
        Type = "python"
        Port = 8501
        ExecutablePath = "app.py"
        Requirements = "requirements.txt"
    }
)

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

function Ensure-Directory {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-Log "Creating directory: $Path"
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Extract-ServiceZip {
    param(
        [string]$ServiceName,
        [string]$ZipPath,
        [string]$DestinationPath
    )
    
    Write-Log "Extracting $ServiceName from $ZipPath to $DestinationPath"
    
    try {
        # Ensure destination exists
        Ensure-Directory -Path $DestinationPath
        
        # Extract zip file
        Expand-Archive -Path $ZipPath -DestinationPath $DestinationPath -Force
        
        Write-Log "Successfully extracted $ServiceName" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to extract $ServiceName`: $_" -Level "ERROR"
        return $false
    }
}

function Setup-PythonVenv {
    param(
        [string]$ServiceName,
        [string]$ServicePath,
        [string]$RequirementsFile
    )
    
    Write-Log "Setting up Python virtual environment for $ServiceName"
    
    $venvPath = Join-Path $ServicePath ".venv"
    $requirementsPath = Join-Path $ServicePath $RequirementsFile
    
    try {
        # Create virtual environment
        Write-Log "Creating virtual environment at $venvPath"
        python -m venv $venvPath
        
        if (-not $?) {
            throw "Failed to create virtual environment"
        }
        
        # Activate virtual environment and install dependencies
        $activateScript = Join-Path $venvPath "Scripts\Activate.ps1"
        
        if (Test-Path $requirementsPath) {
            Write-Log "Installing dependencies from $RequirementsFile"
            
            # Use direct pip call instead of activation for better error handling
            $pipPath = Join-Path $venvPath "Scripts\pip.exe"
            & $pipPath install --upgrade pip
            & $pipPath install -r $requirementsPath
            
            if (-not $?) {
                throw "Failed to install requirements"
            }
        } else {
            Write-Log "No $RequirementsFile found, skipping dependency installation" -Level "WARN"
        }
        
        Write-Log "Python virtual environment setup completed for $ServiceName" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to setup Python virtual environment for $ServiceName`: $_" -Level "ERROR"
        return $false
    }
}

function Deploy-Service {
    param($Service)
    
    $serviceName = $Service.Name
    Write-Log "Deploying service: $serviceName"
    
    # Define paths
    $zipFile = Join-Path $DistPath "$serviceName.zip"
    $servicePath = Join-Path $AITB_ROOT "$serviceName\$GREEN_SLOT\$Version"
    $logPath = Join-Path $LOGS_ROOT $serviceName
    
    # Check if zip file exists
    if (-not (Test-Path $zipFile)) {
        Write-Log "Zip file not found: $zipFile" -Level "ERROR"
        return $false
    }
    
    # Create log directory
    Ensure-Directory -Path $logPath
    
    # Extract service
    $extractSuccess = Extract-ServiceZip -ServiceName $serviceName -ZipPath $zipFile -DestinationPath $servicePath
    if (-not $extractSuccess) {
        return $false
    }
    
    # Setup Python virtual environment if needed
    if ($Service.Type -eq "python") {
        $venvSuccess = Setup-PythonVenv -ServiceName $serviceName -ServicePath $servicePath -RequirementsFile $Service.Requirements
        if (-not $venvSuccess) {
            return $false
        }
    }
    
    Write-Log "Service $serviceName deployed successfully to $servicePath" -Level "SUCCESS"
    return $true
}

# Main execution
Write-Log "Starting AITB Episode 5 deployment to staging slots"
Write-Log "Version: $Version"
Write-Log "Distribution path: $DistPath"
Write-Log "Target root: $AITB_ROOT"

# Validate inputs
if (-not (Test-Path $DistPath)) {
    Write-Log "Distribution path does not exist: $DistPath" -Level "ERROR"
    exit 1
}

# Create base directories
Write-Log "Creating base directory structure"
Ensure-Directory -Path $AITB_ROOT
Ensure-Directory -Path $LOGS_ROOT

# Deploy each service
$deploymentResults = @{}
$overallSuccess = $true

foreach ($service in $SERVICES) {
    $success = Deploy-Service -Service $service
    $deploymentResults[$service.Name] = $success
    
    if (-not $success) {
        $overallSuccess = $false
    }
}

# Report results
Write-Log "`n=== DEPLOYMENT SUMMARY ===" -Level "INFO"
foreach ($service in $SERVICES) {
    $status = if ($deploymentResults[$service.Name]) { "SUCCESS" } else { "FAILED" }
    $level = if ($deploymentResults[$service.Name]) { "SUCCESS" } else { "ERROR" }
    Write-Log "$($service.Name): $status" -Level $level
}

Write-Log "`n=== DEPLOYMENT PATHS ===" -Level "INFO"
foreach ($service in $SERVICES) {
    if ($deploymentResults[$service.Name]) {
        $servicePath = Join-Path $AITB_ROOT "$($service.Name)\$GREEN_SLOT\$Version"
        Write-Log "$($service.Name): $servicePath"
    }
}

if ($overallSuccess) {
    Write-Log "`nAll services deployed successfully to green staging slots!" -Level "SUCCESS"
    Write-Log "Next step: Run NSSM service installation scripts" -Level "INFO"
    exit 0
} else {
    Write-Log "`nSome services failed to deploy. Check errors above." -Level "ERROR"
    exit 1
}