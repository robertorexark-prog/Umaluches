namespace Umaluches.Models.ViewModels;

public class PerfilViewModel
{
    public Usuario Usuario { get; set; } = new();
    public IEnumerable<Compra> Historial { get; set; } = [];
}
