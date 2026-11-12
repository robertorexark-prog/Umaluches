namespace Umaluches.Models.Consultas;

// Resultado de sp_Checkout_ProcesarCompra: el Id del pedido o el mensaje de error del THROW
public record ResultadoCompra(int? PedidoId, string? Error)
{
    public bool Exitoso => PedidoId.HasValue;
}
