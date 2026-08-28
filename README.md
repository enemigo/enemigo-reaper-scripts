# enemigo-reaper-scripts

Colección de scripts Lua (ReaScripts) para **REAPER**, creada por Patricio Maripani Navarro ("enemigo") para automatizar su flujo de trabajo de mezcla: grabación con equipo externo (outboard) vía ReaInsert, monitorización del canal máster, ruteo automático de mezclas completas y utilidades de tempo.

---

## Estructura

Casi todos los scripts definen una variable `POS_x` con la posición del plugin en la cadena de monitorización del máster. **Si cambias el orden de los plugins en tu cadena, ajusta esas posiciones.**

---

## Scripts

### Grabación / impresión con outboard (Freeze con ReaInsert)

Estos dos scripts forman un par de "imprimir" (freeze) mediante ReaInsert (envío de pista a equipo externo y retorno):

- **`freeze_reainsert.lua`** — **AUTO FREEZE**:
  - Detecta pistas con un **ReaInsert activo**.
  - Inserta una pista `FREEZE – <nombre>` justo debajo de cada una.
  - Copia color, canales, estado de Master/Parent send y todos los sends de la original.
  - Crea un send de impresión original → FREEZE, arma y monitoriza la pista, y elige **mono o estéreo** de forma inteligente (según canales, ancho estéreo y el audio existente).
  - Vuelve al inicio y **grabación**.
  - Requiere la extensión SWS.

- **`desarma_freeze.lua`** — **EXIT Freeze** (deshacer el freeze):
  - Pone **offline** los FX activos de la pista original (incluido el ReaInsert).
  - Desactiva el ruteo de la original: mutea sends y apaga el Master/Parent send.
  - Mutea (o borra, opcional) el send de impresión original → FREEZE.
  - Reactiva los sends y el Master send en la pista FREEZE y la desarma.
  - Asume que cada pista FREEZE está **justo debajo** de su pista original.

### Monitorización (plugins del canal máster)

Alternan plugins de la cadena de monitorización del máster, actualizando el highlight del botón de toolbar (toggle). Posiciones: DIM=1, TONAL=2, SONARWORKS=4, SIENNA=5, EXTRA=6.

- **`monitor_switch.lua`** — Alterna entre **Sonarworks** y **Sienna** (activa uno, desactiva el otro).
- **`monitor_toggle3.lua`** — Cicla por **3 plugins** de monitorización (Sonarworks → Sienna → Extra → Sonarworks...).
- **`monitor_off.lua`** — Bypass de **Sonarworks y Sienna** (toggle todo encendido / apagado).
- **`monotor_dim.lua`** — Toggle de bypass del plugin **DIM** (dim/attenuación).
- **`monitor_tonal_balance.lua`** — Muestra/oculta la ventana del plugin **Tonal Balance Control** (iZotope).

### Ruteo y estructura de mezcla

- **`setea_B.lua`** — El script más grande. Crea la **estructura de mezcla completa**:
  - Reconoce o crea pistas de batería por nombre/alias (`kick_in`, `kick_out`, `snare_top`, `snare_bottom`, `snare_rev`, `ohl`, `ohr`, `tom1..3`, `room`, `room_comp`, `gDrum`, `NY`) con su ruteo típico (OH estéreo con panoramas, Toms con panoramas, etc.).
  - Crea los grupos **A, B (batería, morado), C, D, VOX, GBV** y los buses de efectos vocales (**VDelay, VRoom, VHall, VPlate**).
  - Auto-rutea por prefijo de nombre: guitarras (`g…`) → C, voces (`v…`) → VOX, instrumentos (piano, keys, strings, synths...) → A, coros (`bv…`) → GBV, bajos (`bajo…`) → B.
  - Aplica códigos de color a todo y **reordena las pistas** en un orden predefinido.
  - Idempotente: si las pistas ya existen, actualiza ruteos y colores.

- **`rutea_a_seleccionado.lua`** — Con varias pistas seleccionadas, enruta **todas a la primera seleccionada**: desactiva su Master send, les asigna el color de la pista destino y crea el send solo si no existe (no duplica).

- **`solo_bus_a.lua`** — Toggle de **selección y solo de un bus** (por defecto `busName = "A"`). Busca por coincidencia difusa de nombre (con puntuación), crea el bus si no existe, des-solo el resto y lo trae a la vista. La variable `busName` se puede cambiar para cualquier bus.

### Utilidades

- **`sincroniza_tempo.lua`** — Muestra una caja con las **duraciones en milisegundos** de las divisiones rítmicas (1/1 a 1/32, tercillos y puntillos) al BPM actual del proyecto, para ajustar delays/release.

---

## Instalación

Cómo instalar: https://forums.cockos.com/showpost.php?p=2190641&postcount=12

Instalación manual:

1. Copia los archivos `.lua` a una (sub)carpeta de la carpeta **Scripts** de tu ruta de recursos de REAPER (*Options → Show REAPER resource path…*).
2. Carga cada archivo desde la **Action List** en la sección `[Main]`.
3. Asigna las acciones a atajos de teclado, botones de toolbar, menús, etc.

> **Nota:** verifica las posiciones (`POS_*`) de los plugins de monitorización y, para el freeze, que cada pista FREEZE quede justo debajo de su original.
