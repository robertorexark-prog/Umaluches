using System;
using System.Collections.Generic;

namespace Umaluches.Models;

public partial class Producto
{
    public int Id { get; set; }

    public string Nombre { get; set; } = null!;

    public decimal Precio { get; set; }

    public string? Descripcion { get; set; }

    public string? ImagenUrl { get; set; }

    public int Stock { get; set; }

    public int AnimeId { get; set; }

    public int GeneracionId { get; set; }

    public virtual Anime Anime { get; set; } = null!;

    public virtual ICollection<DetallesPedido> DetallesPedidos { get; set; } = new List<DetallesPedido>();

    public virtual Generacione Generacion { get; set; } = null!;
}
