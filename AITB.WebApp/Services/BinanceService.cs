using System.Net.Http.Json;
using System.Text.Json;

namespace AITB.WebApp.Services
{
    public class BinanceService
    {
        private readonly HttpClient _http;
        private readonly string _apiBase;
        private readonly ILogger<BinanceService> _logger;

        public BinanceService(HttpClient httpClient, IConfiguration config, ILogger<BinanceService> logger)
        {
            _http = httpClient;
            _apiBase = config["BINANCE_BASE_URL"] ?? "https://api.binance.com";
            _logger = logger;
        }

        public async Task<object?> GetTickerAsync(string symbol)
        {
            try
            {
                var url = $"{_apiBase}/api/v3/ticker/24hr?symbol={symbol.ToUpper()}";
                var response = await _http.GetAsync(url);
                if (!response.IsSuccessStatusCode) 
                {
                    _logger.LogWarning("Failed to get ticker for {Symbol}. Status: {StatusCode}", symbol, response.StatusCode);
                    return null;
                }
                var json = await response.Content.ReadFromJsonAsync<JsonElement>();
                return json;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Exception getting ticker for {Symbol}", symbol);
                return null;
            }
        }

        public async Task<List<object>> GetMarketListAsync()
        {
            try
            {
                var url = $"{_apiBase}/api/v3/ticker/price";
                var response = await _http.GetAsync(url);
                if (!response.IsSuccessStatusCode) 
                {
                    _logger.LogWarning("Failed to get market list. Status: {StatusCode}", response.StatusCode);
                    return new();
                }
                var json = await response.Content.ReadFromJsonAsync<List<object>>();
                return json ?? new();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Exception getting market list");
                return new();
            }
        }
    }
}