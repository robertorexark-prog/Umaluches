/* =====================================================================
   CutiesDB - Procedimientos almacenados
   Requisito: haber ejecutado antes CutiesDB.sql
   Idempotente: borra y vuelve a crear cada objeto. Ejecutar completo (F5).
   ===================================================================== */

USE CutiesDB;
GO

/* =====================================================================
   1. sp_Catalogo_BuscarProductos
      Filtros opcionales: texto (producto, anime o generación) y rango de precio.
   ===================================================================== */
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.sp_Catalogo_BuscarProductos') AND type = N'P')
    DROP PROCEDURE dbo.sp_Catalogo_BuscarProductos;
GO

CREATE PROCEDURE dbo.sp_Catalogo_BuscarProductos
    @Busqueda  NVARCHAR(100) = NULL,
    @PrecioMin DECIMAL(10,2) = NULL,
    @PrecioMax DECIMAL(10,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Una cadena vacía o con espacios cuenta como "sin filtro"
    SET @Busqueda = NULLIF(LTRIM(RTRIM(@Busqueda)), N'');

    SELECT  p.Id,
            p.Nombre,
            p.Precio,
            p.Descripcion,
            p.ImagenUrl,
            p.Stock,
            a.Nombre AS Anime,
            g.Nombre AS Generacion
    FROM dbo.Productos p
    JOIN dbo.Animes       a ON a.Id = p.AnimeId
    JOIN dbo.Generaciones g ON g.Id = p.GeneracionId
    WHERE (@Busqueda IS NULL
           OR p.Nombre LIKE N'%' + @Busqueda + N'%'
           OR a.Nombre LIKE N'%' + @Busqueda + N'%'
           OR g.Nombre LIKE N'%' + @Busqueda + N'%')
      AND (@PrecioMin IS NULL OR p.Precio >= @PrecioMin)
      AND (@PrecioMax IS NULL OR p.Precio <= @PrecioMax)
    ORDER BY p.Nombre
    OPTION (RECOMPILE);  -- Plan acorde a los filtros que sí llegan
END
GO

/* =====================================================================
   2. sp_Producto_ObtenerDetalle
      Devuelve una fila con el producto y sus catálogos, o ninguna si no existe.
   ===================================================================== */
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.sp_Producto_ObtenerDetalle') AND type = N'P')
    DROP PROCEDURE dbo.sp_Producto_ObtenerDetalle;
GO

CREATE PROCEDURE dbo.sp_Producto_ObtenerDetalle
    @ProductoId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  p.Id,
            p.Nombre,
            p.Precio,
            p.Descripcion,
            p.ImagenUrl,
            p.Stock,
            p.AnimeId,
            a.Nombre AS Anime,
            p.GeneracionId,
            g.Nombre AS Generacion
    FROM dbo.Productos p
    JOIN dbo.Animes       a ON a.Id = p.AnimeId
    JOIN dbo.Generaciones g ON g.Id = p.GeneracionId
    WHERE p.Id = @ProductoId;
END
GO

/* =====================================================================
   3. sp_Usuario_Autenticar
      Devuelve el usuario si correo (o nombre de usuario) y hash coinciden;
      si no, devuelve un conjunto vacío (en C#: null).
      Nota: sirve con hashes deterministas (SHA2_256 de prueba). Con
      PasswordHasher<Usuario> el hash lleva sal: en ese caso trae el usuario
      por correo y verifica la contraseña en C# con VerifyHashedPassword.
   ===================================================================== */
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.sp_Usuario_Autenticar') AND type = N'P')
    DROP PROCEDURE dbo.sp_Usuario_Autenticar;
GO

CREATE PROCEDURE dbo.sp_Usuario_Autenticar
    @Correo         NVARCHAR(150),
    @ContrasenaHash NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;

    -- Nunca se devuelve el hash al cliente
    SELECT  u.Id,
            u.NombreUsuario,
            u.Correo,
            u.FechaCreacion
    FROM dbo.Usuarios u
    WHERE (u.Correo = @Correo OR u.NombreUsuario = @Correo)  -- El login del MVC acepta ambos
      AND u.ContrasenaHash = @ContrasenaHash;
END
GO

/* =====================================================================
   4. sp_Checkout_ProcesarCompra
      Inserta el pedido COMPLETO en una sola transacción usando un TVP:
      encabezado + detalles + descuento de stock. Si algo falla, no queda nada.
      - Los precios se toman de la BD, no del cliente.
      - @Total se valida contra (subtotal + envío) para detectar manipulaciones.
   ===================================================================== */

-- El procedimiento se borra antes que el tipo, porque depende de él
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.sp_Checkout_ProcesarCompra') AND type = N'P')
    DROP PROCEDURE dbo.sp_Checkout_ProcesarCompra;
GO

IF EXISTS (SELECT * FROM sys.types WHERE name = N'TipoDetallePedido' AND is_table_type = 1)
    DROP TYPE dbo.TipoDetallePedido;
GO

-- Tipo de tabla para mandar los renglones del carrito desde C#
CREATE TYPE dbo.TipoDetallePedido AS TABLE
(
    ProductoId INT NOT NULL,
    Cantidad   INT NOT NULL CHECK (Cantidad > 0)
);
GO

CREATE PROCEDURE dbo.sp_Checkout_ProcesarCompra
    @UsuarioId  INT,
    @Total      DECIMAL(10,2),
    @Detalles   dbo.TipoDetallePedido READONLY,
    @CostoEnvio DECIMAL(10,2) = 99.00,
    @Estado     NVARCHAR(20)  = N'Pendiente',
    @PedidoId   INT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;  -- Cualquier error de ejecución revierte la transacción

    BEGIN TRY
        -- Validaciones previas (no requieren transacción)
        IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Id = @UsuarioId)
            THROW 50001, N'El usuario no existe.', 1;

        IF NOT EXISTS (SELECT 1 FROM @Detalles)
            THROW 50002, N'El pedido no tiene productos.', 1;

        IF @Estado NOT IN (N'Pendiente', N'Completado')
            THROW 50003, N'Estado inicial no válido: usa Pendiente o Completado.', 1;

        -- Agrupa por producto por si el carrito trae renglones repetidos
        DECLARE @Lineas TABLE
        (
            ProductoId     INT PRIMARY KEY,
            Cantidad       INT NOT NULL,
            PrecioUnitario DECIMAL(10,2) NULL
        );

        INSERT INTO @Lineas (ProductoId, Cantidad)
        SELECT ProductoId, SUM(Cantidad)
        FROM @Detalles
        GROUP BY ProductoId;

        BEGIN TRAN;

            -- Toma el precio actual y bloquea las filas para evitar sobreventa
            UPDATE l
            SET    l.PrecioUnitario = p.Precio
            FROM   @Lineas l
            JOIN   dbo.Productos p WITH (UPDLOCK, ROWLOCK) ON p.Id = l.ProductoId;

            IF EXISTS (SELECT 1 FROM @Lineas WHERE PrecioUnitario IS NULL)
                THROW 50004, N'Uno o más productos no existen.', 1;

            IF EXISTS (SELECT 1 FROM @Lineas l JOIN dbo.Productos p ON p.Id = l.ProductoId
                       WHERE p.Stock < l.Cantidad)
                THROW 50005, N'No hay stock suficiente para uno o más productos.', 1;

            -- El total enviado debe coincidir con el calculado en la BD
            DECLARE @TotalCalculado DECIMAL(10,2) =
                (SELECT SUM(Cantidad * PrecioUnitario) FROM @Lineas) + @CostoEnvio;

            IF @Total <> @TotalCalculado
                THROW 50006, N'El total no coincide con los precios actuales.', 1;

            -- Encabezado
            INSERT INTO dbo.Pedidos (UsuarioId, Total, Estado)
            VALUES (@UsuarioId, @TotalCalculado, @Estado);

            SET @PedidoId = SCOPE_IDENTITY();

            -- Detalles
            INSERT INTO dbo.DetallesPedido (PedidoId, ProductoId, Cantidad, PrecioUnitario)
            SELECT @PedidoId, ProductoId, Cantidad, PrecioUnitario
            FROM @Lineas;

            -- Descuento de inventario
            UPDATE p
            SET    p.Stock = p.Stock - l.Cantidad
            FROM   dbo.Productos p
            JOIN   @Lineas l ON l.ProductoId = p.Id;

        COMMIT TRAN;

        -- También se devuelve como resultado para leerlo con ExecuteScalar
        SELECT @PedidoId AS PedidoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        THROW;  -- Re-lanza el error original hacia C#
    END CATCH
END
GO

/* =====================================================================
   5. sp_Usuario_Registrar
      Crea una cuenta nueva. El hash llega ya calculado desde C#.
      Errores: 50010 = nombre de usuario ocupado, 50011 = correo ocupado.
   ===================================================================== */
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.sp_Usuario_Registrar') AND type = N'P')
    DROP PROCEDURE dbo.sp_Usuario_Registrar;
GO

CREATE PROCEDURE dbo.sp_Usuario_Registrar
    @NombreUsuario  NVARCHAR(50),
    @Correo         NVARCHAR(150),
    @ContrasenaHash NVARCHAR(256),
    @UsuarioId      INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @NombreUsuario = LTRIM(RTRIM(@NombreUsuario));
    SET @Correo        = LTRIM(RTRIM(@Correo));

    IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE NombreUsuario = @NombreUsuario)
        THROW 50010, N'Ese nombre de usuario ya está ocupado.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = @Correo)
        THROW 50011, N'Ya existe una cuenta con ese correo.', 1;

    BEGIN TRY
        INSERT INTO dbo.Usuarios (NombreUsuario, Correo, ContrasenaHash)
        VALUES (@NombreUsuario, @Correo, @ContrasenaHash);
    END TRY
    BEGIN CATCH
        -- Dos registros simultáneos con el mismo dato chocan con los índices UNIQUE
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 50012, N'El usuario o el correo ya están registrados.', 1;
        THROW;
    END CATCH

    SET @UsuarioId = SCOPE_IDENTITY();

    -- Igual que sp_Usuario_Autenticar: datos de sesión, nunca el hash
    SELECT Id, NombreUsuario, Correo, FechaCreacion
    FROM dbo.Usuarios
    WHERE Id = @UsuarioId;
END
GO

/* =====================================================================
   6. Pruebas rápidas (puedes comentar este bloque)
   ===================================================================== */

-- Catálogo con y sin filtros
EXEC dbo.sp_Catalogo_BuscarProductos;
EXEC dbo.sp_Catalogo_BuscarProductos @Busqueda = N'Golden', @PrecioMax = 450;

-- Detalle
EXEC dbo.sp_Producto_ObtenerDetalle @ProductoId = 1;

-- Login de prueba (trainer / cuties123)
DECLARE @Hash NVARCHAR(256) = CONVERT(NVARCHAR(256), HASHBYTES('SHA2_256', N'cuties123'), 2);
EXEC dbo.sp_Usuario_Autenticar @Correo = N'trainer@tracen.com', @ContrasenaHash = @Hash;
GO

-- Compra de prueba dentro de una transacción que se revierte (no deja datos)
BEGIN TRAN;
    DECLARE @Carrito dbo.TipoDetallePedido;
    DECLARE @UsuarioId INT = (SELECT Id FROM dbo.Usuarios WHERE NombreUsuario = N'trainer');
    DECLARE @Nuevo INT;

    INSERT INTO @Carrito (ProductoId, Cantidad)
    SELECT Id, 1 FROM dbo.Productos WHERE Nombre IN (N'Special Week', N'Silence Suzuka');

    -- 449 + 449 + 99 de envío = 997
    EXEC dbo.sp_Checkout_ProcesarCompra
         @UsuarioId = @UsuarioId,
         @Total     = 997.00,
         @Detalles  = @Carrito,
         @PedidoId  = @Nuevo OUTPUT;

    SELECT * FROM dbo.DetallesPedido WHERE PedidoId = @Nuevo;
IF @@TRANCOUNT > 0 ROLLBACK TRAN;
GO
