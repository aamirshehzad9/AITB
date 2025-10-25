using AITB.WebApp.Services;
using AITB.WebApp.Hubs;
using Microsoft.AspNetCore.SignalR;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllersWithViews();
builder.Services.AddSignalR();
builder.Services.AddHttpClient();

// Add background services
builder.Services.AddHostedService<WebSocketService>();
builder.Services.AddHostedService<AISignalService>();

// Configure CORS for SignalR
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins("http://localhost:5000", "https://localhost:5001")
              .AllowAnyMethod()
              .AllowAnyHeader()
              .AllowCredentials();
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseCors();
app.UseAuthorization();

// Map controllers
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

// Map API controllers
app.MapControllerRoute(
    name: "api",
    pattern: "api/{controller=Market}/{action=Index}/{id?}");

// Map SignalR hub
app.MapHub<TradeHub>("/hubs/tradehub");

// Health check endpoint
app.MapGet("/health", () => Results.Ok(new { 
    status = "healthy", 
    timestamp = DateTimeOffset.UtcNow,
    version = "2.0.0",
    services = new {
        webapp = "running",
        signalr = "connected",
        websocket = "streaming"
    }
}));

// API endpoint for external trade notifications
app.MapPost("/api/notify-trade", async (TradeEvent tradeEvent, IHubContext<TradeHub> hub) =>
{
    await hub.Clients.All.SendAsync("ReceiveTrade", tradeEvent);
    return Results.Ok(new { received = true, timestamp = DateTimeOffset.UtcNow });
});

// API endpoint for external AI signal notifications
app.MapPost("/api/notify-signal", async (AISignalEvent signalEvent, IHubContext<TradeHub> hub) =>
{
    await hub.Clients.All.SendAsync("ReceiveAISignal", signalEvent);
    return Results.Ok(new { received = true, timestamp = DateTimeOffset.UtcNow });
});

app.Run("http://0.0.0.0:5000");

// Event Models for external notifications
public class TradeEvent
{
    public string Symbol { get; set; } = "";
    public string Action { get; set; } = "";
    public decimal Price { get; set; }
    public decimal Amount { get; set; }
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}

public class AISignalEvent
{
    public string Symbol { get; set; } = "";
    public string Action { get; set; } = "";
    public double Confidence { get; set; }
    public string Reasoning { get; set; } = "";
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}