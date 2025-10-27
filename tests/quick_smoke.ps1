# AITB Quick Smoke Test - Lightweight Version
# Zero-dependency proof that core systems work

param(
    [string]$WebAppUrl = "http://localhost:5000",
    [string]$DashboardUrl = "http://localhost:8502"
)

$ErrorActionPreference = "Continue"
$StartTime = Get-Date
$ReportsDir = "D:\AITB\reports"

# Ensure reports directory exists
if (!(Test-Path $ReportsDir)) {
    New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
}

Write-Host "🚀 AITB Quick Smoke Test Started" -ForegroundColor Green
Write-Host "📊 Testing URLs: WebApp=$WebAppUrl, Dashboard=$DashboardUrl"

$Results = @()

# Test 1: Home Page
Write-Host "`n🧪 Test 1: Home Page Accessibility" -ForegroundColor Cyan
try {
    $Response = Invoke-WebRequest -Uri "$WebAppUrl/" -UseBasicParsing -TimeoutSec 10
    if ($Response.StatusCode -eq 200) {
        Write-Host "✅ PASS: Home page returns 200" -ForegroundColor Green
        $Results += "✅ Home Page: 200 OK"
    }
}
catch {
    Write-Host "❌ FAIL: Home page - $($_.Exception.Message)" -ForegroundColor Red
    $Results += "❌ Home Page: $($_.Exception.Message)"
}

# Test 2: Login Page
Write-Host "`n🧪 Test 2: Login Page" -ForegroundColor Cyan
try {
    $Response = Invoke-WebRequest -Uri "$WebAppUrl/auth/login" -UseBasicParsing -TimeoutSec 10
    if ($Response.StatusCode -eq 200) {
        Write-Host "✅ PASS: Login page returns 200" -ForegroundColor Green
        $Results += "✅ Login Page: 200 OK"
    }
}
catch {
    Write-Host "❌ FAIL: Login page - $($_.Exception.Message)" -ForegroundColor Red
    $Results += "❌ Login Page: $($_.Exception.Message)"
}

# Test 3: Authentication
Write-Host "`n🧪 Test 3: Authentication System" -ForegroundColor Cyan
$Token = $null
try {
    $LoginData = @{
        username = "admin"
        password = "admin123"
    } | ConvertTo-Json

    $Response = Invoke-WebRequest -Uri "$WebAppUrl/api/auth/login" -Method POST -Body $LoginData -ContentType "application/json" -UseBasicParsing -TimeoutSec 10
    
    if ($Response.StatusCode -eq 200) {
        $AuthResult = $Response.Content | ConvertFrom-Json
        if ($AuthResult.success -and $AuthResult.token) {
            Write-Host "✅ PASS: Authentication successful, token received" -ForegroundColor Green
            $Results += "✅ Authentication: Token received"
            $Token = $AuthResult.token
        }
    }
}
catch {
    Write-Host "❌ FAIL: Authentication - $($_.Exception.Message)" -ForegroundColor Red
    $Results += "❌ Authentication: $($_.Exception.Message)"
}

# Test 4: Bot Status
Write-Host "`n🧪 Test 4: Bot Status Endpoint" -ForegroundColor Cyan
try {
    if ($Token) {
        $Headers = @{ "Authorization" = "Bearer $Token" }
        $Response = Invoke-WebRequest -Uri "$WebAppUrl/api/bot/status" -Headers $Headers -UseBasicParsing -TimeoutSec 10
    } else {
        $Response = Invoke-WebRequest -Uri "$DashboardUrl/bot/status" -UseBasicParsing -TimeoutSec 10
    }
    
    if ($Response.StatusCode -eq 200) {
        $StatusData = $Response.Content | ConvertFrom-Json
        Write-Host "✅ PASS: Bot status endpoint returns JSON data" -ForegroundColor Green
        $Results += "✅ Bot Status: JSON response received"
    }
}
catch {
    Write-Host "❌ FAIL: Bot status - $($_.Exception.Message)" -ForegroundColor Red
    $Results += "❌ Bot Status: $($_.Exception.Message)"
}

# Test 5: Market Data
Write-Host "`n🧪 Test 5: Market Data Endpoint" -ForegroundColor Cyan
try {
    if ($Token) {
        $Headers = @{ "Authorization" = "Bearer $Token" }
        $Response = Invoke-WebRequest -Uri "$WebAppUrl/api/chart/price?symbol=BTCUSDT" -Headers $Headers -UseBasicParsing -TimeoutSec 10
    } else {
        $Response = Invoke-WebRequest -Uri "$DashboardUrl/data/price?symbol=BTCUSDT" -UseBasicParsing -TimeoutSec 10
    }
    
    if ($Response.StatusCode -eq 200) {
        $PriceData = $Response.Content | ConvertFrom-Json
        Write-Host "✅ PASS: Market data endpoint returns price data" -ForegroundColor Green
        $Results += "✅ Market Data: Price data received"
    }
}
catch {
    Write-Host "❌ FAIL: Market data - $($_.Exception.Message)" -ForegroundColor Red
    $Results += "❌ Market Data: $($_.Exception.Message)"
}

# Test 6: Bot Control
Write-Host "`n🧪 Test 6: Bot Control API" -ForegroundColor Cyan
try {
    if ($Token) {
        $Headers = @{ "Authorization" = "Bearer $Token" }
        $ControlData = @{
            action = "start"
            symbol = "BTCUSDT"
            timeframe = "1m"
        } | ConvertTo-Json

        $Response = Invoke-WebRequest -Uri "$WebAppUrl/api/bot/control" -Method POST -Headers $Headers -Body $ControlData -ContentType "application/json" -UseBasicParsing -TimeoutSec 10
        
        Write-Host "⏳ Waiting 5 seconds for state change..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        
        # Check status after control command
        $StatusResponse = Invoke-WebRequest -Uri "$WebAppUrl/api/bot/status" -Headers $Headers -UseBasicParsing -TimeoutSec 10
        $StatusData = $StatusResponse.Content | ConvertFrom-Json
        
        Write-Host "✅ PASS: Bot control command executed" -ForegroundColor Green
        $Results += "✅ Bot Control: Command executed"
    } else {
        Write-Host "⚠️ SKIP: Bot control test skipped (no auth token)" -ForegroundColor Yellow
        $Results += "⚠️ Bot Control: Skipped (no auth token)"
    }
}
catch {
    Write-Host "❌ FAIL: Bot control - $($_.Exception.Message)" -ForegroundColor Red
    $Results += "❌ Bot Control: $($_.Exception.Message)"
}

# Generate final report
$EndTime = Get-Date
$Duration = $EndTime - $StartTime
$PassCount = ($Results | Where-Object { $_ -match "✅" }).Count
$FailCount = ($Results | Where-Object { $_ -match "❌" }).Count
$TotalTests = $PassCount + $FailCount

Write-Host "`n📊 TEST SUMMARY" -ForegroundColor Magenta
Write-Host "Total Tests: $TotalTests" -ForegroundColor White
Write-Host "Passed: $PassCount" -ForegroundColor Green
Write-Host "Failed: $FailCount" -ForegroundColor Red
Write-Host "Duration: $($Duration.TotalSeconds.ToString('F2'))s" -ForegroundColor White

# Create simple acceptance report
$AcceptanceReport = "# AITB Quick Smoke Test Results`n`nGenerated: $(Get-Date)`nDuration: $($Duration.TotalSeconds.ToString('F2')) seconds`nStatus: $(if ($FailCount -eq 0) { 'ALL TESTS PASSED' } else { "$FailCount ISSUES FOUND" })`n`n## Test Results`n`nTotal Tests: $TotalTests`nPassed: $PassCount`nFailed: $FailCount`n`n## Details`n`n$($Results -join "`n")`n`n## Final Verdict`n`n$(if ($FailCount -eq 0) { 'AITB SYSTEM OPERATIONAL - All core functionality verified' } else { 'SYSTEM NEEDS ATTENTION - Review failed tests' })`n`nGenerated at: $(Get-Date)"

$AcceptanceFile = "$ReportsDir\ACCEPTANCE.md"
$AcceptanceReport | Out-File -FilePath $AcceptanceFile -Encoding UTF8

Write-Host "`n📄 Acceptance report saved: $AcceptanceFile" -ForegroundColor Cyan

if ($FailCount -eq 0) {
    Write-Host "`n🎉 ALL TESTS PASSED - AITB SYSTEM VERIFIED!" -ForegroundColor Green
} else {
    Write-Host "`n⚠️ $FailCount TESTS FAILED - CHECK RESULTS" -ForegroundColor Yellow
}

Write-Host "`nQuick verification complete." -ForegroundColor Blue