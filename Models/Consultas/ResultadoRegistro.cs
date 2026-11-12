namespace Umaluches.Models.Consultas;

// Resultado de sp_Usuario_Registrar: el usuario creado o el mensaje de error del THROW
public record ResultadoRegistro(UsuarioSesion? Usuario, string? Error)
{
    public bool Exitoso => Usuario is not null;
}
