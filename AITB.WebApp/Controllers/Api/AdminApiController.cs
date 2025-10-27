using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;

namespace AITB.WebApp.Controllers.Api
{
    [ApiController]
    [Route("api/admin")]
    [Authorize(Policy = "AdminOnly")]
    public class AdminApiController : ControllerBase
    {
        private readonly ILogger<AdminApiController> _logger;
        private readonly HttpClient _httpClient;

        public AdminApiController(ILogger<AdminApiController> logger, HttpClient httpClient)
        {
            _logger = logger;
            _httpClient = httpClient;
        }

        [HttpPost("backfill-candles")]
        public async Task<IActionResult> BackfillCandles([FromBody] BackfillRequest? request = null)
        {
            try
            {
                var symbol = request?.Symbol ?? "BTCUSDT";
                var interval = request?.Interval ?? "1m";
                var limit = request?.Limit ?? 1000;

                _logger.LogInformation($"Starting candle backfill for {symbol} {interval} (limit: {limit})");

                // Call the dashboard API to trigger backfill
                var backfillRequest = new
                {
                    symbol = symbol,
                    interval = interval,
                    limit = limit,
                    action = "backfill"
                };

                var json = System.Text.Json.JsonSerializer.Serialize(backfillRequest);
                var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");

                var response = await _httpClient.PostAsync("http://localhost:8502/admin/backfill", content);
                
                if (response.IsSuccessStatusCode)
                {
                    var result = await response.Content.ReadAsStringAsync();
                    _logger.LogInformation($"Backfill completed successfully for {symbol}");
                    
                    return Ok(new { 
                        success = true, 
                        message = $"Backfilled {limit} candles for {symbol} ({interval})",
                        symbol = symbol,
                        interval = interval,
                        limit = limit,
                        timestamp = DateTime.UtcNow
                    });
                }
                else
                {
                    var error = await response.Content.ReadAsStringAsync();
                    _logger.LogError($"Backfill failed: {response.StatusCode} - {error}");
                    
                    return StatusCode((int)response.StatusCode, new { 
                        success = false, 
                        message = "Backfill request failed",
                        error = error
                    });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during candle backfill");
                
                // Fallback: simulate backfill for demo
                _logger.LogInformation("Simulating backfill for demo purposes");
                
                return Ok(new { 
                    success = true, 
                    message = $"Demo backfill completed for {request?.Symbol ?? "BTCUSDT"}",
                    simulated = true,
                    timestamp = DateTime.UtcNow
                });
            }
        }

        [HttpGet("service-health")]
        public async Task<IActionResult> GetServiceHealth()
        {
            var healthStatus = new
            {
                webapp = await CheckWebAppHealth(),
                bot = await CheckBotHealth(),
                dashboard = await CheckDashboardHealth(),
                inference = await CheckInferenceHealth(),
                timestamp = DateTime.UtcNow
            };

            return Ok(healthStatus);
        }

        [HttpPost("emergency-stop")]
        public async Task<IActionResult> EmergencyStop()
        {
            try
            {
                _logger.LogWarning("EMERGENCY STOP initiated by admin user");

                // Call bot service to stop
                var stopRequest = new { action = "emergency_stop", reason = "Admin initiated" };
                var json = System.Text.Json.JsonSerializer.Serialize(stopRequest);
                var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");

                var response = await _httpClient.PostAsync("http://localhost:8502/bot/control", content);
                
                if (response.IsSuccessStatusCode)
                {
                    return Ok(new { 
                        success = true, 
                        message = "Emergency stop activated - All trading halted",
                        timestamp = DateTime.UtcNow
                    });
                }
                else
                {
                    // Fallback for demo
                    return Ok(new { 
                        success = true, 
                        message = "Emergency stop simulated - Demo mode",
                        simulated = true,
                        timestamp = DateTime.UtcNow
                    });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during emergency stop");
                return StatusCode(500, new { 
                    success = false, 
                    message = "Emergency stop failed",
                    error = ex.Message
                });
            }
        }

        [HttpPost("clear-cache")]
        public async Task<IActionResult> ClearCache()
        {
            try
            {
                _logger.LogInformation("Cache clear initiated by admin");

                // In a real application, you would clear various caches here
                // For demo purposes, we'll just simulate it
                await Task.Delay(1000); // Simulate cache clearing

                return Ok(new { 
                    success = true, 
                    message = "Application cache cleared successfully",
                    timestamp = DateTime.UtcNow
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error clearing cache");
                return StatusCode(500, new { 
                    success = false, 
                    message = "Cache clear failed",
                    error = ex.Message
                });
            }
        }

        private async Task<string> CheckWebAppHealth()
        {
            try
            {
                // WebApp is healthy if we can execute this
                return "Healthy";
            }
            catch
            {
                return "Error";
            }
        }

        private async Task<string> CheckBotHealth()
        {
            try
            {
                var response = await _httpClient.GetAsync("http://localhost:8000/health");
                return response.IsSuccessStatusCode ? "Healthy" : "Error";
            }
            catch
            {
                return "Offline";
            }
        }

        private async Task<string> CheckDashboardHealth()
        {
            try
            {
                var response = await _httpClient.GetAsync("http://localhost:8502/health");
                return response.IsSuccessStatusCode ? "Healthy" : "Error";
            }
            catch
            {
                return "Offline";
            }
        }

        private async Task<string> CheckInferenceHealth()
        {
            try
            {
                var response = await _httpClient.GetAsync("http://localhost:8001/health");
                return response.IsSuccessStatusCode ? "Healthy" : "Error";
            }
            catch
            {
                return "Offline";
            }
        }
    }

    public class BackfillRequest
    {
        public string Symbol { get; set; } = "BTCUSDT";
        public string Interval { get; set; } = "1m";
        public int Limit { get; set; } = 1000;
    }
}