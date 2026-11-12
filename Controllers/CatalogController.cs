using Microsoft.AspNetCore.Mvc;
using Umaluches.Models;
using Umaluches.Models.ViewModels;

namespace Umaluches.Controllers;

public class CatalogController : Controller
{
    private readonly CutiesDBContext _context;

    // El DbContext llega por inyección de dependencias (registrado en Program.cs con AddDbContext)
    public CatalogController(CutiesDBContext context)
    {
        _context = context;
    }

    // GET /Catalog?busqueda=oguri&precioMin=400&precioMax=500
    public async Task<IActionResult> Index(string? busqueda, decimal? precioMin, decimal? precioMax)
    {
        // Si el usuario invierte el rango, se acomoda en lugar de devolver cero resultados
        if (precioMin > precioMax)
        {
            (precioMin, precioMax) = (precioMax, precioMin);
        }

        // sp_Catalogo_BuscarProductos filtra por nombre, anime o generación y por rango de precio
        var modelo = new CatalogoViewModel
        {
            Productos = await _context.BuscarProductosAsync(busqueda, precioMin, precioMax),
            Busqueda = busqueda,
            PrecioMin = precioMin,
            PrecioMax = precioMax
        };

        return View(modelo);
    }

    // GET /Catalog/Details/3
    public async Task<IActionResult> Details(int id)
    {
        // sp_Producto_ObtenerDetalle
        var producto = await _context.ObtenerProductoAsync(id);
        if (producto is null)
        {
            TempData["CatalogoAviso"] = "Ese peluche no existe o ya no está en el catálogo.";
            return RedirectToAction(nameof(Index));
        }

        return View(producto);
    }
}
