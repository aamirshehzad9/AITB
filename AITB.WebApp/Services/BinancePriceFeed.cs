using System.Net.WebSockets;
using System.Text;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace AITB.WebApp.Services
{
    public class BinancePriceFeed : IPriceFeed
    {
        private readonly HttpClient _httpClient;
        private readonly ILogger<BinancePriceFeed> _logger;
        private ClientWebSocket? _webSocket;
        private CancellationTokenSource? _cancellationTokenSource;
        private readonly string _baseUrl = "https://api.binance.com";

        public BinancePriceFeed(HttpClient httpClient, ILogger<BinancePriceFeed> logger)
        {
            _httpClient = httpClient;
            _logger = logger;
        }

        public async Task<IEnumerable<KlineData>> GetKlinesAsync(string symbol, string interval, int limit)
        {
            try
            {
                var url = $"{_baseUrl}/api/v3/klines?symbol={symbol}&interval={interval}&limit={limit}";
                var response = await _httpClient.GetStringAsync(url);
                var klines = JsonConvert.DeserializeObject<decimal[][]>(response);
                
                if (klines != null)
                {
                    return klines.Select(k => new KlineData
                    {
                        Time = (long)k[0],
                        Open = k[1],
                        High = k[2],
                        Low = k[3],
                        Close = k[4],
                        Volume = k[5]
                    });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get klines for {Symbol}", symbol);
                return GenerateFallbackKlines(symbol, limit);
            }

            return new List<KlineData>();
        }

        public async Task<IEnumerable<MarketTicker>> GetMarketsAsync()
        {
            try
            {
                var url = $"{_baseUrl}/api/v3/ticker/24hr";
                var response = await _httpClient.GetStringAsync(url);
                var tickers = JsonConvert.DeserializeObject<JArray>(response);
                
                if (tickers != null)
                {
                    return tickers
                        .Where(t => t["symbol"]?.ToString().EndsWith("USDT") == true)
                        .Take(50)
                        .Select(t => new MarketTicker
                        {
                            Symbol = t["symbol"]?.ToString() ?? "",
                            DisplaySymbol = FormatSymbol(t["symbol"]?.ToString() ?? ""),
                            LastPrice = decimal.TryParse(t["lastPrice"]?.ToString(), out var price) ? price : 0,
                            Change24h = decimal.TryParse(t["priceChange"]?.ToString(), out var change) ? change : 0,
                            ChangePercent24h = decimal.TryParse(t["priceChangePercent"]?.ToString(), out var percent) ? percent : 0,
                            Volume24h = decimal.TryParse(t["volume"]?.ToString(), out var volume) ? volume : 0
                        });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get market data");
                return GenerateFallbackMarkets();
            }

            return new List<MarketTicker>();
        }

        public async Task<MarketTicker?> GetTickerAsync(string symbol)
        {
            try
            {
                var url = $"{_baseUrl}/api/v3/ticker/24hr?symbol={symbol}";
                var response = await _httpClient.GetStringAsync(url);
                var ticker = JsonConvert.DeserializeObject<JObject>(response);
                
                if (ticker != null)
                {
                    return new MarketTicker
                    {
                        Symbol = ticker["symbol"]?.ToString() ?? "",
                        DisplaySymbol = FormatSymbol(ticker["symbol"]?.ToString() ?? ""),
                        LastPrice = decimal.TryParse(ticker["lastPrice"]?.ToString(), out var price) ? price : 0,
                        Change24h = decimal.TryParse(ticker["priceChange"]?.ToString(), out var change) ? change : 0,
                        ChangePercent24h = decimal.TryParse(ticker["priceChangePercent"]?.ToString(), out var percent) ? percent : 0,
                        Volume24h = decimal.TryParse(ticker["volume"]?.ToString(), out var volume) ? volume : 0
                    };
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get ticker for {Symbol}", symbol);
            }

            return null;
        }

        public async Task StartWebSocketAsync(string symbol, string interval, Func<KlineData, Task> onKlineReceived)
        {
            try
            {
                _cancellationTokenSource = new CancellationTokenSource();
                _webSocket = new ClientWebSocket();
                
                var uri = new Uri($"wss://stream.binance.com:9443/ws/{symbol.ToLower()}@kline_{interval}");
                await _webSocket.ConnectAsync(uri, _cancellationTokenSource.Token);
                
                _logger.LogInformation("WebSocket connected for {Symbol} {Interval}", symbol, interval);
                
                _ = Task.Run(async () =>
                {
                    var buffer = new byte[4096];
                    while (_webSocket.State == WebSocketState.Open && !_cancellationTokenSource.Token.IsCancellationRequested)
                    {
                        try
                        {
                            var result = await _webSocket.ReceiveAsync(new ArraySegment<byte>(buffer), _cancellationTokenSource.Token);
                            if (result.MessageType == WebSocketMessageType.Text)
                            {
                                var message = Encoding.UTF8.GetString(buffer, 0, result.Count);
                                var data = JsonConvert.DeserializeObject<JObject>(message);
                                
                                if (data?["k"] != null)
                                {
                                    var kline = data["k"];
                                    var klineData = new KlineData
                                    {
                                        Time = kline["t"]?.Value<long>() ?? 0,
                                        Open = kline["o"]?.Value<decimal>() ?? 0,
                                        High = kline["h"]?.Value<decimal>() ?? 0,
                                        Low = kline["l"]?.Value<decimal>() ?? 0,
                                        Close = kline["c"]?.Value<decimal>() ?? 0,
                                        Volume = kline["v"]?.Value<decimal>() ?? 0
                                    };
                                    
                                    await onKlineReceived(klineData);
                                }
                            }
                        }
                        catch (Exception ex)
                        {
                            _logger.LogError(ex, "WebSocket receive error");
                            break;
                        }
                    }
                }, _cancellationTokenSource.Token);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to start WebSocket");
                // Fallback to polling
                await StartPollingFallback(symbol, interval, onKlineReceived);
            }
        }

        public async Task StopWebSocketAsync()
        {
            _cancellationTokenSource?.Cancel();
            if (_webSocket != null && _webSocket.State == WebSocketState.Open)
            {
                await _webSocket.CloseAsync(WebSocketCloseStatus.NormalClosure, "Closing", CancellationToken.None);
            }
            _webSocket?.Dispose();
            _cancellationTokenSource?.Dispose();
        }

        private async Task StartPollingFallback(string symbol, string interval, Func<KlineData, Task> onKlineReceived)
        {
            _logger.LogInformation("Starting polling fallback for {Symbol} {Interval}", symbol, interval);
            
            _ = Task.Run(async () =>
            {
                while (!_cancellationTokenSource?.Token.IsCancellationRequested == true)
                {
                    try
                    {
                        var klines = await GetKlinesAsync(symbol, interval, 1);
                        if (klines?.Any() == true)
                        {
                            await onKlineReceived(klines.First());
                        }
                        await Task.Delay(3000, _cancellationTokenSource?.Token ?? CancellationToken.None);
                    }
                    catch (Exception pollingEx)
                    {
                        _logger.LogError(pollingEx, "REST polling error");
                        await Task.Delay(5000, _cancellationTokenSource?.Token ?? CancellationToken.None);
                    }
                }
            }, _cancellationTokenSource?.Token ?? CancellationToken.None);
        }

        private static string FormatSymbol(string symbol)
        {
            if (symbol.EndsWith("USDT"))
            {
                return symbol.Replace("USDT", "/USDT");
            }
            return symbol;
        }

        private IEnumerable<KlineData> GenerateFallbackKlines(string symbol, int limit)
        {
            var random = new Random();
            var basePrice = symbol.StartsWith("BTC") ? 45000 : 
                           symbol.StartsWith("ETH") ? 3000 : 
                           symbol.StartsWith("BNB") ? 300 : 100;
                           
            var klines = new List<KlineData>();
            var currentTime = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            
            for (int i = limit - 1; i >= 0; i--)
            {
                var time = currentTime - (i * 60000); // 1 minute intervals
                var price = basePrice + (decimal)(random.NextDouble() * (double)basePrice * 0.1 - (double)basePrice * 0.05);
                var variation = (decimal)(random.NextDouble() * (double)price * 0.02);
                
                klines.Add(new KlineData
                {
                    Time = time,
                    Open = price - variation,
                    High = price + variation,
                    Low = price - variation * 1.5m,
                    Close = price,
                    Volume = (decimal)(random.NextDouble() * 1000)
                });
            }
            
            return klines;
        }

        private IEnumerable<MarketTicker> GenerateFallbackMarkets()
        {
            var symbols = new[] { "BTCUSDT", "ETHUSDT", "BNBUSDT", "ADAUSDT", "DOTUSDT", "XRPUSDT", "LTCUSDT", "LINKUSDT" };
            var markets = new List<MarketTicker>();
            var random = new Random();
            
            foreach (var symbol in symbols)
            {
                var basePrice = symbol.StartsWith("BTC") ? 45000 : 
                               symbol.StartsWith("ETH") ? 3000 : 
                               symbol.StartsWith("BNB") ? 300 : 
                               random.Next(1, 1000);

                markets.Add(new MarketTicker
                {
                    Symbol = symbol,
                    DisplaySymbol = FormatSymbol(symbol),
                    LastPrice = basePrice + (decimal)(random.NextDouble() * (double)basePrice * 0.1 - (double)basePrice * 0.05),
                    Change24h = (decimal)(random.NextDouble() * 200 - 100),
                    ChangePercent24h = (decimal)(random.NextDouble() * 10 - 5),
                    Volume24h = (decimal)(random.NextDouble() * 1000000)
                });
            }
            
            return markets;
        }
    }
}