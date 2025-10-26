using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace AITB.WebApp.Services
{
    public class BinanceHttpService
    {
        private readonly HttpClient _httpClient;
        private readonly ILogger<BinanceHttpService> _logger;
        private readonly string _apiKey;
        private readonly string _secretKey;
        private readonly string _baseUrl;

        public BinanceHttpService(HttpClient httpClient, ILogger<BinanceHttpService> logger, IConfiguration configuration)
        {
            _httpClient = httpClient;
            _logger = logger;
            _apiKey = Environment.GetEnvironmentVariable("BINANCE_API_KEY") ?? "";
            _secretKey = Environment.GetEnvironmentVariable("BINANCE_SECRET_KEY") ?? "";
            _baseUrl = Environment.GetEnvironmentVariable("BINANCE_HTTP_URL") ?? "https://api.binance.com";
            
            if (string.IsNullOrEmpty(_apiKey) || string.IsNullOrEmpty(_secretKey))
            {
                _logger.LogWarning("Binance API credentials not found in environment variables");
            }
        }

        public async Task<JsonElement?> GetTickerAsync(string symbol)
        {
            try
            {
                var url = $"{_baseUrl}/api/v3/ticker/24hr?symbol={symbol.ToUpper()}";
                
                var response = await _httpClient.GetAsync(url);
                
                if (!response.IsSuccessStatusCode)
                {
                    _logger.LogWarning("Failed to get ticker for {Symbol}. Status: {StatusCode}", symbol, response.StatusCode);
                    return null;
                }
                
                var content = await response.Content.ReadAsStringAsync();
                var data = JsonSerializer.Deserialize<JsonElement>(content);
                
                return data;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Exception getting ticker for {Symbol}", symbol);
                return null;
            }
        }

        public async Task<JsonElement?> GetKlinesAsync(string symbol, string interval = "1m", int limit = 100)
        {
            try
            {
                var url = $"{_baseUrl}/api/v3/klines?symbol={symbol.ToUpper()}&interval={interval}&limit={limit}";
                
                var response = await _httpClient.GetAsync(url);
                
                if (!response.IsSuccessStatusCode)
                {
                    _logger.LogWarning("Failed to get klines for {Symbol}. Status: {StatusCode}", symbol, response.StatusCode);
                    return null;
                }
                
                var content = await response.Content.ReadAsStringAsync();
                var data = JsonSerializer.Deserialize<JsonElement>(content);
                
                return data;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Exception getting klines for {Symbol}", symbol);
                return null;
            }
        }

        public async Task<JsonElement?> GetAccountInfoAsync()
        {
            if (string.IsNullOrEmpty(_apiKey) || string.IsNullOrEmpty(_secretKey))
            {
                _logger.LogError("API credentials required for account info");
                return null;
            }

            try
            {
                var timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
                var queryString = $"timestamp={timestamp}";
                var signature = CreateSignature(queryString);
                
                var url = $"{_baseUrl}/api/v3/account?{queryString}&signature={signature}";
                
                var request = new HttpRequestMessage(HttpMethod.Get, url);
                request.Headers.Add("X-MBX-APIKEY", _apiKey);
                
                var response = await _httpClient.SendAsync(request);
                
                if (!response.IsSuccessStatusCode)
                {
                    _logger.LogWarning("Failed to get account info. Status: {StatusCode}", response.StatusCode);
                    return null;
                }
                
                var content = await response.Content.ReadAsStringAsync();
                var data = JsonSerializer.Deserialize<JsonElement>(content);
                
                return data;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Exception getting account info");
                return null;
            }
        }

        public async Task<List<JsonElement>> GetExchangeInfoAsync()
        {
            try
            {
                var url = $"{_baseUrl}/api/v3/exchangeInfo";
                
                var response = await _httpClient.GetAsync(url);
                
                if (!response.IsSuccessStatusCode)
                {
                    _logger.LogWarning("Failed to get exchange info. Status: {StatusCode}", response.StatusCode);
                    return new List<JsonElement>();
                }
                
                var content = await response.Content.ReadAsStringAsync();
                var data = JsonSerializer.Deserialize<JsonElement>(content);
                
                if (data.TryGetProperty("symbols", out var symbols))
                {
                    return symbols.EnumerateArray().ToList();
                }
                
                return new List<JsonElement>();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Exception getting exchange info");
                return new List<JsonElement>();
            }
        }

        public async Task<List<object>> GetTop10USDTMarketsAsync()
        {
            try
            {
                var url = $"{_baseUrl}/api/v3/ticker/24hr";
                
                var response = await _httpClient.GetAsync(url);
                
                if (!response.IsSuccessStatusCode)
                {
                    _logger.LogWarning("Failed to get 24hr ticker data. Status: {StatusCode}", response.StatusCode);
                    return new List<object>();
                }
                
                var content = await response.Content.ReadAsStringAsync();
                var tickers = JsonSerializer.Deserialize<JsonElement[]>(content);
                
                var usdtPairs = tickers
                    .Where(t => t.GetProperty("symbol").GetString()?.EndsWith("USDT") == true)
                    .Where(t => t.GetProperty("count").GetInt64() > 1000) // Filter active pairs
                    .OrderByDescending(t => decimal.Parse(t.GetProperty("quoteVolume").GetString() ?? "0"))
                    .Take(10)
                    .Select(t => new
                    {
                        symbol = t.GetProperty("symbol").GetString(),
                        lastPrice = decimal.Parse(t.GetProperty("lastPrice").GetString() ?? "0"),
                        priceChange = decimal.Parse(t.GetProperty("priceChange").GetString() ?? "0"),
                        priceChangePercent = decimal.Parse(t.GetProperty("priceChangePercent").GetString() ?? "0"),
                        volume = decimal.Parse(t.GetProperty("volume").GetString() ?? "0"),
                        quoteVolume = decimal.Parse(t.GetProperty("quoteVolume").GetString() ?? "0"),
                        count = t.GetProperty("count").GetInt64()
                    })
                    .Cast<object>()
                    .ToList();
                
                _logger.LogInformation("Retrieved {Count} top USDT markets", usdtPairs.Count);
                return usdtPairs;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Exception getting top 10 USDT markets");
                return new List<object>();
            }
        }

        public async Task<List<object>> GetFormattedKlinesAsync(string symbol, string interval = "1m", int limit = 500)
        {
            try
            {
                var url = $"{_baseUrl}/api/v3/klines?symbol={symbol.ToUpper()}&interval={interval}&limit={limit}";
                
                var response = await _httpClient.GetAsync(url);
                
                if (!response.IsSuccessStatusCode)
                {
                    _logger.LogWarning("Failed to get klines for {Symbol}. Status: {StatusCode}", symbol, response.StatusCode);
                    return new List<object>();
                }
                
                var content = await response.Content.ReadAsStringAsync();
                var rawKlines = JsonSerializer.Deserialize<decimal[][]>(content);
                
                var formattedKlines = rawKlines?.Select(k => new
                {
                    time = (long)(k[0] / 1000), // Convert to seconds for Lightweight Charts
                    open = k[1],
                    high = k[2],
                    low = k[3],
                    close = k[4],
                    volume = k[5]
                }).Cast<object>().ToList() ?? new List<object>();
                
                return formattedKlines;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Exception getting formatted klines for {Symbol}", symbol);
                return new List<object>();
            }
        }

        private string CreateSignature(string queryString)
        {
            var key = Encoding.UTF8.GetBytes(_secretKey);
            var message = Encoding.UTF8.GetBytes(queryString);
            
            using (var hmac = new HMACSHA256(key))
            {
                var hash = hmac.ComputeHash(message);
                return Convert.ToHexString(hash).ToLower();
            }
        }

        public bool HasValidCredentials()
        {
            return !string.IsNullOrEmpty(_apiKey) && !string.IsNullOrEmpty(_secretKey);
        }
    }
}