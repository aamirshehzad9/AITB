using Microsoft.AspNetCore.SignalR;

namespace AITB.WebApp.Hubs
{
    public class MarketHub : Hub
    {
        private readonly ILogger<MarketHub> _logger;

        public MarketHub(ILogger<MarketHub> logger)
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

        public override async Task OnConnectedAsync()
        {
            _logger.LogInformation("Client {ConnectionId} connected to MarketHub", Context.ConnectionId);
            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            _logger.LogInformation("Client {ConnectionId} disconnected from MarketHub", Context.ConnectionId);
            await base.OnDisconnectedAsync(exception);
        }
    }
}