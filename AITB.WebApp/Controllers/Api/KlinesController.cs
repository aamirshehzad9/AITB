using Microsoft.AspNetCore.Mvc;
using AITB.WebApp.Services;

namespace AITB.WebApp.Controllers.Api
{
    [ApiController]
    [Route("api/[controller]")]
    public class KlinesController : ControllerBase
    {
        private readonly IPriceFeed _priceFeed;
        private readonly ILogger<KlinesController> _logger;

        public KlinesController(IPriceFeed priceFeed, ILogger<KlinesController> logger)
        {
            _priceFeed = priceFeed;
            _logger = logger;
        }

        [HttpGet]
        public async Task<IActionResult> GetKlines([FromQuery] string symbol = "BTCUSDT", 
                                                   [FromQuery] string interval = "15m", 
                                                   [FromQuery] int limit = 500)
        {
            try
            {
                var klines = await _priceFeed.GetKlinesAsync(symbol, interval, limit);
                
                // Format for Lightweight Charts
                var formattedKlines = klines.Select(k => new
                {
                    time = k.Time / 1000, // Convert to seconds for Lightweight Charts
                    open = k.Open,
                    high = k.High,
                    low = k.Low,
                    close = k.Close,
                    volume = k.Volume
                });

                return Ok(formattedKlines);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get klines for {Symbol} {Interval}", symbol, interval);
                return StatusCode(500, new { error = "Failed to retrieve kline data" });
            }
        }
    }
}