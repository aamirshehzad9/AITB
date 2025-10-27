# AITB WebApp Build Script
# Builds ASP.NET Core application and packages into versioned zip

param(
    [string]$Version = "1.0.0",
    [string]$Configuration = "Release",
    [string]$OutputPath = "D:\AITB\dist"
)

$ErrorActionPreference = "Stop"

Write-Host "AITB WebApp Build" -ForegroundColor Green
Write-Host "=================" -ForegroundColor Green
Write-Host "Version: $Version" -ForegroundColor Yellow
Write-Host "Configuration: $Configuration" -ForegroundColor Yellow
Write-Host "Output: $OutputPath" -ForegroundColor Yellow

# Set paths
$ProjectPath = "D:\AITB\AITB.WebApp"
$BuildPath = "$ProjectPath\bin\$Configuration\net8.0"
$TempPath = "$env:TEMP\aitb-webapp-build-$Version"
$ZipPath = "$OutputPath\webapp-$Version.zip"

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

    # Restore dependencies
    Write-Host "`nRestoring NuGet packages..." -ForegroundColor Yellow
    Push-Location $ProjectPath
    dotnet restore
    if ($LASTEXITCODE -ne 0) { throw "dotnet restore failed" }

    # Build project
    Write-Host "`nBuilding project..." -ForegroundColor Yellow
    dotnet build -c $Configuration --no-restore
    if ($LASTEXITCODE -ne 0) { throw "dotnet build failed" }

    # Publish for deployment
    Write-Host "`nPublishing application..." -ForegroundColor Yellow
    dotnet publish -c $Configuration --no-build --output $TempPath
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed" }

    Pop-Location

    # Create version info file
    $VersionInfo = @{
        service = "webapp"
        version = $Version
        buildTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss UTC")
        configuration = $Configuration
        framework = "net8.0"
        runtime = "host-native"
    }
    $VersionInfo | ConvertTo-Json -Depth 2 | Set-Content "$TempPath\version.json"

    # Create startup script
    $StartupScript = @"
@echo off
REM AITB WebApp Startup Script
REM Load environment from D:\configs\aitb\webapp\.env

set CONFIG_FILE=D:\configs\aitb\webapp\.env
if exist "%CONFIG_FILE%" (
    for /f "usebackq tokens=1,2 delims==" %%a in ("%CONFIG_FILE%") do (
        if not "%%a"=="" if not "%%a:~0,1%"=="#" set %%a=%%b
    )
)

dotnet AITB.WebApp.dll
"@
    $StartupScript | Set-Content "$TempPath\start.bat"

    # Create PowerShell startup script
    $PSStartupScript = @"
# AITB WebApp PowerShell Startup Script
# Load environment from D:\configs\aitb\webapp\.env

`$ConfigFile = "D:\configs\aitb\webapp\.env"
if (Test-Path `$ConfigFile) {
    Get-Content `$ConfigFile | ForEach-Object {
        if (`$_ -match '^([^=]+)=(.*)$' -and -not `$_.StartsWith('#')) {
            `$key = `$matches[1].Trim()
            `$value = `$matches[2].Trim()
            [Environment]::SetEnvironmentVariable(`$key, `$value, "Process")
            Write-Host "Loaded: `$key" -ForegroundColor Green
        }
    }
}

# Start the application
dotnet AITB.WebApp.dll
"@
    $PSStartupScript | Set-Content "$TempPath\start.ps1"

    # Create README
    $ReadmeContent = @"
# AITB WebApp - Version $Version

## Description
ASP.NET Core web application for AITB trading interface.

## Built
- Time: $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss UTC"))
- Configuration: $Configuration
- Framework: .NET 8.0

## Deployment
1. Extract to D:\apps\aitb\webapp\$Version\
2. Ensure D:\configs\aitb\webapp\.env is configured
3. Run start.ps1 or start.bat

## Configuration
Reads environment variables from: D:\configs\aitb\webapp\.env
Required variables: INFLUX_URL, INFLUX_ORG, INFLUX_BUCKET, INFLUX_TOKEN, GRAFANA_USER, GRAFANA_PASSWORD, COINAPI_KEY, MCP_BASE_URL

## Service Definition
Use: ci-cd\service_defs\webapp.json
"@
    $ReadmeContent | Set-Content "$TempPath\README.md"

    # Create the zip file
    Write-Host "`nCreating zip package..." -ForegroundColor Yellow
    Compress-Archive -Path "$TempPath\*" -DestinationPath $ZipPath -Force

    # Calculate checksum
    $Hash = Get-FileHash $ZipPath -Algorithm SHA256
    $ChecksumFile = "$OutputPath\webapp-$Version.zip.sha256"
    "$($Hash.Hash)  webapp-$Version.zip" | Set-Content $ChecksumFile

    # Cleanup temp directory
    Remove-Item $TempPath -Recurse -Force

    # Output results
    $ZipSize = [math]::Round((Get-Item $ZipPath).Length / 1MB, 2)
    Write-Host "`n✅ Build completed successfully!" -ForegroundColor Green
    Write-Host "📦 Package: $ZipPath ($ZipSize MB)" -ForegroundColor Green
    Write-Host "🔒 Checksum: $ChecksumFile" -ForegroundColor Green
    Write-Host "🔢 SHA256: $($Hash.Hash)" -ForegroundColor Gray

} catch {
    Write-Host "`n❌ Build failed: $($_.Exception.Message)" -ForegroundColor Red
    if (Test-Path $TempPath) {
        Remove-Item $TempPath -Recurse -Force
    }
    exit 1
} finally {
    if (Get-Location -eq $ProjectPath) {
        Pop-Location
    }
}