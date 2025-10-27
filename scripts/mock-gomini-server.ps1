#!/usr/bin/env powershell
# Mock GOmini-AI verification endpoint for testing
# ⚠️ MANDATORY: Agents MUST read /context/project_manifest.yaml before any action.
# Runs on http://192.168.1.4:8505/handshake/verify

param(
    [Parameter()]
    [int]$Port = 8505,
    
    [Parameter()]
    [string]$IP = "192.168.1.4"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Mock GOmini-AI Verification Server" -ForegroundColor Cyan
Write-Host "Listening on: http://$IP`:$Port" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Create a simple HTTP listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://$IP`:$Port/")

try {
    $listener.Start()
    Write-Host "✓ Mock server started successfully" -ForegroundColor Green
    Write-Host "Waiting for verification requests from AITB..." -ForegroundColor Yellow
    
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        # Log the incoming request
        Write-Host "" -ForegroundColor White
        Write-Host "$(Get-Date) - Received $($request.HttpMethod) $($request.Url)" -ForegroundColor Cyan
        
        if ($request.HttpMethod -eq "POST" -and $request.Url.AbsolutePath -eq "/handshake/verify") {
            # Read the request body
            $reader = New-Object System.IO.StreamReader($request.InputStream)
            $requestBody = $reader.ReadToEnd()
            $reader.Close()
            
            Write-Host "Request body: $requestBody" -ForegroundColor White
            
            try {
                $payload = $requestBody | ConvertFrom-Json
                
                # Validate the verification payload
                if ($payload.node -eq "AITB" -and $payload.ip -eq "192.168.1.2" -and $payload.token) {
                    # Send success response
                    $responseData = @{
                        status = "verified"
                        node = "GOmini-AI"
                        ip = "192.168.1.4"
                        token = $payload.token
                        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    } | ConvertTo-Json
                    
                    $response.StatusCode = 200
                    $response.ContentType = "application/json"
                    
                    Write-Host "✓ Sending verification success response" -ForegroundColor Green
                } else {
                    # Send error response
                    $responseData = @{
                        error = "Invalid verification payload"
                        expected = @{
                            node = "AITB"
                            ip = "192.168.1.2"
                        }
                        received = $payload
                    } | ConvertTo-Json
                    
                    $response.StatusCode = 400
                    $response.ContentType = "application/json"
                    
                    Write-Host "✗ Sending verification error response" -ForegroundColor Red
                }
            } catch {
                # Send JSON parse error
                $responseData = @{
                    error = "Invalid JSON payload"
                    message = $_.Exception.Message
                } | ConvertTo-Json
                
                $response.StatusCode = 400
                $response.ContentType = "application/json"
                
                Write-Host "✗ JSON parse error: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            # Send 404 for other endpoints
            $responseData = @{
                error = "Endpoint not found"
                path = $request.Url.AbsolutePath
                method = $request.HttpMethod
            } | ConvertTo-Json
            
            $response.StatusCode = 404
            $response.ContentType = "application/json"
            
            Write-Host "✗ Endpoint not found: $($request.HttpMethod) $($request.Url.AbsolutePath)" -ForegroundColor Yellow
        }
        
        # Send the response
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseData)
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.OutputStream.Close()
        
        Write-Host "Response sent: $responseData" -ForegroundColor Gray
    }
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    Write-Host "Mock server stopped." -ForegroundColor Yellow
}