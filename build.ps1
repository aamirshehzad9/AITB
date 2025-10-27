# AITB Main Build Script
# Orchestrates building all services and produces immutable versioned artifacts

param(
    [string]$Version = "1.0.0",
    [string]$Configuration = "Release",
    [string]$OutputPath = "D:\AITB\dist",
    [switch]$CleanFirst = $false,
    [switch]$CreateRelease = $false
)

$ErrorActionPreference = "Stop"

Write-Host "AITB Main Build Script" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Green
Write-Host "Version: $Version" -ForegroundColor Yellow
Write-Host "Configuration: $Configuration" -ForegroundColor Yellow
Write-Host "Output: $OutputPath" -ForegroundColor Yellow
Write-Host "Clean First: $CleanFirst" -ForegroundColor Yellow
Write-Host "Create Release: $CreateRelease" -ForegroundColor Yellow

# Service definitions
$Services = @(
    @{
        Name = "webapp"
        Path = "AITB.WebApp\build.ps1"
        Description = "ASP.NET Core Web Application"
    },
    @{
        Name = "inference"
        Path = "services\inference\build.ps1"
        Description = "ML Inference Service"
    },
    @{
        Name = "bot"
        Path = "services\bot\build.ps1"
        Description = "Trading Bot Engine"
    },
    @{
        Name = "notifier"
        Path = "services\notifier\build.ps1"
        Description = "Notification Service"
    },
    @{
        Name = "dashboard"
        Path = "services\dashboard\build.ps1"
        Description = "Analytics Dashboard"
    }
)

try {
    $StartTime = Get-Date
    
    # Clean output directory if requested
    if ($CleanFirst -and (Test-Path $OutputPath)) {
        Write-Host "`nCleaning output directory..." -ForegroundColor Yellow
        Remove-Item "$OutputPath\*" -Force
    }
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        Write-Host "Created output directory: $OutputPath" -ForegroundColor Green
    }
    
    # Track build results
    $BuildResults = @()
    $TotalSize = 0
    
    # Build each service
    foreach ($service in $Services) {
        Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
        Write-Host "Building $($service.Name): $($service.Description)" -ForegroundColor Cyan
        Write-Host ("=" * 60) -ForegroundColor Cyan
        
        $ServiceStartTime = Get-Date
        
        try {
            # Execute service build script
            $BuildScript = Join-Path $PSScriptRoot $service.Path
            if (Test-Path $BuildScript) {
                & $BuildScript -Version $Version -Configuration $Configuration -OutputPath $OutputPath
                if ($LASTEXITCODE -ne 0) {
                    throw "Build script exited with code $LASTEXITCODE"
                }
            } else {
                throw "Build script not found: $BuildScript"
            }
            
            # Verify output files
            $ZipFile = "$OutputPath\$($service.Name)-$Version.zip"
            $ChecksumFile = "$OutputPath\$($service.Name)-$Version.zip.sha256"
            
            if (-not (Test-Path $ZipFile)) {
                throw "Output zip file not found: $ZipFile"
            }
            
            if (-not (Test-Path $ChecksumFile)) {
                throw "Checksum file not found: $ChecksumFile"
            }
            
            # Get file info
            $ZipInfo = Get-Item $ZipFile
            $ServiceBuildTime = (Get-Date) - $ServiceStartTime
            $TotalSize += $ZipInfo.Length
            
            # Read checksum
            $Checksum = (Get-Content $ChecksumFile).Split(' ')[0]
            
            $BuildResults += @{
                Service = $service.Name
                Status = "Success"
                ZipFile = $ZipFile
                Size = $ZipInfo.Length
                SizeMB = [math]::Round($ZipInfo.Length / 1MB, 2)
                Checksum = $Checksum
                BuildTime = $ServiceBuildTime
                Error = $null
            }
            
            Write-Host "✅ $($service.Name) build completed successfully" -ForegroundColor Green
            Write-Host "   Size: $([math]::Round($ZipInfo.Length / 1MB, 2)) MB" -ForegroundColor Gray
            Write-Host "   Time: $($ServiceBuildTime.TotalSeconds) seconds" -ForegroundColor Gray
            
        } catch {
            $ServiceBuildTime = (Get-Date) - $ServiceStartTime
            
            $BuildResults += @{
                Service = $service.Name
                Status = "Failed"
                ZipFile = $null
                Size = 0
                SizeMB = 0
                Checksum = $null
                BuildTime = $ServiceBuildTime
                Error = $_.Exception.Message
            }
            
            Write-Host "❌ $($service.Name) build failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    $TotalBuildTime = (Get-Date) - $StartTime
    
    # Create build summary
    Write-Host "`n" + ("=" * 80) -ForegroundColor Green
    Write-Host "BUILD SUMMARY" -ForegroundColor Green
    Write-Host ("=" * 80) -ForegroundColor Green
    
    $SuccessCount = ($BuildResults | Where-Object { $_.Status -eq "Success" }).Count
    $FailedCount = ($BuildResults | Where-Object { $_.Status -eq "Failed" }).Count
    
    Write-Host "Total Services: $($Services.Count)" -ForegroundColor White
    Write-Host "Successful: $SuccessCount" -ForegroundColor Green
    Write-Host "Failed: $FailedCount" -ForegroundColor Red
    Write-Host "Total Size: $([math]::Round($TotalSize / 1MB, 2)) MB" -ForegroundColor White
    Write-Host "Total Time: $($TotalBuildTime.TotalSeconds) seconds" -ForegroundColor White
    
    # Detailed results
    Write-Host "`nDetailed Results:" -ForegroundColor Yellow
    foreach ($result in $BuildResults) {
        $status = if ($result.Status -eq "Success") { "✅" } else { "❌" }
        Write-Host "$status $($result.Service) - $($result.SizeMB) MB - $($result.BuildTime.TotalSeconds)s" -ForegroundColor White
        if ($result.Status -eq "Failed") {
            Write-Host "   Error: $($result.Error)" -ForegroundColor Red
        }
    }
    
    # Create master checksum file
    if ($SuccessCount -gt 0) {
        Write-Host "`nCreating master checksum file..." -ForegroundColor Yellow
        $MasterChecksumFile = "$OutputPath\master-checksums-$Version.sha256"
        
        $BuildResults | Where-Object { $_.Status -eq "Success" } | ForEach-Object {
            "$($_.Checksum)  $($_.Service)-$Version.zip" | Add-Content $MasterChecksumFile
        }
        
        Write-Host "Master checksum file created: $MasterChecksumFile" -ForegroundColor Green
    }
    
    # Create build manifest
    $BuildManifest = @{
        version = $Version
        configuration = $Configuration
        buildTime = $StartTime.ToString("yyyy-MM-dd HH:mm:ss UTC")
        totalBuildTime = $TotalBuildTime.TotalSeconds
        totalSize = $TotalSize
        totalSizeMB = [math]::Round($TotalSize / 1MB, 2)
        successCount = $SuccessCount
        failedCount = $FailedCount
        services = $BuildResults
        outputPath = $OutputPath
    }
    
    $ManifestFile = "$OutputPath\build-manifest-$Version.json"
    $BuildManifest | ConvertTo-Json -Depth 4 | Set-Content $ManifestFile
    Write-Host "Build manifest created: $ManifestFile" -ForegroundColor Green
    
    # Create release package if requested
    if ($CreateRelease -and $SuccessCount -gt 0) {
        Write-Host "`nCreating release package..." -ForegroundColor Yellow
        
        $ReleaseDir = "$OutputPath\aitb-release-$Version"
        $ReleaseTempDir = "$env:TEMP\aitb-release-$Version"
        
        # Clean up any existing temp directory
        if (Test-Path $ReleaseTempDir) {
            Remove-Item $ReleaseTempDir -Recurse -Force
        }
        
        # Create release directory structure
        New-Item -Path $ReleaseTempDir -ItemType Directory -Force | Out-Null
        New-Item -Path "$ReleaseTempDir\services" -ItemType Directory -Force | Out-Null
        New-Item -Path "$ReleaseTempDir\checksums" -ItemType Directory -Force | Out-Null
        New-Item -Path "$ReleaseTempDir\manifests" -ItemType Directory -Force | Out-Null
        
        # Copy successful service packages
        $BuildResults | Where-Object { $_.Status -eq "Success" } | ForEach-Object {
            Copy-Item $_.ZipFile "$ReleaseTempDir\services\"
            Copy-Item "$($_.ZipFile).sha256" "$ReleaseTempDir\checksums\"
        }
        
        # Copy manifests
        Copy-Item $ManifestFile "$ReleaseTempDir\manifests\"
        if (Test-Path "$OutputPath\master-checksums-$Version.sha256") {
            Copy-Item "$OutputPath\master-checksums-$Version.sha256" "$ReleaseTempDir\checksums\"
        }
        
        # Create release README
        $ReleaseReadme = @"
# AITB Release Package v$Version

## Build Information
- Version: $Version
- Configuration: $Configuration
- Build Time: $($StartTime.ToString("yyyy-MM-dd HH:mm:ss UTC"))
- Total Size: $([math]::Round($TotalSize / 1MB, 2)) MB
- Services: $SuccessCount/$($Services.Count) successful

## Services Included
$($BuildResults | Where-Object { $_.Status -eq "Success" } | ForEach-Object { "- $($_.Service) ($($_.SizeMB) MB)" } | Out-String)

## Deployment
1. Extract service packages to their respective directories under D:\apps\aitb\
2. Follow the deployment runbooks in ci-cd\runbooks\
3. Verify checksums before deployment

## Verification
All packages include SHA256 checksums for integrity verification.
Use master-checksums-$Version.sha256 to verify all packages at once.

## Service Definitions
Service definitions are located in ci-cd\service_defs\
Use these for host-native service installation.
"@
        $ReleaseReadme | Set-Content "$ReleaseTempDir\README.md"
        
        # Create release archive
        $ReleaseZip = "$OutputPath\aitb-release-$Version.zip"
        Compress-Archive -Path "$ReleaseTempDir\*" -DestinationPath $ReleaseZip -Force
        
        # Calculate release checksum
        $ReleaseHash = Get-FileHash $ReleaseZip -Algorithm SHA256
        "$($ReleaseHash.Hash)  aitb-release-$Version.zip" | Set-Content "$OutputPath\aitb-release-$Version.zip.sha256"
        
        # Cleanup temp directory
        Remove-Item $ReleaseTempDir -Recurse -Force
        
        $ReleaseSize = [math]::Round((Get-Item $ReleaseZip).Length / 1MB, 2)
        Write-Host "✅ Release package created: $ReleaseZip ($ReleaseSize MB)" -ForegroundColor Green
    }
    
    # Final status
    if ($FailedCount -eq 0) {
        Write-Host "`n🎉 All builds completed successfully!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`n⚠️  Build completed with $FailedCount failures" -ForegroundColor Yellow
        exit 1
    }
    
} catch {
    Write-Host "`n💥 Main build script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}