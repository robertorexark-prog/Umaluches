using System.ComponentModel.DataAnnotations;

namespace Umaluches.Models.ViewModels;

public class RegistroViewModel
{
    [Required(ErrorMessage = "Escribe un nombre de usuario.")]
    [StringLength(50, MinimumLength = 3, ErrorMessage = "El usuario debe tener entre 3 y 50 caracteres.")]
    [RegularExpression(@"^[A-Za-z0-9_.-]+$", ErrorMessage = "Usa solo letras, números, punto, guion o guion bajo (sin espacios).")]
    [Display(Name = "Nombre de usuario")]
    public string NombreUsuario { get; set; } = string.Empty;

    [Required(ErrorMessage = "Escribe tu correo.")]
    [EmailAddress(ErrorMessage = "El correo no es válido.")]
    [StringLength(150)]
    [Display(Name = "Correo electrónico")]
    public string Correo { get; set; } = string.Empty;

    [Required(ErrorMessage = "Escribe una contraseña.")]
    [StringLength(100, MinimumLength = 6, ErrorMessage = "La contraseña debe tener al menos 6 caracteres.")]
    [DataType(DataType.Password)]
    [Display(Name = "Contraseña")]
    public string Contrasena { get; set; } = string.Empty;

    [Required(ErrorMessage = "Confirma tu contraseña.")]
    [Compare(nameof(Contrasena), ErrorMessage = "Las contraseñas no coinciden.")]
    [DataType(DataType.Password)]
    [Display(Name = "Confirmar contraseña")]
    public string ConfirmarContrasena { get; set; } = string.Empty;

    // Para regresar al Checkout si el usuario venía de "Comprar"
    public string? ReturnUrl { get; set; }
}
