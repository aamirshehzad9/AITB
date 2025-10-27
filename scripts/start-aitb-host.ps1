#!/usr/bin/env powershell
# AITB Host Agent Startup Script
# ⚠️ MANDATORY: Agents MUST read /context/project_manifest.yaml before any action.
# Handles handshake initialization from GOmini-AI (192.168.1.4)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AITB Host Agent (192.168.1.2)" -ForegroundColor Cyan
Write-Host "Initializing handshake listener..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Set location to API service directory
Set-Location "D:\AITB\services\api"

# Check if Node.js is available
try {
    $nodeVersion = node --version
    Write-Host "✓ Node.js detected: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Node.js not found. Please install Node.js first." -ForegroundColor Red
    exit 1
}

# Check if package.json exists
if (-Not (Test-Path "package.json")) {
    Write-Host "✗ package.json not found in current directory" -ForegroundColor Red
    exit 1
}

Write-Host "Installing dependencies..." -ForegroundColor Yellow
npm install

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to install dependencies" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Dependencies installed successfully" -ForegroundColor Green

# Ensure logs directory exists
$logsDir = "D:\AITB\logs"
if (-Not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force
    Write-Host "✓ Created logs directory: $logsDir" -ForegroundColor Green
}

# Set environment variables for AITB Host configuration
$env:API_PORT = "8505"
$env:NODE_ENV = "production"
$env:LOG_LEVEL = "info"

Write-Host "" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Starting AITB Host Agent..." -ForegroundColor Cyan
Write-Host "Listening on: http://192.168.1.2:8505" -ForegroundColor Cyan
Write-Host "Handshake endpoint: /handshake/init" -ForegroundColor Cyan
Write-Host "Status endpoint: /handshake/status" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Start the server
node server.js