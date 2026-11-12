using System.ComponentModel.DataAnnotations;

namespace Umaluches.Models.ViewModels;

public class LoginViewModel
{
    [Required(ErrorMessage = "Escribe tu usuario o correo.")]
    [Display(Name = "Usuario o correo")]
    public string Usuario { get; set; } = string.Empty;

    [Required(ErrorMessage = "Escribe tu contraseña.")]
    [DataType(DataType.Password)]
    [Display(Name = "Contraseña")]
    public string Contrasena { get; set; } = string.Empty;

    // A dónde regresar después de iniciar sesión (ej. /Checkout?productoId=1)
    public string? ReturnUrl { get; set; }
}
