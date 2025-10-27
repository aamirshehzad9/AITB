using AITB.WebApp.Models.Auth;
using BCrypt.Net;

namespace AITB.WebApp.Services
{
    public interface IUserService
    {
        User? ValidateUser(string username, string password);
        User? GetUser(string username);
        IEnumerable<User> GetAllUsers();
        void UpdateLastLogin(string username);
    }

    public class InMemoryUserService : IUserService
    {
        private readonly List<User> _users;
        private readonly ILogger<InMemoryUserService> _logger;

        public InMemoryUserService(IConfiguration configuration, ILogger<InMemoryUserService> logger)
        {
            _logger = logger;
            _users = LoadUsersFromConfiguration(configuration);
            _logger.LogInformation($"Loaded {_users.Count} demo users");
        }

        private List<User> LoadUsersFromConfiguration(IConfiguration configuration)
        {
            var users = new List<User>();

            // Load from configuration or create default demo users
            var configUsers = configuration.GetSection("DemoUsers").Get<List<DemoUserConfig>>();
            
            if (configUsers != null && configUsers.Any())
            {
                foreach (var configUser in configUsers)
                {
                    users.Add(new User
                    {
                        Username = configUser.Username,
                        PasswordHash = configUser.PasswordHash,
                        Role = configUser.Role,
                        IsActive = configUser.IsActive
                    });
                }
            }
            else
            {
                // Create default demo users if none configured
                users.AddRange(CreateDefaultDemoUsers());
            }

            return users;
        }

        private List<User> CreateDefaultDemoUsers()
        {
            return new List<User>
            {
                new User
                {
                    Username = "admin",
                    PasswordHash = BCrypt.Net.BCrypt.HashPassword("admin123"), // Demo password
                    Role = Roles.Admin,
                    IsActive = true
                },
                new User
                {
                    Username = "viewer",
                    PasswordHash = BCrypt.Net.BCrypt.HashPassword("viewer123"), // Demo password
                    Role = Roles.Viewer,
                    IsActive = true
                },
                new User
                {
                    Username = "demo",
                    PasswordHash = BCrypt.Net.BCrypt.HashPassword("demo123"), // Demo password
                    Role = Roles.Viewer,
                    IsActive = true
                }
            };
        }

        public User? ValidateUser(string username, string password)
        {
            var user = _users.FirstOrDefault(u => u.Username.Equals(username, StringComparison.OrdinalIgnoreCase) && u.IsActive);
            
            if (user != null && BCrypt.Net.BCrypt.Verify(password, user.PasswordHash))
            {
                _logger.LogInformation($"User {username} authenticated successfully with role {user.Role}");
                return user;
            }

            _logger.LogWarning($"Authentication failed for user {username}");
            return null;
        }

        public User? GetUser(string username)
        {
            return _users.FirstOrDefault(u => u.Username.Equals(username, StringComparison.OrdinalIgnoreCase) && u.IsActive);
        }

        public IEnumerable<User> GetAllUsers()
        {
            return _users.Where(u => u.IsActive).Select(u => new User
            {
                Username = u.Username,
                Role = u.Role,
                IsActive = u.IsActive,
                CreatedAt = u.CreatedAt,
                LastLoginAt = u.LastLoginAt
                // Exclude password hash
            });
        }

        public void UpdateLastLogin(string username)
        {
            var user = _users.FirstOrDefault(u => u.Username.Equals(username, StringComparison.OrdinalIgnoreCase));
            if (user != null)
            {
                user.LastLoginAt = DateTime.UtcNow;
            }
        }
    }

    public class DemoUserConfig
    {
        public string Username { get; set; } = string.Empty;
        public string PasswordHash { get; set; } = string.Empty;
        public string Role { get; set; } = string.Empty;
        public bool IsActive { get; set; } = true;
    }
}