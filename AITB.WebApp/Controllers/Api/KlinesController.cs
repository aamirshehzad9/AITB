using Microsoft.AspNetCore.Mvc;
using AITB.WebApp.Services;

namespace AITB.WebApp.Controllers.Api
{
    [ApiController]
    [Route("api/[controller]")]
    public class KlinesController : ControllerBase
    {
        private readonly IPriceFeed _priceFeed;
        private readonly BinanceHttpService _binanceHttp;
        private readonly ILogger<KlinesController> _logger;

        public KlinesController(IPriceFeed priceFeed, BinanceHttpService binanceHttp, ILogger<KlinesController> logger)
        {
            _priceFeed = priceFeed;
            _binanceHttp = binanceHttp;
            _logger = logger;
        }

        [HttpGet]
        public async Task<IActionResult> GetKlines([FromQuery] string symbol = "BTCUSDT", 
                                                   [FromQuery] string interval = "1m", 
                                                   [FromQuery] int limit = 500)
        {
            try
            {
                // Use the new formatted klines method for better performance
                var klines = await _binanceHttp.GetFormattedKlinesAsync(symbol, interval, limit);
                return Ok(klines);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get klines for {Symbol} {Interval}", symbol, interval);
                return StatusCode(500, new { error = "Failed to retrieve kline data" });
            }
        }

        [HttpGet("candles")]
        public async Task<IActionResult> GetCandles([FromQuery] string symbol = "BTCUSDT", 
                                                   [FromQuery] string interval = "1m", 
                                                   [FromQuery] int limit = 500)
        {
            try
            {
                var klines = await _binanceHttp.GetFormattedKlinesAsync(symbol, interval, limit);
                return Ok(klines);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get candles for {Symbol} {Interval}", symbol, interval);
                return StatusCode(500, new { error = "Failed to retrieve candle data" });
            }
        }
    }
}