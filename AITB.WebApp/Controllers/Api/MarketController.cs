using Microsoft.AspNetCore.Mvc;
using AITB.WebApp.Services;

namespace AITB.WebApp.Controllers.Api
{
    [ApiController]
    [Route("api/market")]
    public class MarketController : ControllerBase
    {
        private readonly BinanceService _binance;

        public MarketController(BinanceService binance)
        {
            _binance = binance;
        }

        [HttpGet("prices")]
        public async Task<IActionResult> GetAll() => Ok(await _binance.GetMarketListAsync());

        [HttpGet("ticker/{symbol}")]
        public async Task<IActionResult> GetTicker(string symbol)
            => Ok(await _binance.GetTickerAsync(symbol));
    }
}