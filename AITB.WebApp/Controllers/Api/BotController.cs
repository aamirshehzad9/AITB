using Microsoft.AspNetCore.Mvc;
using System.Text.Json;

namespace AITB.WebApp.Controllers.Api;

[ApiController]
[Route("api/[controller]")]
public class BotController : ControllerBase
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<BotController> _logger;

    public BotController(HttpClient httpClient, IConfiguration configuration, ILogger<BotController> logger)
    {
        _httpClient = httpClient;
        _configuration = configuration;
        _logger = logger;
    }

    [HttpPost("start")]
    public async Task<IActionResult> StartBot()
    {
        try
        {
            // Connect to bot service - assuming bot runs as Docker container or service
            var botUrl = _configuration["BOT_URL"] ?? "http://localhost:8002";
            
            var response = await _httpClient.PostAsync($"{botUrl}/start", null);
            
            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("Trading bot started successfully");
                return Ok(new { status = "started", timestamp = DateTimeOffset.UtcNow });
            }
            else
            {
                var error = await response.Content.ReadAsStringAsync();
                _logger.LogWarning("Failed to start bot: {Error}", error);
                return StatusCode((int)response.StatusCode, new { error = "Failed to start bot" });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error starting trading bot");
            
            // Mock response for development
            _logger.LogInformation("Bot start simulated (service unavailable)");
            return Ok(new { status = "started", timestamp = DateTimeOffset.UtcNow, simulated = true });
        }
    }

    [HttpPost("pause")]
    public async Task<IActionResult> PauseBot()
    {
        try
        {
            var botUrl = _configuration["BOT_URL"] ?? "http://localhost:8002";
            
            var response = await _httpClient.PostAsync($"{botUrl}/pause", null);
            
            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("Trading bot paused successfully");
                return Ok(new { status = "paused", timestamp = DateTimeOffset.UtcNow });
            }
            else
            {
                var error = await response.Content.ReadAsStringAsync();
                _logger.LogWarning("Failed to pause bot: {Error}", error);
                return StatusCode((int)response.StatusCode, new { error = "Failed to pause bot" });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error pausing trading bot");
            
            // Mock response for development
            _logger.LogInformation("Bot pause simulated (service unavailable)");
            return Ok(new { status = "paused", timestamp = DateTimeOffset.UtcNow, simulated = true });
        }
    }

    [HttpPost("stop")]
    public async Task<IActionResult> StopBot()
    {
        try
        {
            var botUrl = _configuration["BOT_URL"] ?? "http://localhost:8002";
            
            var response = await _httpClient.PostAsync($"{botUrl}/stop", null);
            
            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("Trading bot stopped successfully");
                return Ok(new { status = "stopped", timestamp = DateTimeOffset.UtcNow });
            }
            else
            {
                var error = await response.Content.ReadAsStringAsync();
                _logger.LogWarning("Failed to stop bot: {Error}", error);
                return StatusCode((int)response.StatusCode, new { error = "Failed to stop bot" });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error stopping trading bot");
            
            // Mock response for development
            _logger.LogInformation("Bot stop simulated (service unavailable)");
            return Ok(new { status = "stopped", timestamp = DateTimeOffset.UtcNow, simulated = true });
        }
    }

    [HttpPost("strategy")]
    public async Task<IActionResult> UpdateStrategy([FromBody] StrategyRequest request)
    {
        try
        {
            var botUrl = _configuration["BOT_URL"] ?? "http://localhost:8002";
            
            var json = JsonSerializer.Serialize(request);
            var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");
            
            var response = await _httpClient.PostAsync($"{botUrl}/strategy", content);
            
            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("Bot strategy updated to {Strategy}", request.Strategy);
                return Ok(new { status = "updated", strategy = request.Strategy, timestamp = DateTimeOffset.UtcNow });
            }
            else
            {
                var error = await response.Content.ReadAsStringAsync();
                _logger.LogWarning("Failed to update strategy: {Error}", error);
                return StatusCode((int)response.StatusCode, new { error = "Failed to update strategy" });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating bot strategy");
            
            // Mock response for development
            _logger.LogInformation("Strategy update simulated: {Strategy}", request.Strategy);
            return Ok(new { status = "updated", strategy = request.Strategy, timestamp = DateTimeOffset.UtcNow, simulated = true });
        }
    }

    [HttpGet("status")]
    public async Task<IActionResult> GetBotStatus()
    {
        try
        {
            var botUrl = _configuration["BOT_URL"] ?? "http://localhost:8002";
            
            var response = await _httpClient.GetAsync($"{botUrl}/status");
            
            if (response.IsSuccessStatusCode)
            {
                var statusJson = await response.Content.ReadAsStringAsync();
                var status = JsonSerializer.Deserialize<BotStatus>(statusJson);
                return Ok(status);
            }
            else
            {
                // Return mock status if bot service unavailable
                return Ok(GenerateMockBotStatus());
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching bot status");
            
            // Return mock status for development
            return Ok(GenerateMockBotStatus());
        }
    }

    [HttpGet("positions")]
    public async Task<IActionResult> GetOpenPositions()
    {
        try
        {
            var botUrl = _configuration["BOT_URL"] ?? "http://localhost:8002";
            
            var response = await _httpClient.GetAsync($"{botUrl}/positions");
            
            if (response.IsSuccessStatusCode)
            {
                var positionsJson = await response.Content.ReadAsStringAsync();
                var positions = JsonSerializer.Deserialize<List<Position>>(positionsJson);
                return Ok(positions);
            }
            else
            {
                // Return mock positions if bot service unavailable
                return Ok(GenerateMockPositions());
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching bot positions");
            
            // Return mock positions for development
            return Ok(GenerateMockPositions());
        }
    }

    private BotStatus GenerateMockBotStatus()
    {
        return new BotStatus
        {
            Active = false,
            Strategy = "balanced",
            Balance = 10000.00m,
            UnrealizedPnL = 234.56m,
            DailyGain = 2.35m,
            TotalProfit = 1234.56m,
            OpenPositions = 1,
            LastUpdated = DateTimeOffset.UtcNow
        };
    }

    private List<Position> GenerateMockPositions()
    {
        return new List<Position>
        {
            new Position
            {
                Symbol = "BTCUSDT",
                Side = "LONG",
                Size = 0.001m,
                EntryPrice = 43100.00m,
                CurrentPrice = 43245.00m,
                UnrealizedPnL = 45.23m,
                PnLPercentage = 1.2m,
                Timestamp = DateTimeOffset.UtcNow.AddMinutes(-30)
            }
        };
    }
}

// Data Models
public class StrategyRequest
{
    public string Strategy { get; set; } = "";
}

public class BotStatus
{
    public bool Active { get; set; }
    public string Strategy { get; set; } = "";
    public decimal Balance { get; set; }
    public decimal UnrealizedPnL { get; set; }
    public decimal DailyGain { get; set; }
    public decimal TotalProfit { get; set; }
    public int OpenPositions { get; set; }
    public DateTimeOffset LastUpdated { get; set; }
}

public class Position
{
    public string Symbol { get; set; } = "";
    public string Side { get; set; } = "";
    public decimal Size { get; set; }
    public decimal EntryPrice { get; set; }
    public decimal CurrentPrice { get; set; }
    public decimal UnrealizedPnL { get; set; }
    public decimal PnLPercentage { get; set; }
    public DateTimeOffset Timestamp { get; set; }
}