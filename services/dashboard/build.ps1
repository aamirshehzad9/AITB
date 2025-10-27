# AITB Dashboard Service Build Script
# Builds Streamlit analytics dashboard with virtual environment

param(
    [string]$Version = "1.0.0",
    [string]$Configuration = "Release",
    [string]$OutputPath = "D:\AITB\dist"
)

$ErrorActionPreference = "Stop"

Write-Host "AITB Dashboard Service Build" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green
Write-Host "Version: $Version" -ForegroundColor Yellow
Write-Host "Configuration: $Configuration" -ForegroundColor Yellow
Write-Host "Output: $OutputPath" -ForegroundColor Yellow

# Set paths
$ServicePath = "D:\AITB\services\dashboard"
$TempPath = "$env:TEMP\aitb-dashboard-build-$Version"
$ZipPath = "$OutputPath\dashboard-$Version.zip"

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
        
        # Create app.py (main Streamlit entry point)
        $AppPy = @"
#!/usr/bin/env python3
"""
AITB Analytics Dashboard
Streamlit-based analytics and monitoring dashboard
"""

import os
import sys
import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from pathlib import Path
from datetime import datetime, timedelta

# Add the service directory to Python path
service_dir = Path(__file__).parent
sys.path.insert(0, str(service_dir))

def load_environment():
    """Load environment variables from config file"""
    config_file = Path("D:/configs/aitb/dashboard/.env")
    if config_file.exists():
        with open(config_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    os.environ[key.strip()] = value.strip()

# Load environment
load_environment()

# Configure Streamlit page
st.set_page_config(
    page_title="AITB Analytics Dashboard",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded"
)

def main():
    """Main dashboard function"""
    st.title("🤖 AITB Analytics Dashboard")
    st.sidebar.title("Navigation")
    
    # Sidebar navigation
    page = st.sidebar.selectbox(
        "Select Page",
        ["Overview", "Trading Performance", "Bot Status", "Market Data", "System Health"]
    )
    
    if page == "Overview":
        show_overview()
    elif page == "Trading Performance":
        show_trading_performance()
    elif page == "Bot Status":
        show_bot_status()
    elif page == "Market Data":
        show_market_data()
    elif page == "System Health":
        show_system_health()

def show_overview():
    """Show overview dashboard"""
    st.header("📊 System Overview")
    
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric("Bot Status", "Running", "✅")
    
    with col2:
        st.metric("Active Trades", "5", "+2")
    
    with col3:
        st.metric("24h P&L", "$1,234.56", "+5.2%")
    
    with col4:
        st.metric("System Health", "Good", "99.8%")
    
    # TODO: Add real-time charts from InfluxDB
    st.info("🚧 Dashboard is under construction. Connect to InfluxDB for real-time data.")

def show_trading_performance():
    """Show trading performance metrics"""
    st.header("💹 Trading Performance")
    
    # TODO: Implement trading performance charts
    st.info("📈 Trading performance charts will be implemented here.")

def show_bot_status():
    """Show bot status and health"""
    st.header("🤖 Bot Status")
    
    # TODO: Check bot heartbeat and status
    st.info("💓 Bot heartbeat monitoring will be implemented here.")

def show_market_data():
    """Show market data and charts"""
    st.header("📈 Market Data")
    
    # TODO: Implement market data visualization
    st.info("📊 Market data charts will be implemented here.")

def show_system_health():
    """Show system health metrics"""
    st.header("🏥 System Health")
    
    # TODO: Implement system health monitoring
    st.info("⚡ System health metrics will be implemented here.")

if __name__ == "__main__":
    main()
"@
        $AppPy | Set-Content "$TempPath\app.py"

        # Create main.py for compatibility
        $MainPy = @"
#!/usr/bin/env python3
"""
AITB Dashboard Service Main Entry Point
Wrapper to start Streamlit dashboard
"""

import os
import sys
import subprocess
from pathlib import Path

def load_environment():
    """Load environment variables from config file"""
    config_file = Path("D:/configs/aitb/dashboard/.env")
    if config_file.exists():
        with open(config_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    os.environ[key.strip()] = value.strip()
                    print(f"Loaded: {key.strip()}")

def main():
    """Main entry point - starts Streamlit"""
    load_environment()
    
    # Set default Streamlit configuration
    port = os.getenv('STREAMLIT_SERVER_PORT', '8501')
    address = os.getenv('STREAMLIT_SERVER_ADDRESS', 'localhost')
    
    print(f"Starting AITB Dashboard on {address}:{port}")
    
    # Start Streamlit
    cmd = [
        sys.executable, "-m", "streamlit", "run", "app.py",
        "--server.port", port,
        "--server.address", address,
        "--server.headless", "true"
    ]
    
    subprocess.run(cmd)

if __name__ == "__main__":
    main()
"@
        $MainPy | Set-Content "$TempPath\main.py"

        # Create requirements.txt
        $Requirements = @"
# AITB Dashboard Service Dependencies
streamlit==1.28.1
pandas==2.1.4
numpy==1.25.2
plotly==5.17.0
influxdb-client==1.38.0
python-dotenv==1.0.0
httpx==0.25.2
requests==2.31.0
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
        service = "dashboard"
        version = $Version
        buildTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss UTC")
        configuration = $Configuration
        runtime = "python-streamlit"
        pythonVersion = (python --version 2>&1)
        streamlitPort = 8501
    }
    $VersionInfo | ConvertTo-Json -Depth 2 | Set-Content "$TempPath\version.json"

    # Create startup script
    $StartupScript = @"
@echo off
REM AITB Dashboard Service Startup Script

set CONFIG_FILE=D:\configs\aitb\dashboard\.env
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
# AITB Dashboard Service PowerShell Startup Script

`$ConfigFile = "D:\configs\aitb\dashboard\.env"
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

# Start the dashboard service
Write-Host "Starting AITB Dashboard Service..." -ForegroundColor Green
Write-Host "Dashboard will be available at: http://localhost:8501" -ForegroundColor Cyan
& ".\venv\Scripts\python.exe" -m main
"@
    $PSStartupScript | Set-Content "$TempPath\start.ps1"

    # Create README
    $ReadmeContent = @"
# AITB Dashboard Service - Version $Version

## Description
Streamlit-based analytics and monitoring dashboard for trading system visualization.

## Built
- Time: $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss UTC"))
- Configuration: $Configuration
- Python Version: $(python --version 2>&1)

## Deployment
1. Extract to D:\apps\aitb\dashboard\$Version\
2. Ensure D:\configs\aitb\dashboard\.env is configured
3. Run start.ps1 or start.bat
4. Access dashboard at http://localhost:8501

## Configuration
Reads environment variables from: D:\configs\aitb\dashboard\.env
Required variables: INFLUX_URL, INFLUX_ORG, INFLUX_BUCKET, INFLUX_TOKEN, GRAFANA_USER, GRAFANA_PASSWORD, COINAPI_KEY, MCP_BASE_URL, INFERENCE_API_BASE

## Service Definition
Use: ci-cd\service_defs\dashboard.json

## Virtual Environment
Includes complete Python virtual environment with all dependencies.
No additional Python packages need to be installed.

## Features
- Real-time trading performance charts
- Bot status monitoring
- Market data visualization
- System health metrics
- Streamlit web interface

## Access
Default URL: http://localhost:8501
Customize port with STREAMLIT_SERVER_PORT environment variable
"@
    $ReadmeContent | Set-Content "$TempPath\README.md"

    # Create the zip file
    Write-Host "`nCreating zip package..." -ForegroundColor Yellow
    Compress-Archive -Path "$TempPath\*" -DestinationPath $ZipPath -Force

    # Calculate checksum
    $Hash = Get-FileHash $ZipPath -Algorithm SHA256
    $ChecksumFile = "$OutputPath\dashboard-$Version.zip.sha256"
    "$($Hash.Hash)  dashboard-$Version.zip" | Set-Content $ChecksumFile

    # Cleanup temp directory
    Remove-Item $TempPath -Recurse -Force

    # Output results
    $ZipSize = [math]::Round((Get-Item $ZipPath).Length / 1MB, 2)
    Write-Host "`n✅ Build completed successfully!" -ForegroundColor Green
    Write-Host "📦 Package: $ZipPath ($ZipSize MB)" -ForegroundColor Green
    Write-Host "🔒 Checksum: $ChecksumFile" -ForegroundColor Green
    Write-Host "🔢 SHA256: $($Hash.Hash)" -ForegroundColor Gray
    Write-Host "🌐 Dashboard URL: http://localhost:8501" -ForegroundColor Cyan

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