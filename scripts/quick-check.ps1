# ⚠️ MANDATORY: Agents MUST read /context/project_manifest.yaml before any action.

Write-Host "AITB Host Agent - Status Check" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan

Write-Host "`nChecking Node.js..." -ForegroundColor Yellow
$nodeExists = Get-Command node -ErrorAction SilentlyContinue
if ($nodeExists) {
    Write-Host "✓ Node.js is installed" -ForegroundColor Green
} else {
    Write-Host "✗ Node.js not found - install from https://nodejs.org/" -ForegroundColor Red
}

Write-Host "`nChecking API files..." -ForegroundColor Yellow
if (Test-Path "D:\AITB\services\api\server.js") {
    Write-Host "✓ server.js found" -ForegroundColor Green
} else {
    Write-Host "✗ server.js missing" -ForegroundColor Red
}

if (Test-Path "D:\AITB\services\api\routes\handshake.js") {
    Write-Host "✓ handshake.js found" -ForegroundColor Green
} else {
    Write-Host "✗ handshake.js missing" -ForegroundColor Red
}

Write-Host "`nChecking logs directory..." -ForegroundColor Yellow
if (Test-Path "D:\AITB\logs") {
    Write-Host "✓ Logs directory exists" -ForegroundColor Green
} else {
    Write-Host "Creating logs directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path "D:\AITB\logs" -Force | Out-Null
    Write-Host "✓ Logs directory created" -ForegroundColor Green
}

Write-Host "`nChecking port 8505..." -ForegroundColor Yellow
$portInUse = netstat -an | findstr ":8505"
if ($portInUse) {
    Write-Host "✓ Port 8505 is in use (AITB may be running)" -ForegroundColor Green
} else {
    Write-Host "○ Port 8505 is available" -ForegroundColor Gray
}

Write-Host "`n===============================" -ForegroundColor Cyan
if ($nodeExists) {
    Write-Host "✓ Ready to start AITB Host Agent!" -ForegroundColor Green
    Write-Host "`nStart commands:" -ForegroundColor White
    Write-Host "cd 'D:\AITB\services\api'" -ForegroundColor Gray
    Write-Host "npm install" -ForegroundColor Gray
    Write-Host "`$env:API_PORT='8505'; node server.js" -ForegroundColor Gray
} else {
    Write-Host "⚠ Install Node.js first" -ForegroundColor Yellow
}
Write-Host "===============================" -ForegroundColor Cyan