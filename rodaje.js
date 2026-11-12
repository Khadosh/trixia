// El rodaje del héroe (#379, #388): un pedido de punta a punta en primeros
// planos. Cada elemento [data-rodaje] lleva dos <video> encimados y la lista de
// planos en el atributo ({ video, dura en ms, desde en segundos }, la arma
// generar.mjs desde pagina.json); el script pasa por los planos de a uno, con
// un fundido, y avisa a la página con el evento «plano» (detail: el número)
// para que la tarjeta del pedido avance a la par. Usa los mismos cortes de
// video/: no hay un video aparte del rodaje.
(function () {
  document.querySelectorAll("[data-rodaje]").forEach((caja) => {
    const PLANOS = JSON.parse(caja.dataset.rodaje);
    const [a, b] = caja.querySelectorAll("video");
    let delante = a;
    let detras = b;
    let i = 0;
    const cargar = (v, p) => {
      v.src = `video/${p.video}.mp4`;
      v.poster = `foto/${p.video}.jpg`;
      v.dataset.desde = p.desde || 0;
      v.addEventListener("loadedmetadata", () => (v.currentTime = p.desde || 0), { once: true });
    };
    const mostrar = () => {
      const p = PLANOS[i];
      detras.classList.add("delante");
      delante.classList.remove("delante");
      if (detras.readyState >= 1) detras.currentTime = +detras.dataset.desde;
      detras.play().catch(() => {});
      [delante, detras] = [detras, delante];
      caja.dispatchEvent(new CustomEvent("plano", { detail: i, bubbles: true }));
      i = (i + 1) % PLANOS.length;
      cargar(detras, PLANOS[i]); // el que sigue, cargándose atrás
      setTimeout(mostrar, p.dura);
    };
    cargar(detras, PLANOS[0]);
    setTimeout(mostrar, 0); // después de que la página escuche «plano»
  });
})();
