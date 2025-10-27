# AITB Host Agent - Production Configuration
# ⚠️ MANDATORY: Agents MUST read /context/project_manifest.yaml before any action.
# Sets the server to listen on 192.168.1.2 for production deployment

Write-Host "AITB Host Agent - Production Configuration" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Check if 192.168.1.2 is available
Write-Host "Checking network configuration..." -ForegroundColor Yellow

$ip192Available = $false
try {
    $networkConfig = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -eq "192.168.1.2"}
    if ($networkConfig) {
        $ip192Available = $true
        Write-Host "✅ IP 192.168.1.2 is configured on interface: $($networkConfig.InterfaceAlias)" -ForegroundColor Green
    } else {
        Write-Host "⚠️ IP 192.168.1.2 not found on any network interface" -ForegroundColor Yellow
        
        # Show available IPs
        Write-Host "Available IP addresses:" -ForegroundColor Gray
        Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.PrefixOrigin -eq "Manual" -or $_.PrefixOrigin -eq "Dhcp"} | ForEach-Object {
            Write-Host "  $($_.IPAddress) on $($_.InterfaceAlias)" -ForegroundColor Gray
        }
        
        # Ask if user wants to add the IP
        $response = Read-Host "`nWould you like to add 192.168.1.2 as an IP alias? (y/n)"
        if ($response -eq "y" -or $response -eq "Y") {
            try {
                $adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
                if ($adapter) {
                    New-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -IPAddress "192.168.1.2" -PrefixLength 24 -PolicyStore PersistentStore
                    Write-Host "✅ IP 192.168.1.2 added to $($adapter.Name)" -ForegroundColor Green
                    $ip192Available = $true
                } else {
                    Write-Host "❌ No active network adapter found" -ForegroundColor Red
                }
            } catch {
                Write-Host "❌ Failed to add IP address: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "You may need to run this script as Administrator" -ForegroundColor Yellow
            }
        }
    }
} catch {
    Write-Host "⚠️ Could not check network configuration" -ForegroundColor Yellow
}

# Configure environment variables
if ($ip192Available) {
    Write-Host "`nConfiguring for production deployment (192.168.1.2)..." -ForegroundColor Green
    $env:API_HOST = "192.168.1.2"
    $env:API_PORT = "8505"
    $env:NODE_ENV = "production"
    
    Write-Host "Production configuration set:" -ForegroundColor White
    Write-Host "- Host: 192.168.1.2" -ForegroundColor Gray
    Write-Host "- Port: 8505" -ForegroundColor Gray
    Write-Host "- Environment: production" -ForegroundColor Gray
    
    Write-Host "`nServer will be accessible at:" -ForegroundColor White
    Write-Host "- Health: http://192.168.1.2:8505/api/health" -ForegroundColor Cyan
    Write-Host "- Handshake: http://192.168.1.2:8505/handshake/init" -ForegroundColor Cyan
    
} else {
    Write-Host "`nConfiguring for development deployment (localhost)..." -ForegroundColor Yellow
    $env:API_HOST = "localhost"
    $env:API_PORT = "8505"
    $env:NODE_ENV = "development"
    
    Write-Host "Development configuration set:" -ForegroundColor White
    Write-Host "- Host: localhost" -ForegroundColor Gray
    Write-Host "- Port: 8505" -ForegroundColor Gray
    Write-Host "- Environment: development" -ForegroundColor Gray
    
    Write-Host "`nServer will be accessible at:" -ForegroundColor White
    Write-Host "- Health: http://localhost:8505/api/health" -ForegroundColor Cyan
    Write-Host "- Handshake: http://localhost:8505/handshake/init" -ForegroundColor Cyan
}

# Navigate to API directory
Set-Location "D:\AITB\services\api"

# Check dependencies
if (-not (Test-Path "node_modules")) {
    Write-Host "`nInstalling dependencies..." -ForegroundColor Yellow
    npm install
}

# Start the server
Write-Host "`nStarting AITB Host Agent..." -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

node server.js