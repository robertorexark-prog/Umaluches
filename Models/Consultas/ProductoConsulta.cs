namespace Umaluches.Models.Consultas;

// Fila que devuelven sp_Catalogo_BuscarProductos y sp_Producto_ObtenerDetalle.
// Anime y Generacion llegan como texto (JOIN dentro del procedimiento).
public class ProductoConsulta
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public decimal Precio { get; set; }
    public string? Descripcion { get; set; }
    public string? ImagenUrl { get; set; }
    public int Stock { get; set; }
    public string Anime { get; set; } = string.Empty;
    public string Generacion { get; set; } = string.Empty;

    // Convierte la fila al modelo Producto para que las vistas no cambien
    public Producto ToProducto() => new()
    {
        Id = Id,
        Nombre = Nombre,
        Precio = Precio,
        Descripcion = Descripcion,
        ImagenUrl = ImagenUrl,
        Stock = Stock,
        Anime = new Umaluches.Models.Anime { Nombre = Anime },
        Generacion = new Umaluches.Models.Generacione { Nombre = Generacion }
    };
}
