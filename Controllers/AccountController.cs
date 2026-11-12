using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Umaluches.Models;
using Umaluches.Models.Consultas;
using Umaluches.Models.ViewModels;

namespace Umaluches.Controllers;

public class AccountController : Controller
{
    private readonly CutiesDBContext _context;

    public AccountController(CutiesDBContext context)
    {
        _context = context;
    }

    [HttpGet]
    public IActionResult Login(string? returnUrl = null)
    {
        if (User.Identity?.IsAuthenticated == true)
        {
            return RedirectToAction(nameof(Profile));
        }

        return View(new LoginViewModel { ReturnUrl = returnUrl });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Login(LoginViewModel modelo)
    {
        if (!ModelState.IsValid)
        {
            return View(modelo);
        }

        var hash = CalcularHash(modelo.Contrasena);
        var usuarioOCorreo = modelo.Usuario.Trim();

        // sp_Usuario_Autenticar acepta correo o nombre de usuario y nunca devuelve el hash
        var usuario = await _context.AutenticarUsuarioAsync(usuarioOCorreo, hash);

        if (usuario is null)
        {
            ModelState.AddModelError(string.Empty, "Usuario o contraseña incorrectos.");
            return View(modelo);
        }

        await IniciarSesionAsync(usuario);
        return RedirigirDespuesDeEntrar(modelo.ReturnUrl);
    }

    [HttpGet]
    public IActionResult Register(string? returnUrl = null)
    {
        if (User.Identity?.IsAuthenticated == true)
        {
            return RedirectToAction(nameof(Profile));
        }

        return View(new RegistroViewModel { ReturnUrl = returnUrl });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Register(RegistroViewModel modelo)
    {
        if (!ModelState.IsValid)
        {
            return View(modelo);
        }

        // sp_Usuario_Registrar valida que el usuario y el correo no existan y crea la cuenta
        var resultado = await _context.RegistrarUsuarioAsync(
            modelo.NombreUsuario.Trim(), modelo.Correo.Trim(), CalcularHash(modelo.Contrasena));

        if (!resultado.Exitoso)
        {
            ModelState.AddModelError(string.Empty, resultado.Error!);
            return View(modelo);
        }

        // La cuenta nueva entra directo, sin volver a escribir la contraseña
        await IniciarSesionAsync(resultado.Usuario!);
        TempData["CuentaNueva"] = $"¡Bienvenido a Umaluches Cuties, {resultado.Usuario!.NombreUsuario}!";
        return RedirigirDespuesDeEntrar(modelo.ReturnUrl);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Logout()
    {
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        return RedirectToAction("Index", "Home");
    }

    [Authorize]
    public async Task<IActionResult> Profile()
    {
        var usuarioId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var usuario = await _context.Usuarios
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == usuarioId);

        if (usuario is null)
        {
            // La cookie apunta a un usuario que ya no existe en la BD
            await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            return RedirectToAction(nameof(Login));
        }

        var pedidos = await _context.Pedidos
            .AsNoTracking()
            .Where(p => p.UsuarioId == usuarioId)
            .Include(p => p.DetallesPedidos)
                .ThenInclude(d => d.Producto)
            .OrderByDescending(p => p.FechaPedido)
            .ToListAsync();

        // Cada Pedido se resume en una fila del historial (la vista Profile no cambia)
        var historial = pedidos.Select(p => new Compra
        {
            Id = p.Id,
            UsuarioId = p.UsuarioId,
            ProductoId = p.DetallesPedidos.Select(d => d.ProductoId).FirstOrDefault(),
            NombreProducto = string.Join(", ", p.DetallesPedidos.Select(d => d.Producto.Nombre)),
            Cantidad = p.DetallesPedidos.Sum(d => d.Cantidad),
            Total = p.Total,
            Fecha = p.FechaPedido,
            Estado = p.Estado
        }).ToList();

        var modelo = new PerfilViewModel
        {
            Usuario = usuario,
            Historial = historial
        };

        return View(modelo);
    }

    // Los claims son los datos del usuario que viajan en la cookie de sesión
    private async Task IniciarSesionAsync(UsuarioSesion usuario)
    {
        var claims = new List<Claim>
        {
            new Claim(ClaimTypes.NameIdentifier, usuario.Id.ToString()),
            new Claim(ClaimTypes.Name, usuario.NombreUsuario),
            new Claim(ClaimTypes.Email, usuario.Correo)
        };
        var identidad = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);

        await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, new ClaimsPrincipal(identidad));
    }

    // Regresa a donde venía el usuario (ej. el Checkout) o a su perfil
    private IActionResult RedirigirDespuesDeEntrar(string? returnUrl)
    {
        if (!string.IsNullOrEmpty(returnUrl) && Url.IsLocalUrl(returnUrl))
        {
            return Redirect(returnUrl);
        }

        return RedirectToAction(nameof(Profile));
    }

    // Debe coincidir con CONVERT(NVARCHAR(256), HASHBYTES('SHA2_256', N'...'), 2) de CutiesDB.sql:
    // N'...' es NVARCHAR, o sea UTF-16 (Encoding.Unicode), y el estilo 2 da hexadecimal en mayúsculas.
    // Solo sirve para el entorno escolar; en producción usa PasswordHasher<Usuario> (con sal).
    private static string CalcularHash(string contrasena)
    {
        var bytes = SHA256.HashData(Encoding.Unicode.GetBytes(contrasena));
        return Convert.ToHexString(bytes);
    }
}
