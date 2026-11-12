using System.Globalization;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Localization;
using Umaluches.Models;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllersWithViews();

// DbContext de EF Core: los controladores lo reciben por constructor
builder.Services.AddDbContext<CutiesDBContext>(opciones =>
    opciones.UseSqlServer(builder.Configuration.GetConnectionString("CutiesDBConnection")));

// Autenticación con cookies: el login de AccountController guarda aquí la sesión.
// Si un usuario sin sesión entra a una acción con [Authorize], se le manda a LoginPath.
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(opciones =>
    {
        opciones.LoginPath = "/Account/Login";
        opciones.LogoutPath = "/Account/Logout";
        opciones.ExpireTimeSpan = TimeSpan.FromHours(8);
    });

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

// Cultura es-MX para que los precios se muestren como $449.00 y los decimales usen punto
var culturaMx = new CultureInfo("es-MX");
app.UseRequestLocalization(new RequestLocalizationOptions
{
    DefaultRequestCulture = new RequestCulture(culturaMx),
    SupportedCultures = [culturaMx],
    SupportedUICultures = [culturaMx]
});

app.UseHttpsRedirection();
app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();

app.MapStaticAssets();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}")
    .WithStaticAssets();


app.Run();
