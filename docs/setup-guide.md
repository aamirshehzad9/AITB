# AITB Host Agent - Setup Guide

## Prerequisites Installation

### 1. Install Node.js

The AITB Host agent requires Node.js 18+ to run. Follow these steps:

#### Option A: Download from Official Website
1. Visit https://nodejs.org/
2. Download the LTS version (18.x or higher)
3. Run the installer and follow the setup wizard
4. Restart PowerShell after installation

#### Option B: Using Chocolatey (if available)
```powershell
choco install nodejs
```

#### Option C: Using Winget (Windows 10/11)
```powershell
winget install OpenJS.NodeJS
```

### 2. Verify Installation
After installing Node.js, verify it's working:

```powershell
node --version
npm --version
```

## AITB Host Agent Setup

### 1. Navigate to API Directory
```powershell
cd "D:\AITB\services\api"
```

### 2. Install Dependencies
```powershell
npm install
```

### 3. Start the AITB Host Agent
```powershell
# Method 1: Using the startup script
PowerShell -ExecutionPolicy Bypass -File "D:\AITB\scripts\start-aitb-host.ps1"

# Method 2: Manual start
$env:API_PORT = "8505"
$env:NODE_ENV = "production"
node server.js
```

## Quick Start Commands

After Node.js is installed, run these commands in sequence:

```powershell
# 1. Navigate to API directory
cd "D:\AITB\services\api"

# 2. Install dependencies
npm install

# 3. Start AITB Host Agent
$env:API_PORT = "8505"; node server.js
```

## Verification

Once the server is running, you should see:
```
AITB API Server running on port 8505
```

Test the handshake endpoint:
```powershell
# Test status endpoint
Invoke-RestMethod -Uri "http://192.168.1.2:8505/handshake/status"

# Test main API endpoint
Invoke-RestMethod -Uri "http://192.168.1.2:8505/"
```

## Firewall Configuration

Ensure Windows Firewall allows connections on port 8505:

```powershell
# Add firewall rule for AITB Host Agent
New-NetFirewallRule -DisplayName "AITB Host Agent" -Direction Inbound -Protocol TCP -LocalPort 8505 -Action Allow
```

## Network Configuration

Verify that the server can bind to 192.168.1.2:

1. Check network adapter configuration
2. Ensure IP address 192.168.1.2 is assigned to a network interface
3. Test network connectivity between 192.168.1.2 and 192.168.1.4

```powershell
# Check IP configuration
ipconfig /all

# Test network connectivity to GOmini-AI
Test-NetConnection -ComputerName 192.168.1.4 -Port 8505
```

## Troubleshooting

### Common Issues

1. **"npm is not recognized"**
   - Node.js is not installed or not in PATH
   - Restart PowerShell after Node.js installation
   - Add Node.js to PATH manually if needed

2. **"listen EADDRNOTAVAIL"**
   - IP address 192.168.1.2 is not available on this machine
   - Check network configuration
   - Consider using 0.0.0.0 or localhost for testing

3. **"Port 8505 already in use"**
   - Another service is using port 8505
   - Stop the conflicting service or use a different port
   - Check with: `netstat -an | findstr ":8505"`

4. **Cannot connect from GOmini-AI**
   - Check Windows Firewall settings
   - Verify network routing between hosts
   - Test with telnet: `telnet 192.168.1.2 8505`

## Status Check

After starting the AITB Host Agent, check its status:

```powershell
# Check if service is listening
netstat -an | findstr ":8505"

# Test handshake endpoint
Invoke-RestMethod -Uri "http://localhost:8505/handshake/status"

# Check logs
Get-Content "D:\AITB\logs\activity.log" -Tail 20
```

## Next Steps

1. Install Node.js using one of the methods above
2. Run the setup commands
3. Start the AITB Host Agent
4. Test the handshake functionality
5. Wait for GOmini-AI to initiate handshake from 192.168.1.4