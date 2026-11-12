namespace Umaluches.Models.Consultas;

// Fila que devuelve sp_Usuario_Autenticar (sin el hash de la contraseña)
public class UsuarioSesion
{
    public int Id { get; set; }
    public string NombreUsuario { get; set; } = string.Empty;
    public string Correo { get; set; } = string.Empty;
    public DateTime FechaCreacion { get; set; }
}
