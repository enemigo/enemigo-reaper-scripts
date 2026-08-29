# Plan de mejoras — enemigo-reaper-scripts

Documento de trabajo para ir acumulando ideas de mejora sobre los scripts.
Cada idea puede marcarse como `[ ]` pendiente o `[x]` hecha.

---

## Monitorización (monitor_switch / monitor_tonal_balance / monitor_ab)

- [x] Eliminar `reaper.defer(function() end)` al final (deja el script "vivo" sin motivo).
- [x] Añadir `reaper.RefreshToolbar2(self, 0)` tras `SetToggleCommandState` para que el highlight del botón se refresque.
- [x] Unificar los 4 toggles en un solo script parametrizado por config (tabla de posiciones), manteniendo acciones separadas.
- [x] Mostrar mensaje de error claro si no se encuentra el plugin en la posición configurada.
- [x] Soportar posiciones configurables por proyecto (ExtState) en vez de hardcodear.
- [x] **Detectar plugins por nombre, no por posición**: buscar "SoundID"/"Sienna" en la cadena de monitorización (`TrackFX_GetFXName`) en vez de `POS_x` hardcodeado. Robusto a reordenar la cadena.
- [x] **Persistir estado en `SetExtState`**: recordar qué plugin estaba activo entre sesiones y sincronizar el highlight del toolbar al abrir el proyecto.
- [x] **Fallback por posición**: si no encuentra por nombre, usa `POSITIONS`/`POS_x` configurada.
- [x] **Toggle robusto en monitor_switch**: si falta un plugin, alterna el existente; error si faltan ambos.
- [x] Eliminar `monitor_toggle3`, `monitor_mult_sienna`, `monitor_off` y `monitor_dim` (no usados/redundantes).

## Freeze (freeze_reainsert / desarma_freeze)

- [x] Eliminar redundancia: `handle_print_send` no aporta si `MUTE_ALL_ORIGINAL_SENDS = true` (ya mutea todos los sends).
- [x] Hacer el EXIT Freeze reversible: guardar estado en `SetExtState` y poder restaurar FX/ruteo originales (MODE = "restore").
- [x] Vaciar la cadena FX de la pista FREEZE al crearla (o heredar solo ReaInsert).
- [x] Manejar estado de transporte: guardar play/record state con `GetPlayStateEx` y retomar.
- [x] Verificar que la pista FREEZE quede justo debajo de la original; dar error si el emparejamiento falla (ya hay aviso básico).
- [x] Considerar modo "print punch" o auto-stop al final del ítem/región.
- [x] **Verificar la grabación**: tras grabar, comprobar que las takes no estén vacías y avisar; auto-stop tras el primer ítem (modo "print punch").

## setea_B.lua

- [x] Unificar los ~8 bloques de Undo en uno solo (deshacer todo de una vez).
- [x] Manejar pistas de batería MIDI (filtrar por `TakeIsMIDI` / `I_NCHAN`).
- [x] Envolver `reorderAllTracks` en `PreventUIRefresh(1)` para evitar refresco repetido.
- [x] Añadir opción de "modo seco": solo crear/rutear sin reordenar (para proyectos grandes).
- [x] Registrar alias nuevos que el usuario encuentre en la práctica (ej. nombres alternos de tracks).

## rutea_a_seleccionado.lua

- [x] Validar pistas con `ValidatePtr` antes de operar.
- [x] Opción de copiar también volumen/pan del send si ya existía.
- [x] Reportar cuántas pistas se rutearon (mensaje o console).

## solo_bus_a.lua

- [x] Localizar `INSTRUMENT_TRACKS_ONLY` y demás variables globales.
- [x] Hacer `busName` configurable por ExtState o input del usuario.
- [x] Revisar la función `getScore` (copiada de SWS) por posibles edge cases.
- [x] **Optimizar para varios buses (A, B, C, D, VOX)**: el `busName` está hardcodeado y hay que editarlo manualmente por bus. Opciones (de mejor a peor):
  - [x] **Un script por bus**: refactorizado a librería compartida (`solo_bus_lib.lua`) + 5 acciones (`solo_bus_a/b/c/d/vox.lua`), instaladas como un único paquete ReaPack. Cada bus con su propio atajo.
  - [x] ~~Script que cicla~~ — descartado en favor de "un script por bus".
  - [x] ~~Pedir el nombre~~ — descartado.

## sincroniza_tempo.lua

- [x] Redondear todos los valores a 2 decimales de forma consistente.
- [x] Añadir división 1/64.
- [x] Localizar la variable `tempo`.
- [x] Opción de copiar al portapapeles (`CF_Text`) un valor elegido.
- [x] **Soporte de tempo maps**: si el proyecto tiene varios BPM (`GetTempoTimeSigMarker`), listar las duraciones por sección.
- [x] **Mejorar la visualización**: se descartó ReaImGui (más problemas que beneficios). Se mantuvo `ShowMessageBox` con mejor formato.
  - Tablas por grupo (directo / tercillo / puntillo / swing) para consulta rápida.
  - Copiar valor al portapapeles.
  - Ajuste de swing (%).

## General / infraestructura

- [x] Headers `@changelog`, `@about`, `@provides` consistentes para ReaPack.
- [x] Generar `index.xml` con `reapack-index` (requiere Ruby + gem + pandoc).
- [x] Mover scripts a `Scripts/` (categoría ReaPack; los archivos en la raíz no se indexan).
- [ ] Revisar la ruta de instalación en REAPER: los atajos actuales apuntan a otra ruta; al instalar por ReaPack habrá que re-mapear una vez.
- [x] Revisar headers de versión/autor en todos los scripts.
- [x] Verificar precondiciones con mensajes de error en español coherentes.
- [x] Consistencia de estilos: indentación, nombres de funciones, español/inglés en comentarios.
