using Microsoft.AspNetCore.SignalR;
using AITB.WebApp.Services;

namespace AITB.WebApp.Hubs
{
    public class MarketDataHub : Hub
    {
        private readonly IPriceFeed _priceFeed;
        private readonly ILogger<MarketDataHub> _logger;
        private static readonly Dictionary<string, HashSet<string>> _subscriptions = new();

        public MarketDataHub(IPriceFeed priceFeed, ILogger<MarketDataHub> logger)
        {
            _priceFeed = priceFeed;
            _logger = logger;
        }

        public async Task Subscribe(string symbol, string interval)
        {
            var key = $"{symbol}_{interval}";
            var connectionId = Context.ConnectionId;

            if (!_subscriptions.ContainsKey(key))
            {
                _subscriptions[key] = new HashSet<string>();
            }

            _subscriptions[key].Add(connectionId);
            await Groups.AddToGroupAsync(connectionId, key);

            _logger.LogInformation("Client {ConnectionId} subscribed to {Symbol} {Interval}", connectionId, symbol, interval);

            // Start WebSocket for this symbol/interval if it's the first subscriber
            if (_subscriptions[key].Count == 1)
            {
                _ = Task.Run(async () =>
                {
                    await _priceFeed.StartWebSocketAsync(symbol, interval, async (klineData) =>
                    {
                        await Clients.Group(key).SendAsync("KlineUpdate", new
                        {
                            symbol,
                            interval,
                            time = klineData.Time,
                            open = klineData.Open,
                            high = klineData.High,
                            low = klineData.Low,
                            close = klineData.Close,
                            volume = klineData.Volume
                        });
                    });
                });
            }

            // Send current market data
            var ticker = await _priceFeed.GetTickerAsync(symbol);
            if (ticker != null)
            {
                await Clients.Caller.SendAsync("PriceUpdate", new
                {
                    symbol = ticker.Symbol,
                    price = ticker.Price,
                    priceChangePercent = ticker.PriceChangePercent
                });
            }
        }

        public async Task Unsubscribe(string symbol, string interval)
        {
            var key = $"{symbol}_{interval}";
            var connectionId = Context.ConnectionId;

            if (_subscriptions.ContainsKey(key))
            {
                _subscriptions[key].Remove(connectionId);
                await Groups.RemoveFromGroupAsync(connectionId, key);

                _logger.LogInformation("Client {ConnectionId} unsubscribed from {Symbol} {Interval}", connectionId, symbol, interval);

                // Stop WebSocket if no more subscribers
                if (_subscriptions[key].Count == 0)
                {
                    _subscriptions.Remove(key);
                    await _priceFeed.StopWebSocketAsync();
                }
            }
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var connectionId = Context.ConnectionId;
            
            // Remove from all subscriptions
            var keysToRemove = new List<string>();
            foreach (var (key, connections) in _subscriptions)
            {
                connections.Remove(connectionId);
                if (connections.Count == 0)
                {
                    keysToRemove.Add(key);
                }
            }

            foreach (var key in keysToRemove)
            {
                _subscriptions.Remove(key);
            }

            _logger.LogInformation("Client {ConnectionId} disconnected", connectionId);
            await base.OnDisconnectedAsync(exception);
        }
    }
}