# AITB Environment Variables Population Script
# This script reads values from D:\Myenv.txt and populates service-specific .env files
# Run this script locally - DO NOT COMMIT the populated .env files

param(
    [string]$SourceFile = "D:\Myenv.txt",
    [string]$ConfigPath = "D:\configs\aitb"
)

Write-Host "AITB Environment Configuration Script" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green

# Check if source file exists
if (-not (Test-Path $SourceFile)) {
    Write-Error "Source file $SourceFile not found!"
    exit 1
}

# Read environment variables from source file
Write-Host "Reading environment variables from $SourceFile..." -ForegroundColor Yellow
$envVars = @{}

Get-Content $SourceFile | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        $envVars[$key] = $value
    }
}

Write-Host "Found $($envVars.Count) environment variables" -ForegroundColor Green

# Function to update .env file with values
function Update-EnvFile {
    param(
        [string]$FilePath,
        [hashtable]$Variables,
        [array]$RequiredKeys
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "File not found: $FilePath"
        return
    }
    
    $content = Get-Content $FilePath
    $updated = $false
    
    for ($i = 0; $i -lt $content.Length; $i++) {
        foreach ($key in $RequiredKeys) {
            if ($content[$i] -match "^$key=") {
                if ($Variables.ContainsKey($key)) {
                    $content[$i] = "$key=$($Variables[$key])"
                    $updated = $true
                    Write-Host "  Updated $key" -ForegroundColor Green
                } else {
                    Write-Warning "  Missing value for $key"
                }
            }
        }
    }
    
    if ($updated) {
        Set-Content -Path $FilePath -Value $content
        Write-Host "Updated: $FilePath" -ForegroundColor Green
    }
}

# Update WebApp .env
Write-Host "`nUpdating WebApp configuration..." -ForegroundColor Yellow
Update-EnvFile -FilePath "$ConfigPath\webapp\.env" -Variables $envVars -RequiredKeys @(
    "INFLUX_URL", "INFLUX_ORG", "INFLUX_BUCKET", "INFLUX_TOKEN",
    "GRAFANA_USER", "GRAFANA_PASSWORD", "COINAPI_KEY", "MCP_BASE_URL"
)

# Update Inference .env
Write-Host "`nUpdating Inference configuration..." -ForegroundColor Yellow
Update-EnvFile -FilePath "$ConfigPath\inference\.env" -Variables $envVars -RequiredKeys @(
    "HUGGINGFACE_API_KEY_01", "HUGGINGFACE_API_KEY_02", "HUGGINGFACE_API_KEY_03",
    "GOOGLE_STUDIO_API_KEY", "INFLUX_URL", "INFLUX_ORG", "INFLUX_BUCKET", "INFLUX_TOKEN",
    "MCP_BASE_URL", "INFERENCE_API_BASE"
)

# Update Bot .env
Write-Host "`nUpdating Bot configuration..." -ForegroundColor Yellow
Update-EnvFile -FilePath "$ConfigPath\bot\.env" -Variables $envVars -RequiredKeys @(
    "MY_BINANCE_API_KEY", "MY_BINANCE_SECRET_KEY", "BINANCE_API_KEY", "BINANCE_SECRET_KEY",
    "COINAPI_KEY", "INFLUX_URL", "INFLUX_ORG", "INFLUX_BUCKET", "INFLUX_TOKEN",
    "INFERENCE_API_BASE", "MCP_BASE_URL"
)

# Update Notifier .env
Write-Host "`nUpdating Notifier configuration..." -ForegroundColor Yellow
Update-EnvFile -FilePath "$ConfigPath\notifier\.env" -Variables $envVars -RequiredKeys @(
    "TELEGRAM_BOT_NAME", "TELEGRAM_TOKEN", "TELEGRAM_CHAT_ID",
    "INFLUX_URL", "INFLUX_ORG", "INFLUX_BUCKET", "INFLUX_TOKEN", "MCP_BASE_URL"
)

# Update Dashboard .env
Write-Host "`nUpdating Dashboard configuration..." -ForegroundColor Yellow
Update-EnvFile -FilePath "$ConfigPath\dashboard\.env" -Variables $envVars -RequiredKeys @(
    "INFLUX_URL", "INFLUX_ORG", "INFLUX_BUCKET", "INFLUX_TOKEN",
    "GRAFANA_USER", "GRAFANA_PASSWORD", "COINAPI_KEY",
    "MCP_BASE_URL", "INFERENCE_API_BASE"
)

Write-Host "`n✅ Environment configuration complete!" -ForegroundColor Green
Write-Host "📋 Remember: DO NOT commit the populated .env files!" -ForegroundColor Red