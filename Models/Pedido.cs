using System;
using System.Collections.Generic;

namespace Umaluches.Models;

public partial class Pedido
{
    public int Id { get; set; }

    public int UsuarioId { get; set; }

    public DateTime FechaPedido { get; set; }

    public decimal Total { get; set; }

    public string Estado { get; set; } = null!;

    public virtual ICollection<DetallesPedido> DetallesPedidos { get; set; } = new List<DetallesPedido>();

    public virtual Usuario Usuario { get; set; } = null!;
}
