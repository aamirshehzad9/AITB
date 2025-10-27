using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;

namespace AITB.WebApp.Controllers
{
    [Authorize(Policy = "AdminOnly")]
    public class AdminController : Controller
    {
        private readonly ILogger<AdminController> _logger;
        private readonly IConfiguration _configuration;

        public AdminController(ILogger<AdminController> logger, IConfiguration configuration)
        {
            _logger = logger;
            _configuration = configuration;
        }

        public IActionResult Index()
        {
            var adminData = new AdminDashboardModel
            {
                ServiceHealth = GetServiceHealth(),
                EnvironmentFlags = GetEnvironmentFlags(),
                SystemInfo = GetSystemInfo()
            };

            return View(adminData);
        }

        private ServiceHealthModel GetServiceHealth()
        {
            return new ServiceHealthModel
            {
                WebApp = "Healthy",
                Database = "Healthy",
                BotService = "Unknown",
                DashboardAPI = "Unknown",
                InferenceAPI = "Unknown"
            };
        }

        private Dictionary<string, string> GetEnvironmentFlags()
        {
            return new Dictionary<string, string>
            {
                { "ASPNETCORE_ENVIRONMENT", Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Development" },
                { "JWT_ENABLED", "True" },
                { "DEMO_MODE", "True" },
                { "INFERENCE_URL", _configuration["INFERENCE_API_BASE"] ?? "http://localhost:8001" },
                { "DASHBOARD_URL", "http://localhost:8502" },
                { "BOT_URL", "http://localhost:8000" }
            };
        }

        private SystemInfoModel GetSystemInfo()
        {
            return new SystemInfoModel
            {
                ServerTime = DateTime.UtcNow,
                Uptime = Environment.TickCount64 / 1000 / 60, // minutes
                MemoryUsage = GC.GetTotalMemory(false) / 1024 / 1024, // MB
                ProcessorCount = Environment.ProcessorCount
            };
        }
    }

    public class AdminDashboardModel
    {
        public ServiceHealthModel ServiceHealth { get; set; } = new();
        public Dictionary<string, string> EnvironmentFlags { get; set; } = new();
        public SystemInfoModel SystemInfo { get; set; } = new();
    }

    public class ServiceHealthModel
    {
        public string WebApp { get; set; } = string.Empty;
        public string Database { get; set; } = string.Empty;
        public string BotService { get; set; } = string.Empty;
        public string DashboardAPI { get; set; } = string.Empty;
        public string InferenceAPI { get; set; } = string.Empty;
    }

    public class SystemInfoModel
    {
        public DateTime ServerTime { get; set; }
        public long Uptime { get; set; }
        public long MemoryUsage { get; set; }
        public int ProcessorCount { get; set; }
    }
}