const miAudio = document.getElementById('musica-fondo');

const eventosInteraccion = ['click', 'keydown', 'mousemove', 'scroll', 'touchstart'];

function activarMusica() {
    miAudio.play()
        .then(() => {
            console.log("Música iniciada por interacción del usuario.");

            // Removemos los event listeners para que no intente reproducir cada vez que te muevas
            eventosInteraccion.forEach(evento => {
                window.removeEventListener(evento, activarMusica);
            });
        })
        .catch(error => {
            console.log("Esperando una interacción más directa para reproducir:", error);
        });
}

// Solo activamos la música si el <audio> existe en la página (está en _Layout.cshtml)
if (miAudio) {
    // Ajustamos el volumen al 20% (puedes cambiar este valor entre 0.0 y 1.0)
    miAudio.volume = 0.2;

    eventosInteraccion.forEach(evento => {
        window.addEventListener(evento, activarMusica, { passive: true });
    });
}

// Botón flotante para silenciar/reanudar; la preferencia se recuerda entre páginas
const botonMusica = document.getElementById('boton-musica');

function pintarBotonMusica() {
    const texto = miAudio.muted ? 'Activar música' : 'Silenciar música';
    botonMusica.innerHTML = miAudio.muted ? '&#128263;' : '&#128266;';
    botonMusica.setAttribute('aria-label', texto);
    botonMusica.title = texto;
}

if (miAudio && botonMusica) {
    try {
        miAudio.muted = localStorage.getItem('musicaSilenciada') === 'si';
    } catch { /* Sin localStorage la música inicia con sonido */ }
    pintarBotonMusica();

    botonMusica.addEventListener('click', () => {
        miAudio.muted = !miAudio.muted;
        try {
            localStorage.setItem('musicaSilenciada', miAudio.muted ? 'si' : 'no');
        } catch { /* Se ignora si el navegador bloquea localStorage */ }
        pintarBotonMusica();
    });
}
