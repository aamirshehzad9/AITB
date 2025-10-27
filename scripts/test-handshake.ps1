#!/usr/bin/env powershell
# Test script to simulate GOmini-AI handshake initialization
# ⚠️ MANDATORY: Agents MUST read /context/project_manifest.yaml before any action.

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AITB Handshake Test Script" -ForegroundColor Cyan
Write-Host "Simulating GOmini-AI (192.168.1.4)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Test payload
$testPayload = @{
    node = "GOmini-AI"
    ip = "192.168.1.4"
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
} | ConvertTo-Json

# AITB Host endpoint
$aitbEndpoint = "http://192.168.1.2:8505/handshake/init"

Write-Host "Sending handshake initialization to: $aitbEndpoint" -ForegroundColor Yellow
Write-Host "Payload:" -ForegroundColor Yellow
Write-Host $testPayload -ForegroundColor White

try {
    # Send POST request
    $response = Invoke-RestMethod -Uri $aitbEndpoint -Method POST -Body $testPayload -ContentType "application/json" -TimeoutSec 30
    
    Write-Host "" -ForegroundColor White
    Write-Host "✓ Response received:" -ForegroundColor Green
    Write-Host ($response | ConvertTo-Json -Depth 3) -ForegroundColor White
    
    # Check handshake status
    Write-Host "" -ForegroundColor White
    Write-Host "Checking handshake status..." -ForegroundColor Yellow
    $statusResponse = Invoke-RestMethod -Uri "http://192.168.1.2:8505/handshake/status" -Method GET
    Write-Host ($statusResponse | ConvertTo-Json -Depth 3) -ForegroundColor White
    
    Write-Host "" -ForegroundColor White
    Write-Host "✓ Handshake test completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "" -ForegroundColor White
    Write-Host "✗ Handshake test failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    
    if ($_.Exception.Response) {
        Write-Host "HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    }
}

Write-Host "" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan