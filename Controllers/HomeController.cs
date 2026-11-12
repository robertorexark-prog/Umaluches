using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Umaluches.Models;
using Umaluches.Models.ViewModels;

namespace Umaluches.Controllers;

public class HomeController : Controller
{
    private readonly CutiesDBContext _context;

    public HomeController(CutiesDBContext context)
    {
        _context = context;
    }

    // Página principal de la tienda Cuties (hero, destacados, disponibilidad y contacto)
    public async Task<IActionResult> Index()
    {
        // Mismo procedimiento que el catálogo, sin filtros
        var productos = await _context.BuscarProductosAsync(null, null, null);

        var modelo = new InicioViewModel
        {
            // Los 3 primeros que tengan existencias
            Destacados = productos.Where(p => p.Stock > 0).OrderBy(p => p.Id).Take(3).ToList(),
            Productos = productos
        };

        return View(modelo);
    }

    // Recibe el formulario de contacto de la vista Index
    [HttpPost]
    [ValidateAntiForgeryToken]
    public IActionResult Contacto(string nombre, string email, string mensaje)
    {
        if (string.IsNullOrWhiteSpace(nombre) || string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(mensaje))
        {
            TempData["ContactoError"] = "Por favor completa todos los campos antes de enviar.";
        }
        else
        {
            // Aquí más adelante se podrá guardar en BD o enviar un correo
            TempData["ContactoOk"] = $"¡Gracias, {nombre}! Recibimos tu mensaje y te responderemos pronto.";
        }

        return RedirectToAction(nameof(Index), null, null, "contacto");
    }

    public IActionResult Privacy()
    {
        return View();
    }

    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
    }
}
