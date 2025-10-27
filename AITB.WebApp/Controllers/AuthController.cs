using Microsoft.AspNetCore.Mvc;

namespace AITB.WebApp.Controllers
{
    public class AuthController : Controller
    {
        public IActionResult Login()
        {
            // If already authenticated, redirect to trade page
            if (User.Identity?.IsAuthenticated == true)
            {
                return RedirectToAction("Index", "Trade");
            }

            return View();
        }

        public IActionResult Logout()
        {
            // JWT is stateless, actual logout happens on client side
            // This is just for redirecting after client-side token removal
            return RedirectToAction("Login");
        }

        public IActionResult AccessDenied()
        {
            return View();
        }
    }
}