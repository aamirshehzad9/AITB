using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Configuration;

public class BinanceService
{
 private readonly HttpClient _http;
 private readonly string _apiBase;

 public BinanceService(IConfiguration config)
 {
     _http = new HttpClient();
     _apiBase = config["BINANCE_BASE_URL"] ?? "https://api.binance.com";
 }

 public async Task<object?> GetTickerAsync(string symbol)
 {
     var url = $"{_apiBase}/api/v3/ticker/24hr?symbol={symbol.ToUpper()}";
     var response = await _http.GetAsync(url);
     if (!response.IsSuccessStatusCode) return null;
     var json = await response.Content.ReadFromJsonAsync<JsonElement>();
     return json;
 }

 public async Task<List<object>> GetMarketListAsync()
 {
     var url = $"{_apiBase}/api/v3/ticker/price";
     var response = await _http.GetAsync(url);
     if (!response.IsSuccessStatusCode) return new();
     var json = await response.Content.ReadFromJsonAsync<List<object>>();
     return json ?? new();
 }
}