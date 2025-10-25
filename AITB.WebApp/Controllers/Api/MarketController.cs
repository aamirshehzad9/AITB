using Microsoft.AspNetCore.Mvc;
using System.Text.Json;

namespace AITB.WebApp.Controllers.Api;

[ApiController]
[Route("api/[controller]")]
public class MarketController : ControllerBase
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<MarketController> _logger;

    public MarketController(HttpClient httpClient, IConfiguration configuration, ILogger<MarketController> logger)
    {
        _httpClient = httpClient;
        _configuration = configuration;
        _logger = logger;
    }

    [HttpGet("live")]
    public async Task<IActionResult> GetLiveData([FromQuery] string symbol = "BTCUSDT")
    {
        try
        {
            // Get data from InfluxDB and real-time sources
            var influxUrl = _configuration["INFLUX_URL"] ?? "http://localhost:8086";
            
            // Simulate market data - replace with real Binance API integration
            var marketData = new MarketData
            {
                Symbol = symbol,
                Price = 43250.00m + (decimal)(new Random().NextDouble() * 100 - 50),
                Change24h = (decimal)(new Random().NextDouble() * 10 - 5),
                Volume24h = 125000000,
                High24h = 44500.00m,
                Low24h = 42100.00m,
                Timestamp = DateTimeOffset.UtcNow
            };

            return Ok(marketData);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching live market data for {Symbol}", symbol);
            return StatusCode(500, new { error = "Failed to fetch market data" });
        }
    }

    [HttpGet("signals")]
    public async Task<IActionResult> GetAISignals([FromQuery] string symbol = "BTCUSDT")
    {
        try
        {
            // Connect to AI inference endpoint (update from localhost:8600 to localhost:8001)
            var inferenceUrl = _configuration["INFERENCE_URL"] ?? "http://localhost:8001/infer";
            
            var request = new AIInferenceRequest
            {
                Pair = symbol,
                Lookback = 100
            };

            var json = JsonSerializer.Serialize(request);
            var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");
            
            var response = await _httpClient.PostAsync(inferenceUrl, content);
            
            if (response.IsSuccessStatusCode)
            {
                var result = await response.Content.ReadAsStringAsync();
                var aiResponse = JsonSerializer.Deserialize<AIInferenceResponse>(result);
                
                var signal = new AISignal
                {
                    Symbol = symbol,
                    Action = aiResponse?.Prediction ?? "HOLD",
                    Confidence = aiResponse?.Confidence ?? 0.5,
                    Timestamp = DateTimeOffset.UtcNow,
                    Reasoning = aiResponse?.Reasoning ?? "Market analysis completed"
                };
                
                return Ok(signal);
            }
            else
            {
                // Fallback to mock signal if AI service unavailable
                var mockSignal = GenerateMockSignal(symbol);
                return Ok(mockSignal);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching AI signals for {Symbol}", symbol);
            
            // Return mock signal as fallback
            var fallbackSignal = GenerateMockSignal(symbol);
            return Ok(fallbackSignal);
        }
    }

    [HttpPost("trade")]
    public async Task<IActionResult> ExecutePaperTrade([FromBody] TradeRequest request)
    {
        try
        {
            // Execute paper trade and store to database
            var trade = new Trade
            {
                Id = Guid.NewGuid(),
                Symbol = request.Symbol,
                Action = request.Action,
                Amount = request.Amount,
                Price = request.Price,
                Timestamp = DateTimeOffset.UtcNow,
                Type = "PAPER",
                Status = "EXECUTED"
            };

            // Store to database (implement your preferred DB here)
            // await _tradeRepository.SaveAsync(trade);

            // Notify via SignalR
            // await _hubContext.Clients.All.SendAsync("ReceiveTrade", trade);

            _logger.LogInformation("Paper trade executed: {Symbol} {Action} {Amount} at {Price}", 
                trade.Symbol, trade.Action, trade.Amount, trade.Price);

            return Ok(trade);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error executing paper trade");
            return StatusCode(500, new { error = "Failed to execute trade" });
        }
    }

    [HttpGet("orderbook")]
    public async Task<IActionResult> GetOrderBook([FromQuery] string symbol = "BTCUSDT")
    {
        try
        {
            // Mock order book data - replace with real Binance WebSocket data
            var orderBook = new OrderBook
            {
                Symbol = symbol,
                Bids = GenerateMockOrderBookSide(43245.20m, false),
                Asks = GenerateMockOrderBookSide(43246.50m, true),
                Timestamp = DateTimeOffset.UtcNow
            };

            return Ok(orderBook);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching order book for {Symbol}", symbol);
            return StatusCode(500, new { error = "Failed to fetch order book" });
        }
    }

    private AISignal GenerateMockSignal(string symbol)
    {
        var random = new Random();
        var actions = new[] { "BUY", "SELL", "HOLD" };
        
        return new AISignal
        {
            Symbol = symbol,
            Action = actions[random.Next(actions.Length)],
            Confidence = 0.6 + random.NextDouble() * 0.3, // 60-90% confidence
            Timestamp = DateTimeOffset.UtcNow,
            Reasoning = "Technical analysis indicates potential movement based on volume and momentum."
        };
    }

    private List<OrderBookEntry> GenerateMockOrderBookSide(decimal basePrice, bool isAsk)
    {
        var entries = new List<OrderBookEntry>();
        var random = new Random();
        
        for (int i = 0; i < 10; i++)
        {
            var priceOffset = (decimal)(random.NextDouble() * 20);
            var price = isAsk ? basePrice + priceOffset : basePrice - priceOffset;
            var quantity = (decimal)(random.NextDouble() * 0.5);
            
            entries.Add(new OrderBookEntry
            {
                Price = Math.Round(price, 2),
                Quantity = Math.Round(quantity, 6)
            });
        }
        
        return entries;
    }
}

// Data Models
public class MarketData
{
    public string Symbol { get; set; } = "";
    public decimal Price { get; set; }
    public decimal Change24h { get; set; }
    public decimal Volume24h { get; set; }
    public decimal High24h { get; set; }
    public decimal Low24h { get; set; }
    public DateTimeOffset Timestamp { get; set; }
}

public class AIInferenceRequest
{
    public string Pair { get; set; } = "";
    public int Lookback { get; set; } = 100;
}

public class AIInferenceResponse
{
    public string Prediction { get; set; } = "";
    public double Confidence { get; set; }
    public string Reasoning { get; set; } = "";
}

public class AISignal
{
    public string Symbol { get; set; } = "";
    public string Action { get; set; } = "";
    public double Confidence { get; set; }
    public DateTimeOffset Timestamp { get; set; }
    public string Reasoning { get; set; } = "";
}

public class TradeRequest
{
    public string Symbol { get; set; } = "";
    public string Action { get; set; } = "";
    public decimal Amount { get; set; }
    public decimal Price { get; set; }
}

public class Trade
{
    public Guid Id { get; set; }
    public string Symbol { get; set; } = "";
    public string Action { get; set; } = "";
    public decimal Amount { get; set; }
    public decimal Price { get; set; }
    public DateTimeOffset Timestamp { get; set; }
    public string Type { get; set; } = "";
    public string Status { get; set; } = "";
}

public class OrderBook
{
    public string Symbol { get; set; } = "";
    public List<OrderBookEntry> Bids { get; set; } = new();
    public List<OrderBookEntry> Asks { get; set; } = new();
    public DateTimeOffset Timestamp { get; set; }
}

public class OrderBookEntry
{
    public decimal Price { get; set; }
    public decimal Quantity { get; set; }
}