using Microsoft.AspNetCore.Mvc;
using AITB.WebApp.Services;

namespace AITB.WebApp.Controllers.Api
{
    [ApiController]
    [Route("api/[controller]")]
    public class MarketController : ControllerBase
    {
        private readonly IPriceFeed _priceFeed;
        private readonly ILogger<MarketController> _logger;

        public MarketController(IPriceFeed priceFeed, ILogger<MarketController> logger)
        {
            _priceFeed = priceFeed;
            _logger = logger;
        }

        [HttpGet("markets")]
        public async Task<IActionResult> GetMarkets()
        {
            try
            {
                var markets = await _priceFeed.GetMarketsAsync();
                return Ok(markets);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get markets");
                return StatusCode(500, new { error = "Failed to retrieve market data" });
            }
        }

        [HttpGet("ticker/{symbol}")]
        public async Task<IActionResult> GetTicker(string symbol)
        {
            try
            {
                var ticker = await _priceFeed.GetTickerAsync(symbol);
                if (ticker == null)
                {
                    return NotFound(new { error = $"Ticker not found for symbol: {symbol}" });
                }
                return Ok(ticker);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get ticker for {Symbol}", symbol);
                return StatusCode(500, new { error = "Failed to retrieve ticker data" });
            }
        }
    }
}