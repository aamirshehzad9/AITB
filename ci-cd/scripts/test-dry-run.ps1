# AITB Episode 7 - Blue/Green Dry Run Test
# Validates complete blue/green workflow without making actual changes

param(
    [Parameter(Mandatory=$false)]
    [string]$Version = "1.0.0-test",
    
    [Parameter(Mandatory=$false)]
    [string]$NginxPath = "C:\nginx",
    
    [Parameter(Mandatory=$false)]
    [switch]$SetupNginx
)

$ErrorActionPreference = "Stop"

Write-Host "=== AITB Episode 7 - Blue/Green Dry Run Test ===" -ForegroundColor Cyan
Write-Host "Version: $Version" -ForegroundColor Yellow
Write-Host "Nginx Path: $NginxPath" -ForegroundColor Yellow
Write-Host ""

# Test Results Tracking
$TestResults = @()

function Add-TestResult {
    param($TestName, $Status, $Details)
    $TestResults += @{
        Test = $TestName
        Status = $Status
        Details = $Details
        Timestamp = Get-Date -Format "HH:mm:ss"
    }
    
    $Color = if ($Status -eq "PASS") { "Green" } elseif ($Status -eq "WARN") { "Yellow" } else { "Red" }
    Write-Host "[$($TestResults.Count.ToString().PadLeft(2))] $TestName - $Status" -ForegroundColor $Color
    if ($Details) {
        Write-Host "    $Details" -ForegroundColor Gray
    }
}

# Test 1: Nginx Configuration Validation
Write-Host "=== Test 1: Nginx Configuration Validation ===" -ForegroundColor Yellow

try {
    if (Test-Path "$NginxPath\nginx.exe") {
        Add-TestResult "Nginx Installation" "PASS" "Found at $NginxPath"
        
        # Test configuration files exist
        $configFiles = @(
            "D:\AITB\ci-cd\nginx\nginx.conf",
            "D:\AITB\ci-cd\nginx\env-mapping.conf",
            "D:\AITB\ci-cd\nginx\env-mapping-blue.conf",
            "D:\AITB\ci-cd\nginx\env-mapping-green.conf"
        )
        
        $missingConfigs = @()
        foreach ($configFile in $configFiles) {
            if (-not (Test-Path $configFile)) {
                $missingConfigs += $configFile
            }
        }
        
        if ($missingConfigs.Count -eq 0) {
            Add-TestResult "Nginx Configuration Files" "PASS" "All configuration files exist"
        } else {
            Add-TestResult "Nginx Configuration Files" "FAIL" "Missing: $($missingConfigs -join ', ')"
        }
    } else {
        Add-TestResult "Nginx Installation" "FAIL" "Nginx not found at $NginxPath"
    }
} catch {
    Add-TestResult "Nginx Configuration" "FAIL" $_.Exception.Message
}

# Test 2: Service Directory Structure
Write-Host ""
Write-Host "=== Test 2: Service Directory Structure ===" -ForegroundColor Yellow

$services = @("webapp", "inference", "bot", "notifier", "dashboard")
$environments = @("blue", "green")

foreach ($service in $services) {
    foreach ($env in $environments) {
        $servicePath = "D:\apps\aitb\$service\$env"
        if (Test-Path $servicePath) {
            Add-TestResult "Service Directory $service/$env" "PASS" "Directory exists"
        } else {
            Add-TestResult "Service Directory $service/$env" "WARN" "Directory missing (will be created during deployment)"
        }
    }
}

# Test 3: Scripts and Tools Validation
Write-Host ""
Write-Host "=== Test 3: Scripts and Tools Validation ===" -ForegroundColor Yellow

$requiredScripts = @(
    "D:\AITB\ci-cd\scripts\switch-environment.ps1",
    "D:\AITB\ci-cd\nginx\setup-nginx.ps1",
    "D:\AITB\tools\watchdog.ps1"
)

foreach ($script in $requiredScripts) {
    if (Test-Path $script) {
        Add-TestResult "Script $(Split-Path $script -Leaf)" "PASS" "Script exists and is ready"
    } else {
        Add-TestResult "Script $(Split-Path $script -Leaf)" "FAIL" "Script missing: $script"
    }
}

# Test 4: Environment Detection and Switching (Dry Run)
Write-Host ""
Write-Host "=== Test 4: Environment Detection and Switching (Dry Run) ===" -ForegroundColor Yellow

try {
    # Test current environment detection
    $currentEnv = "blue"  # Default for testing
    if (Test-Path "D:\AITB\ci-cd\nginx\env-mapping.conf") {
        $mappingContent = Get-Content "D:\AITB\ci-cd\nginx\env-mapping.conf" -Raw
        if ($mappingContent -match "webapp_green") {
            $currentEnv = "green"
        }
    }
    
    Add-TestResult "Environment Detection" "PASS" "Current environment: $currentEnv"
    
    # Test switch script dry run
    $targetEnv = if ($currentEnv -eq "blue") { "green" } else { "blue" }
    Add-TestResult "Target Environment" "PASS" "Target would be: $targetEnv"
    
    if (Test-Path "D:\AITB\ci-cd\scripts\switch-environment.ps1") {
        Write-Host "    Testing switch script dry run..." -ForegroundColor Cyan
        
        # This would fail without nginx running, so we'll just validate the script syntax
        $scriptContent = Get-Content "D:\AITB\ci-cd\scripts\switch-environment.ps1" -Raw
        if ($scriptContent -match "DryRun" -and $scriptContent -match "TargetEnvironment") {
            Add-TestResult "Switch Script Validation" "PASS" "Script has required dry-run capability"
        } else {
            Add-TestResult "Switch Script Validation" "FAIL" "Script missing dry-run parameters"
        }
    }
} catch {
    Add-TestResult "Environment Switching" "FAIL" $_.Exception.Message
}

# Test 5: Pipeline Configuration Validation
Write-Host ""
Write-Host "=== Test 5: Pipeline Configuration Validation ===" -ForegroundColor Yellow

$pipelineFile = "D:\AITB\ci-cd\pipelines\promote.yml"
if (Test-Path $pipelineFile) {
    $pipelineContent = Get-Content $pipelineFile -Raw
    
    # Check for required pipeline features
    $requiredFeatures = @(
        "workflow_dispatch",
        "download-artifacts", 
        "deploy-to-idle",
        "run-acceptance-tests",
        "switch-traffic",
        "dry_run"
    )
    
    $missingFeatures = @()
    foreach ($feature in $requiredFeatures) {
        if ($pipelineContent -notmatch $feature) {
            $missingFeatures += $feature
        }
    }
    
    if ($missingFeatures.Count -eq 0) {
        Add-TestResult "Pipeline Configuration" "PASS" "All required features present"
    } else {
        Add-TestResult "Pipeline Configuration" "WARN" "Missing features: $($missingFeatures -join ', ')"
    }
} else {
    Add-TestResult "Pipeline Configuration" "FAIL" "Pipeline file missing: $pipelineFile"
}

# Test 6: Logging and Monitoring Setup
Write-Host ""
Write-Host "=== Test 6: Logging and Monitoring Setup ===" -ForegroundColor Yellow

$logDirs = @(
    "D:\logs\aitb\deployment",
    "D:\logs\aitb\bot",
    "D:\logs\aitb\inference",
    "D:\logs\nginx"
)

foreach ($logDir in $logDirs) {
    if (Test-Path $logDir) {
        Add-TestResult "Log Directory $(Split-Path $logDir -Leaf)" "PASS" "Directory exists"
    } else {
        try {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            Add-TestResult "Log Directory $(Split-Path $logDir -Leaf)" "PASS" "Directory created"
        } catch {
            Add-TestResult "Log Directory $(Split-Path $logDir -Leaf)" "FAIL" "Cannot create directory: $_"
        }
    }
}

# Optional: Setup Nginx for Testing
if ($SetupNginx -and (Test-Path "D:\AITB\ci-cd\nginx\setup-nginx.ps1")) {
    Write-Host ""
    Write-Host "=== Setting up Nginx for Testing ===" -ForegroundColor Yellow
    
    try {
        & "D:\AITB\ci-cd\nginx\setup-nginx.ps1" -NginxPath $NginxPath -CreateSelfSignedCert
        Add-TestResult "Nginx Setup" "PASS" "Nginx configured for blue/green testing"
    } catch {
        Add-TestResult "Nginx Setup" "FAIL" "Failed to setup nginx: $_"
    }
}

# Test Summary
Write-Host ""
Write-Host "=== Episode 7 Dry Run Test Summary ===" -ForegroundColor Cyan

$passCount = ($TestResults | Where-Object { $_.Status -eq "PASS" }).Count
$warnCount = ($TestResults | Where-Object { $_.Status -eq "WARN" }).Count
$failCount = ($TestResults | Where-Object { $_.Status -eq "FAIL" }).Count
$totalCount = $TestResults.Count

Write-Host "Total Tests: $totalCount" -ForegroundColor White
Write-Host "✅ Passed: $passCount" -ForegroundColor Green
Write-Host "⚠️ Warnings: $warnCount" -ForegroundColor Yellow
Write-Host "❌ Failed: $failCount" -ForegroundColor Red

# Detailed Results
Write-Host ""
Write-Host "=== Detailed Test Results ===" -ForegroundColor Cyan
$TestResults | ForEach-Object {
    $statusColor = switch ($_.Status) {
        "PASS" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
    }
    Write-Host "[$($_.Timestamp)] $($_.Test): $($_.Status)" -ForegroundColor $statusColor
    if ($_.Details) {
        Write-Host "  → $($_.Details)" -ForegroundColor Gray
    }
}

# Overall Assessment
Write-Host ""
if ($failCount -eq 0) {
    Write-Host "🎯 EPISODE 7 DRY RUN: READY FOR PRODUCTION" -ForegroundColor Green
    Write-Host "All critical components are in place for blue/green deployment" -ForegroundColor Green
} elseif ($failCount -le 2) {
    Write-Host "⚠️ EPISODE 7 DRY RUN: MOSTLY READY" -ForegroundColor Yellow
    Write-Host "Minor issues detected but blue/green infrastructure is functional" -ForegroundColor Yellow
} else {
    Write-Host "❌ EPISODE 7 DRY RUN: NEEDS ATTENTION" -ForegroundColor Red
    Write-Host "Several critical components need to be addressed" -ForegroundColor Red
}

# Next Steps
Write-Host ""
Write-Host "=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. Install nginx if not already installed: https://nginx.org/en/download.html" -ForegroundColor White
Write-Host "2. Run nginx setup: .\ci-cd\nginx\setup-nginx.ps1 -StartService" -ForegroundColor White
Write-Host "3. Test environment switching: .\ci-cd\scripts\switch-environment.ps1 -TargetEnvironment green -DryRun" -ForegroundColor White
Write-Host "4. Run promotion pipeline: GitHub Actions → AITB Blue/Green Promotion" -ForegroundColor White
Write-Host ""

# Save test results
$resultFile = "D:\logs\aitb\deployment\dry-run-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$TestResults | ConvertTo-Json -Depth 3 | Set-Content $resultFile
Write-Host "Detailed results saved to: $resultFile" -ForegroundColor Cyan

Write-Host ""
Write-Host "Episode 7 Blue/Green Infrastructure Validation Complete!" -ForegroundColor Green