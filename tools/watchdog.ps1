#Requires -Version 5.1

<#
.SYNOPSIS
    AITB Watchdog Script - Health monitoring and Telegram alerting
    
.DESCRIPTION
    Episode 6 watchdog script that:
    - Polls /health endpoints for inference and API services
    - Monitors bot heartbeat (must be ≤60 seconds)
    - Posts to Telegram on service failures
    - Does NOT auto-restart services during trading hours
    - Logs all monitoring activities
    
.PARAMETER TelegramToken
    Telegram bot token for notifications
    
.PARAMETER TelegramChatId
    Telegram chat ID for notifications
    
.PARAMETER CheckInterval
    Check interval in seconds (default: 30)
    
.PARAMETER NoTelegram
    Disable Telegram notifications (log only)
    
.EXAMPLE
    .\watchdog.ps1
    
.EXAMPLE
    .\watchdog.ps1 -TelegramToken "your_token" -TelegramChatId "your_chat_id"
    
.EXAMPLE
    .\watchdog.ps1 -CheckInterval 60 -NoTelegram
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$TelegramToken = $env:TG_BOT_TOKEN,
    
    [Parameter(Mandatory = $false)]
    [string]$TelegramChatId = $env:TG_CHAT_ID,
    
    [Parameter(Mandatory = $false)]
    [int]$CheckInterval = 30,
    
    [Parameter(Mandatory = $false)]
    [switch]$NoTelegram
)

# Configuration
$SERVICES_CONFIG = @{
    "inference" = @{
        "url" = "http://localhost:8001/health"
        "name" = "AITB Inference Service"
        "critical" = $true
    }
    "webapp" = @{
        "url" = "http://localhost:61427/"
        "name" = "AITB WebApp"
        "critical" = $true
    }
    "bot" = @{
        "url" = "http://localhost:8000/health"
        "name" = "AITB Trading Bot"
        "critical" = $true
        "heartbeat_check" = $true
    }
    "dashboard" = @{
        "url" = "http://localhost:8501/health"
        "name" = "AITB Dashboard"
        "critical" = $false
    }
}

$GRAFANA_CONFIG = @{
    "url" = "http://localhost:3000/api/health"
    "name" = "Grafana"
    "critical" = $false
}

$LOGS_PATH = "D:\logs\aitb"
$WATCHDOG_LOG = "$LOGS_PATH\watchdog.log"
$HEARTBEAT_LOG = "$LOGS_PATH\bot\bot-heartbeat.log"

# Global state
$script:lastAlerts = @{}
$script:serviceStates = @{}
$script:alertCooldowns = @{}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            "ALERT" { "Magenta" }
            default { "White" }
        }
    )
    
    # Write to log file
    try {
        if (-not (Test-Path (Split-Path $WATCHDOG_LOG))) {
            New-Item -ItemType Directory -Path (Split-Path $WATCHDOG_LOG) -Force | Out-Null
        }
        Add-Content -Path $WATCHDOG_LOG -Value $logEntry
    }
    catch {
        Write-Warning "Failed to write to log file: $_"
    }
}

function Send-TelegramAlert {
    param(
        [string]$Message,
        [string]$AlertType = "WARNING"
    )
    
    if ($NoTelegram -or -not $TelegramToken -or -not $TelegramChatId) {
        Write-Log "Telegram disabled or not configured, skipping alert: $Message" -Level "WARN"
        return $false
    }
    
    try {
        $emoji = switch ($AlertType) {
            "ERROR" { "🔴" }
            "WARNING" { "⚠️" }
            "SUCCESS" { "✅" }
            "INFO" { "ℹ️" }
            default { "📊" }
        }
        
        $formattedMessage = "$emoji $AlertType - AITB Watchdog`n`n$Message`n`nTime: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"
        
        $body = @{
            chat_id = $TelegramChatId
            text = $formattedMessage
            parse_mode = "Markdown"
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri "https://api.telegram.org/bot$TelegramToken/sendMessage" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 10
        
        if ($response.ok) {
            Write-Log "Telegram alert sent successfully: $AlertType" -Level "SUCCESS"
            return $true
        } else {
            Write-Log "Telegram API returned error: $($response.description)" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Failed to send Telegram alert: $_" -Level "ERROR"
        return $false
    }
}

function Test-ServiceHealth {
    param(
        [string]$ServiceName,
        [hashtable]$ServiceConfig
    )
    
    $result = @{
        name = $ServiceName
        status = "unknown"
        response_time = 0
        error = $null
        healthy = $false
        last_check = Get-Date
    }
    
    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        $response = Invoke-RestMethod -Uri $ServiceConfig.url -Method Get -TimeoutSec 10 -ErrorAction Stop
        
        $stopwatch.Stop()
        $result.response_time = $stopwatch.ElapsedMilliseconds
        
        # Check if response indicates health
        if ($response -is [string] -and $response.Length -gt 0) {
            # For webapp home page, any response is good
            $result.status = "healthy"
            $result.healthy = $true
        }
        elseif ($response.status -eq "healthy" -or $response.status -eq "running") {
            # For health endpoints with status field
            $result.status = "healthy"
            $result.healthy = $true
        }
        elseif ($response.is_running -eq $true -or $response.uptime -gt 0) {
            # For bot service with different response format
            $result.status = "healthy"
            $result.healthy = $true
        }
        else {
            $result.status = "unhealthy"
            $result.error = "Service response indicates unhealthy state"
        }
        
        Write-Log "$ServiceName health check: $($result.status) ($($result.response_time)ms)"
        
    }
    catch {
        $result.status = "error"
        $result.error = $_.Exception.Message
        $result.response_time = if ($stopwatch) { $stopwatch.ElapsedMilliseconds } else { 0 }
        
        Write-Log "$ServiceName health check failed: $($result.error)" -Level "ERROR"
    }
    
    return $result
}

function Test-BotHeartbeat {
    try {
        if (-not (Test-Path $HEARTBEAT_LOG)) {
            Write-Log "Bot heartbeat log not found: $HEARTBEAT_LOG" -Level "WARN"
            return @{
                healthy = $false
                last_heartbeat = $null
                age_seconds = 999
                error = "Heartbeat log file not found"
            }
        }
        
        # Get the last few lines of the log to find the most recent heartbeat
        $logLines = Get-Content $HEARTBEAT_LOG -Tail 10 -ErrorAction Stop
        $heartbeatPattern = "🟢 HEARTBEAT:"
        
        $lastHeartbeat = $null
        foreach ($line in ($logLines | Sort-Object -Descending)) {
            if ($line -match $heartbeatPattern -and $line -match "\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}") {
                # Extract timestamp
                if ($line -match "(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[\.\d]*(?:Z|[\+\-]\d{2}:\d{2})?)") {
                    $lastHeartbeat = [DateTime]::Parse($matches[1])
                    break
                }
            }
        }
        
        if (-not $lastHeartbeat) {
            return @{
                healthy = $false
                last_heartbeat = $null
                age_seconds = 999
                error = "No heartbeat found in log"
            }
        }
        
        $ageSeconds = (Get-Date - $lastHeartbeat).TotalSeconds
        $healthy = $ageSeconds -le 60
        
        Write-Log "Bot heartbeat check: Last heartbeat $([math]::Round($ageSeconds, 1))s ago - $(if ($healthy) { 'HEALTHY' } else { 'STALE' })"
        
        return @{
            healthy = $healthy
            last_heartbeat = $lastHeartbeat
            age_seconds = $ageSeconds
            error = if ($healthy) { $null } else { "Heartbeat is $([math]::Round($ageSeconds, 1)) seconds old (>60s)" }
        }
    }
    catch {
        Write-Log "Bot heartbeat check failed: $_" -Level "ERROR"
        return @{
            healthy = $false
            last_heartbeat = $null
            age_seconds = 999
            error = "Failed to check heartbeat: $_"
        }
    }
}

function Test-GrafanaDatasource {
    try {
        $result = Test-ServiceHealth -ServiceName "grafana" -ServiceConfig $GRAFANA_CONFIG
        
        if ($result.healthy) {
            Write-Log "Grafana datasource check: OK"
            return @{
                healthy = $true
                status = "connected"
                error = $null
            }
        } else {
            Write-Log "Grafana datasource check: FAILED - $($result.error)" -Level "WARN"
            return @{
                healthy = $false
                status = "disconnected"
                error = $result.error
            }
        }
    }
    catch {
        Write-Log "Grafana datasource check failed: $_" -Level "ERROR"
        return @{
            healthy = $false
            status = "error"
            error = "Failed to check Grafana: $_"
        }
    }
}

function Should-SendAlert {
    param(
        [string]$ServiceName,
        [string]$AlertType,
        [int]$CooldownMinutes = 15
    )
    
    $alertKey = "$ServiceName-$AlertType"
    $now = Get-Date
    
    if ($script:alertCooldowns.ContainsKey($alertKey)) {
        $lastAlert = $script:alertCooldowns[$alertKey]
        $timeSinceLastAlert = ($now - $lastAlert).TotalMinutes
        
        if ($timeSinceLastAlert -lt $CooldownMinutes) {
            return $false
        }
    }
    
    $script:alertCooldowns[$alertKey] = $now
    return $true
}

function Process-ServiceResult {
    param(
        [string]$ServiceName,
        [hashtable]$ServiceConfig,
        [hashtable]$Result
    )
    
    $previousState = $script:serviceStates[$ServiceName]
    $script:serviceStates[$ServiceName] = $Result
    
    # Determine if we need to alert
    $shouldAlert = $false
    $alertType = "INFO"
    $alertMessage = ""
    
    if (-not $Result.healthy -and $ServiceConfig.critical) {
        # Service is down and critical
        if (-not $previousState -or $previousState.healthy) {
            # State changed from healthy to unhealthy
            $shouldAlert = Should-SendAlert -ServiceName $ServiceName -AlertType "DOWN"
            $alertType = "ERROR"
            $alertMessage = "🔴 *$($ServiceConfig.name)* is DOWN`n`nError: $($Result.error)`nLast check: $(Get-Date -Format 'HH:mm:ss')"
        }
    }
    elseif ($Result.healthy -and $previousState -and -not $previousState.healthy) {
        # Service recovered
        $shouldAlert = Should-SendAlert -ServiceName $ServiceName -AlertType "RECOVERY"
        $alertType = "SUCCESS"
        $alertMessage = "✅ *$($ServiceConfig.name)* has RECOVERED`n`nResponse time: $($Result.response_time)ms`nRecovered at: $(Get-Date -Format 'HH:mm:ss')"
    }
    
    if ($shouldAlert -and $alertMessage) {
        Send-TelegramAlert -Message $alertMessage -AlertType $alertType
    }
}

function Process-HeartbeatResult {
    param([hashtable]$HeartbeatResult)
    
    $previousState = $script:serviceStates["bot-heartbeat"]
    $script:serviceStates["bot-heartbeat"] = $HeartbeatResult
    
    if (-not $HeartbeatResult.healthy) {
        if (-not $previousState -or $previousState.healthy) {
            # Heartbeat went stale
            if (Should-SendAlert -ServiceName "bot-heartbeat" -AlertType "STALE") {
                $alertMessage = "⚠️ *Bot Heartbeat* is STALE`n`nLast heartbeat: $($HeartbeatResult.age_seconds) seconds ago`nRequired: ≤60 seconds`n`nBot may be unresponsive or stopped."
                Send-TelegramAlert -Message $alertMessage -AlertType "WARNING"
            }
        }
    }
    elseif ($HeartbeatResult.healthy -and $previousState -and -not $previousState.healthy) {
        # Heartbeat recovered
        if (Should-SendAlert -ServiceName "bot-heartbeat" -AlertType "RECOVERY") {
            $alertMessage = "✅ *Bot Heartbeat* has RECOVERED`n`nLast heartbeat: $($HeartbeatResult.age_seconds) seconds ago`nBot is responding normally."
            Send-TelegramAlert -Message $alertMessage -AlertType "SUCCESS"
        }
    }
}

function Start-HealthMonitoring {
    Write-Log "🚀 AITB Watchdog starting health monitoring..." -Level "SUCCESS"
    Write-Log "Check interval: $CheckInterval seconds"
    Write-Log "Telegram notifications: $(if ($NoTelegram -or -not $TelegramToken) { 'DISABLED' } else { 'ENABLED' })"
    Write-Log "Monitoring services: $($SERVICES_CONFIG.Keys -join ', ')"
    
    # Send startup notification
    if (-not $NoTelegram -and $TelegramToken) {
        Send-TelegramAlert -Message "🚀 *AITB Watchdog* started`n`nMonitoring $($SERVICES_CONFIG.Count) services`nCheck interval: $CheckInterval seconds`n`n⚠️ *Trading hours protection enabled*`nServices will NOT be auto-restarted during trading" -AlertType "INFO"
    }
    
    $iteration = 0
    
    while ($true) {
        try {
            $iteration++
            Write-Log "--- Health Check Iteration $iteration ---"
            
            # Check all services
            foreach ($serviceName in $SERVICES_CONFIG.Keys) {
                $serviceConfig = $SERVICES_CONFIG[$serviceName]
                $result = Test-ServiceHealth -ServiceName $serviceName -ServiceConfig $serviceConfig
                Process-ServiceResult -ServiceName $serviceName -ServiceConfig $serviceConfig -Result $result
            }
            
            # Check bot heartbeat specifically
            $heartbeatResult = Test-BotHeartbeat
            Process-HeartbeatResult -HeartbeatResult $heartbeatResult
            
            # Check Grafana datasource
            $grafanaResult = Test-GrafanaDatasource
            Process-ServiceResult -ServiceName "grafana" -ServiceConfig $GRAFANA_CONFIG -Result $grafanaResult
            
            # Summary log
            $healthyServices = ($script:serviceStates.Values | Where-Object { $_.healthy }).Count
            $totalServices = $script:serviceStates.Count
            Write-Log "Health check completed: $healthyServices/$totalServices services healthy"
            
            # Wait for next check
            Start-Sleep -Seconds $CheckInterval
        }
        catch {
            Write-Log "Error in monitoring loop: $_" -Level "ERROR"
            Start-Sleep -Seconds 10
        }
    }
}

# Handle Ctrl+C gracefully
$script:running = $true
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Write-Log "🛑 AITB Watchdog shutting down..." -Level "WARN"
    if (-not $NoTelegram -and $TelegramToken) {
        Send-TelegramAlert -Message "🛑 *AITB Watchdog* shutting down`n`nHealth monitoring stopped at $(Get-Date -Format 'HH:mm:ss')" -AlertType "WARNING"
    }
}

# Main execution
try {
    # Validate configuration
    if (-not $NoTelegram -and $TelegramToken -and $TelegramChatId) {
        Write-Log "Telegram notifications configured" -Level "SUCCESS"
    } elseif (-not $NoTelegram) {
        Write-Log "Telegram not configured - set TG_BOT_TOKEN and TG_CHAT_ID environment variables" -Level "WARN"
    }
    
    # Start monitoring
    Start-HealthMonitoring
}
catch {
    Write-Log "Fatal error in watchdog: $_" -Level "ERROR"
    exit 1
}