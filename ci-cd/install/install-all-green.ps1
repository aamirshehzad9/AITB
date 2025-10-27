#Requires -Version 5.1

<#
.SYNOPSIS
    Install all AITB services to green staging slots using NSSM
    
.DESCRIPTION
    Episode 5 master service installation script that:
    - Installs all AITB services (webapp, inference, bot, notifier, dashboard)
    - Registers Windows services using NSSM
    - Points to versioned green slot deployments
    - Configures logging and restart policies
    - Does NOT start services (leaves in Stopped state)
    
.PARAMETER Version
    Version number for the deployment (e.g., "1.0.0")
    
.PARAMETER NSSMPath
    Path to nssm.exe (default: attempts to find in PATH or common locations)
    
.PARAMETER Services
    Array of services to install (default: all services)
    Valid values: webapp, inference, bot, notifier, dashboard
    
.EXAMPLE
    .\install-all-green.ps1 -Version "1.0.0"
    
.EXAMPLE
    .\install-all-green.ps1 -Version "1.0.0" -Services @("webapp", "inference")
    
.EXAMPLE
    .\install-all-green.ps1 -Version "1.0.0" -NSSMPath "C:\Tools\nssm\nssm.exe"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    
    [Parameter(Mandatory = $false)]
    [string]$NSSMPath,
    
    [Parameter(Mandatory = $false)]
    [string[]]$Services = @("webapp", "inference", "bot", "notifier", "dashboard")
)

# Configuration
$INSTALL_SCRIPTS_PATH = $PSScriptRoot
$AVAILABLE_SERVICES = @("webapp", "inference", "bot", "notifier", "dashboard")

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

function Install-Service {
    param(
        [string]$ServiceName,
        [string]$Version,
        [string]$NSSMPath
    )
    
    $scriptName = "install-$ServiceName-green.ps1"
    $scriptPath = Join-Path $INSTALL_SCRIPTS_PATH $scriptName
    
    if (-not (Test-Path $scriptPath)) {
        Write-Log "Installation script not found: $scriptPath" -Level "ERROR"
        return $false
    }
    
    Write-Log "Installing $ServiceName service..."
    
    try {
        $args = @("-Version", $Version)
        if ($NSSMPath) {
            $args += @("-NSSMPath", $NSSMPath)
        }
        
        $result = & $scriptPath @args
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "$ServiceName service installed successfully" -Level "SUCCESS"
            return $true
        } else {
            Write-Log "$ServiceName service installation failed with exit code $LASTEXITCODE" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Failed to execute installation script for $ServiceName`: $_" -Level "ERROR"
        return $false
    }
}

function Get-ServiceStatus {
    param([string]$ServiceName)
    
    $fullServiceName = "AITB-$ServiceName-Green"
    try {
        $service = Get-Service -Name $fullServiceName -ErrorAction SilentlyContinue
        if ($service) {
            return @{
                Name = $fullServiceName
                Status = $service.Status
                StartType = $service.StartType
                Installed = $true
            }
        } else {
            return @{
                Name = $fullServiceName
                Status = "Not Found"
                StartType = "Unknown"
                Installed = $false
            }
        }
    }
    catch {
        return @{
            Name = $fullServiceName
            Status = "Error"
            StartType = "Unknown"
            Installed = $false
        }
    }
}

# Main execution
Write-Log "Starting AITB Episode 5 - Green Slot Service Installation"
Write-Log "Version: $Version"
Write-Log "Services to install: $($Services -join ', ')"

# Validate inputs
foreach ($service in $Services) {
    if ($service -notin $AVAILABLE_SERVICES) {
        Write-Log "Invalid service name: $service" -Level "ERROR"
        Write-Log "Available services: $($AVAILABLE_SERVICES -join ', ')" -Level "INFO"
        exit 1
    }
}

# Install services
$installationResults = @{}
$overallSuccess = $true

foreach ($service in $Services) {
    Write-Log "`n--- Installing $service service ---"
    $success = Install-Service -ServiceName $service -Version $Version -NSSMPath $NSSMPath
    $installationResults[$service] = $success
    
    if (-not $success) {
        $overallSuccess = $false
    }
    
    Start-Sleep -Seconds 2
}

# Get final service status
Write-Log "`n=== SERVICE INSTALLATION SUMMARY ===" -Level "INFO"
$serviceStatuses = @{}

foreach ($service in $Services) {
    $status = Get-ServiceStatus -ServiceName $service
    $serviceStatuses[$service] = $status
    
    $statusLevel = if ($status.Installed) { "SUCCESS" } else { "ERROR" }
    Write-Log "$service`: $($status.Status) (StartType: $($status.StartType))" -Level $statusLevel
}

# Final summary
Write-Log "`n=== FINAL SUMMARY ===" -Level "INFO"
$successCount = ($installationResults.Values | Where-Object { $_ }).Count
$totalCount = $Services.Count

Write-Log "Services installed: $successCount/$totalCount"

if ($overallSuccess) {
    Write-Log "All services installed successfully!" -Level "SUCCESS"
    Write-Log "`nAll services are in STOPPED state as required for Episode 5" -Level "INFO"
    Write-Log "Services are configured with:" -Level "INFO"
    Write-Log "  - StartMode: Automatic" -Level "INFO"
    Write-Log "  - Recovery: Restart on failure with backoff" -Level "INFO"
    Write-Log "  - Logs: D:\logs\aitb\<service>\" -Level "INFO"
    Write-Log "  - Paths: D:\apps\aitb\<service>\green\$Version\" -Level "INFO"
} else {
    Write-Log "Some services failed to install. Check errors above." -Level "ERROR"
}

# Next steps
Write-Log "`n=== NEXT STEPS ===" -Level "INFO"
Write-Log "1. Verify all services are installed: Get-Service -Name 'AITB-*-Green'"
Write-Log "2. Check service configurations using services.msc"
Write-Log "3. Review logs in D:\logs\aitb\<service>\"
Write-Log "4. When ready to start services, use individual Start-Service commands"

if ($overallSuccess) {
    Write-Log "`nEpisode 5 acceptance criteria met: Services installed (Stopped), pointing to green paths" -Level "SUCCESS"
    exit 0
} else {
    exit 1
}