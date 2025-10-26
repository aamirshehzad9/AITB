using Microsoft.AspNetCore.Mvc;
using AITB.WebApp.Services;

namespace AITB.WebApp.Controllers.Api
{
    [ApiController]
    [Route("api/market")]
    public class MarketController : ControllerBase
    {
        private readonly BinanceService _binance;
        private readonly BinanceHttpService _binanceHttp;
        private readonly ILogger<MarketController> _logger;

        public MarketController(BinanceService binance, BinanceHttpService binanceHttp, ILogger<MarketController> logger)
        {
            _binance = binance;
            _binanceHttp = binanceHttp;
            _logger = logger;
        }

        [HttpGet("prices")]
        public async Task<IActionResult> GetAll() => Ok(await _binance.GetMarketListAsync());

        [HttpGet("ticker/{symbol}")]
        public async Task<IActionResult> GetTicker(string symbol)
            => Ok(await _binance.GetTickerAsync(symbol));

        [HttpGet("top10")]
        public async Task<IActionResult> GetTop10Markets()
        {
            try
            {
                var markets = await _binanceHttp.GetTop10USDTMarketsAsync();
                return Ok(markets);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get top 10 markets");
                return StatusCode(500, new { error = "Failed to retrieve top 10 markets" });
            }
        }
    }
}