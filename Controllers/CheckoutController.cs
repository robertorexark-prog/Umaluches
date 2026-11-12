using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Umaluches.Models;
using Umaluches.Models.ViewModels;

namespace Umaluches.Controllers;

// [Authorize] protege todo el controlador: si no hay sesión, ASP.NET Core
// redirige solo a /Account/Login?ReturnUrl=... (LoginPath en Program.cs).
// AccountController.Login valida al usuario con sp_Usuario_Autenticar, crea sus Claims
// (Id, nombre, correo) y llama a HttpContext.SignInAsync, que guarda la cookie.
[Authorize]
public class CheckoutController : Controller
{
    private readonly CutiesDBContext _context;

    public CheckoutController(CutiesDBContext context)
    {
        _context = context;
    }

    // GET /Checkout?productoId=3
    [HttpGet]
    public async Task<IActionResult> Index(int productoId)
    {
        var producto = await _context.ObtenerProductoAsync(productoId);
        if (producto is null)
        {
            return RedirectToAction("Index", "Catalog");
        }

        if (producto.Stock == 0)
        {
            TempData["CatalogoAviso"] = $"{producto.Nombre} está agotado por ahora.";
            return RedirectToAction("Details", "Catalog", new { id = producto.Id });
        }

        var modelo = new CheckoutViewModel
        {
            ProductoId = producto.Id,
            Producto = producto,
            NombreCompleto = User.Identity?.Name ?? string.Empty
        };

        return View(modelo);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Index(CheckoutViewModel modelo)
    {
        // El producto se vuelve a cargar de la BD para que el precio no se pueda alterar desde el formulario
        modelo.Producto = await _context.ObtenerProductoAsync(modelo.ProductoId);
        if (modelo.Producto is null)
        {
            return RedirectToAction("Index", "Catalog");
        }

        if (modelo.Cantidad > modelo.Producto.Stock)
        {
            ModelState.AddModelError(nameof(modelo.Cantidad), $"Solo quedan {modelo.Producto.Stock} piezas disponibles.");
        }

        if (!ModelState.IsValid)
        {
            return View(modelo);
        }

        var usuarioId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        // sp_Checkout_ProcesarCompra guarda pedido + detalle y descuenta el stock en una sola
        // transacción; además recalcula el total con los precios de la BD y lo compara con el nuestro
        var resultado = await _context.ProcesarCompraAsync(
            usuarioId, modelo.Producto.Id, modelo.Cantidad, modelo.Total, modelo.CostoEnvio);

        if (!resultado.Exitoso)
        {
            ModelState.AddModelError(string.Empty, resultado.Error!);
            return View(modelo);
        }

        TempData["CompraOk"] = $"¡Compra realizada! Pedido #{resultado.PedidoId}: tu peluche de {modelo.Producto.Nombre} va en camino.";
        return RedirectToAction("Profile", "Account");
    }
}
