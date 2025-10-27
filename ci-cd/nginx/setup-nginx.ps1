# AITB Nginx Blue/Green Setup Script
# Episode 7 - Configure nginx for local blue/green deployments

param(
    [Parameter(Mandatory=$false)]
    [string]$NginxPath = "C:\nginx",
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateSelfSignedCert,
    
    [Parameter(Mandatory=$false)]
    [switch]$StartService
)

$ErrorActionPreference = "Stop"

Write-Host "=== AITB Episode 7 - Nginx Blue/Green Setup ===" -ForegroundColor Cyan

# Create required directories
$RequiredDirs = @(
    "D:\logs\nginx",
    "D:\nginx",
    "$NginxPath\conf\conf.d"
)

foreach ($dir in $RequiredDirs) {
    if (-not (Test-Path $dir)) {
        Write-Host "Creating directory: $dir" -ForegroundColor Yellow
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

# Check if nginx is installed
if (-not (Test-Path "$NginxPath\nginx.exe")) {
    Write-Host "❌ Nginx not found at $NginxPath" -ForegroundColor Red
    Write-Host "Please install nginx or specify correct path with -NginxPath parameter" -ForegroundColor Yellow
    Write-Host "Download from: http://nginx.org/en/download.html" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Found nginx at $NginxPath" -ForegroundColor Green

# Copy nginx configuration
$SourceConfig = "D:\AITB\ci-cd\nginx\nginx.conf"
$TargetConfig = "$NginxPath\conf\nginx.conf"
$BackupConfig = "$NginxPath\conf\nginx.conf.backup"

if (Test-Path $TargetConfig) {
    Write-Host "Backing up existing nginx.conf..." -ForegroundColor Yellow
    Copy-Item $TargetConfig $BackupConfig -Force
}

Write-Host "Installing AITB nginx configuration..." -ForegroundColor Yellow
Copy-Item $SourceConfig $TargetConfig -Force

# Copy environment mapping files
$EnvMappingDir = "$NginxPath\conf\conf.d"
Copy-Item "D:\AITB\ci-cd\nginx\env-mapping*.conf" $EnvMappingDir -Force

# Create symbolic link for active mapping
$ActiveMapping = "$NginxPath\conf\conf.d\env-mapping.conf"
if (Test-Path $ActiveMapping) {
    Remove-Item $ActiveMapping -Force
}
Copy-Item "D:\AITB\ci-cd\nginx\env-mapping-blue.conf" $ActiveMapping -Force

Write-Host "✅ Nginx configuration installed" -ForegroundColor Green

# Create self-signed SSL certificate if requested
if ($CreateSelfSignedCert) {
    Write-Host "Creating self-signed SSL certificate..." -ForegroundColor Yellow
    
    $CertPath = "D:\AITB\ci-cd\nginx\ssl\server.crt"
    $KeyPath = "D:\AITB\ci-cd\nginx\ssl\server.key"
    
    # Create OpenSSL configuration
    $OpenSSLConf = @"
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = localhost

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = aitb.local
DNS.3 = 127.0.0.1
IP.1 = 127.0.0.1
"@
    
    $OpenSSLConf | Set-Content "D:\AITB\ci-cd\nginx\ssl\openssl.conf"
    
    # Generate certificate (requires OpenSSL)
    try {
        & openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
            -keyout $KeyPath `
            -out $CertPath `
            -config "D:\AITB\ci-cd\nginx\ssl\openssl.conf"
        
        Write-Host "✅ Self-signed certificate created" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Could not create SSL certificate. OpenSSL may not be installed." -ForegroundColor Yellow
        Write-Host "SSL will be disabled in nginx configuration." -ForegroundColor Yellow
    }
}

# Test nginx configuration
Write-Host "Testing nginx configuration..." -ForegroundColor Yellow
try {
    $TestResult = & "$NginxPath\nginx.exe" -t 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Nginx configuration test passed" -ForegroundColor Green
    } else {
        Write-Host "❌ Nginx configuration test failed:" -ForegroundColor Red
        Write-Host $TestResult -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Failed to test nginx configuration: $_" -ForegroundColor Red
    exit 1
}

# Start nginx service if requested
if ($StartService) {
    Write-Host "Starting nginx service..." -ForegroundColor Yellow
    
    # Stop existing nginx processes
    Get-Process -Name "nginx" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
    
    # Start nginx
    try {
        Start-Process -FilePath "$NginxPath\nginx.exe" -WorkingDirectory $NginxPath -WindowStyle Hidden
        Start-Sleep -Seconds 3
        
        # Verify nginx is running
        $NginxProcess = Get-Process -Name "nginx" -ErrorAction SilentlyContinue
        if ($NginxProcess) {
            Write-Host "✅ Nginx started successfully (PID: $($NginxProcess.Id -join ', '))" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to start nginx" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "❌ Failed to start nginx: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "=== AITB Nginx Blue/Green Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Configuration Details:" -ForegroundColor Cyan
Write-Host "  • Main site: http://localhost" -ForegroundColor White
Write-Host "  • Blue environment: http://localhost:8080" -ForegroundColor Blue
Write-Host "  • Green environment: http://localhost:8090" -ForegroundColor Green
Write-Host "  • Deployment status: http://localhost/admin/deployment-status" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Start AITB services in blue and green slots" -ForegroundColor White
Write-Host "  2. Use .\ci-cd\scripts\switch-environment.ps1 to switch colors" -ForegroundColor White
Write-Host "  3. Test with .\ci-cd\pipelines\promote.yml for automated deployment" -ForegroundColor White
Write-Host ""

if ($StartService) {
    Write-Host "Nginx is now running and ready for blue/green deployments!" -ForegroundColor Green
} else {
    Write-Host "To start nginx: nginx.exe (from $NginxPath)" -ForegroundColor Yellow
    Write-Host "To stop nginx: nginx.exe -s stop" -ForegroundColor Yellow
}

Write-Host ""