// El movimiento de la página del estudio (#802): la barra y el menú, el
// contador del héroe que baja a cero, la lista que se tilda, el pedido que
// recorre sus paradas, lo que se enciende al verse y el formulario, que manda
// el pedido de demo sin salir de la página. Ningún video ni foto baja antes
// de acercarse, salvo el del héroe.
(function () {
  const quieto = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const $ = (s, d = document) => d.querySelector(s);
  const $$ = (s, d = document) => [...d.querySelectorAll(s)];

  // Las personitas, a escala entera: el alto de cada dibujo va a su CSS.
  $$(".fila-gente img, .retrato img").forEach((img) => {
    const medir = () => img.style.setProperty("--alto", img.naturalHeight);
    img.complete && img.naturalHeight ? medir() : img.addEventListener("load", medir);
  });

  // La barra y el menú del celular.
  const barra = $("#barra"), menu = $("#menu"), abrir = $(".abrir-menu");
  abrir.addEventListener("click", () => abrir.setAttribute("aria-expanded", menu.classList.toggle("abierto")));
  const enlaces = $$("a", menu);
  enlaces.forEach((a) => a.addEventListener("click", () => {
    menu.classList.remove("abierto");
    abrir.setAttribute("aria-expanded", false);
  }));
  // La sección en la que estás: la última del menú que cruzó una línea a un
  // tercio de la pantalla. El héroe, la lista y el cierre no marcan ninguna.
  const secciones = $$("main > section");
  const pegado = $(".pegado"), primero = $(".hola .boton"), pedi = $("#pedi");
  function alBajar() {
    barra.classList.toggle("con-fondo", scrollY > 40);
    let cual = null;
    for (const s of secciones) {
      if (s.getBoundingClientRect().top > innerHeight / 3) break;
      if (enlaces.some((a) => a.hash === "#" + s.id)) cual = s.id;
      else if (["inicio", "lista", "pedi"].includes(s.id)) cual = null;
    }
    enlaces.forEach((a) => a.classList.toggle("aqui", a.hash === "#" + cual));
    // En el celular, el botón de la demo queda abajo cuando el del héroe ya
    // pasó, y se esconde al llegar al formulario.
    pegado.classList.toggle("visible", primero.getBoundingClientRect().bottom < 64 && pedi.getBoundingClientRect().top > innerHeight);
  }
  addEventListener("scroll", alBajar, { passive: true });
  addEventListener("resize", alBajar);
  alBajar();

  // Las fotos bajan cuando se acercan; los videos, cuando se ven, y se paran
  // cuando no. El del héroe baja al abrir.
  const cerca = new IntersectionObserver((vs) => vs.forEach((v) => {
    if (!v.isIntersecting) return;
    const e = v.target;
    if (e.dataset.poster) e.poster = e.dataset.poster;
    if (e.dataset.fondo) e.style.backgroundImage = 'url("' + e.dataset.fondo + '")';
    cerca.unobserve(e);
  }), { rootMargin: "100% 0px" });
  const mover = new IntersectionObserver((vs) => vs.forEach((v) => {
    const video = v.target;
    if (!v.isIntersecting) return video.pause();
    if (!video.getAttribute("src")) video.src = video.dataset.src;
    video.play().catch(() => {});
  }), { threshold: 0.25 });
  $$("video[data-poster], [data-fondo]").forEach((e) => cerca.observe(e));
  $$("video[data-src]").forEach((v) => mover.observe(v));

  // Lo que se enciende al verse: el resaltador, los casilleros, los días, la barrita.
  const ver = new IntersectionObserver((vs) => vs.forEach((v) => {
    if (!v.isIntersecting) return;
    v.target.classList.add("visto");
    ver.unobserve(v.target);
  }), { threshold: 0.35 });
  $$(".lista-texto, .noche-dentro, .panorama-texto, .cierre-texto").forEach((e) => ver.observe(e));

  // El contador del héroe: de tantas personas como hay en la fila, a cero; y
  // recién ahí aparecen los cartelitos. La página llega escrita en cero.
  const cuenta = $("#cuenta"), fila = $(".fila");
  const escribir = (n) => {
    cuenta.dataset.texto = n + " " + cuenta.dataset.que;
    dispatchEvent(new Event("resize")); // pixel.js lo redibuja
  };
  if (quieto) fila.classList.add("contada");
  else {
    let n = Number(cuenta.dataset.desde);
    escribir(n);
    const bajar = () => {
      escribir(--n);
      if (n > 0) setTimeout(bajar, 170);
      else fila.classList.add("contada");
    };
    setTimeout(bajar, 1100);
  }

  // La lista se tilda sola cuando se ve; el último renglón queda para vos.
  const pendientes = $("#pendientes");
  new IntersectionObserver((vs, o) => vs.forEach((v) => {
    if (!v.isIntersecting) return;
    o.disconnect();
    $$("li:not(.tuyo)", pendientes).forEach((li, i) => setTimeout(() => li.classList.add("hecho"), quieto ? 0 : 500 + i * 420));
  }), { threshold: 0.6 }).observe(pendientes);

  // El pedido: avanza solo mientras se ve; tocar una parada salta ahí y la
  // deja más tiempo. Dos videos encimados: el que sigue se funde encima
  // recién cuando tiene su primer cuadro, así nunca pasa por negro.
  const via = $("#via"), paradas = $$("li", via), texto = $(".parada-texto");
  let [delante, detras] = $$(".ventana video");
  let ahora = -1, reloj = null, enVista = false;
  const seguir = (ms) => {
    clearTimeout(reloj);
    if (enVista && !quieto) reloj = setTimeout(() => ir((ahora + 1) % paradas.length), ms);
  };
  function ir(i, porToque) {
    if (i === ahora) return;
    ahora = i;
    const p = paradas[i].dataset;
    paradas.forEach((li, j) => {
      li.classList.toggle("pasado", j < i);
      li.classList.toggle("ahora", j === i);
    });
    via.style.setProperty("--hecho", i / (paradas.length - 1));
    $("#parada-area").textContent = p.area;
    $("#parada-nombre").textContent = p.nombre;
    $("#parada-verbo").textContent = p.verbo;
    $("#parada-cuenta").textContent = p.cuenta;
    texto.classList.remove("cambia");
    void texto.offsetWidth;
    texto.classList.add("cambia");
    const entra = detras;
    entra.poster = "foto/" + p.video + ".jpg";
    entra.src = "video/" + p.video + ".mp4";
    entra.preload = "auto";
    const fundir = () => {
      if (entra !== detras) return; // ya pidieron otra parada
      detras.classList.add("delante");
      delante.classList.remove("delante");
      [delante, detras] = [detras, delante];
      if (enVista) delante.play().catch(() => {});
    };
    entra.readyState >= 2 ? fundir() : entra.addEventListener("loadeddata", fundir, { once: true });
    seguir(porToque ? 9000 : 4600);
  }
  paradas.forEach((li, i) => $("button", li).addEventListener("click", () => ir(i, true)));
  new IntersectionObserver((vs) => vs.forEach((v) => {
    enVista = v.isIntersecting;
    clearTimeout(reloj);
    if (!enVista) return delante.pause();
    if (ahora < 0) return ir(0);
    delante.play().catch(() => {});
    seguir(4600);
  }), { threshold: 0.3 }).observe($(".ventana"));

  // El formulario: manda el pedido al servicio y contesta ahí mismo. Sin
  // destino (la página de prueba), lo dice y no manda nada.
  const formulario = $("#formulario");
  const boton = $("button", formulario), gracias = $(".gracias", formulario), error = $(".error", formulario);
  formulario.addEventListener("submit", async (e) => {
    e.preventDefault();
    error.hidden = true;
    if (!formulario.getAttribute("action")) {
      error.hidden = false;
      return;
    }
    const antes = boton.textContent;
    boton.disabled = true;
    boton.textContent = "…";
    try {
      const r = await fetch(formulario.action, { method: "POST", body: new FormData(formulario), headers: { Accept: "application/json" } });
      if (!r.ok) throw new Error(r.status);
      $$("label", formulario).forEach((l) => (l.hidden = true));
      boton.hidden = true;
      gracias.hidden = false;
    } catch {
      boton.disabled = false;
      boton.textContent = antes;
      error.hidden = false;
    }
  });
})();
