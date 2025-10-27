using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using AITB.WebApp.Models.Auth;
using AITB.WebApp.Services;

namespace AITB.WebApp.Controllers.Api
{
    [ApiController]
    [Route("api/auth")]
    public class AuthController : ControllerBase
    {
        private readonly IUserService _userService;
        private readonly IJwtService _jwtService;
        private readonly ILogger<AuthController> _logger;

        public AuthController(IUserService userService, IJwtService jwtService, ILogger<AuthController> logger)
        {
            _userService = userService;
            _jwtService = jwtService;
            _logger = logger;
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequest request)
        {
            try
            {
                if (!ModelState.IsValid)
                {
                    return BadRequest(new LoginResponse 
                    { 
                        Success = false, 
                        Message = "Invalid login request" 
                    });
                }

                var user = _userService.ValidateUser(request.Username, request.Password);
                
                if (user == null)
                {
                    _logger.LogWarning($"Failed login attempt for username: {request.Username}");
                    return Unauthorized(new LoginResponse 
                    { 
                        Success = false, 
                        Message = "Invalid username or password" 
                    });
                }

                var token = _jwtService.GenerateToken(user);
                _userService.UpdateLastLogin(user.Username);

                _logger.LogInformation($"User {user.Username} logged in successfully with role {user.Role}");

                return Ok(new LoginResponse
                {
                    Token = token,
                    Role = user.Role,
                    Username = user.Username,
                    ExpiresAt = DateTime.UtcNow.AddMinutes(480), // 8 hours
                    Success = true,
                    Message = "Login successful"
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during login");
                return StatusCode(500, new LoginResponse 
                { 
                    Success = false, 
                    Message = "An error occurred during login" 
                });
            }
        }

        [HttpPost("logout")]
        [Authorize]
        public async Task<IActionResult> Logout()
        {
            // JWT is stateless, so logout is handled client-side by removing the token
            var username = User.Identity?.Name ?? "Unknown";
            _logger.LogInformation($"User {username} logged out");
            
            return Ok(new { message = "Logout successful" });
        }

        [HttpGet("me")]
        [Authorize]
        public async Task<IActionResult> GetCurrentUser()
        {
            try
            {
                var username = User.Identity?.Name;
                if (string.IsNullOrEmpty(username))
                {
                    return Unauthorized(new { message = "Invalid token" });
                }

                var user = _userService.GetUser(username);
                if (user == null)
                {
                    return Unauthorized(new { message = "User not found" });
                }

                return Ok(new
                {
                    username = user.Username,
                    role = user.Role,
                    lastLoginAt = user.LastLoginAt
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting current user");
                return StatusCode(500, new { message = "An error occurred" });
            }
        }

        [HttpGet("validate")]
        [Authorize]
        public async Task<IActionResult> ValidateToken()
        {
            // If we reach here, the token is valid (due to [Authorize])
            return Ok(new { valid = true, user = User.Identity?.Name, role = User.FindFirst("role")?.Value });
        }

        [HttpGet("demo-users")]
        public async Task<IActionResult> GetDemoUsers()
        {
            // Public endpoint to show available demo users
            var demoUsers = new[]
            {
                new { username = "admin", password = "admin123", role = "admin", description = "Admin user with full access" },
                new { username = "viewer", password = "viewer123", role = "viewer", description = "Viewer user with read-only access" },
                new { username = "demo", password = "demo123", role = "viewer", description = "Demo user for testing" }
            };

            return Ok(new { 
                message = "Demo users for testing", 
                users = demoUsers,
                note = "These are demo credentials for development only"
            });
        }
    }
}