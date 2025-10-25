using Microsoft.AspNetCore.SignalR;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllersWithViews();
builder.Services.AddSignalR();
builder.Services.AddHttpClient();

// Configure CORS
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(builder =>
    {
        builder.AllowAnyOrigin()
               .AllowAnyMethod()
               .AllowAnyHeader();
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

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.MapHub<TradeHub>("/tradehub");

// API endpoint for trade notifications
app.MapPost("/notify-trade", async (TradeEvent tradeEvent, IHubContext<TradeHub> hub) =>
{
    await hub.Clients.All.SendAsync("ReceiveTrade", tradeEvent);
    return Results.Ok();
});

app.Run("http://0.0.0.0:5000");

// Trade Hub for SignalR
public class TradeHub : Hub
{
    public async Task SendTrade(string user, string message)
    {
        await Clients.All.SendAsync("ReceiveTrade", user, message);
    }
}

// Trade Event Model
public class TradeEvent
{
    public string Symbol { get; set; } = "";
    public string Action { get; set; } = "";
    public decimal Price { get; set; }
    public decimal Amount { get; set; }
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}