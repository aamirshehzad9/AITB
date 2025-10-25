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