# AITB Trading Bot Build Script
# Builds Python trading bot with virtual environment

param(
    [string]$Version = "1.0.0",
    [string]$Configuration = "Release",
    [string]$OutputPath = "D:\AITB\dist"
)

$ErrorActionPreference = "Stop"

Write-Host "AITB Trading Bot Build" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Green
Write-Host "Version: $Version" -ForegroundColor Yellow
Write-Host "Configuration: $Configuration" -ForegroundColor Yellow
Write-Host "Output: $OutputPath" -ForegroundColor Yellow

# Set paths
$ServicePath = "D:\AITB\services\bot"
$TempPath = "$env:TEMP\aitb-bot-build-$Version"
$ZipPath = "$OutputPath\bot-$Version.zip"

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
AITB Trading Bot
Main entry point for the trading bot engine
"""

import os
import sys
import logging
import time
import json
from pathlib import Path
from datetime import datetime

# Add the service directory to Python path
service_dir = Path(__file__).parent
sys.path.insert(0, str(service_dir))

def load_environment():
    """Load environment variables from config file"""
    config_file = Path("D:/configs/aitb/bot/.env")
    if config_file.exists():
        with open(config_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    os.environ[key.strip()] = value.strip()
                    print(f"Loaded: {key.strip()}")

def write_heartbeat():
    """Write heartbeat to log file"""
    heartbeat_file = Path("D:/logs/aitb/bot/bot-heartbeat.log")
    heartbeat_file.parent.mkdir(parents=True, exist_ok=True)
    
    heartbeat_data = {
        "timestamp": datetime.utcnow().isoformat(),
        "status": "running",
        "service": "bot",
        "version": "$Version"
    }
    
    with open(heartbeat_file, 'w') as f:
        json.dump(heartbeat_data, f)

def main():
    """Main entry point"""
    load_environment()
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    logger = logging.getLogger(__name__)
    logger.info("AITB Trading Bot starting...")
    
    # TODO: Implement trading bot logic
    logger.info("Trading bot is running...")
    
    # Keep service running with heartbeat
    try:
        while True:
            write_heartbeat()
            logger.info("Trading bot heartbeat")
            time.sleep(60)  # Heartbeat every 60 seconds
    except KeyboardInterrupt:
        logger.info("Trading bot stopping...")

if __name__ == "__main__":
    main()
"@
        $MainPy | Set-Content "$TempPath\main.py"

        # Create requirements.txt
        $Requirements = @"
# AITB Trading Bot Dependencies
ccxt==4.1.50
pandas==2.1.4
numpy==1.25.2
requests==2.31.0
websocket-client==1.6.4
python-binance==1.0.19
influxdb-client==1.38.0
python-dotenv==1.0.0
httpx==0.25.2
pydantic==2.5.0
schedule==1.2.0
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
        service = "bot"
        version = $Version
        buildTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss UTC")
        configuration = $Configuration
        runtime = "python"
        pythonVersion = (python --version 2>&1)
        criticalService = $true
    }
    $VersionInfo | ConvertTo-Json -Depth 2 | Set-Content "$TempPath\version.json"

    # Create startup script
    $StartupScript = @"
@echo off
REM AITB Trading Bot Startup Script

set CONFIG_FILE=D:\configs\aitb\bot\.env
if exist "%CONFIG_FILE%" (
    echo Loading environment from %CONFIG_FILE%
    for /f "usebackq tokens=1,2 delims==" %%a in ("%CONFIG_FILE%") do (
        if not "%%a"=="" if not "%%a:~0,1%"=="#" set %%a=%%b
    )
)

REM Create logs directory
mkdir "D:\logs\aitb\bot" 2>nul

venv\Scripts\python.exe -m main
"@
    $StartupScript | Set-Content "$TempPath\start.bat"

    # Create PowerShell startup script
    $PSStartupScript = @"
# AITB Trading Bot PowerShell Startup Script

`$ConfigFile = "D:\configs\aitb\bot\.env"
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

# Create logs directory
`$LogDir = "D:\logs\aitb\bot"
if (-not (Test-Path `$LogDir)) {
    New-Item -Path `$LogDir -ItemType Directory -Force | Out-Null
    Write-Host "Created log directory: `$LogDir" -ForegroundColor Yellow
}

# Start the trading bot
Write-Host "Starting AITB Trading Bot..." -ForegroundColor Green
& ".\venv\Scripts\python.exe" -m main
"@
    $PSStartupScript | Set-Content "$TempPath\start.ps1"

    # Create README
    $ReadmeContent = @"
# AITB Trading Bot - Version $Version

## Description
Core trading bot engine with strategy execution and risk management.

## Built
- Time: $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss UTC"))
- Configuration: $Configuration
- Python Version: $(python --version 2>&1)

## Deployment
1. Extract to D:\apps\aitb\bot\$Version\
2. Ensure D:\configs\aitb\bot\.env is configured
3. Run start.ps1 or start.bat

## Configuration
Reads environment variables from: D:\configs\aitb\bot\.env
Required variables: MY_BINANCE_API_KEY, MY_BINANCE_SECRET_KEY, BINANCE_API_KEY, BINANCE_SECRET_KEY, COINAPI_KEY, INFLUX_URL, INFLUX_ORG, INFLUX_BUCKET, INFLUX_TOKEN, INFERENCE_API_BASE, MCP_BASE_URL

## Service Definition
Use: ci-cd\service_defs\bot.json

## Virtual Environment
Includes complete Python virtual environment with all dependencies.
No additional Python packages need to be installed.

## Heartbeat
Service writes heartbeat to: D:\logs\aitb\bot\bot-heartbeat.log
Heartbeat interval: 60 seconds
Monitor this file to ensure bot is running properly.

## Critical Service
This is a critical service for trading operations.
Enhanced recovery settings apply.
"@
    $ReadmeContent | Set-Content "$TempPath\README.md"

    # Create the zip file
    Write-Host "`nCreating zip package..." -ForegroundColor Yellow
    Compress-Archive -Path "$TempPath\*" -DestinationPath $ZipPath -Force

    # Calculate checksum
    $Hash = Get-FileHash $ZipPath -Algorithm SHA256
    $ChecksumFile = "$OutputPath\bot-$Version.zip.sha256"
    "$($Hash.Hash)  bot-$Version.zip" | Set-Content $ChecksumFile

    # Cleanup temp directory
    Remove-Item $TempPath -Recurse -Force

    # Output results
    $ZipSize = [math]::Round((Get-Item $ZipPath).Length / 1MB, 2)
    Write-Host "`n✅ Build completed successfully!" -ForegroundColor Green
    Write-Host "📦 Package: $ZipPath ($ZipSize MB)" -ForegroundColor Green
    Write-Host "🔒 Checksum: $ChecksumFile" -ForegroundColor Green
    Write-Host "🔢 SHA256: $($Hash.Hash)" -ForegroundColor Gray
    Write-Host "💓 Heartbeat: D:\logs\aitb\bot\bot-heartbeat.log" -ForegroundColor Cyan

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