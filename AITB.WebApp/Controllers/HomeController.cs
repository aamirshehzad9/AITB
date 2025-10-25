using Microsoft.AspNetCore.Mvc;
using System.Text.Json;

namespace AITB.WebApp.Controllers;

public class HomeController : Controller
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;

    public HomeController(HttpClient httpClient, IConfiguration configuration)
    {
        _httpClient = httpClient;
        _configuration = configuration;
    }

    public async Task<IActionResult> Index()
    {
        var model = new DashboardModel();
        
        try
        {
            // Get MCP status
            var mcpUrl = _configuration["MCP_BASE_URL"] ?? "http://localhost:8600";
            var mcpResponse = await _httpClient.GetStringAsync($"{mcpUrl}/health");
            model.MCPStatus = "Healthy";
            model.MCPUrl = mcpUrl;
        }
        catch
        {
            model.MCPStatus = "Offline";
        }

        try
        {
            // Get InfluxDB status
            var influxUrl = _configuration["INFLUX_URL"] ?? "http://localhost:8086";
            var influxResponse = await _httpClient.GetAsync($"{influxUrl}/ping");
            model.InfluxStatus = influxResponse.IsSuccessStatusCode ? "Healthy" : "Offline";
            model.InfluxUrl = influxUrl;
        }
        catch
        {
            model.InfluxStatus = "Offline";
        }

        model.StreamlitUrl = "http://localhost:8501";
        model.GrafanaUrl = "http://localhost:3001";
        
        return View(model);
    }

    [HttpPost]
    public async Task<IActionResult> TestInference([FromBody] InferenceRequest request)
    {
        try
        {
            var mcpUrl = _configuration["MCP_BASE_URL"] ?? "http://localhost:8600";
            var json = JsonSerializer.Serialize(new { prompt = request.Prompt, model = "test-gemma-model" });
            var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");
            
            var response = await _httpClient.PostAsync($"{mcpUrl}/generate", content);
            var result = await response.Content.ReadAsStringAsync();
            
            return Json(new { success = true, result = result });
        }
        catch (Exception ex)
        {
            return Json(new { success = false, error = ex.Message });
        }
    }
}

public class DashboardModel
{
    public string MCPStatus { get; set; } = "";
    public string MCPUrl { get; set; } = "";
    public string InfluxStatus { get; set; } = "";
    public string InfluxUrl { get; set; } = "";
    public string StreamlitUrl { get; set; } = "";
    public string GrafanaUrl { get; set; } = "";
}

public class InferenceRequest
{
    public string Prompt { get; set; } = "";
}