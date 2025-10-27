using AITB.WebApp.Hubs;
using AITB.WebApp.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using Serilog;
using System.Diagnostics;

// Port enforcement logic - terminate existing listeners on port 5000
if (Environment.GetCommandLineArgs().Contains("--force-port"))
{
    try
    {
        var psi = new ProcessStartInfo("cmd", "/c netstat -ano | findstr :5000")
        {
            RedirectStandardOutput = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };
        
        using var process = Process.Start(psi);
        if (process != null)
        {
            var output = process.StandardOutput.ReadToEnd();
            process.WaitForExit();
            
            foreach (var line in output.Split('\n'))
            {
                if (line.Contains("LISTENING"))
                {
                    var parts = line.Trim().Split(new char[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                    if (parts.Length > 0)
                    {
                        var pid = parts.Last();
                        if (int.TryParse(pid, out int processId))
                        {
                            try
                            {
                                Process.Start("cmd", $"/c taskkill /PID {processId} /F");
                                Console.WriteLine($"Terminated process {processId} using port 5000");
                            }
                            catch (Exception ex)
                            {
                                Console.WriteLine($"Failed to terminate process {processId}: {ex.Message}");
                            }
                        }
                    }
                }
            }
        }
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Error checking/terminating port 5000 processes: {ex.Message}");
    }
    
    // Give a moment for processes to terminate
    Thread.Sleep(2000);
}

var builder = WebApplication.CreateBuilder(args);

// Load .env file
DotNetEnv.Env.Load(Path.Combine(Directory.GetCurrentDirectory(), "..", ".env"));

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
builder.Services.AddSingleton<BinanceService>();
builder.Services.AddSingleton<BinanceStreamService>();
builder.Services.AddSingleton<BinanceHttpService>();

// Register authentication services
builder.Services.AddScoped<IJwtService, JwtService>();
builder.Services.AddSingleton<IUserService, InMemoryUserService>();

// Configure JWT Authentication
var jwtKey = builder.Configuration["Jwt:SecretKey"] ?? "AITB-Demo-Secret-Key-For-Development-Only-2024";
var key = Encoding.ASCII.GetBytes(jwtKey);

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.RequireHttpsMetadata = false; // For development
    options.SaveToken = true;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(key),
        ValidateIssuer = true,
        ValidIssuer = builder.Configuration["Jwt:Issuer"] ?? "AITB.WebApp",
        ValidateAudience = true,
        ValidAudience = builder.Configuration["Jwt:Audience"] ?? "AITB.WebApp",
        ValidateLifetime = true,
        ClockSkew = TimeSpan.Zero
    };
});

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("AdminOnly", policy => policy.RequireRole("admin"));
    options.AddPolicy("ViewerOrAdmin", policy => policy.RequireRole("viewer", "admin"));
});

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

// Add Authentication and Authorization middleware
app.UseAuthentication();
app.UseAuthorization();

// Configure routes
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

// Map SignalR Hub
app.MapHub<MarketHub>("/marketHub");

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