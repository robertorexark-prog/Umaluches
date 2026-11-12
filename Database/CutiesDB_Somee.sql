/* =====================================================================
   CutiesDB - Script para somee.com (SQL Server compartido)
   ---------------------------------------------------------------------
   * La base de datos se crea desde el panel de Somee: este script NO
     incluye CREATE DATABASE, USE [master] ni ALTER DATABASE.
   * Ejecutar conectado YA a tu base de Somee (SSMS o SQL Manager).
   * Re-ejecutable: borra y vuelve a crear todo (¡se pierden los datos!).
   ===================================================================== */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* =====================================================================
   0. Limpieza (orden inverso de dependencias)
   ===================================================================== */
DROP PROCEDURE IF EXISTS dbo.sp_Usuario_Registrar;
DROP PROCEDURE IF EXISTS dbo.sp_Usuario_Autenticar;
DROP PROCEDURE IF EXISTS dbo.sp_Producto_ObtenerDetalle;
DROP PROCEDURE IF EXISTS dbo.sp_Checkout_ProcesarCompra;
DROP PROCEDURE IF EXISTS dbo.sp_Catalogo_BuscarProductos;
DROP TABLE IF EXISTS dbo.DetallesPedido;
DROP TABLE IF EXISTS dbo.Pedidos;
DROP TABLE IF EXISTS dbo.Productos;
DROP TABLE IF EXISTS dbo.Usuarios;
DROP TABLE IF EXISTS dbo.Generaciones;
DROP TABLE IF EXISTS dbo.Animes;
DROP TYPE  IF EXISTS dbo.TipoDetallePedido;
GO

/* =====================================================================
   1. Tipo de tabla (TVP) para el checkout
   ===================================================================== */
CREATE TYPE dbo.TipoDetallePedido AS TABLE
(
    ProductoId INT NOT NULL,
    Cantidad   INT NOT NULL CHECK (Cantidad > 0)
);
GO

/* =====================================================================
   2. Tablas
   ===================================================================== */
CREATE TABLE dbo.Animes
(
    Id     INT IDENTITY(1,1) NOT NULL,
    Nombre NVARCHAR(100)     NOT NULL,
    CONSTRAINT PK_Animes        PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT UQ_Animes_Nombre UNIQUE NONCLUSTERED (Nombre)
);
GO

CREATE TABLE dbo.Generaciones
(
    Id     INT IDENTITY(1,1) NOT NULL,
    Nombre NVARCHAR(100)     NOT NULL,
    CONSTRAINT PK_Generaciones        PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT UQ_Generaciones_Nombre UNIQUE NONCLUSTERED (Nombre)
);
GO

CREATE TABLE dbo.Usuarios
(
    Id             INT IDENTITY(1,1) NOT NULL,
    NombreUsuario  NVARCHAR(50)      NOT NULL,
    Correo         NVARCHAR(150)     NOT NULL,
    ContrasenaHash NVARCHAR(256)     NOT NULL,
    FechaCreacion  DATETIME2(0)      NOT NULL CONSTRAINT DF_Usuarios_FechaCreacion DEFAULT (GETDATE()),
    CONSTRAINT PK_Usuarios               PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT UQ_Usuarios_Correo        UNIQUE NONCLUSTERED (Correo),
    CONSTRAINT UQ_Usuarios_NombreUsuario UNIQUE NONCLUSTERED (NombreUsuario)
);
GO

CREATE TABLE dbo.Productos
(
    Id           INT IDENTITY(1,1) NOT NULL,
    Nombre       NVARCHAR(100)     NOT NULL,
    Precio       DECIMAL(10,2)     NOT NULL,
    Descripcion  NVARCHAR(500)     NULL,
    ImagenUrl    NVARCHAR(300)     NULL,
    Stock        INT               NOT NULL CONSTRAINT DF_Productos_Stock DEFAULT (0),
    AnimeId      INT               NOT NULL,
    GeneracionId INT               NOT NULL,
    CONSTRAINT PK_Productos             PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_Productos_Animes      FOREIGN KEY (AnimeId)      REFERENCES dbo.Animes (Id),
    CONSTRAINT FK_Productos_Generaciones FOREIGN KEY (GeneracionId) REFERENCES dbo.Generaciones (Id),
    CONSTRAINT CK_Productos_Precio      CHECK (Precio >= 0),
    CONSTRAINT CK_Productos_Stock       CHECK (Stock >= 0)
);
GO

CREATE TABLE dbo.Pedidos
(
    Id          INT IDENTITY(1,1) NOT NULL,
    UsuarioId   INT               NOT NULL,
    FechaPedido DATETIME2(0)      NOT NULL CONSTRAINT DF_Pedidos_FechaPedido DEFAULT (GETDATE()),
    Total       DECIMAL(10,2)     NOT NULL,
    Estado      NVARCHAR(20)      NOT NULL CONSTRAINT DF_Pedidos_Estado DEFAULT (N'Pendiente'),
    CONSTRAINT PK_Pedidos          PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_Pedidos_Usuarios FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios (Id),
    CONSTRAINT CK_Pedidos_Total    CHECK (Total >= 0),
    CONSTRAINT CK_Pedidos_Estado   CHECK (Estado IN (N'Pendiente', N'En camino', N'Entregado', N'Completado', N'Cancelado'))
);
GO

CREATE TABLE dbo.DetallesPedido
(
    PedidoId       INT           NOT NULL,
    ProductoId     INT           NOT NULL,
    Cantidad       INT           NOT NULL,
    PrecioUnitario DECIMAL(10,2) NOT NULL,
    CONSTRAINT PK_DetallesPedido           PRIMARY KEY CLUSTERED (PedidoId, ProductoId),
    CONSTRAINT FK_DetallesPedido_Pedidos   FOREIGN KEY (PedidoId)   REFERENCES dbo.Pedidos (Id) ON DELETE CASCADE,
    CONSTRAINT FK_DetallesPedido_Productos FOREIGN KEY (ProductoId) REFERENCES dbo.Productos (Id),
    CONSTRAINT CK_DetallesPedido_Cantidad  CHECK (Cantidad > 0),
    CONSTRAINT CK_DetallesPedido_Precio    CHECK (PrecioUnitario >= 0)
);
GO

/* Índices de apoyo para las FK */
CREATE NONCLUSTERED INDEX IX_Pedidos_UsuarioId       ON dbo.Pedidos   (UsuarioId);
CREATE NONCLUSTERED INDEX IX_Productos_AnimeId       ON dbo.Productos (AnimeId);
CREATE NONCLUSTERED INDEX IX_Productos_GeneracionId  ON dbo.Productos (GeneracionId);
GO

/* =====================================================================
   3. Procedimientos almacenados
   ===================================================================== */
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

            INSERT INTO dbo.Pedidos (UsuarioId, Total, Estado)
            VALUES (@UsuarioId, @TotalCalculado, @Estado);

            SET @PedidoId = SCOPE_IDENTITY();

            INSERT INTO dbo.DetallesPedido (PedidoId, ProductoId, Cantidad, PrecioUnitario)
            SELECT @PedidoId, ProductoId, Cantidad, PrecioUnitario
            FROM @Lineas;

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
   4. Datos iniciales
   ===================================================================== */
INSERT INTO dbo.Animes (Nombre)
VALUES (N'Cinderella Gray'),
       (N'Uma Musume: Pretty Derby'),
       (N'Uma Musume: Pretty Derby Season 2');
GO

INSERT INTO dbo.Generaciones (Nombre)
VALUES (N'Era Oguri'),
       (N'Golden Week'),
       (N'Generación Teio'),
       (N'Team Spica');
GO

-- Las FK se resuelven por nombre para no depender de los Id
INSERT INTO dbo.Productos (Nombre, Precio, Descripcion, ImagenUrl, Stock, AnimeId, GeneracionId)
SELECT v.Nombre, v.Precio, v.Descripcion, NULL, v.Stock, a.Id, g.Id
FROM (VALUES
    (N'Oguri Cap',      499.00, N'La Cenicienta gris de Kasamatsu, con su apetito legendario. Peluche Cuties de 20 cm con su chaqueta de carrera.', 15, N'Cinderella Gray',                   N'Era Oguri'),
    (N'Tamamo Cross',   469.00, N'El relámpago blanco, rival de Oguri Cap. Versión Cuties con su característico uniforme azul y blanco.',           10, N'Cinderella Gray',                   N'Era Oguri'),
    (N'Special Week',   449.00, N'La chica de Hokkaido que sueña con ser la mejor uma de Japón. Viene con su clásico uniforme y una sonrisa lista para el Derby.', 20, N'Uma Musume: Pretty Derby', N'Golden Week'),
    (N'Silence Suzuka', 449.00, N'La escapista silenciosa que siempre va al frente. Tranquila, elegante y perfecta para decorar tu escritorio.',   18, N'Uma Musume: Pretty Derby',          N'Golden Week'),
    (N'El Condor Pasa', 429.00, N'¡La luchadora enmascarada! Su peluche Cuties incluye su máscara de lucha libre.',                                12, N'Uma Musume: Pretty Derby',          N'Golden Week'),
    (N'Tokai Teio',     479.00, N'La emperatriz invicta llega en formato Cuties con toda su energía y su paso de baile característico.',            8, N'Uma Musume: Pretty Derby Season 2', N'Generación Teio')
) AS v (Nombre, Precio, Descripcion, Stock, Anime, Generacion)
JOIN dbo.Animes       a ON a.Nombre = v.Anime
JOIN dbo.Generaciones g ON g.Nombre = v.Generacion;
GO

-- Usuario de prueba: trainer / cuties123  (SHA2_256 sobre N'...' en hex mayúsculas)
INSERT INTO dbo.Usuarios (NombreUsuario, Correo, ContrasenaHash)
VALUES (N'trainer', N'trainer@tracen.com',
        CONVERT(NVARCHAR(256), HASHBYTES('SHA2_256', N'cuties123'), 2));
GO

-- Pedidos de ejemplo del historial (envío fijo de $99)
DECLARE @UsuarioId INT = (SELECT Id FROM dbo.Usuarios WHERE NombreUsuario = N'trainer');
DECLARE @PedidoId  INT;

INSERT INTO dbo.Pedidos (UsuarioId, FechaPedido, Total, Estado)
VALUES (@UsuarioId, '2026-09-14', 548.00, N'Entregado');
SET @PedidoId = SCOPE_IDENTITY();
INSERT INTO dbo.DetallesPedido (PedidoId, ProductoId, Cantidad, PrecioUnitario)
SELECT @PedidoId, Id, 1, Precio FROM dbo.Productos WHERE Nombre = N'Special Week';

INSERT INTO dbo.Pedidos (UsuarioId, FechaPedido, Total, Estado)
VALUES (@UsuarioId, '2026-10-02', 1097.00, N'En camino');
SET @PedidoId = SCOPE_IDENTITY();
INSERT INTO dbo.DetallesPedido (PedidoId, ProductoId, Cantidad, PrecioUnitario)
SELECT @PedidoId, Id, 2, Precio FROM dbo.Productos WHERE Nombre = N'Oguri Cap';
GO

/* =====================================================================
   5. Verificación rápida
   ===================================================================== */
SELECT (SELECT COUNT(*) FROM dbo.Animes)       AS Animes,
       (SELECT COUNT(*) FROM dbo.Generaciones) AS Generaciones,
       (SELECT COUNT(*) FROM dbo.Productos)    AS Productos,
       (SELECT COUNT(*) FROM dbo.Usuarios)     AS Usuarios,
       (SELECT COUNT(*) FROM dbo.Pedidos)      AS Pedidos;
GO
