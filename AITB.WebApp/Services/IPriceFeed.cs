namespace AITB.WebApp.Services
{
    public class KlineData
    {
        public long Time { get; set; }
        public decimal Open { get; set; }
        public decimal High { get; set; }
        public decimal Low { get; set; }
        public decimal Close { get; set; }
        public decimal Volume { get; set; }
    }

    public class MarketTicker
    {
        public string Symbol { get; set; } = string.Empty;
        public string DisplaySymbol { get; set; } = string.Empty;
        public decimal LastPrice { get; set; }
        public decimal Change24h { get; set; }
        public decimal ChangePercent24h { get; set; }
        public decimal Volume24h { get; set; }
        public string Price => LastPrice.ToString("F4");
        public string PriceChangePercent => ChangePercent24h.ToString("F2");
    }

    public interface IPriceFeed
    {
        Task<IEnumerable<KlineData>> GetKlinesAsync(string symbol, string interval, int limit);
        Task<IEnumerable<MarketTicker>> GetMarketsAsync();
        Task<MarketTicker?> GetTickerAsync(string symbol);
        Task StartWebSocketAsync(string symbol, string interval, Func<KlineData, Task> onKlineReceived);
        Task StopWebSocketAsync();
    }
}