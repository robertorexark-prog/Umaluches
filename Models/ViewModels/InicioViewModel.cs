namespace Umaluches.Models.ViewModels;

// Datos de la página de inicio: tarjetas destacadas y la tabla de disponibilidad
public class InicioViewModel
{
    public IEnumerable<Producto> Destacados { get; set; } = [];
    public IEnumerable<Producto> Productos { get; set; } = [];
}
