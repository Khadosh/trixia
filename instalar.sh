#!/usr/bin/env bash
set -uo pipefail

PGS_REPO="${PGS_REPO:-https://github.com/Khadosh/pixel-gaming-studio.git}"
PGS_PAQUETE="${PGS_PAQUETE:-https://github.com/Khadosh/pixel-gaming-studio/releases/download/motor/pgs-motor.tar.gz}"
PGS_DONDE="${PGS_DONDE:-$HOME/pgs}"
PRUEBA="${PGS_PRUEBA:-$HOME/pgs-prueba}"
ESTUDIO_DONDE="${ESTUDIO_DONDE:-$HOME/mi-estudio}"
NODE_MINIMO=20

tope() { perl -e 'alarm shift; exec @ARGV' "$@"; }
hay() { command -v "$1" >/dev/null 2>&1; }
paso() { printf '\n%s\n' "$1"; }
bien() { printf '  ✓ %s\n' "$1"; }
aviso() { printf '  · %s\n      → %s\n' "$1" "$2"; }
corta() {
	printf '  ✗ %s\n      → %s\n\n' "$1" "$2" >&2
	echo "No terminó. Arreglá eso y corré de nuevo: bash instalar.sh ${modulo}" >&2
	exit 1
}

lista() {
	cat <<'EOF'
Los módulos del estudio (cada uno incluye al anterior):

  taller    PGS solo, conectado a tu Claude. Le pedís un dibujo, una
            tipografía o un sonido y lo hace en tu carpeta.
            Pide: Node 20 o más nuevo, y Claude (Claude Code o la app).
            Lo que falte lo instala solo (en macOS, sin contraseña).
            bash instalar.sh taller

  mesa      El taller y una carpeta de proyecto con el método del estudio,
            para que un agente construya con las reglas de la casa.
            Pide además git y python3 (en la Mac: xcode-select --install).
            bash instalar.sh mesa ~/mi-proyecto

  oficina   El estudio entero: el juego, el puente, el tablero y los
            departamentos. Pide además gh, Godot 4.6, una cuenta de GitHub y que
            te inviten al repo del estudio (te pasan su nombre, dueño/repo).
            bash instalar.sh oficina <dueño/repo>

Sueltos, que se suman a la oficina cuando hacen falta: la memoria
(scripts/memoria_instalar.sh), video, Codex, las voces y NOCTIS.
EOF
}

NODE_DIST="${NODE_DIST:-https://nodejs.org/dist/latest-v22.x}"
GH_VERSION="${GH_VERSION:-2.103.3}"
GH_DIST="${GH_DIST:-https://github.com/cli/cli/releases/download/v${GH_VERSION}}"
GODOT_VERSION="${GODOT_VERSION:-4.6.2-stable}"
GODOT_DIST="${GODOT_DIST:-https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}}"
LOCAL="$HOME/.local"

en_mac() { [ "$(uname -s)" = Darwin ]; }
arq() { case "$(uname -m)" in arm64 | aarch64) echo arm64 ;; *) echo x64 ;; esac; }
bajada() {
	local linea real
	linea="$(tope 120 curl -fsSL "$1/$2" 2>/dev/null | grep -E "[ *]$3\$" | head -1)"
	[ -n "$linea" ] || return 1
	tope 1800 curl -fsSL -o "$5" "$1/${linea##* }" 2>/dev/null || return 1
	real="$(shasum -a "$4" "$5")"
	[ "${real%% *}" = "${linea%% *}" ]
}
temporal() { mktemp -d "${TMPDIR:-/tmp}/instalar.XXXXXX"; }

node_ok() {
	local v
	hay node || return 1
	[ "${pgs_repo:-0}" = 1 ] && ! hay npm && return 1
	v="$(node --version 2>/dev/null)"
	v="${v#v}"
	[ "${v%%.*}" -ge "$NODE_MINIMO" ] 2>/dev/null
}
poner_node() {
	local t b
	t="$(temporal)" || return 1
	bajada "$NODE_DIST" SHASUMS256.txt "node-v[0-9.]+-darwin-$(arq)\.tar\.gz" 256 "$t/node.tgz" \
		&& rm -rf "$LOCAL/node" && mkdir -p "$LOCAL/node" "$LOCAL/bin" \
		&& tar -xzf "$t/node.tgz" -C "$LOCAL/node" --strip-components 1 || { rm -rf "$t"; return 1; }
	rm -rf "$t"
	for b in node npm npx; do ln -sf "../node/bin/$b" "$LOCAL/bin/$b"; done
}
gh_ok() { hay gh; }
bajadores_ok() { hay curl && hay tar; }
git_ok() { git --version >/dev/null 2>&1; }
python_ok() { python3 --version >/dev/null 2>&1; }
poner_gh() {
	local t a
	a="$(arq)"
	[ "$a" = x64 ] && a=amd64
	t="$(temporal)" || return 1
	bajada "$GH_DIST" "gh_${GH_VERSION}_checksums.txt" "gh_${GH_VERSION}_macOS_${a}\.zip" 256 "$t/gh.zip" \
		&& unzip -q "$t/gh.zip" -d "$t" && mkdir -p "$LOCAL/bin" \
		&& cp "$t/gh_${GH_VERSION}_macOS_${a}/bin/gh" "$LOCAL/bin/gh" || { rm -rf "$t"; return 1; }
	rm -rf "$t"
}
GODOT_MIO="$HOME/Applications/Godot.app/Contents/MacOS/Godot"
es_46() { [ -x "$1" ] || return 1; case "$(tope 20 "$1" --version 2>/dev/null)" in 4.6*) return 0 ;; *) return 1 ;; esac; }
godot_ok() {
	local b
	[ -n "${GODOT:-}" ] && { es_46 "$GODOT"; return; }
	for b in $(command -v godot godot4) ${ESTUDIO_GODOT_DONDE-/Applications/Godot.app/Contents/MacOS/Godot $GODOT_MIO $HOME/.local/bin/godot /usr/local/bin/godot /usr/bin/godot /opt/godot/godot}; do
		[ -x "$b" ] && { es_46 "$b"; return; }
	done
	return 1
}
poner_godot() {
	local t
	if ! es_46 "$GODOT_MIO"; then
		t="$(temporal)" || return 1
		bajada "$GODOT_DIST" SHA512-SUMS.txt "Godot_v${GODOT_VERSION}_macos\.universal\.zip" 512 "$t/godot.zip" \
			&& unzip -q "$t/godot.zip" -d "$t" && mkdir -p "$HOME/Applications" \
			&& rm -rf "$HOME/Applications/Godot.app" && mv "$t/Godot.app" "$HOME/Applications/" || { rm -rf "$t"; return 1; }
		rm -rf "$t"
	fi
	godot_ok && return 0
	export GODOT="$GODOT_MIO"
	grep -qsF "GODOT=\"$GODOT_MIO\"" "$HOME/.zshrc" || printf '\n%s\n' "export GODOT=\"$GODOT_MIO\"  # el Godot 4.6 del estudio (instalar.sh)" >>"$HOME/.zshrc"
}
al_path() {
	grep -qsF '.local/bin' "$HOME/.zshrc" || printf '\n%s\n' 'export PATH="$HOME/.local/bin:$PATH"  # el estudio (instalar.sh)' >>"$HOME/.zshrc"
}
conseguir() {
	if $2; then
		bien "$1"
		return 0
	fi
	if en_mac && [ -n "$3" ]; then
		echo "  … no está: bajando $1"
		if $3 && hash -r && $2; then
			al_path
			bien "$1 (lo instalé)"
			return 0
		fi
	fi
	printf '  ✗ %s\n      → %s\n' "$1" "$4"
	faltan=$((faltan + 1))
}

revisar() {
	local faltan=0
	paso "1. Lo que hace falta (lo que no está, lo instalo)"
	export PATH="$LOCAL/bin:$PATH"
	if en_mac && hay xcode-select && ! xcode-select -p >/dev/null 2>&1; then
		xcode-select --install >/dev/null 2>&1
		corta "faltan las herramientas de Apple (git y python3)" "Se abrió una ventana de Apple: tocá Instalar, esperá que termine (unos minutos) y corré de nuevo."
	fi
	[ "${pide_git:-0}" = 1 ] && conseguir git git_ok "" "En una Terminal corré: xcode-select --install  (en Linux: sudo apt install git)."
	conseguir "curl y tar (bajan PGS)" bajadores_ok "" "Vienen con macOS; en Linux: sudo apt install curl tar."
	conseguir "Node ${NODE_MINIMO} o más nuevo" node_ok poner_node "Bajá la versión LTS de https://nodejs.org, instalala y abrí una Terminal nueva."
	[ "${pide_python:-0}" = 1 ] && conseguir python3 python_ok "" "En una Terminal corré: xcode-select --install  (en Linux: sudo apt install python3)."
	conseguir perl "hay perl" "" "Viene con macOS y Linux: si falta, instalalo (brew install perl)."
	[ "${pide_oficina:-0}" = 1 ] && conseguir "gh, el programa de GitHub" gh_ok poner_gh "Bajá el instalador de https://cli.github.com, abrí una Terminal nueva y corré de nuevo."
	[ "${pide_oficina:-0}" = 1 ] && conseguir "Godot 4.6" godot_ok poner_godot "Bajala de https://godotengine.org/download y arrastrá Godot a Aplicaciones."
	[ "$faltan" -eq 0 ] && return 0
	if [ "$faltan" -eq 1 ]; then printf '\nFalta una cosa. Arreglala' >&2; else printf '\nFaltan %s cosas. Arreglalas' "$faltan" >&2; fi
	printf ' y corré de nuevo: bash instalar.sh %s\n' "$modulo" >&2
	exit 1
}

bajar() {
	paso "2. PGS, en ${PGS_DONDE}"
	if [ -d "$PGS_DONDE/.git" ] || [ "${pgs_repo:-0}" = 1 ]; then bajar_repo; else bajar_paquete; fi
}

bajar_paquete() {
	local nuevo="${PGS_DONDE}.bajando" viejo="${PGS_DONDE}.anterior" habia=0
	if [ -e "$PGS_DONDE" ] && [ ! -f "$PGS_DONDE/lib/cli.mjs" ] && [ -n "$(ls -A "$PGS_DONDE" 2>/dev/null)" ]; then
		corta "${PGS_DONDE} ya existe y no es PGS" "Movela o elegí otra carpeta: PGS_DONDE=~/otra-carpeta bash instalar.sh ${modulo}"
	fi
	[ ! -e "$PGS_DONDE" ] && [ -f "$viejo/bin/pgs-mcp" ] && mv "$viejo" "$PGS_DONDE"
	mkdir -p "$(dirname "$PGS_DONDE")" || corta "no pude crear $(dirname "$PGS_DONDE")" "Elegí otra carpeta: PGS_DONDE=~/otra-carpeta bash instalar.sh ${modulo}"
	rm -rf "$nuevo" "$viejo"
	mkdir -p "$nuevo"
	if ! tope 300 curl -fsSL "$PGS_PAQUETE" -o "$nuevo/pgs-motor.tar.gz" 2>/dev/null \
		|| ! tar -xzf "$nuevo/pgs-motor.tar.gz" -C "$nuevo" 2>/dev/null \
		|| [ ! -f "$nuevo/pgs-motor/bin/pgs-mcp" ]; then
		rm -rf "$nuevo"
		[ -f "$PGS_DONDE/bin/pgs-mcp" ] || corta "no pude bajar PGS" "¿Hay internet? Se baja de ${PGS_PAQUETE}"
		aviso "ya estaba, pero no lo pude poner al día" "Sigue con la versión que tenés. Si hay internet, probá más tarde."
		return
	fi
	if [ -f "$PGS_DONDE/VERSION" ] && cmp -s "$PGS_DONDE/VERSION" "$nuevo/pgs-motor/VERSION"; then
		rm -rf "$nuevo"
		bien "ya estaba, y al día"
		return
	fi
	[ -e "$PGS_DONDE" ] && habia=1
	if [ "$habia" = 1 ] && ! mv "$PGS_DONDE" "$viejo"; then
		rm -rf "$nuevo"
		corta "no pude cambiar PGS en ${PGS_DONDE}" "¿Está abierto en otro lado? Cerralo y corré de nuevo."
	fi
	if ! mv "$nuevo/pgs-motor" "$PGS_DONDE"; then
		[ "$habia" = 1 ] && mv "$viejo" "$PGS_DONDE"
		rm -rf "$nuevo"
		corta "no pude dejar PGS en ${PGS_DONDE}" "¿Está abierto en otro lado? Cerralo y corré de nuevo."
	fi
	rm -rf "$nuevo" "$viejo"
	if [ "$habia" = 1 ]; then bien "ya estaba: lo puse al día"; else bien "bajado ($(du -sh "$PGS_DONDE" 2>/dev/null | cut -f1 | tr -d ' '))"; fi
}

bajar_repo() {
	local antes="" despues=""
	[ ! -d "$PGS_DONDE/.git" ] && [ -f "$PGS_DONDE/lib/cli.mjs" ] && rm -rf "$PGS_DONDE"
	if [ -d "$PGS_DONDE/.git" ]; then
		antes="$(git -C "$PGS_DONDE" rev-parse HEAD 2>/dev/null)"
		if tope 300 git -C "$PGS_DONDE" pull --quiet --ff-only >/dev/null 2>&1; then
			despues="$(git -C "$PGS_DONDE" rev-parse HEAD 2>/dev/null)"
			if [ "$antes" = "$despues" ]; then bien "ya estaba, y al día"; else bien "ya estaba: lo puse al día"; fi
		else
			aviso "ya estaba, pero no lo pude poner al día" "Sigue con la versión que tenés. Si hay internet, probá más tarde."
		fi
	elif [ -e "$PGS_DONDE" ] && [ -n "$(ls -A "$PGS_DONDE" 2>/dev/null)" ]; then
		corta "${PGS_DONDE} ya existe y no es PGS" "Movela o elegí otra carpeta: PGS_DONDE=~/otra-carpeta bash instalar.sh ${modulo}"
	else
		mkdir -p "$(dirname "$PGS_DONDE")" || corta "no pude crear $(dirname "$PGS_DONDE")" "Elegí otra carpeta: PGS_DONDE=~/otra-carpeta bash instalar.sh ${modulo}"
		tope 600 git clone --quiet --depth 1 "$PGS_REPO" "$PGS_DONDE" 2>/dev/null \
			|| corta "no pude bajar PGS" "¿Hay internet? Se baja de ${PGS_REPO}"
		bien "bajado"
	fi
	[ -f "$PGS_DONDE/bin/pgs-mcp" ] || corta "lo que hay en ${PGS_DONDE} no trae bin/pgs-mcp" "Borrá esa carpeta y corré de nuevo."
	local ahora marca="$PGS_DONDE/.git/piezas-instaladas"
	ahora="$(git -C "$PGS_DONDE" rev-parse HEAD 2>/dev/null)"
	if [ -n "$ahora" ] && [ "$(cat "$marca" 2>/dev/null)" = "$ahora" ]; then
		bien "sus piezas"
	else
		echo "  … instalando sus piezas (un par de minutos la primera vez)"
		local solo_motor=""
		node -e 'process.exit(require(process.argv[1]).dependencies?.tsx ? 0 : 1)' "$PGS_DONDE/package.json" 2>/dev/null && solo_motor="--omit=dev"
		hay npm || corta "npm (viene con Node)" "Reinstalá Node desde https://nodejs.org: trae npm."
		if ! ( cd "$PGS_DONDE" && tope 1200 npm ci $solo_motor --no-audit --no-fund --loglevel=error >"$PGS_DONDE/.instalar.log" 2>&1 ); then
			tail -15 "$PGS_DONDE/.instalar.log" >&2
			corta "no pude instalar las piezas de PGS" "¿Hay internet? Lo de arriba es lo que dijo npm. A mano: (cd ${PGS_DONDE} && npm ci)"
		fi
		rm -f "$PGS_DONDE/.instalar.log"
		echo "$ahora" >"$marca"
		bien "sus piezas"
	fi
}

if ! declare -F bajar >/dev/null; then
	if [ -f "$(dirname "${BASH_SOURCE[0]}")/scripts/instalar_pgs.sh" ]; then
		. "$(dirname "${BASH_SOURCE[0]}")/scripts/instalar_pgs.sh"
	else
		bajar() { corta "este instalar.sh no trae cómo bajar PGS (ni la plantilla de la mesa)" "Bajalo entero de la página del estudio: docs/instalar/taller.md"; }
	fi
fi

probar() {
	local n
	paso "3. La prueba"
	mkdir -p "$PRUEBA" || corta "no pude crear ${PRUEBA}" "Elegí otra carpeta: PGS_PRUEBA=~/otra bash instalar.sh ${modulo}"
	cat >"$PRUEBA/dado.txt" <<'EOF'
id: dado
name: Dado de veinte
size: 15x15

1 = #1c1626 tinta
2 = #c8553d rojo
3 = #e8866a rojo_luz
4 = #8a3324 rojo_sombra
5 = #f4e3c1 numero

==
......111......
....1133311....
..11333333311..
.1332222222331.
.1222222222221.
.1225552555221.
.1222252525221.
.1225552525221.
.1225222525221.
.1225552555221.
.1222222222221.
.1442222222441.
..11444444411..
....1144411....
......111......
EOF
	rm -f "$PRUEBA/dado.png"
	( cd "$PRUEBA" && tope 120 "$PGS_DONDE/bin/pgs" from_ascii txt=dado.txt out=dado.pss.json >/dev/null 2>&1 \
		&& tope 120 "$PGS_DONDE/bin/pgs" render path=dado.pss.json out=dado.png scale=16 >/dev/null 2>&1 )
	[ -s "$PRUEBA/dado.png" ] || corta "PGS no pudo hacer el dibujo de prueba" "Probá a mano y mirá qué dice: (cd ${PRUEBA} && ${PGS_DONDE}/bin/pgs from_ascii txt=dado.txt out=dado.pss.json)"
	bien "dibujó un dado: ${PRUEBA}/dado.png"
	n="$(printf '%s\n%s\n%s\n' \
		'{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"instalar","version":"1"}}}' \
		'{"jsonrpc":"2.0","method":"notifications/initialized"}' \
		'{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
		| tope 60 "$PGS_DONDE/bin/pgs-mcp" 2>/dev/null \
		| node -e 'let t="";process.stdin.on("data",d=>t+=d).on("end",()=>{let n=0;for(const l of t.split("\n")){try{const m=JSON.parse(l);if(m.id===2)n=m.result.tools.length}catch{}}console.log(n)})' 2>/dev/null)"
	if [ "${n:-0}" -gt 0 ] 2>/dev/null; then
		bien "el servidor de PGS contesta (${n} herramientas)"
	else
		corta "el servidor de PGS no contesta" "Probá a mano: ${PGS_DONDE}/bin/pgs-mcp   (tiene que quedarse esperando; Ctrl+C para salir)."
	fi
}

conectar() {
	local conectado=0 app config
	paso "4. Conectarlo a tu Claude"
	if hay claude; then
		tope 60 claude mcp remove --scope user pgs >/dev/null 2>&1
		if tope 60 claude mcp add --scope user pgs -- "$PGS_DONDE/bin/pgs-mcp" >/dev/null 2>&1; then
			bien "Claude Code (en cualquier carpeta)"
			conectado=1
		else
			aviso "no pude sumarlo a Claude Code" "A mano: claude mcp add --scope user pgs -- ${PGS_DONDE}/bin/pgs-mcp"
		fi
	fi
	case "$(uname -s)" in
		Darwin) app="$HOME/Library/Application Support/Claude" ;;
		*) app="${XDG_CONFIG_HOME:-$HOME/.config}/Claude" ;;
	esac
	if [ -d "$app" ]; then
		config="$app/claude_desktop_config.json"
		if PGS_MCP="$PGS_DONDE/bin/pgs-mcp" NODE_DIR="$(dirname "$(command -v node)")" node - "$config" <<'JS'
const fs = require("fs");
const archivo = process.argv[2];
let c = {};
if (fs.existsSync(archivo)) {
	const texto = fs.readFileSync(archivo, "utf8");
	if (texto.trim()) c = JSON.parse(texto); // si no se entiende, no se pisa: sale con error
	if (!fs.existsSync(archivo + ".antes-de-pgs")) fs.copyFileSync(archivo, archivo + ".antes-de-pgs");
}
if (typeof c !== "object" || c === null || Array.isArray(c)) process.exit(1);
c.mcpServers = c.mcpServers || {};
c.mcpServers.pgs = {
	command: process.env.PGS_MCP,
	env: { PATH: `${process.env.NODE_DIR}:/usr/local/bin:/usr/bin:/bin` },
};
fs.writeFileSync(archivo, JSON.stringify(c, null, 2) + "\n");
JS
		then
			bien "la app de Claude (cerrala del todo y volvé a abrirla)"
			conectado=1
		else
			aviso "no pude sumarlo a la app de Claude" "Su configuración (${config}) no se entiende y no la toqué."
		fi
	fi
	if [ "$conectado" -eq 0 ]; then
		aviso "no encontré Claude en esta compu" "Instalá Claude Code (curl -fsSL https://claude.ai/install.sh | bash) o la app (https://claude.ai/download) y corré de nuevo: bash instalar.sh ${modulo}"
		return 1
	fi
}

taller() {
	echo "El taller: PGS, conectado a tu Claude."
	revisar
	bajar
	probar
	if conectar; then
		cat <<EOF

Listo. Abrí Claude y pedile, por ejemplo:
  «Usá PGS para dibujar un escudo de 16x16 con una paleta de cuatro colores
   en la carpeta ~/mi-proyecto, y mostrámelo.»
El dibujo de prueba quedó en ${PRUEBA}/dado.png: abrilo para verlo.
EOF
	else
		cat <<EOF

PGS quedó instalado y dibuja (${PRUEBA}/dado.png), pero falta conectarlo a Claude.
EOF
		exit 1
	fi
}

hay_terminal() { [ -t 0 ] && [ -t 1 ]; }

cuentas() {
	paso "1b. Para la oficina: GitHub y Claude Code"
	hay gh || corta "falta gh, el programa de GitHub" "Bajá el instalador de https://cli.github.com, abrí una Terminal nueva y corré de nuevo."
	if tope 60 gh auth status >/dev/null 2>&1; then
		bien "gh, con tu cuenta"
	elif hay_terminal; then
		echo "  … entrá a GitHub (elegí GitHub.com y Login with a web browser)"
		gh auth login || corta "no entraste a GitHub" "Corré: gh auth login"
		bien "gh, con tu cuenta"
	else
		corta "gh no tiene tu cuenta" "Corré: gh auth login   (y después, de nuevo: bash instalar.sh oficina ${base})"
	fi
	if ! hay claude; then
		echo "  … instalando Claude Code"
		tope 600 bash -c 'curl -fsSL https://claude.ai/install.sh | bash' >/dev/null 2>&1
		export PATH="$HOME/.local/bin:$PATH"
		hay claude || corta "no pude instalar Claude Code" "A mano: curl -fsSL https://claude.ai/install.sh | bash"
	fi
	bien "Claude Code"
}

traer() {
	local tmp
	paso "5. El estudio, en ${ESTUDIO_DONDE}"
	if [ -x "$ESTUDIO_DONDE/scripts/doctor.sh" ]; then
		bien "ya estaba"
		return 0
	fi
	[ -n "$base" ] || corta "falta de qué repo sale el estudio" "Quien te invitó te pasa su nombre: bash instalar.sh oficina <dueño/repo>"
	tmp="$(mktemp -d "${TMPDIR:-/tmp}/estudio-base.XXXXXX")" || corta "no pude crear una carpeta temporal" "Revisá que haya lugar en el disco."
	tope 900 gh repo clone "$base" "$tmp/base" -- --quiet --depth 1 >/dev/null 2>&1 \
		|| corta "no pude bajar ${base}" "¿Te invitaron al repo y aceptaste la invitación? Probá: gh repo view ${base}"
	tope 900 "$tmp/base/scripts/estudio_nuevo.sh" "$ESTUDIO_DONDE" >"$tmp/armar.log" 2>&1 \
		|| { tail -15 "$tmp/armar.log" >&2; corta "no pude armar tu estudio" "Lo de arriba es lo que dijo. Si ${ESTUDIO_DONDE} quedó a medias, borrala y corré de nuevo."; }
	rm -rf "$tmp"
	bien "armado a partir de ${base}, sin los datos de su dueño"
}

tu_nombre() {
	local nombre id
	paso "6. Tu nombre en el estudio"
	nombre="${ESTUDIO_DUENO:-}"
	if [ -z "$nombre" ] && grep -q '"id": "sol"' "$ESTUDIO_DONDE/data/clientes.json" 2>/dev/null && hay_terminal; then
		printf '  ¿Cómo te llamás? (así te dicen los agentes): '
		read -r nombre
	fi
	if [ -z "$nombre" ]; then
		if grep -q '"id": "sol"' "$ESTUDIO_DONDE/data/clientes.json" 2>/dev/null; then
			aviso "sigue la dueña de ejemplo, Sol" "Cambiala en ${ESTUDIO_DONDE}/data/clientes.json, o: ESTUDIO_DUENO=\"Tu nombre\" bash instalar.sh oficina"
		else
			bien "ya estaba"
		fi
		return 0
	fi
	id="$(NOMBRE="$nombre" node -e 'process.stdout.write(process.env.NOMBRE.normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase().replace(/[^a-z0-9]+/g,"_").replace(/^_+|_+$/g,"")||"duenio")')"
	NOMBRE="$nombre" ID="$id" node - "$ESTUDIO_DONDE/data/clientes.json" <<'JS' || corta "no pude escribir tu nombre" "A mano, en data/clientes.json: el primero es el tuyo."
const fs = require("fs");
const archivo = process.argv[2];
const c = JSON.parse(fs.readFileSync(archivo, "utf8"));
c.clientes[0].nombre = process.env.NOMBRE;
c.clientes[0].id = process.env.ID;
fs.writeFileSync(archivo, JSON.stringify(c, null, 1) + "\n");
JS
	git -C "$ESTUDIO_DONDE" add -- data/clientes.json \
		&& git -C "$ESTUDIO_DONDE" -c user.name="Estudio nuevo" -c user.email="estudio@localhost" commit -q -m "La dueña del estudio: ${nombre}" >/dev/null 2>&1
	bien "${nombre} (${id})"
}

su_repo() {
	local nombre
	paso "7. Su repo en GitHub (los pedidos viven ahí)"
	if git -C "$ESTUDIO_DONDE" remote get-url origin >/dev/null 2>&1; then
		bien "ya tiene: $(git -C "$ESTUDIO_DONDE" remote get-url origin)"
		return 0
	fi
	nombre="$(basename "$ESTUDIO_DONDE")"
	if (cd "$ESTUDIO_DONDE" && tope 300 gh repo create "$nombre" --private --source . --push >/dev/null 2>&1); then
		bien "${nombre}, privado"
	else
		aviso "no pude crear su repo" "En ${ESTUDIO_DONDE}: gh repo create ${nombre} --private --source . --push   (sin repo se abre igual, pero sin tablero)"
	fi
}

al_dia() {
	paso "8. Los dibujos, las cuentas de los agentes y el doctor"
	[ "$PGS_DONDE" = "$HOME/pgs" ] || export ESTUDIO_PGS="$PGS_DONDE"
	[ "$PGS_DONDE" = "$HOME/pgs" ] || aviso "PGS quedó en ${PGS_DONDE}, no en ~/pgs" "Para que la oficina lo encuentre siempre, sumá a tu ~/.zshrc: export ESTUDIO_PGS=${PGS_DONDE}"
	(cd "$ESTUDIO_DONDE" && tope 120 scripts/instalar_hooks.sh >/dev/null 2>&1) || aviso "no pude poner el control de commits" "En ${ESTUDIO_DONDE}: scripts/instalar_hooks.sh"
	if (cd "$ESTUDIO_DONDE" && tope 1800 python3 scripts/dibujos_al_dia.py --traer >/dev/null 2>&1); then
		bien "los dibujos, al día"
	else
		aviso "no pude poner los dibujos al día" "En ${ESTUDIO_DONDE}: python3 scripts/dibujos_al_dia.py --traer"
	fi
	if hay_terminal; then
		echo "  … las cuentas de los agentes (abre el navegador: Claude, después GitHub)"
		(cd "$ESTUDIO_DONDE" && scripts/login_estudio.sh) || aviso "no terminaron de entrar las cuentas" "En ${ESTUDIO_DONDE}: scripts/login_estudio.sh"
	else
		aviso "faltan las cuentas de los agentes" "En una Terminal, en ${ESTUDIO_DONDE}: scripts/login_estudio.sh"
	fi
	echo
	if (cd "$ESTUDIO_DONDE" && tope 300 scripts/doctor.sh); then
		cat <<EOF

Listo. Para abrir la oficina:
  cd ${ESTUDIO_DONDE} && ./run.sh
EOF
	else
		cat <<EOF

Casi: falta lo que dice el doctor (arriba, con cómo se arregla).
Cuando lo arregles: cd ${ESTUDIO_DONDE} && scripts/doctor.sh
EOF
		exit 1
	fi
}

MARCA_MESA='#__PLANTILLA_DE_LA_MESA__'
GUARDIA_MESA="guardia.sh juzgar.py partir.py"

plantilla() {
	local yo aca h
	yo="${BASH_SOURCE[0]}"
	aca="$(cd "$(dirname "$yo")" && pwd)"
	if grep -qx -- "$MARCA_MESA" "$yo" 2>/dev/null; then
		node - "$yo" "$1" "$MARCA_MESA" <<'JS'
const fs = require("fs"), path = require("path");
const [yo, dest, marca] = process.argv.slice(2);
const lineas = fs.readFileSync(yo, "utf8").split("\n");
const datos = JSON.parse(Buffer.from(lineas[lineas.indexOf(marca) + 1], "base64").toString("utf8"));
for (const [ruta, a] of Object.entries(datos)) {
	const f = path.join(dest, ruta);
	fs.mkdirSync(path.dirname(f), { recursive: true });
	fs.writeFileSync(f, a.texto, { mode: a.modo });
}
JS
	elif [ -d "$aca/plantillas/mesa" ]; then
		cp -R "$aca/plantillas/mesa/." "$1/" && mkdir -p "$1/scripts/hooks" || return 1
		for h in $GUARDIA_MESA; do cp -p "$aca/scripts/hooks/$h" "$1/scripts/hooks/" || return 1; done
	else
		return 1
	fi
}

armar_mesa() {
	local tmp f nuevos=0 viejos=0
	paso "5. La mesa, en ${destino}"
	mkdir -p "$destino" 2>/dev/null && destino="$(cd "$destino" && pwd)" \
		|| corta "no pude crear ${destino}" "Elegí otra carpeta: bash instalar.sh mesa ~/otra-carpeta"
	tmp="$(mktemp -d "${TMPDIR:-/tmp}/mesa.XXXXXX")" || corta "no pude crear una carpeta temporal" "Revisá que haya lugar en el disco."
	plantilla "$tmp" || corta "este instalador no trae la plantilla de la mesa" "Pedí el instalador entero (lo arma scripts/empaquetar_instalador.sh en el estudio)."
	while IFS= read -r f; do
		f="${f#./}"
		if [ -e "$destino/$f" ]; then
			viejos=$((viejos + 1))
		else
			mkdir -p "$(dirname "$destino/$f")" && cp -p "$tmp/$f" "$destino/$f" && nuevos=$((nuevos + 1))
		fi
	done < <(cd "$tmp" && find . -type f | sort)
	rm -rf "$tmp"
	[ -e "$destino/CLAUDE.md" ] || [ -L "$destino/CLAUDE.md" ] || ln -s AGENTS.md "$destino/CLAUDE.md"
	echo "$PGS_DONDE" >"$destino/.pgs-donde"
	[ -e "$destino/.git" ] || git -C "$destino" init -q >/dev/null 2>&1 || aviso "no pude hacerla repo de git" "En ${destino}: git init"
	bien "el método (AGENTS.md), el estilo (pgs.json), el guardia y las pruebas: ${nuevos} archivos nuevos"
	[ "$viejos" -eq 0 ] || bien "${viejos} ya estaban: no los toqué"
	if ! (cd "$destino" && PGS_DONDE="$PGS_DONDE" tope 600 bash probar.sh >"$destino/.probar.log" 2>&1); then
		cat "$destino/.probar.log" >&2
		corta "las pruebas de la mesa dieron rojo" "Lo de arriba es lo que dijeron. A mano: cd ${destino} && ./probar.sh"
	fi
	rm -f "$destino/.probar.log"
	bien "sus pruebas, en verde (./probar.sh)"
}

mesa() {
	local conectado=1
	echo "La mesa: el taller y una carpeta de proyecto con el método."
	[ -n "$destino" ] || corta "falta en qué carpeta va la mesa" "Decile cuál: bash instalar.sh mesa ~/mi-proyecto"
	revisar
	bajar
	probar
	conectar || conectado=0
	armar_mesa
	if [ "$conectado" -eq 0 ]; then
		printf '\nLa mesa quedó en %s, pero falta conectar PGS a Claude (arriba dice cómo).\n' "$destino"
		exit 1
	fi
	cat <<EOF

Listo. La mesa quedó en ${destino}. Para trabajar ahí:
  cd ${destino} && claude
y pedile, por ejemplo:
  «Leé AGENTS.md. Quiero hacer una planilla de personaje: preguntame cómo
   quiero que se vea y dibujá con PGS el primer ícono.»
EOF
}

oficina() {
	echo "La oficina: el estudio entero, con el taller adentro."
	revisar
	cuentas
	bajar
	probar
	conectar || corta "PGS no quedó conectado a Claude" "Lo de arriba dice qué falta."
	traer
	tu_nombre
	su_repo
	al_dia
}

modulo="${1:-taller}"
case "$modulo" in
	taller) taller ;;
	--lista | lista | -h | --help | ayuda) lista ;;
	--plantilla) plantilla "${2:?la carpeta}" ;;
	mesa)
		destino="${2:-}"
		modulo="mesa${destino:+ $destino}"
		pide_python=1
		pide_git=1
		mesa
		;;
	oficina)
		base="${2:-${ESTUDIO_BASE:-}}"
		modulo="oficina${base:+ $base}"
		pide_python=1 pide_oficina=1 pide_git=1 pgs_repo=1
		oficina
		;;
	*)
		echo "No conozco el módulo «${modulo}»." >&2
		lista >&2
		exit 2
		;;
esac
exit 0
#__PLANTILLA_DE_LA_MESA__
eyIuY2xhdWRlL3NldHRpbmdzLmpzb24iOnsibW9kbyI6NDIwLCJ0ZXh0byI6IntcbiAgXCJob29rc1wiOiB7XG4gICAgXCJQcmVUb29sVXNlXCI6IFtcbiAgICAgIHtcbiAgICAgICAgXCJtYXRjaGVyXCI6IFwiQmFzaFwiLFxuICAgICAgICBcImhvb2tzXCI6IFtcbiAgICAgICAgICB7XG4gICAgICAgICAgICBcInR5cGVcIjogXCJjb21tYW5kXCIsXG4gICAgICAgICAgICBcImNvbW1hbmRcIjogXCJcXFwiJENMQVVERV9QUk9KRUNUX0RJUlxcXCIvc2NyaXB0cy9ob29rcy9ndWFyZGlhLnNoXCJcbiAgICAgICAgICB9XG4gICAgICAgIF1cbiAgICAgIH1cbiAgICBdXG4gIH1cbn1cbiJ9LCIuZ2l0aWdub3JlIjp7Im1vZG8iOjQyMCwidGV4dG8iOiIuRFNfU3RvcmVcbi5wZ3MtZG9uZGVcbiJ9LCJBR0VOVFMubWQiOnsibW9kbyI6NDIwLCJ0ZXh0byI6IiMgQUdFTlRTLm1kOiBjw7NtbyBzZSB0cmFiYWphIGVuIGVzdGEgY2FycGV0YVxuXG5MbyBwcmltZXJvIHF1ZSBsZWUgY3VhbHF1aWVyIGFnZW50ZSAoQ2xhdWRlIENvZGUsIENvZGV4IHUgb3RybykuIGBDTEFVREUubWRgXG5hcHVudGEgYSBlc3RlIGFyY2hpdm8uIEVzIGVsIG3DqXRvZG8gZGVsIGVzdHVkaW8gZW4gY29ydG86IHNhbGnDsyBkZSBoYWNlciB1blxuanVlZ28gZW50ZXJvIGFzw60sIHkgY2FkYSByZWdsYSBjb3N0w7MgYWxnbyBxdWUgc2Ugcm9tcGnDsy5cblxuIyMgUXVpw6luIGhhY2UgcXXDqVxuXG4tICoqTGEgcGVyc29uYSBkZWNpZGUqKjogcXXDqSBzZSBoYWNlLCBjw7NtbyBzZSB2ZSwgY3XDoW5kbyBlc3TDoSBiaWVuLiBObyB0aWVuZVxuICBwb3IgcXXDqSBsZWVyIGPDs2RpZ28uXG4tICoqRWwgYWdlbnRlIGNvbnN0cnV5ZSoqOiBjw7NkaWdvLCBhcmNoaXZvcywgcHJ1ZWJhcyB5IGVsIGNvbnRyb2wgZGUgY2FsaWRhZFxuICBkZSBvZmljaW8uIExvIHF1ZSBlbnRyZWdhLCB5YSBsbyBtaXLDsyDDqWwuXG4tICoqUEdTIGRpYnVqYSoqOiB0b2RvIGxvIHZpc3VhbCAocGl4ZWwgYXJ0LCDDrWNvbm9zLCB0aXBvZ3JhZsOtYXMsIHNvbmlkb3MpIHNhbGVcbiAgZGUgUEdTLCBjb25lY3RhZG8gY29tbyBzZXJ2aWRvciBNQ1AgKGBwZ3NgKS4gTm8gc2UgZGlidWphIGEgbWFubyBlbiB1biBlZGl0b3JcbiAgbmkgc2UgYmFqYSBhcnRlIGRlIGludGVybmV0LlxuXG4jIyBBbnRlcyBkZSBkaWJ1amFyXG5cbjEuIExlw6kgZWwgZXN0aWxvIGRlbCBwcm95ZWN0bzogbGEgaGVycmFtaWVudGEgYHByb2plY3RgIGRlIFBHUyAob1xuICAgYHBncyBwcm9qZWN0YCkgbGVlIGBwZ3MuanNvbmAuXG4yLiBTaSBkaWNlIMKrdG9kYXbDrWEgc2luIGVzdGlsb8K7LCBwcmVndW50YWxlIGEgbGEgcGVyc29uYSBjw7NtbyBxdWllcmUgcXVlIHNlXG4gICB2ZWEgKGRvcyBvIHRyZXMgb3BjaW9uZXMsIG1vc3RyYWRhcykgeSBlc2NyaWJpbG8gZW4gYHBncy5qc29uYDogbGEgcHJvc2EgZW5cbiAgIGBzYXlzYCwgbG9zIG7Dum1lcm9zIGVuIGB2aXN1YWxgIChsYSBwYWxldGEsIGxhIGdyaWxsYSwgbG9zIHRhbWHDsW9zKS5cbjMuIEVsIGFydGUgdml2ZSBlbiBgYXJ0L2AgY29tbyB0ZXh0byAodW4gYC50eHRgIGRlIGBmcm9tX2FzY2lpYCwgbyBsYSByZWNldGFcbiAgIHF1ZSBjb3JyZXNwb25kYSkgeSBzdSBgLnBzcy5qc29uYDsgZWwgUE5HIHNlIHNhY2EgY29uIGByZW5kZXJgLlxuNC4gKipNaXLDoSBjYWRhIGRpYnVqbyoqIGEgc3UgdGFtYcOxbyB5IGFtcGxpYWRvIChgcmVuZGVyYCwgYGNvbnRhY3RgKSBhbnRlcyBkZVxuICAgbW9zdHJhcmxvLiBTaSBhIHZvcyB0ZSBwYXJlY2UgZmVvLCBlcyBmZW86IG90cmEgcGFzYWRhLlxuXG4jIyBQcm9oaWJpY2lvbmVzIGR1cmFzXG5cbk5vIHNlIG5lZ29jaWFuIHBvciBhcHVyby4gRWwgZ3VhcmRpYSAoYHNjcmlwdHMvaG9va3MvZ3VhcmRpYS5zaGAsIHlhIGNvbmVjdGFkb1xuZW4gYC5jbGF1ZGUvc2V0dGluZ3MuanNvbmApIGNvcnRhIGxhcyBkZSBjb21hbmRvczsgbGFzIGRlbcOhcyBsYXMgY29ydMOhcyB2b3MuXG5cbi0gKipOdW5jYSBgcGtpbGxgIG5pIGBraWxsYWxsYCoqOiBlbiBtYWNPUyBtYXRhbiBkZSBtw6FzLiBgcGdyZXAgLWZsYCB5XG4gIGBraWxsIDxwaWQ+YCBkZWwgcHJvY2VzbyBleGFjdG8uXG4tICoqTnVuY2EgYGdpdCBzdGFzaGAsIGByZXNldGAsIGBjaGVja291dCA8cmFtYT5gLCBgY2xlYW5gIG5pIGByZWJhc2VgKio6IHBpc2FuXG4gIHRyYWJham8gcXVlIG5vIGVzIHR1eW8uIFBhcmEgY29tcGFyYXIsIGBnaXQgZGlmZmAgbyBgZ2l0IHNob3cgSEVBRDo8cnV0YT5gLlxuLSAqKkNvbW1pdHMgcG9yIHJ1dGFzKiogKGBnaXQgYWRkIDxydXRhPmApLCBudW5jYSBgZ2l0IGFkZCAtQWAgbmkgYC5gOyB5IG5hZGFcbiAgZGUgYHB1c2hgIHNpbiBxdWUgbGEgcGVyc29uYSBsbyBwaWRhLlxuLSAqKk51bmNhIGxlZXIgbmkgaW1wcmltaXIgY2xhdmVzKiogKGAuZW52YCwgdG9rZW5zKTogbG8gcXVlIG5lY2VzaXRhIHVuYSwgbG9cbiAgY29ycmUgbGEgcGVyc29uYSB5IHZvcyBsZSBkYXMgZWwgY29tYW5kby5cbi0gKipOYWRhIGNvbGdhZG8qKjogdG9kbyBsbyBxdWUgcHVlZGUgcXVlZGFyc2UgZXNwZXJhbmRvIHZhIGNvbiB0b3BlXG4gIChgcGVybCAtZSAnYWxhcm0gMzAwOyBleGVjIEBBUkdWJyA8Y29tYW5kbz5gKSwgeSBhbCB0ZXJtaW5hciBubyBxdWVkYSBuYWRhXG4gIHR1eW8gY29ycmllbmRvLlxuLSAqKkxvcyBhcmNoaXZvcyBkZSBsYSBwZXJzb25hIGZ1ZXJhIGRlIGVzdGEgY2FycGV0YSBubyBzZSB0b2NhbioqOiBzZSBjb3BpYW5cbiAgeSBzZSB0cmFiYWphIHNvYnJlIGxhIGNvcGlhLlxuXG4jIyBMYXMgcHJ1ZWJhc1xuXG4tIGAuL3Byb2Jhci5zaGAgY29ycmUgdG9kbyBsbyBkZSBgdGVzdHMvYC4gQW50ZXMgZGUgZGVjaXIgcXVlIGFsZ28gYW5kYSwgZW5cbiAgdmVyZGUgeSBjb3JyaWRvIHBvciB2b3MuXG4tIFRvZGEgbMOzZ2ljYSBudWV2YSBlbnRyYSBjb24gc3UgcHJ1ZWJhLCB5IGxhIHBydWViYSB0aWVuZSBxdWUgZmFsbGFyIHNpXG4gIHJvbXDDqXMgZWwgY8OzZGlnby5cbi0gVW5hIHBydWViYSBlc3BlcmEgdW5hIGNvbmRpY2nDs24gKHVuIGFyY2hpdm8sIHVuIGVzdGFkbyksIG51bmNhIHVuIHRpZW1wbyBmaWpvLlxuLSBBcmNoaXZvcyBjaGljb3M6IG5pbmd1bm8gZGUgY8OzZGlnbyBwYXNhIGRlIDYwMCBsw61uZWFzOyBzZSBwYXJ0ZSBwb3IgdGVtYS5cblxuIyMgUXXDqSBzZSBsZSBwcmVndW50YSBhIGxhIHBlcnNvbmFcblxuLSAqKlPDs2xvIGd1c3RvIHkgYWxjYW5jZSoqOiBjw7NtbyBzZSB2ZSwgcXXDqSBzZSBoYWNlLCBjdcOhbnRvIGN1ZXN0YSBkZSBtw6FzLlxuLSBMbyBkZSBvZmljaW8gKGPDs21vIHNlIHByb2dyYW1hLCBxdcOpIGhlcnJhbWllbnRhLCB1biBlcnJvcikgbG8gZGVjaWTDrXMgdm9zLlxuLSBBbnRlcyBkZSBhbGdvIHF1ZSBubyBzZWEgdHJpdmlhbCwgcGVuc8OhIGFsIG1lbm9zIGRvcyBmb3JtYXMsIGNvbiBsbyBxdWVcbiAgY3Vlc3RhIGNhZGEgdW5hLCB5IGVsZWfDrTsgc2kgbGEgbWVqb3IgZXMgbXVjaG8gbcOhcyBjYXJhIHF1ZSBsYSBvYnZpYSwgb1xuICBjYW1iaWEgbG8gcXVlIHBpZGnDsywgcHJlZ3VudMOhIGFudGVzLlxuLSBTaSB1bmEgZGVjaXNpw7NuIHN1eWEgdGUgcGFyZWNlIG1hbGEsIGRlY8Otc2VsbyBhbnRlcyBkZSBoYWNlcmxhLiBTaSBsYVxuICByZWFmaXJtYSwgc2UgaGFjZSBjb21vIGRpam8uXG5cbiMjIEFsIHRlcm1pbmFyIGFsZ29cblxuRGVjw60gcXXDqSBjYW1iacOzIHkgKipxdcOpIHByb2JhciB5IGPDs21vKiosIGNvbmNyZXRvICjCq2FicsOtIFgsIGhhY8OpIFksIHRlbmRyw61hc1xucXVlIHZlciBawrspLiBZIGVuIHRyZXMgcmVuZ2xvbmVzOiAqKlZpc3RvKiogKGxvIHF1ZSBjb3JyaXN0ZSBvIG1pcmFzdGUpLFxuKipEZWR1Y2lkbyoqIChsbyBxdWUgY3Jlw6lzIHF1ZSBhbmRhIHNpbiBoYWJlcmxvIHZpc3RvKSB5ICoqU2luIHZlcioqIChsbyBxdWVcbm5vIHB1ZGlzdGUgcHJvYmFyIHkgcG9yIHF1w6kpLlxuIn0sInBncy5qc29uIjp7Im1vZG8iOjQyMCwidGV4dG8iOiJ7XG4gIFwibmFtZVwiOiBcIk1pIHByb3llY3RvXCIsXG4gIFwic2F5c1wiOiBcIlRvZGF2w61hIHNpbiBlc3RpbG86IHByZWd1bnRhbGUgYSBsYSBwZXJzb25hIGPDs21vIHF1aWVyZSBxdWUgc2UgdmVhIHkgZXNjcmliaWxvIGFjw6EgKGxhIHByb3NhLCBhcXXDrTsgbGEgcGFsZXRhIHkgbG9zIHRhbWHDsW9zLCBlbiB2aXN1YWwpLlwiLFxuICBcInZpc3VhbFwiOiB7XG4gICAgXCJncmlkXCI6IDFcbiAgfVxufVxuIn0sInByb2Jhci5zaCI6eyJtb2RvIjo0OTMsInRleHRvIjoiIyEvdXNyL2Jpbi9lbnYgYmFzaFxuc2V0IC11byBwaXBlZmFpbFxuY2QgXCIkKGRpcm5hbWUgXCIkMFwiKVwiIHx8IGV4aXQgMVxucm9qYXM9MFxuZm9yIHQgaW4gdGVzdHMvKi5zaDsgZG9cblx0WyAtZiBcIiR0XCIgXSB8fCBjb250aW51ZVxuXHRpZiBwZXJsIC1lICdhbGFybSAzMDA7IGV4ZWMgQEFSR1YnIGJhc2ggXCIkdFwiOyB0aGVuIDo7IGVsc2Vcblx0XHRlY2hvIFwi4pyXICR7dH1cIlxuXHRcdHJvamFzPSQoKHJvamFzICsgMSkpXG5cdGZpXG5kb25lXG5pZiBbIFwiJHJvamFzXCIgLWVxIDAgXTsgdGhlblxuXHRlY2hvIFwi4pyTIHRvZG8gdmVyZGVcIlxuZWxzZVxuXHRlY2hvIFwi4pyXICR7cm9qYXN9IGVuIHJvam9cIlxuXHRleGl0IDFcbmZpXG4ifSwic2NyaXB0cy9ob29rcy9ndWFyZGlhLnNoIjp7Im1vZG8iOjQ5MywidGV4dG8iOiIjIS91c3IvYmluL2VudiBiYXNoXG5zZXQgLXVcbmlmIFsgJCMgLWd0IDAgXTsgdGhlblxuXHRpbnB1dD1cIiQqXCJcbmVsc2Vcblx0aW5wdXQ9XCIkKGNhdClcIlxuZmlcblxuY29uZmlnPVwiJHtFU1RVRElPX0NPTkZJRzotJChjZCBcIiQoZGlybmFtZSBcIiQwXCIpLy4uLy4uXCIgJiYgcHdkKS8uZXN0dWRpby9jb25maWcuanNvbn1cIlxuaWYgWyAtZiBcIiRjb25maWdcIiBdICYmIGdyZXAgLXEgJ1wiY2FycGV0YXNfYWplbmFzXCInIFwiJGNvbmZpZ1wiIDI+L2Rldi9udWxsICYmIGNvbW1hbmQgLXYgbm9kZSA+L2Rldi9udWxsIDI+JjE7IHRoZW5cblx0cG9yPVwiJChwcmludGYgJyVzJyBcIiRpbnB1dFwiIHwgRVNUVURJT19DT05GSUc9XCIkY29uZmlnXCIgbm9kZSBcIiQoZGlybmFtZSBcIiQwXCIpLy4uLy4uL3B1ZW50ZS9wZXJmaWwubWpzXCIgYWplbmEgMj4mMSA+L2Rldi9udWxsKVwiXG5cdGlmIFsgLW4gXCIkcG9yXCIgXTsgdGhlblxuXHRcdHByaW50ZiAnJXNcXG4nIFwiJHBvclwiID4mMlxuXHRcdGV4aXQgMlxuXHRmaVxuZmlcbnByaW50ZiAnJXMnIFwiJGlucHV0XCIgfCBleGVjIHB5dGhvbjMgXCIkKGRpcm5hbWUgXCIkMFwiKS9qdXpnYXIucHlcIlxuIn0sInNjcmlwdHMvaG9va3MvanV6Z2FyLnB5Ijp7Im1vZG8iOjQyMCwidGV4dG8iOiJcIlwiXCJMYXMgcmVnbGFzIGRlbCBndWFyZGlhLCBzb2JyZSBlbCBjb21hbmRvIHlhIHBhcnRpZG8uIExvIGxsYW1hIGd1YXJkaWEuc2guXG5cbkxlZSBwb3Igc3RkaW4gZWwgY29tYW5kbyAodGV4dG8sIG8gZWwgSlNPTiBkZSB1biBob29rKSB5IHNhbGUgY29uIDAgc2kgcGFzYSwgb1xuY29uIDIgeSBlbCBtb3Rpdm8gZW4gc3RkZXJyIHNpIGxvIGZyZW5hLiBFbCBjb21hbmRvIGxvIHBhcnRlIHBhcnRpci5weTsgY2FkYVxucmVnbGEgbWlyYSBlbCBwcm9ncmFtYSB5IHN1cyBhcmd1bWVudG9zLCBubyBwYWxhYnJhcyBzdWVsdGFzIGVuIGVsIHRleHRvOlxuXG4tIExvIHF1ZSBlamVjdXRhIGEgb3RybyBzZSBkZXNlbnZ1ZWx2ZSAoZW52LCBzdWRvLCBub2h1cCwgZXhlYywgbmljZSwgdGltZSxcbiAgY2FmZmVpbmF0ZSwgdGFza3BvbGljeSwgeGFyZ3MsIGB0aW1lb3V0IE5gLCBgcGVybCAtZSAn4oCmYWxhcm0gTjsgZXhlYyBAQVJHVidgKSxcbiAgeSBlbCB0b3BlIGRlIGB0aW1lb3V0YCBvIGRlbCBgYWxhcm1gIGVzIGRlIGxvIHF1ZSBlbnZ1ZWx2ZS5cbi0gTG8gcXVlIGNvcnJlIHRleHRvIHNlIHZ1ZWx2ZSBhIHBhcnRpciB5IGp1emdhcjogYGJhc2ggLWNgLCBgZXZhbGAsIGBzc2hgLFxuICBgc3UgLWNgLCB1biBoZXJlZG9jIHF1ZSB2YSBhIHVuIHNoZWxsIChgYmFzaCA8PEVPRmAsIGBjYXQgPDxFT0YgfCBzaGApIG8gYSB1blxuICBhcmNoaXZvIHF1ZSBkZXNwdcOpcyBzZSBjb3JyZSAoYGNhdCA+IHguc2ggPDxFT0Yg4oCmOyAuL3guc2hgKS5cbi0gTG8gZGVtw6FzIGVudHJlIGNvbWlsbGFzLCBlbiB1biBoZXJlZG9jLCB1biBgLW1gIG8gdW4gYHByaW50ZmAgZXMgdGV4dG86IG5vIGNvcnJlLlxuXG5RdcOpIGNvcnRhLCB5IHBvciBxdcOpLCBlbiBlbCBlbmNhYmV6YWRvIGRlIGd1YXJkaWEuc2guXG5cIlwiXCJcbmltcG9ydCBqc29uXG5pbXBvcnQgb3NcbmltcG9ydCByZVxuaW1wb3J0IHN5c1xuXG5zeXMuZG9udF93cml0ZV9ieXRlY29kZSA9IFRydWVcbnN5cy5wYXRoLmluc2VydCgwLCBvcy5wYXRoLmRpcm5hbWUob3MucGF0aC5hYnNwYXRoKF9fZmlsZV9fKSkpXG5mcm9tIHBhcnRpciBpbXBvcnQgQWJpZXJ0bywgYV9sb19icnV0bywgcGFydGlyXG5cbkFTSUdOQSA9IHJlLmNvbXBpbGUoclwiXltBLVphLXpfXVtBLVphLXowLTlfXSo9XCIpXG5TSEVMTFMgPSB7XCJiYXNoXCIsIFwic2hcIiwgXCJ6c2hcIiwgXCJkYXNoXCIsIFwia3NoXCIsIFwiZmlzaFwifVxuQUJSRV9CVUNMRSA9IHtcIndoaWxlXCIsIFwidW50aWxcIiwgXCJmb3JcIiwgXCJzZWxlY3RcIn1cbk5PTUJSQV9HT0RPVCA9IHJlLmNvbXBpbGUoclwiR29kb3R8Z29kb3R8XFwuLyhydW58dGVzdHxleHBvcnRhcnxwdWJsaWNhcilcXC5zaHxnb2RvdF9zaW5fZm9jb1xcLnNoXCIpXG5MQU5aQURPUkVTID0ge1wicnVuLnNoXCIsIFwidGVzdC5zaFwiLCBcImV4cG9ydGFyLnNoXCIsIFwicHVibGljYXIuc2hcIn1cbkNPTl9WQUxPUiA9IHtcbiAgICBcInN1ZG9cIjogc2V0KFwidWdwQ2hydFRVRFwiKSwgXCJlbnZcIjogc2V0KFwidVNDUFwiKSwgXCJuaWNlXCI6IHNldChcIm5cIiksIFwiY2FmZmVpbmF0ZVwiOiBzZXQoXCJ0d1wiKSxcbiAgICBcInRhc2twb2xpY3lcIjogc2V0KFwiY2d0bHBcIiksIFwieGFyZ3NcIjogc2V0KFwiSUpMblBzZEVcIiksIFwidGltZW91dFwiOiBzZXQoXCJza1wiKSwgXCJleGVjXCI6IHNldChcImFcIiksXG4gICAgXCJzc2hcIjogc2V0KFwiYmNERWVGSWlKTGxtT29wUVJTV3dcIiksXG59XG5HSVRfQ09OX1ZBTE9SID0ge1wiLUNcIiwgXCItY1wiLCBcIi0tZ2l0LWRpclwiLCBcIi0td29yay10cmVlXCIsIFwiLS1uYW1lc3BhY2VcIiwgXCItLXN1cGVyLXByZWZpeFwiLCBcIi0tY29uZmlnLWVudlwifVxuQ09NTUlUX0NPTl9WQUxPUiA9IHNldChcIm1GQ2NTdFwiKVxuQ09NTUlUX0xBUkdBUyA9IHtcIi0tbWVzc2FnZVwiLCBcIi0tZmlsZVwiLCBcIi0tYXV0aG9yXCIsIFwiLS1kYXRlXCIsIFwiLS1yZXVzZS1tZXNzYWdlXCIsIFwiLS1yZWVkaXQtbWVzc2FnZVwiLFxuICAgICAgICAgICAgICAgICBcIi0tZml4dXBcIiwgXCItLXNxdWFzaFwiLCBcIi0tdGVtcGxhdGVcIiwgXCItLWNsZWFudXBcIiwgXCItLXRyYWlsZXJcIiwgXCItLXBhdGhzcGVjLWZyb20tZmlsZVwifVxuXG5cbmNsYXNzIEZyZW5hKEV4Y2VwdGlvbik6XG4gICAgXCJcIlwiTG8gZnJlbmEgdW5hIHJlZ2xhOiBzdSBjbGF2ZSBlbiBNT1RJVk9TIHkgZWwgY29tYW5kbyBxdWUgbGEgcm9tcGUuXCJcIlwiXG4gICAgZGVmIF9faW5pdF9fKHNlbGYsIGNsYXZlLCBwYWxhYnJhcz0oKSk6XG4gICAgICAgIHN1cGVyKCkuX19pbml0X18oY2xhdmUpXG4gICAgICAgIHNlbGYuY2xhdmUsIHNlbGYucGFsYWJyYXMgPSBjbGF2ZSwgbGlzdChwYWxhYnJhcylcblxuXG5NT1RJVk9TID0ge1xuICAgIFwibWF0YXJcIjogXCJwa2lsbC9raWxsYWxsIGVzdMOhbiBwcm9oaWJpZG9zIChlbiBtYWNPUyBtYXRhbiBsbyBxdWUgbm8gZXMpLiBVc8OhIHBncmVwIC1mbCB5IGtpbGwgPHBpZD4gZGVsIHByb2Nlc28gZXhhY3RvLlwiLFxuICAgIFwicGlzYVwiOiBcImdpdCBzdGFzaC9yZXNldC9yZWJhc2Uvc3dpdGNoIGVzdMOhbiBwcm9oaWJpZG9zIGNvbiBhZ2VudGVzIGVuIHBhcmFsZWxvOiBwaXNhbiBlbCDDrW5kaWNlIG8gZWwgw6FyYm9sIGRlIG90cm8uIENvbW1pdGXDoSBwb3IgcnV0YXMsIG8gZGVqw6EgZWwgYXJjaGl2byBjb21vIGVzdMOhIHkgZGVjaWxvIGVuIGVsIHJlcG9ydGUuXCIsXG4gICAgXCJjaGVja291dFwiOiBcImdpdCBjaGVja291dCA8cmFtYT4gZXN0w6EgcHJvaGliaWRvIGNvbiBhZ2VudGVzIGVuIHBhcmFsZWxvIChjYW1iaWEgZWwgw6FyYm9sIGRlIHRvZG9zKS4gU8OzbG8gdmFsZSBnaXQgY2hlY2tvdXQgLS0gPGFyY2hpdm8+LCB5IHPDs2xvIHNvYnJlIGFyY2hpdm9zIHByb3Bpb3MuXCIsXG4gICAgXCJhZGRcIjogXCJnaXQgYWRkIHZhIHBvciBydXRhcywgbnVuY2EgLUEgbmkgLiAoQUdFTlRTLm1kKTogaGF5IHRyYWJham8gYWplbm8gZW4gZWwgw6FyYm9sLlwiLFxuICAgIFwiY29tbWl0XCI6IFwiZ2l0IGNvbW1pdCAtYSBzZSBsbGV2YSBsbyBhamVubzogYWdyZWfDoSBwb3IgcnV0YXMgKGdpdCBhZGQgPHJ1dGE+KSB5IGNvbW1pdGXDoSBlc28uXCIsXG4gICAgXCJidWNsZVwiOiBcIlVuIGJ1Y2xlIGRlIGVzcGVyYSAodW50aWwvd2hpbGUgY29uIHNsZWVwKSB2YSBjb24gdG9wZTogcGVybCAtZSAnYWxhcm0gNjAwOyBleGVjIEBBUkdWJyBiYXNoIC1jICfigKYnLCBvIHVuIGNvbnRhZG9yIGRlIHZ1ZWx0YXMuXCIsXG4gICAgXCJnb2RvdFwiOiBcIkdvZG90IHkgbG8gcXVlIGxvIGxhbnphIHZhbiBzaWVtcHJlIGNvbiB0b3BlOiBwZXJsIC1lICdhbGFybSA2MDA7IGV4ZWMgQEFSR1YnIDxjb21hbmRvPiAobyB0aW1lb3V0IDYwMCA8Y29tYW5kbz4pLiBTaW4gdG9wZSwgdW4gcHJvY2VzbyBjb2xnYWRvIHNlIHF1ZWRhIHBhcmEgc2llbXByZS5cIixcbiAgICBcInRvcGVcIjogXCJVbiB0b3BlIGRlIG3DoXMgZGUgMzAgbWluIHBhcmEgdW4gdGVzdCAoYWxhcm0gPiAxODAwLCBHT0RPVF9UT1BFID4gOTAwKSBlc3TDoSBwcm9oaWJpZG86IHVuIHRlc3QgcXVlIHBhc2Egc3UgdG9wZSBubyBzZSByZXBpdGUgY29uIHVubyBtw6FzIGxhcmdvLiBFbnRyZWfDoSBQQVJBIFJFVklTQVIgeSBkZWNpbG87IGVsIGludGVncmFkb3IgbG8gY29ycmUgZGUgbnVldm8gY29uIGxhIG3DoXF1aW5hIHRyYW5xdWlsYS5cIixcbn1cblxuXG5jbGFzcyBDb250ZXh0bzpcbiAgICBkZWYgX19pbml0X18oc2VsZiwgbm9tYnJhLCB0b3BlPU5vbmUsIGVudj1Ob25lLCBlc2NyaXRvcz1Ob25lLCBkaXI9XCIuXCIpOlxuICAgICAgICBzZWxmLm5vbWJyYSwgc2VsZi50b3BlLCBzZWxmLmRpciA9IG5vbWJyYSwgdG9wZSwgZGlyXG4gICAgICAgIHNlbGYuZW52ID0gZGljdChlbnYgb3Ige30pXG4gICAgICAgIHNlbGYuZXNjcml0b3MgPSBlc2NyaXRvcyBpZiBlc2NyaXRvcyBpcyBub3QgTm9uZSBlbHNlIHt9XG4gICAgICAgIHNlbGYuYnVjbGVzID0gW11cbiAgICAgICAgc2VsZi5mdW5jaW9uZXMsIHNlbGYuZGVmaW5pZW5kbywgc2VsZi5sbGF2ZXMgPSB7fSwgTm9uZSwgMFxuXG4gICAgZGVmIGhpam8oc2VsZiwgdG9wZT1Ob25lKTpcbiAgICAgICAgXCJcIlwiUGFyYSBlbCB0ZXh0byBxdWUgY29ycmUgb3RybyAoYmFzaCAtYywgZXZhbCk6IHN1IHByb3BpbyBzaGVsbC5cIlwiXCJcbiAgICAgICAgcmV0dXJuIENvbnRleHRvKHNlbGYubm9tYnJhLCB0b3BlIGlmIHRvcGUgaXMgbm90IE5vbmUgZWxzZSBzZWxmLnRvcGUsIHNlbGYuZW52LCBzZWxmLmVzY3JpdG9zLCBzZWxmLmRpcilcblxuICAgIGRlZiBjZChzZWxmLCBhcmdzKTpcbiAgICAgICAgXCJcIlwiU2lndWUgbG9zIGBjZGA6IE5vbmUgc2kgeWEgbm8gc2Ugc2FiZSBkw7NuZGUgZXN0w6EuXCJcIlwiXG4gICAgICAgIGRlc3Rpbm8gPSBuZXh0KChhIGZvciBhIGluIGFyZ3MgaWYgbm90IGEuc3RhcnRzd2l0aChcIi1cIikgb3IgYSA9PSBcIi1cIiksIE5vbmUpXG4gICAgICAgIGlmIHNlbGYuZGlyIGlzIE5vbmUgb3IgZGVzdGlubyBpcyBOb25lIG9yIGRlc3Rpbm8gPT0gXCItXCIgb3IgXCIkXCIgaW4gZGVzdGlubyBvciBkZXN0aW5vLnN0YXJ0c3dpdGgoXCJ+XCIpOlxuICAgICAgICAgICAgc2VsZi5kaXIgPSBOb25lXG4gICAgICAgIGVsc2U6XG4gICAgICAgICAgICBzZWxmLmRpciA9IG9zLnBhdGgubm9ybXBhdGgob3MucGF0aC5qb2luKHNlbGYuZGlyLCBkZXN0aW5vKSlcblxuXG5kZWYgc2VndW5kb3Mocyk6XG4gICAgbSA9IHJlLmZ1bGxtYXRjaChyXCIoXFxkKyg/OlxcLlxcZCspPykoW3NtaGRdPylcIiwgcylcbiAgICBpZiBub3QgbTpcbiAgICAgICAgcmV0dXJuIE5vbmVcbiAgICByZXR1cm4gZmxvYXQobS5ncm91cCgxKSkgKiB7XCJcIjogMSwgXCJzXCI6IDEsIFwibVwiOiA2MCwgXCJoXCI6IDM2MDAsIFwiZFwiOiA4NjQwMH1bbS5ncm91cCgyKV1cblxuXG5kZWYgc2FsdGVhcl9vcGNpb25lcyhwcywgaSwgcHJvZyk6XG4gICAgXCJcIlwiw41uZGljZSBkZSBsYSBwcmltZXJhIHBhbGFicmEgcXVlIG5vIGVzIG9wY2nDs24gZGUgYHByb2dgLlwiXCJcIlxuICAgIHZhbG9yID0gQ09OX1ZBTE9SLmdldChwcm9nLCBzZXQoKSlcbiAgICB3aGlsZSBpIDwgbGVuKHBzKSBhbmQgcHNbaV0uc3RhcnRzd2l0aChcIi1cIikgYW5kIHBzW2ldICE9IFwiLVwiOlxuICAgICAgICB3ID0gcHNbaV1cbiAgICAgICAgaSArPSAxXG4gICAgICAgIGlmIHcgPT0gXCItLVwiOlxuICAgICAgICAgICAgYnJlYWtcbiAgICAgICAgaWYgbm90IHcuc3RhcnRzd2l0aChcIi0tXCIpIGFuZCB3Wy0xXSBpbiB2YWxvcjpcbiAgICAgICAgICAgIGkgKz0gMVxuICAgIHJldHVybiBpXG5cblxuZGVmIGRlc2Vudm9sdmVyKHBzLCBlbnYsIGZ1bmNpb25lcz1Ob25lKTpcbiAgICBcIlwiXCIocHJvZ3JhbWEsIGFyZ3VtZW50b3MsIHRvcGUpIGRlIGxvIHF1ZSBkZSB2ZXJkYWQgY29ycmU7IHN1bWEgYSBlbnYgbGFzXG4gICAgYXNpZ25hY2lvbmVzIGRlIGFkZWxhbnRlIHkgbGFzIGRlIGBlbnYgWD0xYC5cIlwiXCJcbiAgICB0b3BlLCBpID0gTm9uZSwgMFxuICAgIHdoaWxlIFRydWU6XG4gICAgICAgIHdoaWxlIGkgPCBsZW4ocHMpIGFuZCBBU0lHTkEubWF0Y2gocHNbaV0pOlxuICAgICAgICAgICAgaywgXywgdiA9IHBzW2ldLnBhcnRpdGlvbihcIj1cIilcbiAgICAgICAgICAgIGVudltrXSA9IHZcbiAgICAgICAgICAgIGkgKz0gMVxuICAgICAgICBpZiBpID49IGxlbihwcyk6XG4gICAgICAgICAgICByZXR1cm4gTm9uZSwgW10sIHRvcGVcbiAgICAgICAgcHJvZyA9IG9zLnBhdGguYmFzZW5hbWUocHNbaV0pXG4gICAgICAgIGlmIChmdW5jaW9uZXMgb3Ige30pLmdldChwc1tpXSkgaXMgbm90IE5vbmU6XG4gICAgICAgICAgICBzID0gZnVuY2lvbmVzW3BzW2ldXVxuICAgICAgICAgICAgdG9wZSA9IHMgaWYgdG9wZSBpcyBOb25lIGVsc2UgbWluKHRvcGUsIHMpXG4gICAgICAgICAgICBpICs9IDFcbiAgICAgICAgZWxpZiBwcm9nIGluIChcImVudlwiLCBcInN1ZG9cIiwgXCJub2h1cFwiLCBcImV4ZWNcIiwgXCJuaWNlXCIsIFwiY2FmZmVpbmF0ZVwiLCBcInRhc2twb2xpY3lcIiwgXCJ4YXJnc1wiLCBcImJ1aWx0aW5cIik6XG4gICAgICAgICAgICBpID0gc2FsdGVhcl9vcGNpb25lcyhwcywgaSArIDEsIHByb2cpXG4gICAgICAgIGVsaWYgcHJvZyA9PSBcInRpbWVcIjpcbiAgICAgICAgICAgIGkgPSBzYWx0ZWFyX29wY2lvbmVzKHBzLCBpICsgMSwgcHJvZylcbiAgICAgICAgZWxpZiBwcm9nID09IFwiY29tbWFuZFwiIGFuZCBub3QgKGkgKyAxIDwgbGVuKHBzKSBhbmQgcHNbaSArIDFdIGluIChcIi12XCIsIFwiLVZcIikpOlxuICAgICAgICAgICAgaSA9IHNhbHRlYXJfb3BjaW9uZXMocHMsIGkgKyAxLCBwcm9nKVxuICAgICAgICBlbGlmIHByb2cgaW4gKFwidGltZW91dFwiLCBcImd0aW1lb3V0XCIpOlxuICAgICAgICAgICAgaSA9IHNhbHRlYXJfb3BjaW9uZXMocHMsIGkgKyAxLCBcInRpbWVvdXRcIilcbiAgICAgICAgICAgIGlmIGkgPCBsZW4ocHMpOlxuICAgICAgICAgICAgICAgIHMgPSBzZWd1bmRvcyhwc1tpXSlcbiAgICAgICAgICAgICAgICB0b3BlID0gcyBpZiB0b3BlIGlzIE5vbmUgZWxzZSBtaW4odG9wZSwgcyBvciB0b3BlKVxuICAgICAgICAgICAgICAgIGkgKz0gMVxuICAgICAgICBlbGlmIHByb2cgPT0gXCJjb25fdG9wZVwiIGFuZCBpICsgMSA8IGxlbihwcyk6XG4gICAgICAgICAgICBzID0gc2VndW5kb3MocHNbaSArIDFdKVxuICAgICAgICAgICAgdG9wZSA9IHMgaWYgdG9wZSBpcyBOb25lIGVsc2UgbWluKHRvcGUsIHMgb3IgdG9wZSlcbiAgICAgICAgICAgIGkgKz0gMlxuICAgICAgICBlbGlmIHByb2cgPT0gXCJjb25fbHVnYXJcIjpcbiAgICAgICAgICAgIGkgKz0gMVxuICAgICAgICBlbGlmIHByb2cgPT0gXCJwZXJsXCIgYW5kIGkgKyAyIDwgbGVuKHBzKSBhbmQgcHNbaSArIDFdIGluIChcIi1lXCIsIFwiLUVcIikgYW5kIHJlLnNlYXJjaChyXCJleGVjXFxzKlxcKD9cXHMqQEFSR1ZcIiwgcHNbaSArIDJdKTpcbiAgICAgICAgICAgIGNvZGlnbyA9IHBzW2kgKyAyXVxuICAgICAgICAgICAgaSArPSAzXG4gICAgICAgICAgICBpZiBpIDwgbGVuKHBzKSBhbmQgcHNbaV0gPT0gXCItLVwiOlxuICAgICAgICAgICAgICAgIGkgKz0gMVxuICAgICAgICAgICAgYWxhcm1hcyA9IFtpbnQoeCkgZm9yIHggaW4gcmUuZmluZGFsbChyXCJhbGFybVxccypcXCg/XFxzKihcXGQrKVwiLCBjb2RpZ28pXVxuICAgICAgICAgICAgaWYgcmUuc2VhcmNoKHJcImFsYXJtXFxzKlxcKD9cXHMqc2hpZnRcIiwgY29kaWdvKSBhbmQgaSA8IGxlbihwcyk6XG4gICAgICAgICAgICAgICAgYWxhcm1hcy5hcHBlbmQoaW50KHNlZ3VuZG9zKHBzW2ldKSBvciAwKSlcbiAgICAgICAgICAgICAgICBpICs9IDFcbiAgICAgICAgICAgIGlmIGFsYXJtYXM6XG4gICAgICAgICAgICAgICAgdG9wZSA9IGFsYXJtYXNbMF0gaWYgdG9wZSBpcyBOb25lIGVsc2UgbWluKHRvcGUsIGFsYXJtYXNbMF0pXG4gICAgICAgIGVsc2U6XG4gICAgICAgICAgICByZXR1cm4gcHNbaV0sIHBzW2kgKyAxOl0sIHRvcGVcblxuXG5kZWYgZXNfZ29kb3QocGFsYWJyYSwgY3R4KTpcbiAgICBpZiBwYWxhYnJhLnN0YXJ0c3dpdGgoXCIkXCIpOlxuICAgICAgICByZXR1cm4gY3R4Lm5vbWJyYVxuICAgIGJhc2UgPSBvcy5wYXRoLmJhc2VuYW1lKHBhbGFicmEpXG4gICAgaWYgcmUubWF0Y2goclwiXmdvZG90XCIsIGJhc2UsIHJlLkkpIG9yIGJhc2UgPT0gXCJnb2RvdF9zaW5fZm9jby5zaFwiOlxuICAgICAgICByZXR1cm4gVHJ1ZVxuICAgIGlmIFwiL1wiIG5vdCBpbiBwYWxhYnJhIG9yIGJhc2Ugbm90IGluIExBTlpBRE9SRVM6XG4gICAgICAgIHJldHVybiBGYWxzZVxuICAgIHJ1dGEgPSBwYWxhYnJhIGlmIG9zLnBhdGguaXNhYnMocGFsYWJyYSkgb3IgY3R4LmRpciBpcyBOb25lIGVsc2Ugb3MucGF0aC5qb2luKGN0eC5kaXIsIHBhbGFicmEpXG4gICAgaWYgbm90IG9zLnBhdGguaXNmaWxlKHJ1dGEpOlxuICAgICAgICByZXR1cm4gVHJ1ZVxuICAgIHJldHVybiBvcy5wYXRoLmlzZmlsZShvcy5wYXRoLmpvaW4ob3MucGF0aC5kaXJuYW1lKHJ1dGEpLCBcInByb2plY3QuZ29kb3RcIikpXG5cblxuZGVmIG9wY2lvbmVzX2RlX3NoZWxsKGFyZ3MpOlxuICAgIFwiXCJcIihjw7NkaWdvIGRlIC1jIG8gTm9uZSwgZWwgc2NyaXB0IG8gTm9uZSwgc2kgc8OzbG8gcmV2aXNhIGNvbiAtbikuXCJcIlwiXG4gICAgaSA9IDBcbiAgICBjb25fYyA9IHNvbG9fbiA9IEZhbHNlXG4gICAgd2hpbGUgaSA8IGxlbihhcmdzKSBhbmQgYXJnc1tpXS5zdGFydHN3aXRoKFwiLVwiKSBhbmQgYXJnc1tpXSBub3QgaW4gKFwiLVwiLCBcIi0tXCIpOlxuICAgICAgICB3ID0gYXJnc1tpXVxuICAgICAgICBpZiBub3Qgdy5zdGFydHN3aXRoKFwiLS1cIik6XG4gICAgICAgICAgICBjb25fYyA9IGNvbl9jIG9yIFwiY1wiIGluIHdbMTpdXG4gICAgICAgICAgICBzb2xvX24gPSBzb2xvX24gb3IgXCJuXCIgaW4gd1sxOl1cbiAgICAgICAgaSArPSAxXG4gICAgICAgIGlmIHcgaW4gKFwiLW9cIiwgXCItT1wiLCBcIitvXCIsIFwiK09cIikgYW5kIGkgPCBsZW4oYXJncyk6XG4gICAgICAgICAgICBpICs9IDFcbiAgICBpZiBpIDwgbGVuKGFyZ3MpIGFuZCBhcmdzW2ldID09IFwiLS1cIjpcbiAgICAgICAgaSArPSAxXG4gICAgaWYgY29uX2M6XG4gICAgICAgIHJldHVybiAoYXJnc1tpXSBpZiBpIDwgbGVuKGFyZ3MpIGVsc2UgXCJcIiksIE5vbmUsIHNvbG9fblxuICAgIHJldHVybiBOb25lLCAoYXJnc1tpXSBpZiBpIDwgbGVuKGFyZ3MpIGVsc2UgTm9uZSksIHNvbG9fblxuXG5cbmRlZiByZW1vdG9fZGVfc3NoKGFyZ3MpOlxuICAgIGkgPSBzYWx0ZWFyX29wY2lvbmVzKGFyZ3MsIDAsIFwic3NoXCIpXG4gICAgcmV0dXJuIGFyZ3NbaSArIDE6XSBpZiBpIDwgbGVuKGFyZ3MpIGVsc2UgW11cblxuXG5kZWYgbGVlX3N0ZGluKHByb2csIGFyZ3MpOlxuICAgIFwiXCJcIsK/RWplY3V0YSBsbyBxdWUgbGUgbGxlZ2EgcG9yIGxhIGVudHJhZGE/IChgYmFzaGAsIGBzaCAtc2AsIGBzc2ggaG9zdGApLlwiXCJcIlxuICAgIGlmIHByb2cgaXMgTm9uZTpcbiAgICAgICAgcmV0dXJuIEZhbHNlXG4gICAgYmFzZSA9IG9zLnBhdGguYmFzZW5hbWUocHJvZylcbiAgICBpZiBiYXNlIGluIFNIRUxMUzpcbiAgICAgICAgY29kaWdvLCBzY3JpcHQsIHNvbG9fbiA9IG9wY2lvbmVzX2RlX3NoZWxsKGFyZ3MpXG4gICAgICAgIHJldHVybiBjb2RpZ28gaXMgTm9uZSBhbmQgc2NyaXB0IGlzIE5vbmUgYW5kIG5vdCBzb2xvX25cbiAgICBpZiBiYXNlID09IFwic3NoXCI6XG4gICAgICAgIHJldHVybiBub3QgcmVtb3RvX2RlX3NzaChhcmdzKVxuICAgIGlmIGJhc2UgaW4gKFwic291cmNlXCIsIFwiLlwiKTpcbiAgICAgICAgcmV0dXJuIG5vdCBhcmdzIG9yIGFyZ3NbMF0gaW4gKFwiL2Rldi9zdGRpblwiLCBcIi1cIilcbiAgICByZXR1cm4gRmFsc2VcblxuXG5kZWYgY29tYW5kb3ModHViZXJpYXMpOlxuICAgIGZvciB0dWJvIGluIHR1YmVyaWFzOlxuICAgICAgICBmb3IgYyBpbiB0dWJvOlxuICAgICAgICAgICAgeWllbGQgY1xuICAgICAgICAgICAgZm9yIHN1YiBpbiBjLnN1YnM6XG4gICAgICAgICAgICAgICAgeWllbGQgZnJvbSBjb21hbmRvcyhzdWIpXG5cblxuZGVmIGFub3Rhcl9lc2NyaXRvcyh0dWJlcmlhcywgZXNjcml0b3MpOlxuICAgIFwiXCJcIkxvIHF1ZSB1biBoZXJlZG9jIGRlamEgZW4gdW4gYXJjaGl2byAoYGNhdCA+IHguc2ggPDxFT0ZgLCBgdGVlIHguc2ggPDxFT0ZgKS5cIlwiXCJcbiAgICBmb3IgYyBpbiBjb21hbmRvcyh0dWJlcmlhcyk6XG4gICAgICAgIGRlc3Rpbm9zID0gbGlzdChjLmVzY3JpYmUpXG4gICAgICAgIGlmIGMucGFsYWJyYXMgYW5kIG9zLnBhdGguYmFzZW5hbWUoYy5wYWxhYnJhc1swXSkgPT0gXCJ0ZWVcIjpcbiAgICAgICAgICAgIGRlc3Rpbm9zICs9IFtwIGZvciBwIGluIGMucGFsYWJyYXNbMTpdIGlmIG5vdCBwLnN0YXJ0c3dpdGgoXCItXCIpXVxuICAgICAgICBmb3IgZCBpbiBkZXN0aW5vczpcbiAgICAgICAgICAgIGZvciBjbGF2ZSBpbiAoZC5yZW1vdmVwcmVmaXgoXCIuL1wiKSwgb3MucGF0aC5iYXNlbmFtZShkKSk6XG4gICAgICAgICAgICAgICAgZXNjcml0b3Muc2V0ZGVmYXVsdChjbGF2ZSwgW10pLmV4dGVuZChjLmN1ZXJwb3MpXG5cblxuZGVmIGNvcnJlX2VzY3JpdG8ocGFsYWJyYSwgY3R4KTpcbiAgICBpZiBub3QgcGFsYWJyYTpcbiAgICAgICAgcmV0dXJuXG4gICAgZm9yIGNsYXZlIGluIChwYWxhYnJhLnJlbW92ZXByZWZpeChcIi4vXCIpLCBvcy5wYXRoLmJhc2VuYW1lKHBhbGFicmEpKTpcbiAgICAgICAgZm9yIGN1ZXJwbyBpbiBjdHguZXNjcml0b3MucG9wKGNsYXZlLCBbXSk6XG4gICAgICAgICAgICBqdXpnYXJfdGV4dG8oY3VlcnBvLCBjdHguaGlqbygpKVxuXG5cbmRlZiByZWdsYV9naXQoYXJncyk6XG4gICAgaSA9IDBcbiAgICB3aGlsZSBpIDwgbGVuKGFyZ3MpIGFuZCBhcmdzW2ldLnN0YXJ0c3dpdGgoXCItXCIpOlxuICAgICAgICB3ID0gYXJnc1tpXVxuICAgICAgICBpICs9IDFcbiAgICAgICAgaWYgdyBpbiBHSVRfQ09OX1ZBTE9SOlxuICAgICAgICAgICAgaSArPSAxXG4gICAgaWYgaSA+PSBsZW4oYXJncyk6XG4gICAgICAgIHJldHVyblxuICAgIHN1YiwgcmVzdG8gPSBhcmdzW2ldLCBhcmdzW2kgKyAxOl1cbiAgICBpZiBzdWIgaW4gKFwic3Rhc2hcIiwgXCJyZXNldFwiLCBcInJlYmFzZVwiLCBcInN3aXRjaFwiKTpcbiAgICAgICAgcmFpc2UgRnJlbmEoXCJwaXNhXCIpXG4gICAgaWYgc3ViID09IFwiY2hlY2tvdXRcIiBhbmQgXCItLVwiIG5vdCBpbiByZXN0bzpcbiAgICAgICAgcmFpc2UgRnJlbmEoXCJjaGVja291dFwiKVxuICAgIGlmIHN1YiA9PSBcImFkZFwiOlxuICAgICAgICBmb3IgdyBpbiByZXN0bzpcbiAgICAgICAgICAgIGlmIHcgaW4gKFwiLUFcIiwgXCItLWFsbFwiLCBcIi5cIiwgXCIuL1wiLCBcIjovXCIsIFwiOi86XCIpIG9yIHJlLmZ1bGxtYXRjaChyXCItW2EtekEtWl0qQVthLXpBLVpdKlwiLCB3KTpcbiAgICAgICAgICAgICAgICByYWlzZSBGcmVuYShcImFkZFwiKVxuICAgIGlmIHN1YiA9PSBcImNvbW1pdFwiOlxuICAgICAgICBzYWx0YXIgPSBGYWxzZVxuICAgICAgICBmb3IgdyBpbiByZXN0bzpcbiAgICAgICAgICAgIGlmIHNhbHRhcjpcbiAgICAgICAgICAgICAgICBzYWx0YXIgPSBGYWxzZVxuICAgICAgICAgICAgZWxpZiB3ID09IFwiLS1cIjpcbiAgICAgICAgICAgICAgICBicmVha1xuICAgICAgICAgICAgZWxpZiB3ID09IFwiLS1hbGxcIjpcbiAgICAgICAgICAgICAgICByYWlzZSBGcmVuYShcImNvbW1pdFwiKVxuICAgICAgICAgICAgZWxpZiB3IGluIENPTU1JVF9MQVJHQVM6XG4gICAgICAgICAgICAgICAgc2FsdGFyID0gVHJ1ZVxuICAgICAgICAgICAgZWxpZiB3LnN0YXJ0c3dpdGgoXCItXCIpIGFuZCBub3Qgdy5zdGFydHN3aXRoKFwiLS1cIik6XG4gICAgICAgICAgICAgICAgZm9yIGosIGNoIGluIGVudW1lcmF0ZSh3WzE6XSk6XG4gICAgICAgICAgICAgICAgICAgIGlmIGNoID09IFwiYVwiOlxuICAgICAgICAgICAgICAgICAgICAgICAgcmFpc2UgRnJlbmEoXCJjb21taXRcIilcbiAgICAgICAgICAgICAgICAgICAgaWYgY2ggaW4gQ09NTUlUX0NPTl9WQUxPUjpcbiAgICAgICAgICAgICAgICAgICAgICAgIHNhbHRhciA9IGogPT0gbGVuKHcpIC0gMlxuICAgICAgICAgICAgICAgICAgICAgICAgYnJlYWtcblxuXG5kZWYgcmVnbGFfZ29kb3QocHJvZywgYXJncywgdG9wZSwgZW52LCBjdHgpOlxuICAgIGJhc2UgPSBvcy5wYXRoLmJhc2VuYW1lKHByb2cpXG4gICAgbGFuemEgPSBlc19nb2RvdChwcm9nLCBjdHgpXG4gICAgaWYgYmFzZSBpbiBTSEVMTFM6XG4gICAgICAgIGNvZGlnbywgc2NyaXB0LCBzb2xvX24gPSBvcGNpb25lc19kZV9zaGVsbChhcmdzKVxuICAgICAgICBsYW56YSA9IGNvZGlnbyBpcyBOb25lIGFuZCBub3Qgc29sb19uIGFuZCBzY3JpcHQgaXMgbm90IE5vbmUgYW5kIGVzX2dvZG90KHNjcmlwdCwgY3R4KVxuICAgIGlmIG5vdCBsYW56YSBvciBcIi0tdmVyc2lvblwiIGluIGFyZ3Mgb3IgXCItLWhlbHBcIiBpbiBhcmdzOlxuICAgICAgICByZXR1cm5cbiAgICBpZiB0b3BlIGlzIE5vbmU6XG4gICAgICAgIHJhaXNlIEZyZW5hKFwiZ29kb3RcIilcbiAgICB0cnk6XG4gICAgICAgIGdvZG90X3RvcGUgPSBpbnQoZW52LmdldChcIkdPRE9UX1RPUEVcIiwgXCIwXCIpKVxuICAgIGV4Y2VwdCBWYWx1ZUVycm9yOlxuICAgICAgICBnb2RvdF90b3BlID0gMFxuICAgIGlmIHRvcGUgPiAxODAwIG9yIGdvZG90X3RvcGUgPiA5MDA6XG4gICAgICAgIHJhaXNlIEZyZW5hKFwidG9wZVwiKVxuXG5cbmRlZiBqdXpnYXJfY29tYW5kbyhjLCBjdHgsIGVudHJhZGFfY29ycmUpOlxuICAgIGZvciBzdWIgaW4gYy5zdWJzOlxuICAgICAgICBqdXpnYXIoc3ViLCBjdHguaGlqbygpKVxuICAgIGZvciBjbGF2ZSBpbiBjLmNsYXZlczpcbiAgICAgICAgaWYgY2xhdmUgaW4gQUJSRV9CVUNMRTpcbiAgICAgICAgICAgIGN0eC5idWNsZXMuYXBwZW5kKGNsYXZlKVxuICAgICAgICBlbGlmIGNsYXZlID09IFwiZG9uZVwiIGFuZCBjdHguYnVjbGVzOlxuICAgICAgICAgICAgY3R4LmJ1Y2xlcy5wb3AoKVxuICAgIGlmIGMuZnVuY2lvbjpcbiAgICAgICAgY3R4LmZ1bmNpb25lc1tjLmZ1bmNpb25dID0gTm9uZVxuICAgICAgICBjdHguZGVmaW5pZW5kbyA9IChjLmZ1bmNpb24sIGN0eC5sbGF2ZXMpXG4gICAgY3R4LmxsYXZlcyArPSBjLmNsYXZlcy5jb3VudChcIntcIikgLSBjLmNsYXZlcy5jb3VudChcIn1cIilcbiAgICBlbnYgPSBkaWN0KGN0eC5lbnYpXG4gICAgcHJvZywgYXJncywgdG9wZV9wcm9waW8gPSBkZXNlbnZvbHZlcihjLnBhbGFicmFzLCBlbnYsIGN0eC5mdW5jaW9uZXMpXG4gICAgaWYgYy5wYWxhYnJhcyBhbmQgcHJvZyBpcyBOb25lIG9yIGMucGFsYWJyYXNbOjFdID09IFtcImV4cG9ydFwiXTpcbiAgICAgICAgY3R4LmVudi51cGRhdGUoe2s6IHYgZm9yIGssIF8sIHYgaW4gKHAucGFydGl0aW9uKFwiPVwiKSBmb3IgcCBpbiBjLnBhbGFicmFzIGlmIEFTSUdOQS5tYXRjaChwKSl9KVxuICAgIHRvcGUgPSBtaW4odCBmb3IgdCBpbiAoY3R4LnRvcGUsIHRvcGVfcHJvcGlvKSBpZiB0IGlzIG5vdCBOb25lKSBpZiAoY3R4LnRvcGUgb3IgdG9wZV9wcm9waW8pIGVsc2UgTm9uZVxuICAgIGlmIGN0eC5kZWZpbmllbmRvIGFuZCBwcm9nIGluIChcIiRAXCIsIFwiJCpcIikgYW5kIHRvcGUgaXMgbm90IE5vbmU6XG4gICAgICAgIGN0eC5mdW5jaW9uZXNbY3R4LmRlZmluaWVuZG9bMF1dID0gdG9wZVxuICAgIGlmIGN0eC5kZWZpbmllbmRvIGFuZCBjdHgubGxhdmVzIDw9IGN0eC5kZWZpbmllbmRvWzFdOlxuICAgICAgICBjdHguZGVmaW5pZW5kbyA9IE5vbmVcbiAgICBmb3IgY3VlcnBvIGluIGMuY3VlcnBvcyBpZiBlbnRyYWRhX2NvcnJlIGVsc2UgW106XG4gICAgICAgIGp1emdhcl90ZXh0byhjdWVycG8sIGN0eC5oaWpvKHRvcGUpKVxuICAgIGlmIHByb2cgaXMgTm9uZTpcbiAgICAgICAgcmV0dXJuXG4gICAgdHJ5OlxuICAgICAgICByZWdsYXMoYywgY3R4LCBwcm9nLCBhcmdzLCB0b3BlLCBlbnYpXG4gICAgZXhjZXB0IEZyZW5hIGFzIGY6XG4gICAgICAgIGYucGFsYWJyYXMgPSBmLnBhbGFicmFzIG9yIGMucGFsYWJyYXNcbiAgICAgICAgcmFpc2VcblxuXG5kZWYgcmVnbGFzKGMsIGN0eCwgcHJvZywgYXJncywgdG9wZSwgZW52KTpcbiAgICBiYXNlID0gb3MucGF0aC5iYXNlbmFtZShwcm9nKVxuICAgIGlmIGJhc2UgaW4gKFwiY2RcIiwgXCJwdXNoZFwiKTpcbiAgICAgICAgY3R4LmNkKGFyZ3MpXG4gICAgaWYgcHJvZyBpbiBjdHguZnVuY2lvbmVzOlxuICAgICAgICByZXR1cm5cbiAgICBpZiBiYXNlIGluIChcInBraWxsXCIsIFwia2lsbGFsbFwiKTpcbiAgICAgICAgcmFpc2UgRnJlbmEoXCJtYXRhclwiKVxuICAgIGlmIGJhc2UgPT0gXCJnaXRcIjpcbiAgICAgICAgcmVnbGFfZ2l0KGFyZ3MpXG4gICAgaWYgYmFzZSA9PSBcInNsZWVwXCIgYW5kIChzZXQoY3R4LmJ1Y2xlcykgJiB7XCJ3aGlsZVwiLCBcInVudGlsXCJ9KSBhbmQgdG9wZSBpcyBOb25lOlxuICAgICAgICByYWlzZSBGcmVuYShcImJ1Y2xlXCIpXG4gICAgcmVnbGFfZ29kb3QocHJvZywgYXJncywgdG9wZSwgZW52LCBjdHgpXG4gICAgdGV4dG8gPSBOb25lXG4gICAgaWYgYmFzZSBpbiBTSEVMTFM6XG4gICAgICAgIGNvZGlnbywgc2NyaXB0LCBzb2xvX24gPSBvcGNpb25lc19kZV9zaGVsbChhcmdzKVxuICAgICAgICBpZiBub3Qgc29sb19uOlxuICAgICAgICAgICAgdGV4dG8gPSBjb2RpZ29cbiAgICAgICAgICAgIGNvcnJlX2VzY3JpdG8oc2NyaXB0LCBjdHgpXG4gICAgZWxpZiBiYXNlID09IFwiZXZhbFwiOlxuICAgICAgICB0ZXh0byA9IFwiIFwiLmpvaW4oYXJncylcbiAgICBlbGlmIGJhc2UgPT0gXCJzc2hcIjpcbiAgICAgICAgdGV4dG8gPSBcIiBcIi5qb2luKHJlbW90b19kZV9zc2goYXJncykpIG9yIE5vbmVcbiAgICBlbGlmIGJhc2UgPT0gXCJzdVwiIGFuZCBcIi1jXCIgaW4gYXJnc1s6LTFdOlxuICAgICAgICB0ZXh0byA9IGFyZ3NbYXJncy5pbmRleChcIi1jXCIpICsgMV1cbiAgICBlbGlmIGJhc2UgaW4gKFwic291cmNlXCIsIFwiLlwiKTpcbiAgICAgICAgY29ycmVfZXNjcml0byhhcmdzWzBdIGlmIGFyZ3MgZWxzZSBOb25lLCBjdHgpXG4gICAgY29ycmVfZXNjcml0byhwcm9nLCBjdHgpXG4gICAgaWYgdGV4dG8gaXMgbm90IE5vbmU6XG4gICAgICAgIGp1emdhcl90ZXh0byh0ZXh0bywgY3R4Lmhpam8odG9wZSkpXG4gICAgICAgIGZvciBzYyBpbiBjb21hbmRvcyhbW2NdXSk6XG4gICAgICAgICAgICBmb3IgY3VlcnBvIGluIHNjLmN1ZXJwb3MgaWYgc2MgaXMgbm90IGMgZWxzZSBbXTpcbiAgICAgICAgICAgICAgICBqdXpnYXJfdGV4dG8oY3VlcnBvLCBjdHguaGlqbyh0b3BlKSlcblxuXG5kZWYganV6Z2FyKHR1YmVyaWFzLCBjdHgpOlxuICAgIGFub3Rhcl9lc2NyaXRvcyh0dWJlcmlhcywgY3R4LmVzY3JpdG9zKVxuICAgIGZvciB0dWJvIGluIHR1YmVyaWFzOlxuICAgICAgICBlbnRyYWRhX2NvcnJlID0gRmFsc2VcbiAgICAgICAgZm9yIGMgaW4gdHVibzpcbiAgICAgICAgICAgIGVudiA9IGRpY3QoY3R4LmVudilcbiAgICAgICAgICAgIHByb2csIGFyZ3MsIF8gPSBkZXNlbnZvbHZlcihjLnBhbGFicmFzLCBlbnYsIGN0eC5mdW5jaW9uZXMpXG4gICAgICAgICAgICBlbnRyYWRhX2NvcnJlID0gZW50cmFkYV9jb3JyZSBvciBsZWVfc3RkaW4ocHJvZywgYXJncylcbiAgICAgICAgZm9yIGMgaW4gdHVibzpcbiAgICAgICAgICAgIGp1emdhcl9jb21hbmRvKGMsIGN0eCwgZW50cmFkYV9jb3JyZSlcblxuXG5kZWYganV6Z2FyX3RleHRvKHRleHRvLCBjdHgpOlxuICAgIHRyeTpcbiAgICAgICAgdHViZXJpYXMgPSBwYXJ0aXIodGV4dG8pXG4gICAgZXhjZXB0IEFiaWVydG86XG4gICAgICAgIHR1YmVyaWFzID0gYV9sb19icnV0byh0ZXh0bylcbiAgICBqdXpnYXIodHViZXJpYXMsIGN0eClcblxuXG5kZWYgZXh0cmFlcihyYXcpOlxuICAgIFwiXCJcIkVsIGNvbWFuZG86IGVsIHRleHRvIHRhbCBjdWFsLCBvIGVsIGRlIHVuIEpTT04gZGUgaG9vayAoXCJcIiBzaSBsYVxuICAgIGhlcnJhbWllbnRhIG5vIGVzIGRlIHNoZWxsOiBlZGl0YXIgbyBsZWVyIHVuIGFyY2hpdm8gbm8gdGllbmUgY29tYW5kbykuXCJcIlwiXG4gICAgdHJ5OlxuICAgICAgICBkID0ganNvbi5sb2FkcyhyYXcpXG4gICAgZXhjZXB0IEV4Y2VwdGlvbjpcbiAgICAgICAgcmV0dXJuIHJhd1xuICAgIGlmIGlzaW5zdGFuY2UoZCwgZGljdCkgYW5kIFwidG9vbF9uYW1lXCIgaW4gZDpcbiAgICAgICAgaWYgbm90IHJlLnNlYXJjaChyXCJiYXNofHNoZWxsfGV4ZWN8Y29tbWFuZHx0ZXJtaW5hbHxydW5cIiwgc3RyKGRbXCJ0b29sX25hbWVcIl0pLCByZS5JKTpcbiAgICAgICAgICAgIHJldHVybiBcIlwiXG5cbiAgICBkZWYgc2FjYShkKTpcbiAgICAgICAgaWYgaXNpbnN0YW5jZShkLCBzdHIpOlxuICAgICAgICAgICAgcmV0dXJuIGRcbiAgICAgICAgaWYgaXNpbnN0YW5jZShkLCBsaXN0KTpcbiAgICAgICAgICAgIHJldHVybiBcIiBcIi5qb2luKHN0cih4KSBmb3IgeCBpbiBkKVxuICAgICAgICBpZiBpc2luc3RhbmNlKGQsIGRpY3QpOlxuICAgICAgICAgICAgZm9yIGsgaW4gKFwidG9vbF9pbnB1dFwiLCBcImlucHV0XCIsIFwiYXJndW1lbnRzXCIsIFwicGFyYW1zXCIpOlxuICAgICAgICAgICAgICAgIGlmIGsgaW4gZDpcbiAgICAgICAgICAgICAgICAgICAgciA9IHNhY2EoZFtrXSlcbiAgICAgICAgICAgICAgICAgICAgaWYgcjpcbiAgICAgICAgICAgICAgICAgICAgICAgIHJldHVybiByXG4gICAgICAgICAgICBmb3IgayBpbiAoXCJjb21tYW5kXCIsIFwiY21kXCIpOlxuICAgICAgICAgICAgICAgIGlmIGsgaW4gZDpcbiAgICAgICAgICAgICAgICAgICAgcmV0dXJuIHNhY2EoZFtrXSlcbiAgICAgICAgcmV0dXJuIFwiXCJcbiAgICByZXR1cm4gc2FjYShkKVxuXG5cbmRlZiBtb3Rpdm8oY21kKTpcbiAgICBcIlwiXCJOb25lIHNpIHBhc2E7IHNpIG5vLCBlbCBtb3Rpdm8uXCJcIlwiXG4gICAgaWYgbm90IGNtZC5zdHJpcCgpOlxuICAgICAgICByZXR1cm4gTm9uZVxuICAgIHRyeTpcbiAgICAgICAgdHJ5OlxuICAgICAgICAgICAganV6Z2FyX3RleHRvKGNtZCwgQ29udGV4dG8oYm9vbChOT01CUkFfR09ET1Quc2VhcmNoKGNtZCkpKSlcbiAgICAgICAgZXhjZXB0IChGcmVuYSwgUmVjdXJzaW9uRXJyb3IpOlxuICAgICAgICAgICAgcmFpc2VcbiAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbjpcbiAgICAgICAgICAgIGp1emdhcihhX2xvX2JydXRvKGNtZCksIENvbnRleHRvKGJvb2woTk9NQlJBX0dPRE9ULnNlYXJjaChjbWQpKSkpXG4gICAgZXhjZXB0IFJlY3Vyc2lvbkVycm9yOlxuICAgICAgICByZXR1cm4gXCJFbCBjb21hbmRvIGFuaWRhIGRlbWFzaWFkbyBwYXJhIGxlZXJsbyAoYmFzaCAtYyBkZW50cm8gZGUgYmFzaCAtY+KApik6IHBhcnRpbG8gZW4gcGFzb3MuXCJcbiAgICBleGNlcHQgRnJlbmEgYXMgZjpcbiAgICAgICAgZW4gPSBcIiBcIi5qb2luKGYucGFsYWJyYXMpXG4gICAgICAgIHJldHVybiBNT1RJVk9TW2YuY2xhdmVdICsgKGZcIiAoZW46IHtlbls6MTIwXX0pXCIgaWYgZW4gZWxzZSBcIlwiKVxuICAgIHJldHVybiBOb25lXG5cblxuaWYgX19uYW1lX18gPT0gXCJfX21haW5fX1wiOlxuICAgIG0gPSBtb3Rpdm8oZXh0cmFlcihzeXMuc3RkaW4ucmVhZCgpKSlcbiAgICBpZiBtOlxuICAgICAgICBwcmludChmXCJbZ3VhcmRpYV0ge219XCIsIGZpbGU9c3lzLnN0ZGVycilcbiAgICAgICAgc3lzLmV4aXQoMilcbiJ9LCJzY3JpcHRzL2hvb2tzL3BhcnRpci5weSI6eyJtb2RvIjo0MjAsInRleHRvIjoiXCJcIlwiUGFydGUgdW4gY29tYW5kbyBkZSBzaGVsbCBjb21vIGxvIGhhcsOtYSBlbCBzaGVsbC4gTG8gdXNhIGp1emdhci5weS5cblxuQW50ZXMgZWwgZ3VhcmRpYSBidXNjYWJhIHBhbGFicmFzIGVuIGVsIHRleHRvICh5IHBhcmEgbm8gZnJlbmFyIGRlIG3DoXMsIHRyZXNcbnByZXByb2Nlc29zOiBzaW4gaGVyZWRvY3MsIHNpbiBjb21pbGxhcywgcXVpw6luIGxhbnphIEdvZG90KS4gQWhvcmEgZWwgY29tYW5kbyBzZVxubGVlIHVuYSB2ZXosIGNvbW8gbG8gbGVlIGJhc2g6IGNvbWlsbGFzLCBgXFxcXGAsIGAkKCApYCwgYmFja3RpY2tzLCBgPCggKWAsXG5gJCgoICkpYCwgaGVyZWRvY3MsIGNvbWVudGFyaW9zLCByZWRpcmVjY2lvbmVzLCBgO2AgYCYmYCBgfHxgIGB8YCBgJmAsIGAoIClgIHlcbmB7IH1gLiBTYWxlIHVuYSBsaXN0YSBkZSB0dWJlcsOtYXM7IGNhZGEgdHViZXLDrWEsIHVuYSBsaXN0YSBkZSBDb21hbmRvOlxuXG4tIGBwYWxhYnJhc2A6IGVsIHByb2dyYW1hIHkgc3VzIGFyZ3VtZW50b3MsIHlhIHNpbiBjb21pbGxhcyBuaSBlc2NhcGVzLiBVbmFcbiAgc3VzdGl0dWNpw7NuIHF1ZWRhIGNvbW8gYCQo4oCmKWAgZGVudHJvIGRlIHN1IHBhbGFicmE7IHVuYSB2YXJpYWJsZSwgY29tbyBgJFhgLlxuLSBgY2xhdmVzYDogbGFzIHBhbGFicmFzIGRlIHNoZWxsIHF1ZSBsbyBwcmVjZWRlbiAoaWYsIHRoZW4sIHdoaWxlLCBkbywgZG9uZeKApikuXG4tIGBzdWJzYDogbG8gcXVlIGNvcnJlIGRlbnRybyBkZSBzdXMgYCQoIClgLCBiYWNrdGlja3MgeSBgPCggKWAsIHlhIHBhcnRpZG8uXG4tIGBjdWVycG9zYDogZWwgdGV4dG8gZGUgc3VzIGhlcmVkb2NzICh0ZXh0bzogc2kgc2UgZWplY3V0YSBsbyBkZWNpZGUgZWwganVleikuXG4tIGBlc2NyaWJlYDogbG9zIGFyY2hpdm9zIGEgbG9zIHF1ZSByZWRpcmlnZSBjb24gYD5gIG8gYD4+YC5cbi0gYGZ1bmNpb25gOiBzaSBkZWZpbmUgdW5hIChgZigpIHtgLCBgZnVuY3Rpb24gZiB7YCksIHN1IG5vbWJyZTsgZWwgY3VlcnBvXG4gIHNpZ3VlIGNvbW8gY29tYW5kb3MuXG5cblNpIGFsZ28gbm8gY2llcnJhICh1bmEgY29taWxsYSwgdW4gYCQoYCksIHNlIGxldmFudGEgYEFiaWVydG9gOiBlbCBqdWV6IHBhcnRlXG5kZSBudWV2byBhIGxvIGJydXRvLCBwYXJhIGZyZW5hciBkZSBtw6FzIHkgbm8gZGUgbWVub3MuXG5cIlwiXCJcbmltcG9ydCByZVxuXG5DTEFWRVMgPSB7XCJpZlwiLCBcInRoZW5cIiwgXCJlbHNlXCIsIFwiZWxpZlwiLCBcImZpXCIsIFwiZG9cIiwgXCJkb25lXCIsIFwid2hpbGVcIiwgXCJ1bnRpbFwiLCBcImZvclwiLFxuICAgICAgICAgIFwiaW5cIiwgXCJjYXNlXCIsIFwiZXNhY1wiLCBcInNlbGVjdFwiLCBcImZ1bmN0aW9uXCIsIFwidGltZVwiLCBcIiFcIiwgXCJ7XCIsIFwifVwiLCBcIltbXCIsIFwiXV1cIn1cbk9QRVJBRE9SRVMgPSAoXCImJlwiLCBcInx8XCIsIFwifCZcIiwgXCI7O1wiLCBcInxcIiwgXCI7XCIsIFwiJlwiLCBcIlxcblwiKVxuUkVESVJJR0UgPSByZS5jb21waWxlKHJcIihcXGQqfCYpKD4+fD5cXHx8PiZ8PD58PCZ8Pnw8KSg/IVxcKClcIilcbkhFUkVET0MgPSByZS5jb21waWxlKHJcIihcXGQqKTw8KC0/KVwiKVxuXG5cbmNsYXNzIEFiaWVydG8oRXhjZXB0aW9uKTpcbiAgICBcIlwiXCJVbmEgY29taWxsYSwgdW5hIHN1c3RpdHVjacOzbiBvIHVuIGdydXBvIHF1ZSBubyBjaWVycmEuXCJcIlwiXG5cblxuY2xhc3MgQ29tYW5kbzpcbiAgICBkZWYgX19pbml0X18oc2VsZik6XG4gICAgICAgIHNlbGYucGFsYWJyYXMsIHNlbGYuY2xhdmVzLCBzZWxmLnN1YnMsIHNlbGYuY3VlcnBvcywgc2VsZi5lc2NyaWJlID0gW10sIFtdLCBbXSwgW10sIFtdXG4gICAgICAgIHNlbGYuZnVuY2lvbiwgc2VsZi5vdHJhcyA9IE5vbmUsIFtdXG5cbiAgICBkZWYgX19yZXByX18oc2VsZik6XG4gICAgICAgIHJldHVybiBmXCJDb21hbmRvKHtzZWxmLmNsYXZlc317c2VsZi5wYWxhYnJhc30sIGN1ZXJwb3M9e2xlbihzZWxmLmN1ZXJwb3MpfSwgc3Vicz17c2VsZi5zdWJzfSlcIlxuXG5cbmNsYXNzIExlY3RvcjpcbiAgICBkZWYgX19pbml0X18oc2VsZiwgdGV4dG8pOlxuICAgICAgICBzZWxmLnQsIHNlbGYuaSwgc2VsZi5wZW5kaWVudGVzID0gdGV4dG8sIDAsIFtdXG5cbiAgICBkZWYgdmVyKHNlbGYsIG49MSk6XG4gICAgICAgIHJldHVybiBzZWxmLnRbc2VsZi5pOnNlbGYuaSArIG5dXG5cbiAgICBkZWYgZmluKHNlbGYpOlxuICAgICAgICByZXR1cm4gc2VsZi5pID49IGxlbihzZWxmLnQpXG5cbiAgICBkZWYgc2ltcGxlKHNlbGYpOlxuICAgICAgICBqID0gc2VsZi50LmZpbmQoXCInXCIsIHNlbGYuaSArIDEpXG4gICAgICAgIGlmIGogPCAwOlxuICAgICAgICAgICAgcmFpc2UgQWJpZXJ0byhcIidcIilcbiAgICAgICAgcywgc2VsZi5pID0gc2VsZi50W3NlbGYuaSArIDE6al0sIGogKyAxXG4gICAgICAgIHJldHVybiBzXG5cbiAgICBkZWYgYW5zaShzZWxmKTpcbiAgICAgICAgaiA9IHNlbGYuaSArIDJcbiAgICAgICAgd2hpbGUgaiA8IGxlbihzZWxmLnQpIGFuZCBzZWxmLnRbal0gIT0gXCInXCI6XG4gICAgICAgICAgICBqICs9IDIgaWYgc2VsZi50W2pdID09IFwiXFxcXFwiIGVsc2UgMVxuICAgICAgICBpZiBqID49IGxlbihzZWxmLnQpOlxuICAgICAgICAgICAgcmFpc2UgQWJpZXJ0byhcIiQnXCIpXG4gICAgICAgIHMsIHNlbGYuaSA9IHNlbGYudFtzZWxmLmkgKyAyOmpdLCBqICsgMVxuICAgICAgICByZXR1cm4gc1xuXG4gICAgZGVmIGRvYmxlKHNlbGYsIHN1YnMpOlxuICAgICAgICBzZWxmLmkgKz0gMVxuICAgICAgICBwYXJ0ZXMgPSBbXVxuICAgICAgICB3aGlsZSBUcnVlOlxuICAgICAgICAgICAgaWYgc2VsZi5maW4oKTpcbiAgICAgICAgICAgICAgICByYWlzZSBBYmllcnRvKCdcIicpXG4gICAgICAgICAgICBjID0gc2VsZi52ZXIoKVxuICAgICAgICAgICAgaWYgYyA9PSAnXCInOlxuICAgICAgICAgICAgICAgIHNlbGYuaSArPSAxXG4gICAgICAgICAgICAgICAgcmV0dXJuIFwiXCIuam9pbihwYXJ0ZXMpXG4gICAgICAgICAgICBpZiBjID09IFwiXFxcXFwiOlxuICAgICAgICAgICAgICAgIHNpZyA9IHNlbGYudFtzZWxmLmkgKyAxOnNlbGYuaSArIDJdXG4gICAgICAgICAgICAgICAgcGFydGVzLmFwcGVuZChzaWcgaWYgc2lnIGluICckYFwiXFxcXFxcbicgZWxzZSBcIlxcXFxcIiArIHNpZylcbiAgICAgICAgICAgICAgICBzZWxmLmkgKz0gMlxuICAgICAgICAgICAgZWxpZiBjID09IFwiJFwiIG9yIGMgPT0gXCJgXCI6XG4gICAgICAgICAgICAgICAgcGFydGVzLmFwcGVuZChzZWxmLmRvbGFyKHN1YnMpKVxuICAgICAgICAgICAgZWxzZTpcbiAgICAgICAgICAgICAgICBwYXJ0ZXMuYXBwZW5kKGMpXG4gICAgICAgICAgICAgICAgc2VsZi5pICs9IDFcblxuICAgIGRlZiBhcml0bWV0aWNhKHNlbGYpOlxuICAgICAgICBcIlwiXCIkKCgg4oCmICkpIG8gKCgg4oCmICkpOiBzZSBzYWx0ZWEgaGFzdGEgbG9zICkpIHF1ZSBjaWVycmFuLlwiXCJcIlxuICAgICAgICBob25kbywgaiA9IDAsIHNlbGYuaVxuICAgICAgICB3aGlsZSBqIDwgbGVuKHNlbGYudCk6XG4gICAgICAgICAgICBpZiBzZWxmLnRbal0gPT0gXCIoXCI6XG4gICAgICAgICAgICAgICAgaG9uZG8gKz0gMVxuICAgICAgICAgICAgZWxpZiBzZWxmLnRbal0gPT0gXCIpXCI6XG4gICAgICAgICAgICAgICAgaG9uZG8gLT0gMVxuICAgICAgICAgICAgICAgIGlmIGhvbmRvID09IDA6XG4gICAgICAgICAgICAgICAgICAgIHMsIHNlbGYuaSA9IHNlbGYudFtzZWxmLmk6aiArIDFdLCBqICsgMVxuICAgICAgICAgICAgICAgICAgICByZXR1cm4gc1xuICAgICAgICAgICAgaiArPSAxXG4gICAgICAgIHJhaXNlIEFiaWVydG8oXCIoKFwiKVxuXG4gICAgZGVmIGRvbGFyKHNlbGYsIHN1YnMpOlxuICAgICAgICBcIlwiXCIkWCwgJHvigKZ9LCAkKCDigKYgKSwgJCgoIOKApiApKSwgYOKApmA6IGxvIHF1ZSBjb3JyZSBhZGVudHJvIHZhIGEgc3Vicy5cIlwiXCJcbiAgICAgICAgaWYgc2VsZi52ZXIoKSA9PSBcImBcIjpcbiAgICAgICAgICAgIGogPSBzZWxmLmkgKyAxXG4gICAgICAgICAgICB3aGlsZSBqIDwgbGVuKHNlbGYudCkgYW5kIHNlbGYudFtqXSAhPSBcImBcIjpcbiAgICAgICAgICAgICAgICBqICs9IDIgaWYgc2VsZi50W2pdID09IFwiXFxcXFwiIGVsc2UgMVxuICAgICAgICAgICAgaWYgaiA+PSBsZW4oc2VsZi50KTpcbiAgICAgICAgICAgICAgICByYWlzZSBBYmllcnRvKFwiYFwiKVxuICAgICAgICAgICAgc3Vicy5hcHBlbmQocGFydGlyKHNlbGYudFtzZWxmLmkgKyAxOmpdLnJlcGxhY2UoXCJcXFxcYFwiLCBcImBcIikpKVxuICAgICAgICAgICAgc2VsZi5pID0gaiArIDFcbiAgICAgICAgICAgIHJldHVybiBcIiQo4oCmKVwiXG4gICAgICAgIGlmIHNlbGYudmVyKDMpID09IFwiJCgoXCI6XG4gICAgICAgICAgICBzZWxmLmkgKz0gMVxuICAgICAgICAgICAgcmV0dXJuIFwiJFwiICsgc2VsZi5hcml0bWV0aWNhKClcbiAgICAgICAgaWYgc2VsZi52ZXIoMikgPT0gXCIkKFwiOlxuICAgICAgICAgICAgc2VsZi5pICs9IDJcbiAgICAgICAgICAgIHN1YnMuYXBwZW5kKHNlbGYubGlzdGEoY2llcnJhPVwiKVwiKSlcbiAgICAgICAgICAgIHJldHVybiBcIiQo4oCmKVwiXG4gICAgICAgIGlmIHNlbGYudmVyKDIpID09IFwiJHtcIjpcbiAgICAgICAgICAgIGogPSBzZWxmLnQuZmluZChcIn1cIiwgc2VsZi5pKVxuICAgICAgICAgICAgaWYgaiA8IDA6XG4gICAgICAgICAgICAgICAgcmFpc2UgQWJpZXJ0byhcIiR7XCIpXG4gICAgICAgICAgICBzLCBzZWxmLmkgPSBzZWxmLnRbc2VsZi5pOmogKyAxXSwgaiArIDFcbiAgICAgICAgICAgIHJldHVybiBzXG4gICAgICAgIG0gPSByZS5jb21waWxlKHJcIlxcJChbQS1aYS16X11bQS1aYS16MC05X10qfFswLTlAKiM/JCEtXSk/XCIpLm1hdGNoKHNlbGYudCwgc2VsZi5pKVxuICAgICAgICBzZWxmLmkgPSBtLmVuZCgpXG4gICAgICAgIHJldHVybiBtLmdyb3VwKDApXG5cbiAgICBkZWYgcGFsYWJyYShzZWxmLCBzdWJzKTpcbiAgICAgICAgXCJcIlwiVW5hIHBhbGFicmEgZW50ZXJhIChwZWdhZGEgZGUgcGFydGVzKSwgbyBOb25lIHNpIG5vIGVtcGllemEgdW5hLlwiXCJcIlxuICAgICAgICBwYXJ0ZXMsIGh1Ym8gPSBbXSwgRmFsc2VcbiAgICAgICAgd2hpbGUgbm90IHNlbGYuZmluKCk6XG4gICAgICAgICAgICBjID0gc2VsZi52ZXIoKVxuICAgICAgICAgICAgaWYgYyBpbiBcIiBcXHRcIiBvciBjIGluIFwiOyZ8PD4oKVxcblwiIGFuZCBub3QgKGMgaW4gXCI8PlwiIGFuZCBzZWxmLnZlcigyKVsxOl0gPT0gXCIoXCIpOlxuICAgICAgICAgICAgICAgIGJyZWFrXG4gICAgICAgICAgICBodWJvID0gVHJ1ZVxuICAgICAgICAgICAgaWYgYyA9PSBcIidcIjpcbiAgICAgICAgICAgICAgICBwYXJ0ZXMuYXBwZW5kKHNlbGYuc2ltcGxlKCkpXG4gICAgICAgICAgICBlbGlmIHNlbGYudmVyKDIpID09IFwiJCdcIjpcbiAgICAgICAgICAgICAgICBwYXJ0ZXMuYXBwZW5kKHNlbGYuYW5zaSgpKVxuICAgICAgICAgICAgZWxpZiBzZWxmLnZlcigyKSA9PSAnJFwiJzpcbiAgICAgICAgICAgICAgICBzZWxmLmkgKz0gMVxuICAgICAgICAgICAgICAgIHBhcnRlcy5hcHBlbmQoc2VsZi5kb2JsZShzdWJzKSlcbiAgICAgICAgICAgIGVsaWYgYyA9PSAnXCInOlxuICAgICAgICAgICAgICAgIHBhcnRlcy5hcHBlbmQoc2VsZi5kb2JsZShzdWJzKSlcbiAgICAgICAgICAgIGVsaWYgYyBpbiBcIiRgXCI6XG4gICAgICAgICAgICAgICAgcGFydGVzLmFwcGVuZChzZWxmLmRvbGFyKHN1YnMpKVxuICAgICAgICAgICAgZWxpZiBjIGluIFwiPD5cIjpcbiAgICAgICAgICAgICAgICBzZWxmLmkgKz0gMlxuICAgICAgICAgICAgICAgIHN1YnMuYXBwZW5kKHNlbGYubGlzdGEoY2llcnJhPVwiKVwiKSlcbiAgICAgICAgICAgICAgICBwYXJ0ZXMuYXBwZW5kKFwiJCjigKYpXCIpXG4gICAgICAgICAgICBlbGlmIGMgPT0gXCJcXFxcXCI6XG4gICAgICAgICAgICAgICAgc2lnID0gc2VsZi50W3NlbGYuaSArIDE6c2VsZi5pICsgMl1cbiAgICAgICAgICAgICAgICBwYXJ0ZXMuYXBwZW5kKFwiXCIgaWYgc2lnID09IFwiXFxuXCIgZWxzZSBzaWcpXG4gICAgICAgICAgICAgICAgc2VsZi5pICs9IDJcbiAgICAgICAgICAgIGVsc2U6XG4gICAgICAgICAgICAgICAgcGFydGVzLmFwcGVuZChjKVxuICAgICAgICAgICAgICAgIHNlbGYuaSArPSAxXG4gICAgICAgIHJldHVybiBcIlwiLmpvaW4ocGFydGVzKSBpZiBodWJvIGVsc2UgTm9uZVxuXG4gICAgZGVmIGJsYW5jb3Moc2VsZik6XG4gICAgICAgIHdoaWxlIG5vdCBzZWxmLmZpbigpOlxuICAgICAgICAgICAgaWYgc2VsZi52ZXIoKSBpbiBcIiBcXHRcIjpcbiAgICAgICAgICAgICAgICBzZWxmLmkgKz0gMVxuICAgICAgICAgICAgZWxpZiBzZWxmLnZlcigyKSA9PSBcIlxcXFxcXG5cIjpcbiAgICAgICAgICAgICAgICBzZWxmLmkgKz0gMlxuICAgICAgICAgICAgZWxpZiBzZWxmLnZlcigpID09IFwiI1wiOlxuICAgICAgICAgICAgICAgIGogPSBzZWxmLnQuZmluZChcIlxcblwiLCBzZWxmLmkpXG4gICAgICAgICAgICAgICAgc2VsZi5pID0gbGVuKHNlbGYudCkgaWYgaiA8IDAgZWxzZSBqXG4gICAgICAgICAgICBlbHNlOlxuICAgICAgICAgICAgICAgIHJldHVyblxuXG4gICAgZGVmIGhlcmVkb2Moc2VsZiwgY21kLCBtZW5vcyk6XG4gICAgICAgIFwiXCJcIkFub3RhIHVuIGhlcmVkb2M7IHN1IGN1ZXJwbyBzZSBsZWUgZW4gZWwgcHLDs3hpbW8gc2FsdG8gZGUgbMOtbmVhLlwiXCJcIlxuICAgICAgICBzZWxmLmJsYW5jb3MoKVxuICAgICAgICBmaW4gPSBzZWxmLnBhbGFicmEoW10pXG4gICAgICAgIGlmIGZpbiBpcyBOb25lOlxuICAgICAgICAgICAgcmFpc2UgQWJpZXJ0byhcIjw8XCIpXG4gICAgICAgIHNlbGYucGVuZGllbnRlcy5hcHBlbmQoKGNtZCwgbWVub3MsIGZpbikpXG5cbiAgICBkZWYgY3VlcnBvcyhzZWxmKTpcbiAgICAgICAgXCJcIlwiRGVzcHXDqXMgZGUgdW4gc2FsdG8gZGUgbMOtbmVhOiBsb3MgY3VlcnBvcyBkZSBsb3MgaGVyZWRvY3MgcGVuZGllbnRlcy5cIlwiXCJcbiAgICAgICAgd2hpbGUgc2VsZi5wZW5kaWVudGVzOlxuICAgICAgICAgICAgY21kLCBtZW5vcywgZmluID0gc2VsZi5wZW5kaWVudGVzLnBvcCgwKVxuICAgICAgICAgICAgbGluZWFzID0gW11cbiAgICAgICAgICAgIHdoaWxlIFRydWU6XG4gICAgICAgICAgICAgICAgaWYgc2VsZi5maW4oKTpcbiAgICAgICAgICAgICAgICAgICAgcmFpc2UgQWJpZXJ0byhcIjw8XCIgKyBmaW4pXG4gICAgICAgICAgICAgICAgaiA9IHNlbGYudC5maW5kKFwiXFxuXCIsIHNlbGYuaSlcbiAgICAgICAgICAgICAgICBqID0gbGVuKHNlbGYudCkgaWYgaiA8IDAgZWxzZSBqXG4gICAgICAgICAgICAgICAgbGluZWEsIHNlbGYuaSA9IHNlbGYudFtzZWxmLmk6al0sIGogKyAxXG4gICAgICAgICAgICAgICAgaWYgKGxpbmVhLmxzdHJpcChcIlxcdFwiKSBpZiBtZW5vcyBlbHNlIGxpbmVhKSA9PSBmaW46XG4gICAgICAgICAgICAgICAgICAgIGJyZWFrXG4gICAgICAgICAgICAgICAgbGluZWFzLmFwcGVuZChsaW5lYSlcbiAgICAgICAgICAgIGNtZC5jdWVycG9zLmFwcGVuZChcIlxcblwiLmpvaW4obGluZWFzKSlcblxuICAgIGRlZiBjb21hbmRvKHNlbGYpOlxuICAgICAgICBjbWQgPSBDb21hbmRvKClcbiAgICAgICAgd2hpbGUgVHJ1ZTpcbiAgICAgICAgICAgIHNlbGYuYmxhbmNvcygpXG4gICAgICAgICAgICBpZiBzZWxmLnZlcigyKSA9PSBcIiY+XCI6XG4gICAgICAgICAgICAgICAgc2VsZi5pICs9IDJcbiAgICAgICAgICAgICAgICBzZWxmLmJsYW5jb3MoKVxuICAgICAgICAgICAgICAgIHNlbGYucGFsYWJyYShjbWQuc3VicylcbiAgICAgICAgICAgICAgICBjb250aW51ZVxuICAgICAgICAgICAgaWYgc2VsZi5maW4oKSBvciBzZWxmLnZlcigpIGluIFwiOyZ8KVxcblwiOlxuICAgICAgICAgICAgICAgIHJldHVybiBjbWRcbiAgICAgICAgICAgIGlmIHNlbGYudmVyKDIpID09IFwiKChcIiBhbmQgbm90IGNtZC5wYWxhYnJhczpcbiAgICAgICAgICAgICAgICBzZWxmLmFyaXRtZXRpY2EoKVxuICAgICAgICAgICAgICAgIGNvbnRpbnVlXG4gICAgICAgICAgICBpZiBzZWxmLnZlcigpID09IFwiKFwiIGFuZCBsZW4oY21kLnBhbGFicmFzKSA9PSAxIGFuZCByZS5tYXRjaChyXCJcXChcXHMqXFwpXCIsIHNlbGYudFtzZWxmLmk6XSk6XG4gICAgICAgICAgICAgICAgc2VsZi5pID0gcmUuY29tcGlsZShyXCJcXChcXHMqXFwpXCIpLm1hdGNoKHNlbGYudCwgc2VsZi5pKS5lbmQoKVxuICAgICAgICAgICAgICAgIGNtZC5mdW5jaW9uLCBjbWQucGFsYWJyYXMgPSBjbWQucGFsYWJyYXNbMF0sIFtdXG4gICAgICAgICAgICAgICAgY29udGludWVcbiAgICAgICAgICAgIGlmIHNlbGYudmVyKCkgPT0gXCIoXCI6XG4gICAgICAgICAgICAgICAgc2VsZi5pICs9IDFcbiAgICAgICAgICAgICAgICBjbWQuc3Vicy5hcHBlbmQoc2VsZi5saXN0YShjaWVycmE9XCIpXCIpKVxuICAgICAgICAgICAgICAgIGNvbnRpbnVlXG4gICAgICAgICAgICBtID0gSEVSRURPQy5tYXRjaChzZWxmLnQsIHNlbGYuaSlcbiAgICAgICAgICAgIGlmIG0gYW5kIHNlbGYudmVyKDMpWzI6XSAhPSBcIjxcIjpcbiAgICAgICAgICAgICAgICBzZWxmLmkgPSBtLmVuZCgpXG4gICAgICAgICAgICAgICAgc2VsZi5oZXJlZG9jKGNtZCwgbS5ncm91cCgyKSA9PSBcIi1cIilcbiAgICAgICAgICAgICAgICBjb250aW51ZVxuICAgICAgICAgICAgaWYgc2VsZi50LnN0YXJ0c3dpdGgoXCI8PDxcIiwgc2VsZi5pKTpcbiAgICAgICAgICAgICAgICBzZWxmLmkgKz0gM1xuICAgICAgICAgICAgICAgIHNlbGYuYmxhbmNvcygpXG4gICAgICAgICAgICAgICAgc2VsZi5wYWxhYnJhKGNtZC5zdWJzKVxuICAgICAgICAgICAgICAgIGNvbnRpbnVlXG4gICAgICAgICAgICBtID0gUkVESVJJR0UubWF0Y2goc2VsZi50LCBzZWxmLmkpXG4gICAgICAgICAgICBpZiBtIGFuZCAobS5ncm91cCgxKSBvciBzZWxmLnZlcigpIGluIFwiPD5cIik6XG4gICAgICAgICAgICAgICAgc2VsZi5pID0gbS5lbmQoKVxuICAgICAgICAgICAgICAgIHNlbGYuYmxhbmNvcygpXG4gICAgICAgICAgICAgICAgZGVzdGlubyA9IHNlbGYucGFsYWJyYShjbWQuc3VicylcbiAgICAgICAgICAgICAgICBpZiBtLmdyb3VwKDIpIGluIChcIj5cIiwgXCI+PlwiLCBcIj58XCIpIGFuZCBkZXN0aW5vIGFuZCBub3QgZGVzdGluby5zdGFydHN3aXRoKFwiJlwiKTpcbiAgICAgICAgICAgICAgICAgICAgY21kLmVzY3JpYmUuYXBwZW5kKGRlc3Rpbm8pXG4gICAgICAgICAgICAgICAgY29udGludWVcbiAgICAgICAgICAgIHcgPSBzZWxmLnBhbGFicmEoY21kLnN1YnMpXG4gICAgICAgICAgICBpZiB3IGlzIE5vbmU6XG4gICAgICAgICAgICAgICAgcmFpc2UgQWJpZXJ0byhzZWxmLnZlcigpKVxuICAgICAgICAgICAgaWYgY21kLmNsYXZlc1stMTpdID09IFtcImZ1bmN0aW9uXCJdIGFuZCBub3QgY21kLmZ1bmNpb246XG4gICAgICAgICAgICAgICAgY21kLmZ1bmNpb24gPSB3XG4gICAgICAgICAgICBlbGlmIHtcImZvclwiLCBcInNlbGVjdFwiLCBcImNhc2VcIn0gJiBzZXQoY21kLmNsYXZlcyk6XG4gICAgICAgICAgICAgICAgY21kLm90cmFzLmFwcGVuZCh3KVxuICAgICAgICAgICAgZWxpZiBub3QgY21kLnBhbGFicmFzIGFuZCB3IGluIENMQVZFUzpcbiAgICAgICAgICAgICAgICBjbWQuY2xhdmVzLmFwcGVuZCh3KVxuICAgICAgICAgICAgZWxzZTpcbiAgICAgICAgICAgICAgICBjbWQucGFsYWJyYXMuYXBwZW5kKHcpXG5cbiAgICBkZWYgbGlzdGEoc2VsZiwgY2llcnJhPU5vbmUpOlxuICAgICAgICB0dWJlcmlhcywgdHVibyA9IFtdLCBbXVxuICAgICAgICB3aGlsZSBUcnVlOlxuICAgICAgICAgICAgY21kID0gc2VsZi5jb21hbmRvKClcbiAgICAgICAgICAgIGlmIGNtZC5wYWxhYnJhcyBvciBjbWQuY2xhdmVzIG9yIGNtZC5zdWJzIG9yIGNtZC5jdWVycG9zIG9yIGNtZC5mdW5jaW9uOlxuICAgICAgICAgICAgICAgIHR1Ym8uYXBwZW5kKGNtZClcbiAgICAgICAgICAgIGlmIHNlbGYuZmluKCk6XG4gICAgICAgICAgICAgICAgaWYgY2llcnJhOlxuICAgICAgICAgICAgICAgICAgICByYWlzZSBBYmllcnRvKGNpZXJyYSlcbiAgICAgICAgICAgICAgICBicmVha1xuICAgICAgICAgICAgaWYgc2VsZi52ZXIoKSA9PSBcIilcIjpcbiAgICAgICAgICAgICAgICBzZWxmLmkgKz0gMVxuICAgICAgICAgICAgICAgIGlmIGNpZXJyYTpcbiAgICAgICAgICAgICAgICAgICAgYnJlYWtcbiAgICAgICAgICAgICAgICBjb250aW51ZVxuICAgICAgICAgICAgb3AgPSBuZXh0KG8gZm9yIG8gaW4gT1BFUkFET1JFUyBpZiBzZWxmLnQuc3RhcnRzd2l0aChvLCBzZWxmLmkpKVxuICAgICAgICAgICAgc2VsZi5pICs9IGxlbihvcClcbiAgICAgICAgICAgIGlmIG9wID09IFwiXFxuXCI6XG4gICAgICAgICAgICAgICAgc2VsZi5jdWVycG9zKClcbiAgICAgICAgICAgIGlmIG9wIG5vdCBpbiAoXCJ8XCIsIFwifCZcIikgYW5kIHR1Ym86XG4gICAgICAgICAgICAgICAgdHViZXJpYXMuYXBwZW5kKHR1Ym8pXG4gICAgICAgICAgICAgICAgdHVibyA9IFtdXG4gICAgICAgIGlmIHR1Ym86XG4gICAgICAgICAgICB0dWJlcmlhcy5hcHBlbmQodHVibylcbiAgICAgICAgaWYgc2VsZi5wZW5kaWVudGVzIGFuZCBub3QgY2llcnJhOlxuICAgICAgICAgICAgcmFpc2UgQWJpZXJ0byhcIjw8XCIpXG4gICAgICAgIHJldHVybiB0dWJlcmlhc1xuXG5cbmRlZiBwYXJ0aXIodGV4dG8pOlxuICAgIFwiXCJcIkxhcyB0dWJlcsOtYXMgZGVsIGNvbWFuZG8uIExldmFudGEgQWJpZXJ0byBzaSBhbGdvIG5vIGNpZXJyYS5cIlwiXCJcbiAgICByZXR1cm4gTGVjdG9yKHRleHRvKS5saXN0YSgpXG5cblxuZGVmIGFfbG9fYnJ1dG8odGV4dG8pOlxuICAgIFwiXCJcIlBhcmEgbG8gcXVlIG5vIGNpZXJyYTogY2FkYSBjb21pbGxhLCBzdXN0aXR1Y2nDs24gbyBzYWx0byBwYXJ0ZSB1biBjb21hbmRvXG4gICAgbnVldm8sIGFzw60gbG8gZGUgYWRlbnRybyBzZSBtaXJhIGNvbW8gc2kgc2UgZWplY3V0YXJhLlwiXCJcIlxuICAgIHR1YmVyaWFzID0gW11cbiAgICBmb3IgdHJhbW8gaW4gcmUuc3BsaXQoclwiWzsmfCgpYCdcXFwiXFxuXXxcXCRcXCh8PDxcIiwgdGV4dG8pOlxuICAgICAgICBjbWQgPSBDb21hbmRvKClcbiAgICAgICAgY21kLnBhbGFicmFzID0gdHJhbW8uc3BsaXQoKVxuICAgICAgICBpZiBjbWQucGFsYWJyYXM6XG4gICAgICAgICAgICB0dWJlcmlhcy5hcHBlbmQoW2NtZF0pXG4gICAgcmV0dXJuIHR1YmVyaWFzXG4ifSwidGVzdHMvZGlidWpvcy5zaCI6eyJtb2RvIjo0OTMsInRleHRvIjoiIyEvdXNyL2Jpbi9lbnYgYmFzaFxuc2V0IC11byBwaXBlZmFpbFxuY2QgXCIkKGRpcm5hbWUgXCIkMFwiKS8uLlwiIHx8IGV4aXQgMVxuZGlidWpvcz0oKVxud2hpbGUgSUZTPSByZWFkIC1yIGY7IGRvIGRpYnVqb3MrPShcIiRmXCIpOyBkb25lIDwgPChmaW5kIGFydCAtbmFtZSAnKi5wc3MuanNvbicgMj4vZGV2L251bGwgfCBzb3J0KVxuaWYgWyBcIiR7I2RpYnVqb3NbQF19XCIgLWVxIDAgXTsgdGhlblxuXHRlY2hvIFwi4pyTIGRpYnVqb3M6IHRvZGF2w61hIG5vIGhheSBuaW5ndW5vIGVuIGFydC9cIlxuXHRleGl0IDBcbmZpXG5kb25kZT1cIiR7UEdTX0RPTkRFOi0kKGNhdCAucGdzLWRvbmRlIDI+L2Rldi9udWxsKX1cIlxuZG9uZGU9XCIke2RvbmRlOi0kSE9NRS9wZ3N9XCJcbnBncz1cIiRkb25kZS9iaW4vcGdzXCJcbmlmIFsgISAteCBcIiRwZ3NcIiBdOyB0aGVuXG5cdGVjaG8gXCIgIG5vIGVuY3VlbnRybyBQR1MgZW4gJHtkb25kZX06IG5vIHNlIGNvbnRyb2xhcm9uICR7I2RpYnVqb3NbQF19IGRpYnVqb3MgKFBHU19ET05ERT08Y2FycGV0YT4gLi9wcm9iYXIuc2gpXCJcblx0ZXhpdCAxXG5maVxubGlzdGE9XCIkKG5vZGUgLWUgJ2NvbnNvbGUubG9nKEpTT04uc3RyaW5naWZ5KHtwYXRoczogcHJvY2Vzcy5hcmd2LnNsaWNlKDEpfSkpJyBcIiR7ZGlidWpvc1tAXX1cIilcIlxuc2FsaWRhPVwiJChwZXJsIC1lICdhbGFybSAyNDA7IGV4ZWMgQEFSR1YnIFwiJHBnc1wiIGxpbnQgXCIkbGlzdGFcIiAyPiYxKVwiXG5pZiBwcmludGYgJyVzXFxuJyBcIiRzYWxpZGFcIiB8IGdyZXAgLUVxICdeKFswLTldKykvXFwxIGNsZWFuJzsgdGhlblxuXHRlY2hvIFwi4pyTIGRpYnVqb3M6IGxvcyAkeyNkaWJ1am9zW0BdfSBwYXNhbiBlbCBsaW50IGRlIFBHU1wiXG5lbHNlXG5cdHByaW50ZiAnJXNcXG4nIFwiJHNhbGlkYVwiXG5cdGV4aXQgMVxuZmlcbiJ9LCJ0ZXN0cy9ndWFyZGlhLnNoIjp7Im1vZG8iOjQ5MywidGV4dG8iOiIjIS91c3IvYmluL2VudiBiYXNoXG5zZXQgLXVvIHBpcGVmYWlsXG5jZCBcIiQoZGlybmFtZSBcIiQwXCIpLy4uXCIgfHwgZXhpdCAxXG5ndWFyZGlhPXNjcmlwdHMvaG9va3MvZ3VhcmRpYS5zaFxubWFsPTBcbmZvciBjIGluICdwa2lsbCAtZiBhbGdvJyAna2lsbGFsbCBub2RlJyAnZ2l0IHN0YXNoJyAnZ2l0IHJlc2V0IC0taGFyZCcgJ2dpdCBhZGQgLUEnICdnaXQgYWRkIC4nICdnaXQgY2hlY2tvdXQgb3RyYS1yYW1hJzsgZG9cblx0aWYgYmFzaCBcIiRndWFyZGlhXCIgXCIkY1wiIDI+L2Rldi9udWxsOyB0aGVuXG5cdFx0ZWNobyBcIiAgZWwgZ3VhcmRpYSBkZWrDsyBwYXNhcjogJGNcIlxuXHRcdG1hbD0xXG5cdGZpXG5kb25lXG5mb3IgYyBpbiAnZ2l0IHN0YXR1cycgJ2xzIGFydCcgJ2dpdCBhZGQgYXJ0L2VzY3Vkby50eHQnICdwZ3JlcCAtZmwgbm9kZSc7IGRvXG5cdGlmICEgYmFzaCBcIiRndWFyZGlhXCIgXCIkY1wiIDI+L2Rldi9udWxsOyB0aGVuXG5cdFx0ZWNobyBcIiAgZWwgZ3VhcmRpYSBmcmVuw7M6ICRjXCJcblx0XHRtYWw9MVxuXHRmaVxuZG9uZVxuaWYgcHJpbnRmICclcycgJ3tcInRvb2xfaW5wdXRcIjp7XCJjb21tYW5kXCI6XCJwa2lsbCAtZiB4XCJ9fScgfCBiYXNoIFwiJGd1YXJkaWFcIiAyPi9kZXYvbnVsbDsgdGhlblxuXHRlY2hvIFwiICBlbCBndWFyZGlhIGRlasOzIHBhc2FyIHBraWxsIGVuIGVsIEpTT04gZGUgdW4gaG9va1wiXG5cdG1hbD0xXG5maVxuWyBcIiRtYWxcIiAtZXEgMCBdICYmIGVjaG8gXCLinJMgZWwgZ3VhcmRpYSBjb3J0YSBsbyBwcm9oaWJpZG8geSBkZWphIHBhc2FyIGxvIGRlbcOhc1wiXG5leGl0IFwiJG1hbFwiXG4ifX0=
