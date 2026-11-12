using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Umaluches.Models.Consultas;

namespace Umaluches.Models;

// Llamadas a los procedimientos almacenados de Database/CutiesDB_StoredProcedures.sql.
// Va en un archivo aparte (partial) para que un nuevo Scaffold de CutiesDBContext.cs no lo borre.
public partial class CutiesDBContext
{
    // Los THROW de los procedimientos usan números 50001-50012
    private const int ErrorNegocioMin = 50000;
    private const int ErrorNegocioMax = 50999;

    public async Task<List<Producto>> BuscarProductosAsync(string? busqueda, decimal? precioMin, decimal? precioMax)
    {
        var filas = await Database
            .SqlQueryRaw<ProductoConsulta>(
                "EXEC dbo.sp_Catalogo_BuscarProductos @Busqueda, @PrecioMin, @PrecioMax",
                new SqlParameter("@Busqueda", SqlDbType.NVarChar, 100) { Value = (object?)busqueda ?? DBNull.Value },
                ParametroDecimal("@PrecioMin", precioMin),
                ParametroDecimal("@PrecioMax", precioMax))
            .ToListAsync();

        return filas.Select(f => f.ToProducto()).ToList();
    }

    public async Task<Producto?> ObtenerProductoAsync(int productoId)
    {
        // Un EXEC no se puede combinar con FirstOrDefault en SQL: se trae la lista y se toma el primero
        var filas = await Database
            .SqlQueryRaw<ProductoConsulta>(
                "EXEC dbo.sp_Producto_ObtenerDetalle @ProductoId",
                new SqlParameter("@ProductoId", SqlDbType.Int) { Value = productoId })
            .ToListAsync();

        return filas.FirstOrDefault()?.ToProducto();
    }

    public async Task<UsuarioSesion?> AutenticarUsuarioAsync(string usuarioOCorreo, string contrasenaHash)
    {
        var filas = await Database
            .SqlQueryRaw<UsuarioSesion>(
                "EXEC dbo.sp_Usuario_Autenticar @Correo, @ContrasenaHash",
                new SqlParameter("@Correo", SqlDbType.NVarChar, 150) { Value = usuarioOCorreo },
                new SqlParameter("@ContrasenaHash", SqlDbType.NVarChar, 256) { Value = contrasenaHash })
            .ToListAsync();

        return filas.FirstOrDefault();
    }

    public async Task<ResultadoRegistro> RegistrarUsuarioAsync(string nombreUsuario, string correo, string contrasenaHash)
    {
        try
        {
            var filas = await Database
                .SqlQueryRaw<UsuarioSesion>(
                    "EXEC dbo.sp_Usuario_Registrar @NombreUsuario, @Correo, @ContrasenaHash",
                    new SqlParameter("@NombreUsuario", SqlDbType.NVarChar, 50) { Value = nombreUsuario },
                    new SqlParameter("@Correo", SqlDbType.NVarChar, 150) { Value = correo },
                    new SqlParameter("@ContrasenaHash", SqlDbType.NVarChar, 256) { Value = contrasenaHash })
                .ToListAsync();

            return new ResultadoRegistro(filas.FirstOrDefault(), null);
        }
        catch (SqlException ex) when (ex.Number is >= ErrorNegocioMin and <= ErrorNegocioMax)
        {
            // Usuario o correo ya ocupados (THROW 50010-50012)
            return new ResultadoRegistro(null, ex.Message);
        }
    }

    public async Task<ResultadoCompra> ProcesarCompraAsync(int usuarioId, int productoId, int cantidad, decimal total, decimal costoEnvio)
    {
        // Renglones del pedido para el parámetro de tipo tabla dbo.TipoDetallePedido
        var detalles = new DataTable();
        detalles.Columns.Add("ProductoId", typeof(int));
        detalles.Columns.Add("Cantidad", typeof(int));
        detalles.Rows.Add(productoId, cantidad);

        var pedidoId = new SqlParameter("@PedidoId", SqlDbType.Int) { Direction = ParameterDirection.Output };

        try
        {
            await Database.ExecuteSqlRawAsync(
                "EXEC dbo.sp_Checkout_ProcesarCompra @UsuarioId = @UsuarioId, @Total = @Total, @Detalles = @Detalles, " +
                "@CostoEnvio = @CostoEnvio, @PedidoId = @PedidoId OUTPUT",
                new SqlParameter("@UsuarioId", SqlDbType.Int) { Value = usuarioId },
                ParametroDecimal("@Total", total),
                new SqlParameter("@Detalles", SqlDbType.Structured) { TypeName = "dbo.TipoDetallePedido", Value = detalles },
                ParametroDecimal("@CostoEnvio", costoEnvio),
                pedidoId);
        }
        catch (SqlException ex) when (ex.Number is >= ErrorNegocioMin and <= ErrorNegocioMax)
        {
            // Errores de negocio del procedimiento (sin stock, total alterado, etc.)
            return new ResultadoCompra(null, ex.Message);
        }

        return new ResultadoCompra((int)pedidoId.Value, null);
    }

    private static SqlParameter ParametroDecimal(string nombre, decimal? valor) =>
        new(nombre, SqlDbType.Decimal) { Precision = 10, Scale = 2, Value = (object?)valor ?? DBNull.Value };
}
