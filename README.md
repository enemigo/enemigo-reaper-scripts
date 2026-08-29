# enemigo-reaper-scripts

Colección de scripts Lua (ReaScripts) para **REAPER**, creada por Patricio Maripani Navarro ("enemigo") para automatizar su flujo de trabajo de mezcla: grabación con equipo externo (outboard) vía ReaInsert, monitorización del canal máster, ruteo automático de mezclas completas y utilidades de tempo.

---

## Estructura

Casi todos los scripts definen una variable `POS_x` con la posición del plugin en la cadena de monitorización del máster. **Si cambias el orden de los plugins en tu cadena, ajusta esas posiciones.**

---

## Scripts

### Grabación / impresión con outboard (Freeze con ReaInsert)

Estos dos scripts forman un par de "imprimir" (freeze) mediante ReaInsert (envío de pista a equipo externo y retorno):

- **`pmn_freeze_reainsert.lua`** — **AUTO FREEZE**:
  - Detecta pistas con un **ReaInsert activo**.
  - Inserta una pista `FREEZE – <nombre>` justo debajo de cada una.
  - Copia color, canales, estado de Master/Parent send y todos los sends de la original.
  - Crea un send de impresión original → FREEZE, arma y monitoriza la pista, y elige **mono o estéreo** de forma inteligente (según canales, ancho estéreo y el audio existente).
  - Vuelve al inicio y **grabación**.
  - Requiere la extensión SWS.

- **`pmn_desarma_freeze.lua`** — **EXIT Freeze** (deshacer el freeze):
  - Pone **offline** los FX activos de la pista original (incluido el ReaInsert).
  - Desactiva el ruteo de la original: mutea sends y apaga el Master/Parent send.
  - Mutea (o borra, opcional) el send de impresión original → FREEZE.
  - Reactiva los sends y el Master send en la pista FREEZE y la desarma.
  - Asume que cada pista FREEZE está **justo debajo** de su pista original.

### Monitorización (plugins del canal máster)

Alternan plugins de la cadena de monitorización del máster, actualizando el highlight del botón de toolbar (toggle). Posiciones: DIM=1, TONAL=2, SONARWORKS=4, SIENNA=5, EXTRA=6.

- **`pmn_monitor_switch.lua`** — Alterna entre **Sonarworks** y **Sienna** (activa uno, desactiva el otro).
- **`pmn_monitor_toggle3.lua`** — Cicla por **3 plugins** de monitorización (Sonarworks → Sienna → Extra → Sonarworks...).
- **`pmn_monitor_off.lua`** — Bypass de **Sonarworks y Sienna** (toggle todo encendido / apagado).
- **`pmn_monotor_dim.lua`** — Toggle de bypass del plugin **DIM** (dim/attenuación).
- **`pmn_monitor_tonal_balance.lua`** — Muestra/oculta la ventana del plugin **Tonal Balance Control** (iZotope).

### Ruteo y estructura de mezcla

- **`pmn_setea_B.lua`** — El script más grande. Crea la **estructura de mezcla completa**:
  - Reconoce o crea pistas de batería por nombre/alias (`kick_in`, `kick_out`, `snare_top`, `snare_bottom`, `snare_rev`, `ohl`, `ohr`, `tom1..3`, `room`, `room_comp`, `gDrum`, `NY`) con su ruteo típico (OH estéreo con panoramas, Toms con panoramas, etc.).
  - Crea los grupos **A, B (batería, morado), C, D, VOX, GBV** y los buses de efectos vocales (**VDelay, VRoom, VHall, VPlate**).
  - Auto-rutea por prefijo de nombre: guitarras (`g…`) → C, voces (`v…`) → VOX, instrumentos (piano, keys, strings, synths...) → A, coros (`bv…`) → GBV, bajos (`bajo…`) → B.
  - Aplica códigos de color a todo y **reordena las pistas** en un orden predefinido.
  - Idempotente: si las pistas ya existen, actualiza ruteos y colores.

- **`pmn_rutea_a_seleccionado.lua`** — Con varias pistas seleccionadas, enruta **todas a la primera seleccionada**: desactiva su Master send, les asigna el color de la pista destino y crea el send solo si no existe (no duplica).

- **`pmn_solo_bus_a.lua`** — Paquete **Solo bus** con 5 acciones: `solo_bus_a/b/c/d/vox.lua` (bus "A", "B", "C", "D" y "VOX"), cada una con su propio atajo. Toggle de **selección y solo del bus**: busca por coincidencia difusa de nombre, crea el bus si no existe, des-solo el resto y lo trae a la vista. Lógica compartida en `pmn_solo_bus_lib.lua`.

### Utilidades

- **`pmn_sincroniza_tempo.lua`** — Ventana interactiva (**ReaImGui**) con las **duraciones en milisegundos** de las divisiones rítmicas (1/1 a 1/64, directas, tercillos, puntillos y swing) al BPM del proyecto. BPM editable en vivo, soporte de **tempo maps** (varias secciones) y botón para **copiar al portapapeles**. Requiere [ReaImGui](https://github.com/cfillion/reaimgui) (ReaPack: ReaTeam Extensions).

---

## Instalación

### Opción A — ReaPack (recomendado)

El repo está preparado como repositorio ReaPack (`index.xml` en la raíz). Requiere la extensión [ReaPack](https://reapack.com).

1. En REAPER: *Extensions → ReaPack → Manage repositories…*.
2. Añade el repo con **Import repositories…** usando la URL:
   - `https://github.com/enemigo/enemigo-reaper-scripts/raw/main/index.xml`
   - (alternativa local, si no quieres usar GitHub): la ruta local del repo, ej. `/Users/patricio/Dropbox/ProyectosIA/Reaper`.
3. *Extensions → ReaPack → Browse packages…* y marca los paquetes de la categoría **Scripts**.
4. *Apply changes* para descargarlos e instalarlos.
5. Carga las acciones desde la **Action List** y asígnalas a atajos/toolbars.

Para actualizar tras nuevos commits: *ReaPack → Synchronize packages*.

> **Sobre tus atajos ya configurados:** si ya tenías estas acciones mapeadas apuntando a otra ruta, ReaPack las instalará en `Scripts/ReaPack/…` y REAPER las verá como **acciones nuevas** (duplicadas). Deberás re-mapear **una vez**; las actualizaciones posteriores conservan los atajos. No borra nada que no gestione él mismo.

### Opción B — Manual

1. Copia los archivos `.lua` a una (sub)carpeta de la carpeta **Scripts** de tu ruta de recursos de REAPER (*Options → Show REAPER resource path…*).
2. Carga cada archivo desde la **Action List** en la sección `[Main]`.
3. Asigna las acciones a atajos de teclado, botones de toolbar, menús, etc.

> **Nota:** verifica las posiciones (`POS_*`) de los plugins de monitorización y, para el freeze, que cada pista FREEZE quede justo debajo de su original.

---

## Mantenimiento del repo (para el autor)

Regenerar `index.xml` tras nuevos commits (requiere Ruby + `gem install reapack-index` + pandoc):

```sh
export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/4.0.0/bin:$PATH"
git add -A && git commit -m "…"      # los cambios deben estar commiteados
reapack-index --name 'enemigo-reaper-scripts'
git add index.xml && git commit -m "Update index.xml"
git push
```

El `index.xml` apunta a `https://github.com/enemigo/enemigo-reaper-scripts/raw/…`; si el repo es privado, usa la **carpeta local** como repositorio en ReaPack.
