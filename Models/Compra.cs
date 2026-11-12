namespace Umaluches.Models;

// Registro del historial de compras de un usuario
public class Compra
{
    public int Id { get; set; }
    public int UsuarioId { get; set; }
    public int ProductoId { get; set; }
    public string NombreProducto { get; set; } = string.Empty;
    public int Cantidad { get; set; }
    public decimal Total { get; set; }
    public DateTime Fecha { get; set; }
    public string Estado { get; set; } = string.Empty;
}
