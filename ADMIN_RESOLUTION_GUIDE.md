# AITB Host Agent - Administrative Resolution Guide

## Issue Diagnosis ❌
- **Problem**: `curl http://192.168.1.2:8505/health` fails with "Unable to connect to the remote server"
- **Root Cause**: AITB Host agent server is not running
- **Secondary Issue**: Node.js is not installed on the system

## Administrative Resolution Steps 🔧

### Step 1: Install Node.js (REQUIRED)

#### Option A: Direct Download (Recommended for Windows Server)
1. Open web browser as Administrator
2. Navigate to: https://nodejs.org/en/download/
3. Download "Windows Installer (.msi)" - LTS version
4. Run the installer as Administrator
5. Follow installation wizard (accept all defaults)
6. **CRITICAL**: Restart PowerShell after installation

#### Option B: Using Winget (Windows 10/11 with Package Manager)
```powershell
# Run as Administrator
winget install OpenJS.NodeJS
```

#### Option C: Using Chocolatey (if available)
```powershell
# Run as Administrator  
choco install nodejs
```

### Step 2: Verify Node.js Installation
```powershell
# Close and reopen PowerShell, then test:
node --version
npm --version
```
**Expected Output**: Version numbers (e.g., v18.17.0, 9.6.7)

### Step 3: Install AITB Dependencies
```powershell
# Navigate to API directory
cd "D:\AITB\services\api"

# Install Node.js dependencies
npm install
```

### Step 4: Configure Network Binding

#### Check Current IP Configuration
```powershell
# View current network configuration
ipconfig /all
Get-NetIPAddress -AddressFamily IPv4
```

#### Option A: If 192.168.1.2 is not available, use localhost for testing
```powershell
# Edit server.js to use localhost temporarily
# Change line: const server = app.listen(PORT, '192.168.1.2', async () => {
# To: const server = app.listen(PORT, 'localhost', async () => {
```

#### Option B: Configure 192.168.1.2 (if network supports it)
```powershell
# Add IP alias to existing network adapter
New-NetIPAddress -InterfaceIndex (Get-NetAdapter | Select-Object -First 1).InterfaceIndex -IPAddress 192.168.1.2 -PrefixLength 24
```

### Step 5: Configure Windows Firewall
```powershell
# Add firewall rule for AITB Host Agent
New-NetFirewallRule -DisplayName "AITB Host Agent" -Direction Inbound -Protocol TCP -LocalPort 8505 -Action Allow -Profile Any

# Verify firewall rule
Get-NetFirewallRule -DisplayName "AITB Host Agent"
```

### Step 6: Start AITB Host Agent
```powershell
# Set environment variables
$env:API_PORT = "8505"
$env:NODE_ENV = "production"

# Navigate to API directory
cd "D:\AITB\services\api"

# Start the server
node server.js
```

### Step 7: Verify Service is Running
Open a **new PowerShell window** and test:

```powershell
# Check if port is listening
netstat -an | findstr ":8505"

# Test health endpoint (adjust IP as needed)
curl http://localhost:8505/api/health
# OR if 192.168.1.2 is configured:
curl http://192.168.1.2:8505/api/health

# Test handshake endpoint
curl http://localhost:8505/handshake/status
```

## Quick Fix Script (All-in-One) 🚀

Save this as `D:\AITB\scripts\admin-fix.ps1`:

```powershell
# Administrative fix for AITB Host Agent
Write-Host "AITB Host Agent - Administrative Fix" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

# Check Node.js
$nodeExists = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeExists) {
    Write-Host "❌ Node.js not found - Please install from https://nodejs.org/" -ForegroundColor Red
    Write-Host "After installation, restart PowerShell and run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Node.js found" -ForegroundColor Green

# Navigate to API directory
cd "D:\AITB\services\api"

# Install dependencies
Write-Host "Installing dependencies..." -ForegroundColor Yellow
npm install

# Add firewall rule
Write-Host "Configuring firewall..." -ForegroundColor Yellow
try {
    New-NetFirewallRule -DisplayName "AITB Host Agent" -Direction Inbound -Protocol TCP -LocalPort 8505 -Action Allow -Profile Any -ErrorAction SilentlyContinue
    Write-Host "✅ Firewall configured" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Firewall rule may already exist" -ForegroundColor Yellow
}

# Set environment and start server
Write-Host "Starting AITB Host Agent..." -ForegroundColor Green
$env:API_PORT = "8505"
$env:NODE_ENV = "production"

Write-Host "Server will start on: http://localhost:8505" -ForegroundColor Cyan
Write-Host "Health endpoint: http://localhost:8505/api/health" -ForegroundColor Cyan
Write-Host "Handshake endpoint: http://localhost:8505/handshake/init" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

node server.js
```

## Alternative: Localhost Configuration 🔄

If you can't configure 192.168.1.2, modify the server to use localhost:

```powershell
# Edit server.js
cd "D:\AITB\services\api"

# Create backup
Copy-Item server.js server.js.backup

# Replace IP binding
(Get-Content server.js) -replace "192.168.1.2", "localhost" | Set-Content server.js

# Start server
$env:API_PORT = "8505"
node server.js
```

Then test with:
```powershell
curl http://localhost:8505/api/health
curl http://localhost:8505/handshake/status
```

## Troubleshooting Common Issues 🔍

### Issue: "node is not recognized"
**Solution**: Install Node.js and restart PowerShell

### Issue: "npm install" fails
**Solution**: Ensure you're running PowerShell as Administrator

### Issue: "EADDRNOTAVAIL" error
**Solution**: Use localhost binding or configure 192.168.1.2 network alias

### Issue: "Port already in use"
**Solution**: Find and stop conflicting service:
```powershell
netstat -ano | findstr ":8505"
# Note the PID and stop the process
Stop-Process -Id <PID> -Force
```

### Issue: Connection refused from remote
**Solution**: Check Windows Firewall and network routing

## Expected Success Output ✅

When working correctly, you should see:
```
AITB API Server running on port 8505
Database connected successfully
Redis connected successfully
```

And health check should return:
```json
{
  "status": "ok",
  "timestamp": "2025-10-25T...",
  "uptime": "0:00:30"
}
```

## Contact Information 📞

After following these steps, the AITB Host Agent should be accessible at:
- **Health Check**: `http://localhost:8505/api/health`
- **Handshake Endpoint**: `http://localhost:8505/handshake/init`
- **Status Check**: `http://localhost:8505/handshake/status`