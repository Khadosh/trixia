// Los títulos con la letra del juego (nube8, la del patio y el estudio).
// Cada elemento con data-pixel se dibuja en un canvas a una escala entera
// (data-escala, 3 por omisión), del color de su CSS, sin suavizar. El texto
// queda para los lectores de pantalla en aria-label.
(function () {
  const hoja = new Image();
  hoja.src = "img/nube8.png";

  function medir(texto) {
    let ancho = 0;
    for (const c of texto) {
      const g = NUBE8[c.codePointAt(0)] || NUBE8[63];
      ancho += g[6];
    }
    return ancho;
  }

  function dibujar(el) {
    const texto = el.dataset.texto;
    const escala = parseInt(getComputedStyle(el).getPropertyValue("--escala")) || 3;
    const alto = 12;
    const ancho = medir(texto);
    const c = document.createElement("canvas");
    c.width = ancho;
    c.height = alto;
    c.style.width = ancho * escala + "px";
    c.style.height = alto * escala + "px";
    const x = c.getContext("2d");
    x.imageSmoothingEnabled = false;
    let cx = 0;
    for (const ch of texto) {
      const g = NUBE8[ch.codePointAt(0)] || NUBE8[63];
      if (g[2] > 0) x.drawImage(hoja, g[0], g[1], g[2], g[3], cx + g[4], g[5], g[2], g[3]);
      cx += g[6];
    }
    x.globalCompositeOperation = "source-in";
    x.fillStyle = getComputedStyle(el).color;
    x.fillRect(0, 0, ancho, alto);
    el.replaceChildren(c);
  }

  function todos() {
    document.querySelectorAll("[data-pixel]").forEach((el) => {
      if (!el.dataset.texto) {
        el.dataset.texto = el.textContent.trim();
        el.setAttribute("aria-label", el.dataset.texto);
      }
      dibujar(el);
    });
  }

  hoja.onload = todos;
  window.addEventListener("resize", () => hoja.complete && todos());
})();
