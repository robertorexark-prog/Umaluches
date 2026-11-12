/* =====================================================================
   CutiesDB - Base de datos de la tienda Umaluches (peluches Cuties)
   Motor: SQL Server 2016+  |  Ejecutar completo en SSMS (F5)
   El script es idempotente: se puede correr varias veces sin errores.
   ===================================================================== */

-- 1. Crear la base de datos si no existe
IF DB_ID(N'CutiesDB') IS NULL
    CREATE DATABASE CutiesDB;
GO

USE CutiesDB;
GO

/* =====================================================================
   2. Tablas (3FN)
   ===================================================================== */

-- Usuarios de la tienda
IF OBJECT_ID(N'dbo.Usuarios', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Usuarios
    (
        Id             INT IDENTITY(1,1) NOT NULL,
        NombreUsuario  NVARCHAR(50)      NOT NULL,
        Correo         NVARCHAR(150)     NOT NULL,
        ContrasenaHash NVARCHAR(256)     NOT NULL,  -- Hash, nunca texto plano
        FechaCreacion  DATETIME2(0)      NOT NULL CONSTRAINT DF_Usuarios_FechaCreacion DEFAULT GETDATE(),

        CONSTRAINT PK_Usuarios               PRIMARY KEY (Id),
        CONSTRAINT UQ_Usuarios_NombreUsuario UNIQUE (NombreUsuario),
        CONSTRAINT UQ_Usuarios_Correo        UNIQUE (Correo)
    );
END
GO

-- Catálogo de animes / series de origen
IF OBJECT_ID(N'dbo.Animes', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Animes
    (
        Id     INT IDENTITY(1,1) NOT NULL,
        Nombre NVARCHAR(100)     NOT NULL,

        CONSTRAINT PK_Animes        PRIMARY KEY (Id),
        CONSTRAINT UQ_Animes_Nombre UNIQUE (Nombre)
    );
END
GO

-- Catálogo de generaciones / equipos
IF OBJECT_ID(N'dbo.Generaciones', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Generaciones
    (
        Id     INT IDENTITY(1,1) NOT NULL,
        Nombre NVARCHAR(100)     NOT NULL,

        CONSTRAINT PK_Generaciones        PRIMARY KEY (Id),
        CONSTRAINT UQ_Generaciones_Nombre UNIQUE (Nombre)
    );
END
GO

-- Peluches a la venta
IF OBJECT_ID(N'dbo.Productos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Productos
    (
        Id           INT IDENTITY(1,1) NOT NULL,
        Nombre       NVARCHAR(100)     NOT NULL,
        Precio       DECIMAL(10,2)     NOT NULL,
        Descripcion  NVARCHAR(500)     NULL,
        ImagenUrl    NVARCHAR(300)     NULL,        -- Ruta relativa a wwwroot; NULL = placeholder
        Stock        INT               NOT NULL CONSTRAINT DF_Productos_Stock DEFAULT 0,
        AnimeId      INT               NOT NULL,
        GeneracionId INT               NOT NULL,

        CONSTRAINT PK_Productos              PRIMARY KEY (Id),
        CONSTRAINT FK_Productos_Animes       FOREIGN KEY (AnimeId)      REFERENCES dbo.Animes (Id),
        CONSTRAINT FK_Productos_Generaciones FOREIGN KEY (GeneracionId) REFERENCES dbo.Generaciones (Id),
        CONSTRAINT CK_Productos_Precio       CHECK (Precio >= 0),
        CONSTRAINT CK_Productos_Stock        CHECK (Stock >= 0)
    );

    -- Índices para los filtros del catálogo
    CREATE INDEX IX_Productos_AnimeId      ON dbo.Productos (AnimeId);
    CREATE INDEX IX_Productos_GeneracionId ON dbo.Productos (GeneracionId);
END
GO

-- Encabezado de cada compra
IF OBJECT_ID(N'dbo.Pedidos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Pedidos
    (
        Id          INT IDENTITY(1,1) NOT NULL,
        UsuarioId   INT               NOT NULL,
        FechaPedido DATETIME2(0)      NOT NULL CONSTRAINT DF_Pedidos_FechaPedido DEFAULT GETDATE(),
        Total       DECIMAL(10,2)     NOT NULL,     -- Subtotal + costo de envío
        Estado      NVARCHAR(20)      NOT NULL CONSTRAINT DF_Pedidos_Estado DEFAULT N'Pendiente',

        CONSTRAINT PK_Pedidos          PRIMARY KEY (Id),
        CONSTRAINT FK_Pedidos_Usuarios FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios (Id),
        CONSTRAINT CK_Pedidos_Total    CHECK (Total >= 0),
        CONSTRAINT CK_Pedidos_Estado   CHECK (Estado IN (N'Pendiente', N'En camino', N'Entregado', N'Completado', N'Cancelado'))
    );

    CREATE INDEX IX_Pedidos_UsuarioId ON dbo.Pedidos (UsuarioId);
END
GO

-- Renglones de cada pedido (PK compuesta)
IF OBJECT_ID(N'dbo.DetallesPedido', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DetallesPedido
    (
        PedidoId       INT           NOT NULL,
        ProductoId     INT           NOT NULL,
        Cantidad       INT           NOT NULL,
        PrecioUnitario DECIMAL(10,2) NOT NULL,      -- Precio congelado al momento de la compra

        CONSTRAINT PK_DetallesPedido           PRIMARY KEY (PedidoId, ProductoId),
        CONSTRAINT FK_DetallesPedido_Pedidos   FOREIGN KEY (PedidoId)   REFERENCES dbo.Pedidos (Id) ON DELETE CASCADE,
        CONSTRAINT FK_DetallesPedido_Productos FOREIGN KEY (ProductoId) REFERENCES dbo.Productos (Id),
        CONSTRAINT CK_DetallesPedido_Cantidad  CHECK (Cantidad > 0),
        CONSTRAINT CK_DetallesPedido_Precio    CHECK (PrecioUnitario >= 0)
    );
END
GO

/* =====================================================================
   3. Datos de prueba (coinciden con los datos simulados del MVC)
   ===================================================================== */

-- Animes
INSERT INTO dbo.Animes (Nombre)
SELECT v.Nombre
FROM (VALUES (N'Cinderella Gray'),
             (N'Uma Musume: Pretty Derby'),
             (N'Uma Musume: Pretty Derby Season 2')) AS v (Nombre)
WHERE NOT EXISTS (SELECT 1 FROM dbo.Animes a WHERE a.Nombre = v.Nombre);
GO

-- Generaciones
INSERT INTO dbo.Generaciones (Nombre)
SELECT v.Nombre
FROM (VALUES (N'Era Oguri'),
             (N'Golden Week'),
             (N'Generación Teio'),
             (N'Team Spica')) AS v (Nombre)
WHERE NOT EXISTS (SELECT 1 FROM dbo.Generaciones g WHERE g.Nombre = v.Nombre);
GO

-- Productos (las FK se resuelven por nombre para no depender de los Id)
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
JOIN dbo.Generaciones g ON g.Nombre = v.Generacion
WHERE NOT EXISTS (SELECT 1 FROM dbo.Productos p WHERE p.Nombre = v.Nombre);
GO

-- Usuario de prueba: trainer / cuties123
-- SHA2_256 en hexadecimal SOLO para pruebas. En la app usa PasswordHasher<Usuario>
-- (o BCrypt/Argon2), que agrega sal e iteraciones, y reemplaza este valor.
IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE NombreUsuario = N'trainer')
    INSERT INTO dbo.Usuarios (NombreUsuario, Correo, ContrasenaHash)
    VALUES (N'trainer', N'trainer@tracen.com',
            CONVERT(NVARCHAR(256), HASHBYTES('SHA2_256', N'cuties123'), 2));
GO

-- Pedidos de ejemplo del historial (envío fijo de $99)
IF NOT EXISTS (SELECT 1 FROM dbo.Pedidos)
BEGIN
    DECLARE @UsuarioId INT = (SELECT Id FROM dbo.Usuarios WHERE NombreUsuario = N'trainer');
    DECLARE @PedidoId  INT;

    -- Pedido 1: 1 x Special Week (449 + 99)
    INSERT INTO dbo.Pedidos (UsuarioId, FechaPedido, Total, Estado)
    VALUES (@UsuarioId, '2026-09-14', 548.00, N'Entregado');
    SET @PedidoId = SCOPE_IDENTITY();

    INSERT INTO dbo.DetallesPedido (PedidoId, ProductoId, Cantidad, PrecioUnitario)
    SELECT @PedidoId, Id, 1, Precio FROM dbo.Productos WHERE Nombre = N'Special Week';

    -- Pedido 2: 2 x Oguri Cap (998 + 99)
    INSERT INTO dbo.Pedidos (UsuarioId, FechaPedido, Total, Estado)
    VALUES (@UsuarioId, '2026-10-02', 1097.00, N'En camino');
    SET @PedidoId = SCOPE_IDENTITY();

    INSERT INTO dbo.DetallesPedido (PedidoId, ProductoId, Cantidad, PrecioUnitario)
    SELECT @PedidoId, Id, 2, Precio FROM dbo.Productos WHERE Nombre = N'Oguri Cap';
END
GO

/* =====================================================================
   4. Verificación rápida
   ===================================================================== */
SELECT p.Id, p.Nombre, p.Precio, p.Stock, a.Nombre AS Anime, g.Nombre AS Generacion
FROM dbo.Productos p
JOIN dbo.Animes       a ON a.Id = p.AnimeId
JOIN dbo.Generaciones g ON g.Id = p.GeneracionId
ORDER BY p.Id;

SELECT u.NombreUsuario, pe.Id AS PedidoId, pe.FechaPedido, pe.Estado, pr.Nombre AS Producto,
       d.Cantidad, d.PrecioUnitario, pe.Total
FROM dbo.Pedidos pe
JOIN dbo.Usuarios       u  ON u.Id = pe.UsuarioId
JOIN dbo.DetallesPedido d  ON d.PedidoId = pe.Id
JOIN dbo.Productos      pr ON pr.Id = d.ProductoId
ORDER BY pe.FechaPedido;
GO
