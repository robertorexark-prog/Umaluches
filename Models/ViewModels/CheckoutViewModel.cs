using System.ComponentModel.DataAnnotations;

namespace Umaluches.Models.ViewModels;

public class CheckoutViewModel
{
    public int ProductoId { get; set; }

    // Se vuelve a cargar en el controlador; no viaja en el formulario
    public Producto? Producto { get; set; }

    [Range(1, 10, ErrorMessage = "Puedes comprar de 1 a 10 piezas.")]
    public int Cantidad { get; set; } = 1;

    [Required(ErrorMessage = "Escribe el nombre de quien recibe.")]
    [Display(Name = "Nombre completo")]
    public string NombreCompleto { get; set; } = string.Empty;

    [Required(ErrorMessage = "Escribe la dirección de envío.")]
    [Display(Name = "Dirección")]
    public string Direccion { get; set; } = string.Empty;

    [Required(ErrorMessage = "Escribe la ciudad.")]
    public string Ciudad { get; set; } = string.Empty;

    [Required(ErrorMessage = "Escribe el código postal.")]
    [RegularExpression(@"^\d{5}$", ErrorMessage = "El código postal debe tener 5 dígitos.")]
    [Display(Name = "Código postal")]
    public string CodigoPostal { get; set; } = string.Empty;

    [Required(ErrorMessage = "Escribe un teléfono de contacto.")]
    [Phone(ErrorMessage = "El teléfono no es válido.")]
    [Display(Name = "Teléfono")]
    public string Telefono { get; set; } = string.Empty;

    public decimal CostoEnvio { get; set; } = 99m;
    public decimal Subtotal => (Producto?.Precio ?? 0) * Cantidad;
    public decimal Total => Subtotal + CostoEnvio;
}
