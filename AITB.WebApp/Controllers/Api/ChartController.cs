using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using System.Text.Json;

namespace AITB.WebApp.Controllers.Api
{
    [ApiController]
    [Route("api/chart")]
    [Authorize(Policy = "ViewerOrAdmin")] // Protect data endpoints for authenticated users
    public class ChartController : ControllerBase
    {
        private readonly ILogger<ChartController> _logger;
        private readonly HttpClient _httpClient;

        public ChartController(ILogger<ChartController> logger, HttpClient httpClient)
        {
            _logger = logger;
            _httpClient = httpClient;
        }

        [HttpGet("price")]
        public async Task<IActionResult> GetPrice([FromQuery] string symbol = "BTCUSDT")
        {
            try
            {
                var response = await _httpClient.GetAsync($"http://localhost:8502/data/price?symbol={symbol}");
                if (response.IsSuccessStatusCode)
                {
                    var content = await response.Content.ReadAsStringAsync();
                    return Content(content, "application/json");
                }
                return StatusCode(500, new { error = "Failed to fetch price" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = ex.Message });
            }
        }

        [HttpGet("candles")]
        public async Task<IActionResult> GetCandles([FromQuery] string symbol = "BTCUSDT", [FromQuery] string interval = "1m", [FromQuery] int limit = 500)
        {
            try
            {
                var response = await _httpClient.GetAsync($"http://localhost:8502/chart/candles?symbol={symbol}&interval={interval}&limit={limit}");
                if (response.IsSuccessStatusCode)
                {
                    var content = await response.Content.ReadAsStringAsync();
                    return Content(content, "application/json");
                }
                return StatusCode(500, new { error = "Failed to fetch candles" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = ex.Message });
            }
        }
    }
}
