# Administrative fix for AITB Host Agent
Write-Host "AITB Host Agent - Administrative Fix" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

# Check Node.js
$nodeExists = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeExists) {
    Write-Host "❌ Node.js not found - Please install from https://nodejs.org/" -ForegroundColor Red
    Write-Host "After installation, restart PowerShell and run this script again." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Quick install options:" -ForegroundColor White
    Write-Host "1. Download from: https://nodejs.org/en/download/" -ForegroundColor Gray
    Write-Host "2. Or use winget: winget install OpenJS.NodeJS" -ForegroundColor Gray
    exit 1
}

Write-Host "✅ Node.js found: $(node --version)" -ForegroundColor Green

# Navigate to API directory
Set-Location "D:\AITB\services\api"

# Install dependencies
Write-Host "Installing dependencies..." -ForegroundColor Yellow
npm install

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to install dependencies" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Dependencies installed" -ForegroundColor Green

# Add firewall rule
Write-Host "Configuring firewall..." -ForegroundColor Yellow
try {
    $existingRule = Get-NetFirewallRule -DisplayName "AITB Host Agent" -ErrorAction SilentlyContinue
    if (-not $existingRule) {
        New-NetFirewallRule -DisplayName "AITB Host Agent" -Direction Inbound -Protocol TCP -LocalPort 8505 -Action Allow -Profile Any | Out-Null
        Write-Host "✅ Firewall rule added" -ForegroundColor Green
    } else {
        Write-Host "✅ Firewall rule already exists" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️ Could not configure firewall (may need Administrator rights)" -ForegroundColor Yellow
}

# Set environment and start server
Write-Host "Starting AITB Host Agent..." -ForegroundColor Green
$env:API_PORT = "8505"
$env:NODE_ENV = "production"

Write-Host ""
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "AITB Host Agent Starting..." -ForegroundColor Green
Write-Host "Server will be available at:" -ForegroundColor White
Write-Host "- Health: http://localhost:8505/api/health" -ForegroundColor Cyan
Write-Host "- Handshake: http://localhost:8505/handshake/init" -ForegroundColor Cyan
Write-Host "- Status: http://localhost:8505/handshake/status" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Start the server
node server.js