using Microsoft.AspNetCore.SignalR;
using AITB.WebApp.Hubs;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;

namespace AITB.WebApp.Services;

public class WebSocketService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<WebSocketService> _logger;
    private ClientWebSocket? _webSocket;
    private readonly CancellationTokenSource _cancellationTokenSource = new();

    public WebSocketService(IServiceProvider serviceProvider, ILogger<WebSocketService> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await ConnectToBinanceWebSocket(stoppingToken);
    }

    private async Task ConnectToBinanceWebSocket(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                _webSocket = new ClientWebSocket();
                
                // Connect to Binance WebSocket for real-time market data
                var uri = new Uri("wss://stream.binance.com:9443/ws/btcusdt@kline_1m");
                await _webSocket.ConnectAsync(uri, cancellationToken);
                
                _logger.LogInformation("Connected to Binance WebSocket");

                // Listen for messages
                await ListenForMessages(cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "WebSocket connection error");
                
                // Fallback to mock data if WebSocket fails
                await SendMockData(cancellationToken);
            }

            // Wait before attempting to reconnect
            await Task.Delay(5000, cancellationToken);
        }
    }

    private async Task ListenForMessages(CancellationToken cancellationToken)
    {
        var buffer = new byte[1024 * 4];
        
        while (_webSocket?.State == WebSocketState.Open && !cancellationToken.IsCancellationRequested)
        {
            try
            {
                var result = await _webSocket.ReceiveAsync(new ArraySegment<byte>(buffer), cancellationToken);
                
                if (result.MessageType == WebSocketMessageType.Text)
                {
                    var message = Encoding.UTF8.GetString(buffer, 0, result.Count);
                    await ProcessBinanceMessage(message);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error receiving WebSocket message");
                break;
            }
        }
    }

    private async Task ProcessBinanceMessage(string message)
    {
        try
        {
            using var scope = _serviceProvider.CreateScope();
            var hubContext = scope.ServiceProvider.GetRequiredService<IHubContext<TradeHub>>();
            
            var binanceData = JsonSerializer.Deserialize<BinanceKlineData>(message);
            
            if (binanceData?.k != null)
            {
                var priceUpdate = new PriceUpdate
                {
                    Symbol = binanceData.k.s,
                    Open = decimal.Parse(binanceData.k.o),
                    High = decimal.Parse(binanceData.k.h),
                    Low = decimal.Parse(binanceData.k.l),
                    Close = decimal.Parse(binanceData.k.c),
                    Volume = decimal.Parse(binanceData.k.v),
                    Timestamp = DateTimeOffset.FromUnixTimeMilliseconds(binanceData.k.T)
                };

                // Broadcast to all connected clients
                await hubContext.Clients.All.SendAsync("ReceivePriceUpdate", priceUpdate);
                
                _logger.LogDebug("Price update sent: {Symbol} @ {Price}", priceUpdate.Symbol, priceUpdate.Close);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing Binance message: {Message}", message);
        }
    }

    private async Task SendMockData(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Using mock market data (WebSocket unavailable)");
        
        using var scope = _serviceProvider.CreateScope();
        var hubContext = scope.ServiceProvider.GetRequiredService<IHubContext<TradeHub>>();
        
        var random = new Random();
        var basePrice = 43250.00m;
        
        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                // Generate mock price movement
                var change = (decimal)(random.NextDouble() * 200 - 100); // ±$100 range
                var newPrice = Math.Max(1000, basePrice + change);
                
                var priceUpdate = new PriceUpdate
                {
                    Symbol = "BTCUSDT",
                    Open = basePrice,
                    High = newPrice + (decimal)(random.NextDouble() * 50),
                    Low = newPrice - (decimal)(random.NextDouble() * 50),
                    Close = newPrice,
                    Volume = (decimal)(random.NextDouble() * 1000),
                    Timestamp = DateTimeOffset.UtcNow
                };

                await hubContext.Clients.All.SendAsync("ReceivePriceUpdate", priceUpdate);
                
                basePrice = newPrice; // Update base for next iteration
                
                await Task.Delay(2000, cancellationToken); // Update every 2 seconds
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error sending mock data");
                await Task.Delay(5000, cancellationToken);
            }
        }
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        _cancellationTokenSource.Cancel();
        
        if (_webSocket?.State == WebSocketState.Open)
        {
            await _webSocket.CloseAsync(WebSocketCloseStatus.NormalClosure, "Service stopping", cancellationToken);
        }
        
        _webSocket?.Dispose();
        await base.StopAsync(cancellationToken);
    }
}

// Data Models for Binance WebSocket
public class BinanceKlineData
{
    public string e { get; set; } = ""; // Event type
    public long E { get; set; } // Event time
    public string s { get; set; } = ""; // Symbol
    public KlineData k { get; set; } = new();
}

public class KlineData
{
    public long t { get; set; } // Kline start time
    public long T { get; set; } // Kline close time
    public string s { get; set; } = ""; // Symbol
    public string i { get; set; } = ""; // Interval
    public long f { get; set; } // First trade ID
    public long L { get; set; } // Last trade ID
    public string o { get; set; } = ""; // Open price
    public string c { get; set; } = ""; // Close price
    public string h { get; set; } = ""; // High price
    public string l { get; set; } = ""; // Low price
    public string v { get; set; } = ""; // Base asset volume
    public long n { get; set; } // Number of trades
    public bool x { get; set; } // Is this kline closed?
    public string q { get; set; } = ""; // Quote asset volume
    public string V { get; set; } = ""; // Taker buy base asset volume
    public string Q { get; set; } = ""; // Taker buy quote asset volume
    public string B { get; set; } = ""; // Ignore
}

public class PriceUpdate
{
    public string Symbol { get; set; } = "";
    public decimal Open { get; set; }
    public decimal High { get; set; }
    public decimal Low { get; set; }
    public decimal Close { get; set; }
    public decimal Volume { get; set; }
    public DateTimeOffset Timestamp { get; set; }
}