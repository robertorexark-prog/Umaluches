namespace Umaluches.Models.ViewModels;

// Lo que necesita Catalog/Index: los productos ya filtrados y los valores del formulario
public class CatalogoViewModel
{
    public IEnumerable<Producto> Productos { get; set; } = [];
    public string? Busqueda { get; set; }
    public decimal? PrecioMin { get; set; }
    public decimal? PrecioMax { get; set; }
}
