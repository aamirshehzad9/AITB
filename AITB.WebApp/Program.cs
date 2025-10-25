using AITB.WebApp.Hubs;
using AITB.WebApp.Services;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

// Configure Serilog
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .WriteTo.File("logs/aitb-webapp.log", 
        rollingInterval: RollingInterval.Day,
        retainedFileCountLimit: 30)
    .CreateLogger();

builder.Host.UseSerilog();

// Add services to the container
builder.Services.AddControllersWithViews();
builder.Services.AddSignalR();

// Register custom services
builder.Services.AddSingleton<IPriceFeed, BinancePriceFeed>();

// Add HttpClient for external API calls
builder.Services.AddHttpClient();

// Add CORS
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

// Configure the HTTP request pipeline
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseCors();
app.UseRouting();
app.UseAuthorization();

// Configure routes
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

// Map SignalR Hub
app.MapHub<MarketDataHub>("/marketHub");

// Health endpoints
app.MapGet("/health/live", () => "OK");
app.MapGet("/api/status", () => new
{
    status = "healthy",
    timestamp = DateTime.UtcNow,
    version = "1.0.0",
    services = new
    {
        signalr = "connected",
        binance_api = "active",
        logging = "enabled"
    }
});

Log.Information("AITB WebApp starting up...");

app.Run();

// Ensure to flush and close logs
Log.CloseAndFlush();