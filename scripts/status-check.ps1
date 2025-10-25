#!/usr/bin/env powershell
# AITB Host Agent Status Check
# Verifies system readiness and current status

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AITB Host Agent - System Status Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check Node.js installation
Write-Host "`n1. Checking Node.js installation..." -ForegroundColor Yellow
try {
    $nodeVersion = node --version 2>$null
    if ($nodeVersion) {
        Write-Host "   ✓ Node.js installed: $nodeVersion" -ForegroundColor Green
        
        $npmVersion = npm --version 2>$null
        if ($npmVersion) {
            Write-Host "   ✓ npm available: $npmVersion" -ForegroundColor Green
        } else {
            Write-Host "   ✗ npm not available" -ForegroundColor Red
        }
    } else {
        Write-Host "   ✗ Node.js not found" -ForegroundColor Red
        Write-Host "   → Install Node.js from https://nodejs.org/" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ✗ Node.js not installed or not in PATH" -ForegroundColor Red
    Write-Host "   → Install Node.js from https://nodejs.org/" -ForegroundColor Yellow
}

# Check API directory structure
Write-Host "`n2. Checking API directory structure..." -ForegroundColor Yellow
$apiDir = "D:\AITB\services\api"
if (Test-Path $apiDir) {
    Write-Host "   ✓ API directory exists: $apiDir" -ForegroundColor Green
    
    $packageJson = Join-Path $apiDir "package.json"
    if (Test-Path $packageJson) {
        Write-Host "   ✓ package.json found" -ForegroundColor Green
    } else {
        Write-Host "   ✗ package.json missing" -ForegroundColor Red
    }
    
    $serverJs = Join-Path $apiDir "server.js"
    if (Test-Path $serverJs) {
        Write-Host "   ✓ server.js found" -ForegroundColor Green
    } else {
        Write-Host "   ✗ server.js missing" -ForegroundColor Red
    }
    
    $handshakeRoute = Join-Path $apiDir "routes\handshake.js"
    if (Test-Path $handshakeRoute) {
        Write-Host "   ✓ handshake.js route found" -ForegroundColor Green
    } else {
        Write-Host "   ✗ handshake.js route missing" -ForegroundColor Red
    }
} else {
    Write-Host "   ✗ API directory not found: $apiDir" -ForegroundColor Red
}

# Check logs directory
Write-Host "`n3. Checking logs directory..." -ForegroundColor Yellow
$logsDir = "D:\AITB\logs"
if (Test-Path $logsDir) {
    Write-Host "   ✓ Logs directory exists: $logsDir" -ForegroundColor Green
    
    $tokenFile = Join-Path $logsDir "gomini_handshake_token.json"
    if (Test-Path $tokenFile) {
        Write-Host "   ✓ Handshake token file exists" -ForegroundColor Green
        try {
            $tokenData = Get-Content $tokenFile | ConvertFrom-Json
            Write-Host "   → Token: $($tokenData.token)" -ForegroundColor Gray
            Write-Host "   → Status: $($tokenData.status)" -ForegroundColor Gray
            Write-Host "   → Last update: $($tokenData.timestamp)" -ForegroundColor Gray
        } catch {
            Write-Host "   ⚠ Token file exists but invalid JSON" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ○ No handshake token file (normal for first run)" -ForegroundColor Gray
    }
} else {
    Write-Host "   ✗ Logs directory not found: $logsDir" -ForegroundColor Red
    Write-Host "   → Creating logs directory..." -ForegroundColor Yellow
    try {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
        Write-Host "   ✓ Logs directory created" -ForegroundColor Green
    } catch {
        Write-Host "   ✗ Failed to create logs directory" -ForegroundColor Red
    }
}

# Check network configuration
Write-Host "`n4. Checking network configuration..." -ForegroundColor Yellow
try {
    $networkConfig = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -eq "192.168.1.2"}
    if ($networkConfig) {
        Write-Host "   ✓ IP address 192.168.1.2 is configured" -ForegroundColor Green
        Write-Host "   → Interface: $($networkConfig.InterfaceAlias)" -ForegroundColor Gray
    } else {
        Write-Host "   ✗ IP address 192.168.1.2 not found on any interface" -ForegroundColor Red
        Write-Host "   → Available IP addresses:" -ForegroundColor Yellow
        Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.PrefixOrigin -eq "Manual" -or $_.PrefixOrigin -eq "Dhcp"} | ForEach-Object {
            Write-Host "     $($_.IPAddress) on $($_.InterfaceAlias)" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "   ⚠ Could not check network configuration" -ForegroundColor Yellow
}

# Check if AITB Host is currently running
Write-Host "`n5. Checking if AITB Host is running..." -ForegroundColor Yellow
try {
    $portCheck = netstat -an | findstr ":8505"
    if ($portCheck) {
        Write-Host "   ✓ Port 8505 is in use (AITB Host may be running)" -ForegroundColor Green
        Write-Host "   → Port status: $portCheck" -ForegroundColor Gray
        
        # Try to connect to the status endpoint
        try {
            $statusResponse = Invoke-RestMethod -Uri "http://192.168.1.2:8505/handshake/status" -TimeoutSec 5 -ErrorAction Stop
            Write-Host "   ✓ AITB Host is responding to requests" -ForegroundColor Green
            Write-Host "   → Status: $($statusResponse.status)" -ForegroundColor Gray
        } catch {
            Write-Host "   ⚠ Port 8505 in use but AITB Host not responding" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ○ Port 8505 is not in use (AITB Host not running)" -ForegroundColor Gray
    }
} catch {
    Write-Host "   ⚠ Could not check port status" -ForegroundColor Yellow
}

# Check firewall status
Write-Host "`n6. Checking Windows Firewall..." -ForegroundColor Yellow
try {
    $firewallRule = Get-NetFirewallRule -DisplayName "AITB Host Agent" -ErrorAction SilentlyContinue
    if ($firewallRule) {
        Write-Host "   ✓ Firewall rule 'AITB Host Agent' exists" -ForegroundColor Green
        if ($firewallRule.Enabled -eq "True") {
            Write-Host "   ✓ Firewall rule is enabled" -ForegroundColor Green
        } else {
            Write-Host "   ✗ Firewall rule is disabled" -ForegroundColor Red
        }
    } else {
        Write-Host "   ○ No specific firewall rule found" -ForegroundColor Gray
        Write-Host "   → Consider adding: New-NetFirewallRule -DisplayName 'AITB Host Agent' -Direction Inbound -Protocol TCP -LocalPort 8505 -Action Allow" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ⚠ Could not check firewall rules" -ForegroundColor Yellow
}

# Summary and next steps
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Summary and Next Steps" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$nodeInstalled = $false
try {
    node --version 2>$null | Out-Null
    $nodeInstalled = $true
} catch {
    # Node.js not available
}

if (-not $nodeInstalled) {
    Write-Host "⚠ SETUP REQUIRED:" -ForegroundColor Yellow
    Write-Host "1. Install Node.js from https://nodejs.org/" -ForegroundColor White
    Write-Host "2. Restart PowerShell" -ForegroundColor White
    Write-Host "3. Run this status check again" -ForegroundColor White
} else {
    $portInUse = $false
    try {
        $portCheck = netstat -an | findstr ":8505"
        if ($portCheck) { $portInUse = $true }
    } catch {
        # Port check failed
    }
    
    if ($portInUse) {
        Write-Host "✓ SYSTEM READY - AITB Host appears to be running" -ForegroundColor Green
        Write-Host "→ Test handshake: Invoke-RestMethod -Uri 'http://192.168.1.2:8505/handshake/status'" -ForegroundColor White
    } else {
        Write-Host "⚠ READY TO START:" -ForegroundColor Yellow
        Write-Host "1. cd 'D:\AITB\services\api'" -ForegroundColor White
        Write-Host "2. npm install" -ForegroundColor White
        Write-Host "3. `$env:API_PORT = '8505'; node server.js" -ForegroundColor White
    }
}

Write-Host "`nFor detailed setup instructions, see: D:\AITB\docs\setup-guide.md" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan