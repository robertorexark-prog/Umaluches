using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore;

namespace Umaluches.Models;

public partial class CutiesDBContext : DbContext
{
    public CutiesDBContext()
    {
    }

    public CutiesDBContext(DbContextOptions<CutiesDBContext> options)
        : base(options)
    {
    }

    public virtual DbSet<Anime> Animes { get; set; }

    public virtual DbSet<DetallesPedido> DetallesPedidos { get; set; }

    public virtual DbSet<Generacione> Generaciones { get; set; }

    public virtual DbSet<Pedido> Pedidos { get; set; }

    public virtual DbSet<Producto> Productos { get; set; }

    public virtual DbSet<Usuario> Usuarios { get; set; }

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        => optionsBuilder.UseSqlServer("Name=ConnectionStrings:CutiesDBConnection");

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Anime>(entity =>
        {
            entity.HasIndex(e => e.Nombre, "UQ_Animes_Nombre").IsUnique();

            entity.Property(e => e.Nombre).HasMaxLength(100);
        });

        modelBuilder.Entity<DetallesPedido>(entity =>
        {
            entity.HasKey(e => new { e.PedidoId, e.ProductoId });

            entity.ToTable("DetallesPedido");

            entity.Property(e => e.PrecioUnitario).HasColumnType("decimal(10, 2)");

            entity.HasOne(d => d.Pedido).WithMany(p => p.DetallesPedidos)
                .HasForeignKey(d => d.PedidoId)
                .HasConstraintName("FK_DetallesPedido_Pedidos");

            entity.HasOne(d => d.Producto).WithMany(p => p.DetallesPedidos)
                .HasForeignKey(d => d.ProductoId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DetallesPedido_Productos");
        });

        modelBuilder.Entity<Generacione>(entity =>
        {
            entity.HasIndex(e => e.Nombre, "UQ_Generaciones_Nombre").IsUnique();

            entity.Property(e => e.Nombre).HasMaxLength(100);
        });

        modelBuilder.Entity<Pedido>(entity =>
        {
            entity.HasIndex(e => e.UsuarioId, "IX_Pedidos_UsuarioId");

            entity.Property(e => e.Estado)
                .HasMaxLength(20)
                .HasDefaultValue("Pendiente", "DF_Pedidos_Estado");
            entity.Property(e => e.FechaPedido)
                .HasPrecision(0)
                .HasDefaultValueSql("(getdate())", "DF_Pedidos_FechaPedido");
            entity.Property(e => e.Total).HasColumnType("decimal(10, 2)");

            entity.HasOne(d => d.Usuario).WithMany(p => p.Pedidos)
                .HasForeignKey(d => d.UsuarioId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Pedidos_Usuarios");
        });

        modelBuilder.Entity<Producto>(entity =>
        {
            entity.HasIndex(e => e.AnimeId, "IX_Productos_AnimeId");

            entity.HasIndex(e => e.GeneracionId, "IX_Productos_GeneracionId");

            entity.Property(e => e.Descripcion).HasMaxLength(500);
            entity.Property(e => e.ImagenUrl).HasMaxLength(300);
            entity.Property(e => e.Nombre).HasMaxLength(100);
            entity.Property(e => e.Precio).HasColumnType("decimal(10, 2)");

            entity.HasOne(d => d.Anime).WithMany(p => p.Productos)
                .HasForeignKey(d => d.AnimeId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Productos_Animes");

            entity.HasOne(d => d.Generacion).WithMany(p => p.Productos)
                .HasForeignKey(d => d.GeneracionId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Productos_Generaciones");
        });

        modelBuilder.Entity<Usuario>(entity =>
        {
            entity.HasIndex(e => e.Correo, "UQ_Usuarios_Correo").IsUnique();

            entity.HasIndex(e => e.NombreUsuario, "UQ_Usuarios_NombreUsuario").IsUnique();

            entity.Property(e => e.ContrasenaHash).HasMaxLength(256);
            entity.Property(e => e.Correo).HasMaxLength(150);
            entity.Property(e => e.FechaCreacion)
                .HasPrecision(0)
                .HasDefaultValueSql("(getdate())", "DF_Usuarios_FechaCreacion");
            entity.Property(e => e.NombreUsuario).HasMaxLength(50);
        });

        OnModelCreatingPartial(modelBuilder);
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}
