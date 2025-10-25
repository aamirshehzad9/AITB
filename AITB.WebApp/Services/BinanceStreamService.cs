using System.Net.WebSockets;
using System.Text;
using System.Text.Json;

namespace AITB.WebApp.Services
{
    public class BinanceStreamService
    {
        private readonly ILogger<BinanceStreamService> _logger;
        private readonly IConfiguration _configuration;
        private readonly string _baseStreamUrl;

        public BinanceStreamService(ILogger<BinanceStreamService> logger, IConfiguration configuration)
        {
            _logger = logger;
            _configuration = configuration;
            _baseStreamUrl = Environment.GetEnvironmentVariable("BINANCE_STREAM_URL") ?? "wss://stream.binance.com:9443/ws";
        }

        public async IAsyncEnumerable<JsonElement> SubscribeTickerAsync(string symbol)
        {
            await foreach (var data in ProcessStreamAsync($"{symbol.ToLower()}@ticker", symbol))
            {
                yield return data;
            }
        }

        public async IAsyncEnumerable<JsonElement> SubscribeKlineAsync(string symbol, string interval = "1m")
        {
            await foreach (var data in ProcessStreamAsync($"{symbol.ToLower()}@kline_{interval}", $"{symbol}-{interval}"))
            {
                yield return data;
            }
        }

        private async IAsyncEnumerable<JsonElement> ProcessStreamAsync(string stream, string logContext)
        {
            while (true)
            {
                ClientWebSocket? socket = null;
                
                var messageQueue = new Queue<JsonElement>();
                var hasConnected = false;
                
                try
                {
                    socket = new ClientWebSocket();
                    var url = new Uri($"{_baseStreamUrl}/{stream}");
                    
                    _logger.LogInformation("Connecting to Binance WebSocket for stream: {Stream}", logContext);
                    await socket.ConnectAsync(url, CancellationToken.None);
                    _logger.LogInformation("Successfully connected to Binance WebSocket for stream: {Stream}", logContext);
                    hasConnected = true;
                    
                    var buffer = new byte[4096];
                    
                    while (socket.State == WebSocketState.Open)
                    {
                        var result = await socket.ReceiveAsync(buffer, CancellationToken.None);
                        
                        if (result.MessageType == WebSocketMessageType.Close)
                        {
                            _logger.LogWarning("WebSocket connection closed for stream: {Stream}", logContext);
                            break;
                        }
                        
                        if (result.MessageType == WebSocketMessageType.Text)
                        {
                            var msg = Encoding.UTF8.GetString(buffer, 0, result.Count);
                            
                            if (TryParseJson(msg, out var data))
                            {
                                messageQueue.Enqueue(data);
                            }
                            else
                            {
                                _logger.LogError("Failed to parse JSON message for stream {Stream}: {Message}", logContext, msg);
                            }
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error in WebSocket connection for stream: {Stream}", logContext);
                }
                finally
                {
                    if (socket?.State == WebSocketState.Open)
                    {
                        try
                        {
                            await socket.CloseAsync(WebSocketCloseStatus.NormalClosure, "Closing", CancellationToken.None);
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning(ex, "Error closing WebSocket for stream: {Stream}", logContext);
                        }
                    }
                    socket?.Dispose();
                }
                
                // Yield any queued messages
                while (messageQueue.Count > 0)
                {
                    yield return messageQueue.Dequeue();
                }
                
                if (hasConnected)
                {
                    // Auto-retry logic
                    _logger.LogInformation("Retrying connection for stream {Stream} in 5 seconds...", logContext);
                    await Task.Delay(5000);
                }
                else
                {
                    // If we couldn't connect initially, wait longer
                    _logger.LogWarning("Failed to connect to stream {Stream}, retrying in 10 seconds...", logContext);
                    await Task.Delay(10000);
                }
            }
        }

        private bool TryParseJson(string json, out JsonElement element)
        {
            try
            {
                element = JsonSerializer.Deserialize<JsonElement>(json);
                return true;
            }
            catch
            {
                element = default;
                return false;
            }
        }
    }
}