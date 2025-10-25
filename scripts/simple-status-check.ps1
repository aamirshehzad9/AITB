#!/usr/bin/env powershell
# AITB Host Agent - Simple Status Check

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AITB Host Agent - System Status Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check Node.js installation
Write-Host "`n1. Node.js Status:" -ForegroundColor Yellow
$nodeCheck = Get-Command node -ErrorAction SilentlyContinue
if ($nodeCheck) {
    Write-Host "   ✓ Node.js is installed" -ForegroundColor Green
    $npmCheck = Get-Command npm -ErrorAction SilentlyContinue
    if ($npmCheck) {
        Write-Host "   ✓ npm is available" -ForegroundColor Green
    } else {
        Write-Host "   ✗ npm not found" -ForegroundColor Red
    }
} else {
    Write-Host "   ✗ Node.js not found - Install from https://nodejs.org/" -ForegroundColor Red
}

# Check API directory
Write-Host "`n2. API Directory:" -ForegroundColor Yellow
if (Test-Path "D:\AITB\services\api") {
    Write-Host "   ✓ API directory exists" -ForegroundColor Green
    if (Test-Path "D:\AITB\services\api\package.json") {
        Write-Host "   ✓ package.json found" -ForegroundColor Green
    }
    if (Test-Path "D:\AITB\services\api\server.js") {
        Write-Host "   ✓ server.js found" -ForegroundColor Green
    }
    if (Test-Path "D:\AITB\services\api\routes\handshake.js") {
        Write-Host "   ✓ handshake.js route found" -ForegroundColor Green
    }
} else {
    Write-Host "   ✗ API directory not found" -ForegroundColor Red
}

# Check logs directory
Write-Host "`n3. Logs Directory:" -ForegroundColor Yellow
if (Test-Path "D:\AITB\logs") {
    Write-Host "   ✓ Logs directory exists" -ForegroundColor Green
    if (Test-Path "D:\AITB\logs\gomini_handshake_token.json") {
        Write-Host "   ✓ Handshake token file exists" -ForegroundColor Green
    } else {
        Write-Host "   ○ No handshake token yet (normal)" -ForegroundColor Gray
    }
} else {
    Write-Host "   ○ Creating logs directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path "D:\AITB\logs" -Force | Out-Null
    Write-Host "   ✓ Logs directory created" -ForegroundColor Green
}

# Check if port 8505 is in use
Write-Host "`n4. Port 8505 Status:" -ForegroundColor Yellow
$portStatus = netstat -an | findstr ":8505"
if ($portStatus) {
    Write-Host "   ✓ Port 8505 is in use" -ForegroundColor Green
    Write-Host "   → $portStatus" -ForegroundColor Gray
} else {
    Write-Host "   ○ Port 8505 is available" -ForegroundColor Gray
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($nodeCheck) {
    Write-Host "✓ System is ready for AITB Host Agent" -ForegroundColor Green
    Write-Host "`nTo start the AITB Host Agent:" -ForegroundColor White
    Write-Host "1. cd 'D:\AITB\services\api'" -ForegroundColor Gray
    Write-Host "2. npm install" -ForegroundColor Gray
    Write-Host "3. `$env:API_PORT='8505'; node server.js" -ForegroundColor Gray
} else {
    Write-Host "⚠ Install Node.js first from https://nodejs.org/" -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Cyan