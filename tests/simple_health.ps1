# Simple AITB Health Check
param(
    [string]$WebAppUrl = "http://localhost:61427"
)

Write-Host "🚀 AITB Health Check Started" -ForegroundColor Green
Write-Host "📊 Testing WebApp at: $WebAppUrl"

$Results = @()
$ErrorActionPreference = "SilentlyContinue"

# Test 1: Home Page
Write-Host "`n🧪 Test 1: Home Page" -ForegroundColor Cyan
try {
    $Response = Invoke-WebRequest -Uri "$WebAppUrl/" -UseBasicParsing -TimeoutSec 10
    if ($Response.StatusCode -eq 200) {
        Write-Host "✅ PASS: Home page accessible" -ForegroundColor Green
        $Results += "✅ Home Page: 200 OK"
    }
}
catch {
    Write-Host "❌ FAIL: Home page error" -ForegroundColor Red
    $Results += "❌ Home Page: Failed"
}

# Test 2: Authentication
Write-Host "`n🧪 Test 2: Login Test" -ForegroundColor Cyan
try {
    $LoginData = '{"username":"admin","password":"admin123"}'
    $Response = Invoke-WebRequest -Uri "$WebAppUrl/api/auth/login" -Method POST -Body $LoginData -ContentType "application/json" -UseBasicParsing -TimeoutSec 10
    
    if ($Response.StatusCode -eq 200) {
        $AuthResult = $Response.Content | ConvertFrom-Json
        if ($AuthResult.success) {
            Write-Host "✅ PASS: Authentication successful" -ForegroundColor Green
            $Results += "✅ Authentication: Success"
            $global:Token = $AuthResult.token
        }
    }
}
catch {
    Write-Host "❌ FAIL: Authentication failed" -ForegroundColor Red
    $Results += "❌ Authentication: Failed"
}

# Test 3: Admin Page (if authenticated)
Write-Host "`n🧪 Test 3: Admin Access" -ForegroundColor Cyan
try {
    if ($global:Token) {
        $Headers = @{ "Authorization" = "Bearer $($global:Token)" }
        $Response = Invoke-WebRequest -Uri "$WebAppUrl/admin" -Headers $Headers -UseBasicParsing -TimeoutSec 10
        
        if ($Response.StatusCode -eq 200) {
            Write-Host "✅ PASS: Admin page accessible" -ForegroundColor Green
            $Results += "✅ Admin Access: Authorized"
        }
    } else {
        Write-Host "⚠️ SKIP: No auth token for admin test" -ForegroundColor Yellow
        $Results += "⚠️ Admin Access: Skipped"
    }
}
catch {
    Write-Host "❌ FAIL: Admin access denied" -ForegroundColor Red
    $Results += "❌ Admin Access: Failed"
}

# Generate Summary
$PassCount = ($Results | Where-Object { $_ -match "✅" }).Count
$FailCount = ($Results | Where-Object { $_ -match "❌" }).Count

Write-Host "`n📊 SUMMARY" -ForegroundColor Magenta
Write-Host "Passed: $PassCount" -ForegroundColor Green
Write-Host "Failed: $FailCount" -ForegroundColor Red

foreach ($result in $Results) {
    Write-Host "  $result"
}

if ($FailCount -eq 0) {
    Write-Host "`n🎉 ALL TESTS PASSED!" -ForegroundColor Green
    Write-Host "AITB WebApp is running successfully on $WebAppUrl" -ForegroundColor Green
} else {
    Write-Host "`n⚠️ Some tests failed. Check the results above." -ForegroundColor Yellow
}

# Save simple report
$ReportDir = "D:\AITB\reports"
if (!(Test-Path $ReportDir)) { New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null }

$Report = "# AITB WebApp Health Check Report`n`nGenerated: $(Get-Date)`nWebApp URL: $WebAppUrl`n`n## Results`n`n$($Results -join "`n")`n`n## Summary`n`nPassed: $PassCount, Failed: $FailCount`n`n$(if ($FailCount -eq 0) { '✅ ALL SYSTEMS OPERATIONAL' } else { '⚠️ ISSUES DETECTED' })"

$Report | Out-File -FilePath "$ReportDir\webapp_health.md" -Encoding UTF8

Write-Host "`n📄 Report saved to: $ReportDir\webapp_health.md" -ForegroundColor Cyan