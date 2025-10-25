using Microsoft.AspNetCore.Mvc;

namespace AITB.WebApp.Controllers
{
    public class TradeController : Controller
    {
        private readonly ILogger<TradeController> _logger;

        public TradeController(ILogger<TradeController> logger)
        {
            _logger = logger;
        }

        public IActionResult Index(string symbol = "BTCUSDT", string interval = "15m")
        {
            _logger.LogInformation("Trade page accessed for {Symbol} {Interval}", symbol, interval);
            
            ViewBag.Symbol = symbol;
            ViewBag.Interval = interval;
            
            return View();
        }
    }
}