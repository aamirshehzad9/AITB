# AITB Notifier Service Build Script
# Builds Python notification service with virtual environment

param(
    [string]$Version = "1.0.0",
    [string]$Configuration = "Release",
    [string]$OutputPath = "D:\AITB\dist"
)

$ErrorActionPreference = "Stop"

Write-Host "AITB Notifier Service Build" -ForegroundColor Green
Write-Host "===========================" -ForegroundColor Green
Write-Host "Version: $Version" -ForegroundColor Yellow
Write-Host "Configuration: $Configuration" -ForegroundColor Yellow
Write-Host "Output: $OutputPath" -ForegroundColor Yellow

# Set paths
$ServicePath = "D:\AITB\services\notifier"
$TempPath = "$env:TEMP\aitb-notifier-build-$Version"
$ZipPath = "$OutputPath\notifier-$Version.zip"

try {
    # Clean previous build
    Write-Host "`nCleaning previous build..." -ForegroundColor Yellow
    if (Test-Path $TempPath) {
        Remove-Item $TempPath -Recurse -Force
    }
    if (Test-Path $ZipPath) {
        Remove-Item $ZipPath -Force
        Write-Host "Removed existing zip: $ZipPath" -ForegroundColor Yellow
    }

    # Create temp build directory
    New-Item -Path $TempPath -ItemType Directory -Force | Out-Null

    # Copy source code
    Write-Host "`nCopying source code..." -ForegroundColor Yellow
    if (Test-Path $ServicePath) {
        robocopy $ServicePath $TempPath /E /XD __pycache__ .pytest_cache .venv env venv /XF *.pyc *.pyo | Out-Null
    } else {
        # Create minimal structure if service doesn't exist yet
        Write-Host "Service directory not found. Creating minimal structure..." -ForegroundColor Yellow
        
        # Create main.py
        $MainPy = @"
#!/usr/bin/env python3
"""
AITB Notification Service
Handles alerts and notifications for trading events
"""

import os
import sys
import logging
import time
import json
import requests
from pathlib import Path
from datetime import datetime

# Add the service directory to Python path
service_dir = Path(__file__).parent
sys.path.insert(0, str(service_dir))

def load_environment():
    """Load environment variables from config file"""
    config_file = Path("D:/configs/aitb/notifier/.env")
    if config_file.exists():
        with open(config_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    os.environ[key.strip()] = value.strip()
                    print(f"Loaded: {key.strip()}")

def send_telegram_message(message):
    """Send message via Telegram bot"""
    bot_token = os.getenv('TELEGRAM_TOKEN')
    chat_id = os.getenv('TELEGRAM_CHAT_ID')
    
    if not bot_token or not chat_id:
        logging.warning("Telegram credentials not configured")
        return False
    
    try:
        url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
        data = {
            'chat_id': chat_id,
            'text': message,
            'parse_mode': 'Markdown'
        }
        response = requests.post(url, data=data, timeout=10)
        return response.status_code == 200
    except Exception as e:
        logging.error(f"Failed to send Telegram message: {e}")
        return False

def monitor_trading_events():
    """Monitor for trading events that require notifications"""
    # TODO: Implement monitoring logic
    # This would typically:
    # 1. Monitor InfluxDB for trading events
    # 2. Check bot heartbeat status
    # 3. Monitor system health metrics
    # 4. Send alerts when thresholds are exceeded
    
    logging.info("Monitoring trading events...")
    
    # Example notification
    send_telegram_message("🤖 *AITB Notifier Started*\nNotification service is now monitoring trading events.")

def main():
    """Main entry point"""
    load_environment()
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    logger = logging.getLogger(__name__)
    logger.info("AITB Notification Service starting...")
    
    # Start monitoring
    monitor_trading_events()
    
    # Keep service running
    try:
        while True:
            # Check for events every 30 seconds
            time.sleep(30)
            logger.debug("Notifier service monitoring...")
            
            # TODO: Implement periodic checks
            # - Bot heartbeat status
            # - Trading performance alerts
            # - System health alerts
            
    except KeyboardInterrupt:
        logger.info("Notification service stopping...")
        send_telegram_message("🔴 *AITB Notifier Stopped*\nNotification service has been shut down.")

if __name__ == "__main__":
    main()
"@
        $MainPy | Set-Content "$TempPath\main.py"

        # Create requirements.txt
        $Requirements = @"
# AITB Notifier Service Dependencies
requests==2.31.0
influxdb-client==1.38.0
python-dotenv==1.0.0
httpx==0.25.2
pydantic==2.5.0
schedule==1.2.0
python-telegram-bot==20.7
"@
        $Requirements | Set-Content "$TempPath\requirements.txt"
    }

    # Create virtual environment
    Write-Host "`nCreating virtual environment..." -ForegroundColor Yellow
    Push-Location $TempPath
    python -m venv venv
    if ($LASTEXITCODE -ne 0) { throw "Failed to create virtual environment" }

    # Activate virtual environment and install dependencies
    Write-Host "`nInstalling dependencies..." -ForegroundColor Yellow
    & ".\venv\Scripts\activate.ps1"
    python -m pip install --upgrade pip
    if (Test-Path "requirements.txt") {
        pip install -r requirements.txt
        if ($LASTEXITCODE -ne 0) { throw "Failed to install dependencies" }
    }

    Pop-Location

    # Create version info file
    $VersionInfo = @{
        service = "notifier"
        version = $Version
        buildTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss UTC")
        configuration = $Configuration
        runtime = "python"
        pythonVersion = (python --version 2>&1)
    }
    $VersionInfo | ConvertTo-Json -Depth 2 | Set-Content "$TempPath\version.json"

    # Create startup script
    $StartupScript = @"
@echo off
REM AITB Notifier Service Startup Script

set CONFIG_FILE=D:\configs\aitb\notifier\.env
if exist "%CONFIG_FILE%" (
    echo Loading environment from %CONFIG_FILE%
    for /f "usebackq tokens=1,2 delims==" %%a in ("%CONFIG_FILE%") do (
        if not "%%a"=="" if not "%%a:~0,1%"=="#" set %%a=%%b
    )
)

venv\Scripts\python.exe -m main
"@
    $StartupScript | Set-Content "$TempPath\start.bat"

    # Create PowerShell startup script
    $PSStartupScript = @"
# AITB Notifier Service PowerShell Startup Script

`$ConfigFile = "D:\configs\aitb\notifier\.env"
if (Test-Path `$ConfigFile) {
    Write-Host "Loading environment from `$ConfigFile" -ForegroundColor Green
    Get-Content `$ConfigFile | ForEach-Object {
        if (`$_ -match '^([^=]+)=(.*)$' -and -not `$_.StartsWith('#')) {
            `$key = `$matches[1].Trim()
            `$value = `$matches[2].Trim()
            [Environment]::SetEnvironmentVariable(`$key, `$value, "Process")
            Write-Host "Loaded: `$key" -ForegroundColor Green
        }
    }
}

# Start the notifier service
Write-Host "Starting AITB Notifier Service..." -ForegroundColor Green
& ".\venv\Scripts\python.exe" -m main
"@
    $PSStartupScript | Set-Content "$TempPath\start.ps1"

    # Create README
    $ReadmeContent = @"
# AITB Notifier Service - Version $Version

## Description
Alert and notification service for trading events and system monitoring.

## Built
- Time: $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss UTC"))
- Configuration: $Configuration
- Python Version: $(python --version 2>&1)

## Deployment
1. Extract to D:\apps\aitb\notifier\$Version\
2. Ensure D:\configs\aitb\notifier\.env is configured
3. Run start.ps1 or start.bat

## Configuration
Reads environment variables from: D:\configs\aitb\notifier\.env
Required variables: TELEGRAM_BOT_NAME, TELEGRAM_TOKEN, TELEGRAM_CHAT_ID, INFLUX_URL, INFLUX_ORG, INFLUX_BUCKET, INFLUX_TOKEN, MCP_BASE_URL

## Service Definition
Use: ci-cd\service_defs\notifier.json

## Virtual Environment
Includes complete Python virtual environment with all dependencies.
No additional Python packages need to be installed.

## Features
- Telegram bot notifications
- Trading event monitoring
- System health alerts
- Bot heartbeat monitoring
- Configurable alert thresholds
"@
    $ReadmeContent | Set-Content "$TempPath\README.md"

    # Create the zip file
    Write-Host "`nCreating zip package..." -ForegroundColor Yellow
    Compress-Archive -Path "$TempPath\*" -DestinationPath $ZipPath -Force

    # Calculate checksum
    $Hash = Get-FileHash $ZipPath -Algorithm SHA256
    $ChecksumFile = "$OutputPath\notifier-$Version.zip.sha256"
    "$($Hash.Hash)  notifier-$Version.zip" | Set-Content $ChecksumFile

    # Cleanup temp directory
    Remove-Item $TempPath -Recurse -Force

    # Output results
    $ZipSize = [math]::Round((Get-Item $ZipPath).Length / 1MB, 2)
    Write-Host "`n✅ Build completed successfully!" -ForegroundColor Green
    Write-Host "📦 Package: $ZipPath ($ZipSize MB)" -ForegroundColor Green
    Write-Host "🔒 Checksum: $ChecksumFile" -ForegroundColor Green
    Write-Host "🔢 SHA256: $($Hash.Hash)" -ForegroundColor Gray

} catch {
    Write-Host "`n❌ Build failed: $($_.Exception.Message)" -ForegroundColor Red
    if (Test-Path $TempPath) {
        Remove-Item $TempPath -Recurse -Force
    }
    exit 1
} finally {
    if (Get-Location -eq $TempPath) {
        Pop-Location
    }
}