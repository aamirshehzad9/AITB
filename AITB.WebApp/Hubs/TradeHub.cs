using Microsoft.AspNetCore.SignalR;

namespace AITB.WebApp.Hubs;

public class TradeHub : Hub
{
    private readonly ILogger<TradeHub> _logger;

    public TradeHub(ILogger<TradeHub> logger)
    {
        _logger = logger;
    }

    public async Task JoinGroup(string groupName)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, groupName);
        _logger.LogInformation("Client {ConnectionId} joined group {GroupName}", Context.ConnectionId, groupName);
    }

    public async Task LeaveGroup(string groupName)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, groupName);
        _logger.LogInformation("Client {ConnectionId} left group {GroupName}", Context.ConnectionId, groupName);
    }

    public async Task SubscribeToSymbol(string symbol)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"symbol-{symbol}");
        _logger.LogInformation("Client {ConnectionId} subscribed to {Symbol}", Context.ConnectionId, symbol);
    }

    public async Task UnsubscribeFromSymbol(string symbol)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"symbol-{symbol}");
        _logger.LogInformation("Client {ConnectionId} unsubscribed from {Symbol}", Context.ConnectionId, symbol);
    }

    public async Task SendTrade(string symbol, string action, decimal amount, decimal price)
    {
        var trade = new
        {
            Symbol = symbol,
            Action = action,
            Amount = amount,
            Price = price,
            Timestamp = DateTimeOffset.UtcNow,
            User = Context.User?.Identity?.Name ?? "System"
        };

        await Clients.All.SendAsync("ReceiveTrade", trade);
        _logger.LogInformation("Trade broadcast: {Symbol} {Action} {Amount} at {Price}", symbol, action, amount, price);
    }

    public async Task SendAISignal(string symbol, string action, double confidence, string reasoning)
    {
        var signal = new
        {
            Symbol = symbol,
            Action = action,
            Confidence = confidence,
            Reasoning = reasoning,
            Timestamp = DateTimeOffset.UtcNow
        };

        await Clients.All.SendAsync("ReceiveAISignal", signal);
        _logger.LogInformation("AI Signal broadcast: {Symbol} {Action} ({Confidence:P})", symbol, action, confidence);
    }

    public async Task SendBotStatus(bool active, string strategy, decimal balance)
    {
        var status = new
        {
            Active = active,
            Strategy = strategy,
            Balance = balance,
            Timestamp = DateTimeOffset.UtcNow
        };

        await Clients.All.SendAsync("ReceiveBotStatus", status);
        _logger.LogInformation("Bot status broadcast: {Active}, {Strategy}, ${Balance}", active, strategy, balance);
    }

    public async Task SendNotification(string type, string message)
    {
        var notification = new
        {
            Type = type,
            Message = message,
            Timestamp = DateTimeOffset.UtcNow
        };

        await Clients.All.SendAsync("ReceiveNotification", notification);
        _logger.LogInformation("Notification sent: {Type} - {Message}", type, message);
    }

    public override async Task OnConnectedAsync()
    {
        _logger.LogInformation("Client connected: {ConnectionId}", Context.ConnectionId);
        
        // Send initial connection confirmation
        await Clients.Caller.SendAsync("ConnectionEstablished", new
        {
            ConnectionId = Context.ConnectionId,
            Timestamp = DateTimeOffset.UtcNow,
            Message = "Connected to AITB Trading Hub"
        });

        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        _logger.LogInformation("Client disconnected: {ConnectionId}", Context.ConnectionId);
        
        if (exception != null)
        {
            _logger.LogError(exception, "Client {ConnectionId} disconnected with error", Context.ConnectionId);
        }

        await base.OnDisconnectedAsync(exception);
    }
}