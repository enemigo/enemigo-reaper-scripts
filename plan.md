# Plan de mejoras — enemigo-reaper-scripts

Documento de trabajo para ir acumulando ideas de mejora sobre los scripts.
Cada idea puede marcarse como `[ ]` pendiente o `[x]` hecha.

---

## Monitorización (monitor_off / monitor_switch / monitor_toggle3 / monotor_dim / monitor_tonal_balance)

- [ ] Eliminar `reaper.defer(function() end)` al final (deja el script "vivo" sin motivo).
- [ ] Añadir `reaper.RefreshToolbar2(self, 0)` tras `SetToggleCommandState` para que el highlight del botón se refresque.
- [ ] Unificar los 4 toggles en un solo script parametrizado por config (tabla de posiciones), manteniendo acciones separadas.
- [ ] Mostrar mensaje de error claro si no se encuentra el plugin en la posición configurada.
- [ ] Soportar posiciones configurables por proyecto (ExtState) en vez de hardcodear.
- [ ] **Detectar plugins por nombre, no por posición**: buscar "Sonarworks"/"Sienna" en la cadena de monitorización (`TrackFX_GetFXName`) en vez de `POS_x` hardcodeado. Robusto a reordenar la cadena.
- [ ] **Persistir estado en `SetExtState`**: recordar qué plugin estaba activo entre sesiones y sincronizar el highlight del toolbar al abrir el proyecto.

## Freeze (freeze_reainsert / desarma_freeze)

- [ ] Eliminar redundancia: `handle_print_send` no aporta si `MUTE_ALL_ORIGINAL_SENDS = true` (ya mutea todos los sends).
- [ ] Hacer el EXIT Freeze reversible: guardar estado en `SetExtState` y poder restaurar FX/ruteo originales.
- [ ] Vaciar la cadena FX de la pista FREEZE al crearla (o heredar solo ReaInsert).
- [ ] Manejar estado de transporte: guardar play/record state con `GetPlayStateEx` y retomar.
- [ ] Verificar que la pista FREEZE quede justo debajo de la original; dar error si el emparejamiento falla (ya hay aviso básico).
- [ ] Considerar modo "print punch" o auto-stop al final del ítem/región.
- [ ] **Verificar la grabación**: tras grabar, comprobar que las takes no estén vacías y avisar; auto-stop tras el primer ítem (modo "print punch").

## setea_B.lua

- [ ] Unificar los ~8 bloques de Undo en uno solo (deshacer todo de una vez).
- [ ] Manejar pistas de batería MIDI (filtrar por `TakeIsMIDI` / `I_NCHAN`).
- [ ] Envolver `reorderAllTracks` en `PreventUIRefresh(1)` para evitar refresco repetido.
- [ ] Añadir opción de "modo seco": solo crear/rutear sin reordenar (para proyectos grandes).
- [ ] Registrar alias nuevos que el usuario encuentre en la práctica (ej. nombres alternos de tracks).

## rutea_a_seleccionado.lua

- [ ] Validar pistas con `ValidatePtr` antes de operar.
- [ ] Opción de copiar también volumen/pan del send si ya existía.
- [ ] Reportar cuántas pistas se rutearon (mensaje o console).

## solo_bus_a.lua

- [ ] Localizar `INSTRUMENT_TRACKS_ONLY` y demás variables globales.
- [ ] Hacer `busName` configurable por ExtState o input del usuario.
- [ ] Revisar la función `getScore` (copiada de SWS) por posibles edge cases.
- [ ] **Optimizar para varios buses (A, B, C, D, VOX)**: el `busName` está hardcodeado y hay que editarlo manualmente por bus. Opciones (de mejor a peor):
  - [ ] **Un script por bus**: generar 5 copias (A, B, C, D, VOX), cada una con su `busName` fijo → 5 acciones, cada una a su atajo/tecla/botón de toolbar. Patrón idiomático en REAPER.
  - [ ] **Script que cicla**: una sola acción que recorre A → B → C → D → VOX → A, memorizando el bus actual con `SetExtState`.
  - [ ] **Pedir el nombre** con `GetUserInputs` cada vez (flexible pero lento).

## sincroniza_tempo.lua

- [ ] Redondear todos los valores a 2 decimales de forma consistente.
- [ ] Añadir división 1/64.
- [ ] Localizar la variable `tempo`.
- [ ] Opción de copiar al portapapeles (`CF_Text`) un valor elegido.
- [ ] **Soporte de tempo maps**: si el proyecto tiene varios BPM (`GetTempoTimeSigMarker`), listar las duraciones por sección.
- [ ] **Mejorar la visualización (ReaImGui)**: reemplazar el `ShowMessageBox` (muy "alert") por una ventana interactiva con:
  - Tablas por grupo (directo / tercillo / puntillo / swing) para consulta rápida.
  - BPM editable en vivo que recalcula al instante.
  - Botón para copiar un valor al portapapeles.
  - Ajuste opcional de swing (%).
  - Requiere ReaImGui (librería ReaPack).

## General / infraestructura

- [ ] Headers `@changelog`, `@about`, `@provides` consistentes para ReaPack.
- [ ] Revisar headers de versión/autor en todos los scripts.
- [ ] Verificar precondiciones con mensajes de error en español coherentes.
- [ ] Consistencia de estilos: indentación, nombres de funciones, español/inglés en comentarios.
