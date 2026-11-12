using System;
using System.Collections.Generic;

namespace Umaluches.Models;

public partial class Anime
{
    public int Id { get; set; }

    public string Nombre { get; set; } = null!;

    public virtual ICollection<Producto> Productos { get; set; } = new List<Producto>();
}
