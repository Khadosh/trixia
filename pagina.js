// La página del estudio (#388, la dirección A del #379): la barra se oscurece
// al bajar y marca la sección en la que estás; en «Cómo funciona», el paso que
// llega al medio de la pantalla cambia el video, cruzándolo con el anterior;
// los videos y sus fotos bajan recién cuando se acercan; el menú del celular;
// y el formulario manda el pedido de demo sin salir de la página.
(function () {
  const barra = document.getElementById("barra");
  const menu = document.getElementById("menu");
  const abrir = document.querySelector(".abrir-menu");

  abrir.addEventListener("click", () => {
    const abierto = menu.classList.toggle("abierto");
    abrir.setAttribute("aria-expanded", abierto);
  });
  menu.querySelectorAll("a").forEach((a) => a.addEventListener("click", () => {
    menu.classList.remove("abierto");
    abrir.setAttribute("aria-expanded", false);
  }));

  // La sección en la que estás: la última que ya cruzó una línea a un tercio
  // de la pantalla. Las que no están en el menú (las salas) marcan la de antes;
  // el héroe y el formulario no marcan ninguna.
  const enlaces = [...menu.querySelectorAll("a")];
  const secciones = [...document.querySelectorAll("main > section")];
  const pegado = document.querySelector(".pegado");
  const ctaHeroe = document.querySelector(".heroe .boton");
  const pedi = document.getElementById("pedi");
  let marcada = null;
  function alBajar() {
    barra.classList.toggle("con-fondo", window.scrollY > 40);
    const linea = window.innerHeight / 3;
    let cual = null;
    for (const s of secciones) {
      if (s.getBoundingClientRect().top > linea) break;
      if (s.id === "inicio" || s.id === "pedi") cual = null;
      else if (enlaces.some((a) => a.hash === "#" + s.id)) cual = s.id;
    }
    if (cual !== marcada) {
      marcada = cual;
      enlaces.forEach((a) => a.classList.toggle("aqui", a.hash === "#" + cual));
    }
    // En el celular, el botón de la demo queda abajo cuando el del héroe ya
    // pasó (y se esconde al llegar al formulario).
    const pasado = ctaHeroe.getBoundingClientRect().bottom < 64;
    const enForm = pedi.getBoundingClientRect().top < window.innerHeight;
    pegado.classList.toggle("visible", pasado && !enForm);
  }
  window.addEventListener("scroll", alBajar, { passive: true });
  window.addEventListener("resize", alBajar);
  alBajar();

  // Las fotos de los videos bajan cuando se acercan; los videos se mueven
  // cuando se ven, y se paran cuando no.
  const acercar = new IntersectionObserver((vistas) => {
    vistas.forEach((v) => {
      if (!v.isIntersecting) return;
      const video = v.target;
      if (video.dataset.poster) video.poster = video.dataset.poster;
      acercar.unobserve(video);
    });
  }, { rootMargin: "100% 0px" });
  const mover = new IntersectionObserver((vistas) => {
    vistas.forEach((v) => (v.isIntersecting ? v.target.play().catch(() => {}) : v.target.pause()));
  }, { threshold: 0.3 });
  document.querySelectorAll("video[data-poster]").forEach((v) => acercar.observe(v));
  document.querySelectorAll(".sala video, .panorama video").forEach((v) => mover.observe(v));

  // El recorrido: dos videos encimados. El que sigue se carga atrás y recién
  // cuando tiene su primer cuadro se funde encima del que está: nunca pasa por
  // negro, aunque tarde en bajar.
  const marco = document.querySelector(".pantalla-marco");
  const [va, vb] = marco.querySelectorAll("video");
  let delante = va;
  let detras = vb;
  const pasos = [...document.querySelectorAll(".paso")];
  let actual = pasos[0];
  let pedido = 0;
  let enPantalla = false;
  const archivo = (paso) => `video/${paso.dataset.video}.mp4`;
  function activar(paso) {
    if (paso === actual) return;
    actual.classList.remove("activo");
    paso.classList.add("activo");
    actual = paso;
    const este = ++pedido;
    if (delante.dataset.src === archivo(paso)) return;
    detras.poster = `foto/${paso.dataset.video}.jpg`;
    detras.dataset.src = archivo(paso);
    detras.src = archivo(paso);
    detras.preload = "auto";
    const fundir = () => {
      if (este !== pedido) return; // ya pidieron otro paso
      // El nuevo se funde encima; el viejo queda entero debajo hasta que
      // el nuevo terminó de entrar.
      const viejo = delante;
      viejo.classList.add("saliendo");
      viejo.classList.remove("delante");
      detras.classList.add("delante");
      [delante, detras] = [detras, delante];
      if (enPantalla) delante.play().catch(() => {});
      setTimeout(() => {
        viejo.classList.remove("saliendo");
        if (viejo !== delante) viejo.pause();
      }, 400);
    };
    if (detras.readyState >= 2) fundir();
    else detras.addEventListener("loadeddata", fundir, { once: true });
  }
  const verPaso = new IntersectionObserver((vistas) => {
    vistas.forEach((v) => v.isIntersecting && activar(v.target));
  }, { rootMargin: "-50% 0px -50% 0px" });
  pasos.forEach((p) => {
    verPaso.observe(p);
    p.addEventListener("click", () => activar(p));
  });
  // El primero baja cuando el recorrido se acerca, y se mueve mientras se ve.
  new IntersectionObserver((vistas) => {
    vistas.forEach((v) => {
      enPantalla = v.isIntersecting;
      if (enPantalla && !delante.src) {
        delante.src = delante.dataset.src;
        delante.preload = "auto";
      }
      if (enPantalla) delante.play().catch(() => {});
      else delante.pause();
    });
  }, { rootMargin: "20% 0px" }).observe(marco);

  // Las personitas, a escala entera (4× en escritorio, 3× en el celular), sin suavizar.
  const escalar = () => document.querySelectorAll(".retrato img").forEach((img) => {
    const e = window.innerWidth < 720 ? 3 : 4;
    img.style.width = img.naturalWidth * e + "px";
    img.style.height = img.naturalHeight * e + "px";
  });
  document.querySelectorAll(".retrato img").forEach((img) => (img.complete ? escalar() : img.addEventListener("load", escalar)));
  window.addEventListener("resize", escalar);

  // La ficha del héroe avanza con el rodaje: cada plano es un paso del pedido.
  const estados = [...document.querySelectorAll(".ficha-estados li")];
  document.addEventListener("plano", (ev) => {
    const n = ev.detail;
    estados.forEach((li, i) => {
      li.classList.toggle("hecho", i < n || n === estados.length - 1);
      li.classList.toggle("ahora", i === n && n < estados.length - 1);
    });
  });

  // El formulario: manda el pedido al servicio y contesta ahí mismo. Sin
  // destino (la página de prueba), lo dice y no manda nada.
  const formulario = document.getElementById("formulario");
  const boton = formulario.querySelector("button");
  const gracias = formulario.querySelector(".gracias");
  const error = formulario.querySelector(".error");
  formulario.addEventListener("submit", async (e) => {
    e.preventDefault();
    error.hidden = true;
    if (!formulario.action || !formulario.getAttribute("action")) {
      error.hidden = false;
      return;
    }
    const texto = boton.textContent;
    boton.disabled = true;
    boton.textContent = "…";
    try {
      const r = await fetch(formulario.action, { method: "POST", body: new FormData(formulario), headers: { Accept: "application/json" } });
      if (!r.ok) throw new Error(r.status);
      formulario.querySelectorAll("label").forEach((l) => (l.hidden = true));
      boton.hidden = true;
      gracias.hidden = false;
    } catch {
      boton.disabled = false;
      boton.textContent = texto;
      error.hidden = false;
    }
  });
})();
