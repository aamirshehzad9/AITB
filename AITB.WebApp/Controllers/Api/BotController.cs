using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using System.Text.Json;
using System.Text;

namespace AITB.WebApp.Controllers.Api
{
    [ApiController]
    [Route("api/bot")]
    [Authorize(Policy = "AdminOnly")] // Protect all bot endpoints for admin only
    public class BotController : ControllerBase
    {
        private readonly ILogger<BotController> _logger;
        private readonly HttpClient _httpClient;

        public BotController(ILogger<BotController> logger, HttpClient httpClient)
        {
            _logger = logger;
            _httpClient = httpClient;
        }

        [HttpPost("control")]
        public async Task<IActionResult> ControlBot([FromBody] BotControlRequest request)
        {
            try
            {
                _logger.LogInformation($"Bot control request: {request.Action}");

                var json = JsonSerializer.Serialize(request);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var response = await _httpClient.PostAsync("http://localhost:8502/bot/control", content);
                
                if (response.IsSuccessStatusCode)
                {
                    var responseContent = await response.Content.ReadAsStringAsync();
                    return Content(responseContent, "application/json");
                }
                
                var errorContent = await response.Content.ReadAsStringAsync();
                _logger.LogError($"Bot control failed: {response.StatusCode} - {errorContent}");
                return StatusCode((int)response.StatusCode, new { error = "Bot control request failed", details = errorContent });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error controlling bot");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        [HttpGet("status")]
        public async Task<IActionResult> GetBotStatus()
        {
            try
            {
                var response = await _httpClient.GetAsync("http://localhost:8502/bot/status");
                
                if (response.IsSuccessStatusCode)
                {
                    var content = await response.Content.ReadAsStringAsync();
                    return Content(content, "application/json");
                }
                
                var errorContent = await response.Content.ReadAsStringAsync();
                _logger.LogError($"Failed to get bot status: {response.StatusCode} - {errorContent}");
                return StatusCode((int)response.StatusCode, new { error = "Failed to get bot status", details = errorContent });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting bot status");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        // Legacy endpoints for compatibility (redirect to new API)
        [HttpPost("start")]
        public async Task<IActionResult> StartBot()
        {
            var request = new BotControlRequest { Action = "start" };
            return await ControlBot(request);
        }

        [HttpPost("pause")]
        public async Task<IActionResult> PauseBot()
        {
            var request = new BotControlRequest { Action = "pause" };
            return await ControlBot(request);
        }

        [HttpPost("stop")]
        public async Task<IActionResult> StopBot()
        {
            var request = new BotControlRequest { Action = "stop" };
            return await ControlBot(request);
        }

        [HttpGet("heartbeat")]
        public async Task<IActionResult> GetLastHeartbeat()
        {
            try
            {
                var response = await _httpClient.GetAsync("http://localhost:8502/bot/status");
                
                if (response.IsSuccessStatusCode)
                {
                    var content = await response.Content.ReadAsStringAsync();
                    var statusData = JsonSerializer.Deserialize<JsonElement>(content);
                    
                    // Extract heartbeat info from status
                    var heartbeatInfo = new
                    {
                        timestamp = statusData.TryGetProperty("last_heartbeat", out var hb) ? hb.GetString() : null,
                        status = statusData.TryGetProperty("state", out var state) ? state.GetString() : "unknown",
                        uptime = statusData.TryGetProperty("uptime", out var up) ? up.GetDouble() : 0.0
                    };
                    
                    return Ok(heartbeatInfo);
                }
                
                return StatusCode(500, new { error = "Failed to get heartbeat data" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting heartbeat data");
                return StatusCode(500, new { error = ex.Message });
            }
        }
    }

    public class BotControlRequest
    {
        public string Action { get; set; } = string.Empty;
        public string? Symbol { get; set; }
        public string? Timeframe { get; set; }
        public Dictionary<string, object>? Parameters { get; set; }
    }
}