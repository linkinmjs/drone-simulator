# Tutorial / instructor de vuelo: análisis y plan

Fecha: 16 de septiembre de 2026. Commit de referencia: `2c5a950`. Godot 4.7 stable.

Estado: **implementado** en la rama `instructor-de-vuelo`. La arquitectura final, los desvíos y las pruebas están en [tutorial.md](tutorial.md). Este documento queda como registro del análisis y del plan original.

Desvíos principales respecto del plan:

- El sistema de traducción ya existía (lo agregó el rediseño de UI): se sumaron claves `TUT_` al mismo CSV.
- Los menús de inicio, selector y final son `MenuScreen` construidos en código, y la tarjeta baja a y = 236 para no tapar la insignia de modo ni el cronómetro de carrera.
- Las lecciones 6 y 7 usan `Gate_Double_1` (abertura de 2,8 m) y la pista del circuito usa `Gate_7x6_Simple`.
- Se corrigieron dos bugs encontrados al probar: el cabeceo invertido de los bindings por defecto (y la navegación con sticks escrita sobre ellos) y un dron desarmado que quedaba atrapado en modo recuperación.
- Se agregó reaparición automática si el dron queda volcado 3 s o cae fuera del mapa.

## 1. Objetivo y decisiones tomadas

El juego tiene un solo nivel (`sceneries/level1.tscn`) con 9 pistas y sin ninguna guía: un jugador nuevo ve "DISARMED" y no sabe que debe bajar el acelerador a cero para armar. `ANALISIS_SIMULADOR_DRONES.md` §3.2 propone una primera sesión guiada como prioridad P1.

Se va a crear un segundo nivel, `sceneries/tutorial_level.tscn`, con 8 lecciones progresivas: mando y armado, despegue y altura, guiñada, cabeceo, alabeo, puertas en Horizon, puertas en Acro y un circuito cronometrado.

Decisiones acordadas con el usuario:

| Tema | Decisión |
|---|---|
| Idioma | Español, con sistema de traducción nuevo (CSV `keys,en,es` + `tr()`). Los menús viejos en inglés no se tocan, salvo el botón nuevo |
| Entrada | Solo mando o radio, como hoy. La lección 1 verifica que haya un joypad y que los sticks respondan. Sin teclado para volar |
| Alcance | Las 8 lecciones. La última reutiliza el sistema de pistas (`Track`) |
| Plataformas | Escritorio y exportación Web (renderer Compatibility, sin hilos) |

## 2. Hallazgos del código relevantes para el tutorial

### 2.1 Cómo se arma un nivel

- `sceneries/level.gd` (137 líneas, `extends Node3D`, sin `class_name`). En `_ready` llama `Graphics.apply_compatibility_workarounds($WorldEnvironment)`, junta las cámaras con `get_cameras()` (no entra en los hijos de `FPVCamera`), arranca en `cameras[0]` y llama `change_camera()`, mete en `tracks` los hijos directos que sean `Track`, y conecta `Global.game_mode_changed` y `drone.respawned`.
- `_unhandled_input` maneja `change_camera` (C / botón 3) y `pause_menu` (Esc / botón 6: pausa el árbol, instancia `gui/pause_menu.tscn`, muestra el mouse).
- `change_camera()` muestra `drone.hud` **solo** con la cámara FPV (`level.gd:70-73`).
- `_on_drone_reset()` resetea todas las pistas; en modo RACE con `Global.active_track` llama `initialize_replay`, `load_replays` y `start_countdown`.
- `_on_game_mode_changed(mode)`: FREE detiene la carrera; RACE elige la pista con el launchpad más cercano (`get_closest_track()`) y hace `drone.reset()`.
- `_on_return_to_menu()` cambia a `res://gui/main_menu.tscn`. No restablece `Global.game_mode`.

Nodos que un nivel debe tener sí o sí:

- `WorldEnvironment` (para la corrección de Compatibility).
- Un `Node3D` llamado `Respawn`: `drone.gd:219` hace `get_tree().root.get_children()[-1].get_node("Respawn")`, así que el nivel debe ser además el **último hijo de root** (lo garantiza `change_scene_to_file`).
- `Drone` (instancia de `drone/drones/drone1.tscn`) con un hijo `FPVCamera` (Camera3D + `drone/fpv_camera/fpv_camera.gd`, rotado 30° hacia abajo, `clip_near = 0.006`). La escena del dron no lo trae; `drone.gd:274` hace `$FPVCamera`.
- `RadioController` (Node + `drone/radio_controller.gd`, `target_path = ../Drone`).
- Al menos una `Camera3D`.

`level1.tscn` (líneas 70-107 y 245) es la fuente para copiar cielo, luz, cámaras, dron y radio.

### 2.2 Dron y controlador de vuelo

- `drone/drone.gd` (`class_name Drone extends RigidBody3D`): señales `respawned` y `transform_updated`. Instancia el HUD (`hud/hud.tscn`) como hijo. `reset()` / `_on_reset()` espera un frame de física, pone velocidades a cero, mueve al `Respawn` (o a un launch area en RACE), llama `flight_controller.reset()` y emite `respawned`. **No hay detección de choques** (`contact_monitor` apagado).
- `drone/flight_controller/flight_controller.gd` (`class_name FlightController`): señales `armed(mode)`, `disarmed`, `arm_failed(reason)` con `enum ArmFail {THROTTLE_HIGH, CRASH_RECOVERY_MODE}`, `flight_mode_changed(mode)`. Estado legible: `pos` (altura en `pos.y`), `angles` (x = pitch, y = yaw, z = roll, radianes), `lin_vel`, `local_vel`, `ang_vel`, `input: FlightCommand` (`power` 0..1, `pitch/roll/yaw` -1..1), `state_armed`, `flight_mode`, `flight_mode_idx`.
- Armado (`_on_arm_input`, líneas 205-218): solo si `input.power <= 0.01` y no está en Recover; si no, emite `arm_failed`.
- `change_flight_mode(idx)` (línea 396) cambia el modo y emite, pero **no** actualiza `flight_mode_idx`; tras Recover → desarme, `_on_disarm_input` vuelve a `flight_mode_idx` (ACRO por defecto). `_on_cycle_flight_modes()` cicla ACRO → HORIZON → SPEED → TRACK y siembra los PID de altura/posición.
- `_ready` difiere `change_flight_mode(ACRO)` con `call_deferred` (línea 76) y conecta `flight_mode_changed` a `get_parent()._on_flight_mode_changed`.
- `_physics_process` pasa HORIZON/SPEED/TRACK a RECOVER cuando `is_flight_safe()` es falso (|pitch| o |roll| > 50°). Recover desarma solo por debajo de 1 m (`flight_mode_recover.gd:37`).
- Modos (`drone/flight_controller/flight_mode/`): `FlightMode.Type {ACRO, HORIZON, SPEED, TRACK, LAUNCH, TURTLE, RECOVER}`. **HORIZON pasa el acelerador directo** (`flight_mode_horizon.gd:22`), autonivela con límite de 35° y el yaw es una velocidad. ACRO es todo velocidades. TRACK ("POSITION") mantiene posición y altura.
- `drone/radio_controller.gd` (`class_name RadioController`): señales `reset_requested`, `mode_changed`, `arm_input`, `disarm_input`, conectadas en su `_ready` al dron y al FC. `input` (sticks crudos) es público. Lee con `Input.get_axis("throttle_down", "throttle_up")` etc.; `power = (eje + 1) / 2`, así que el centro de un stick con resorte es 50 %.

### 2.3 HUD, pistas y checkpoints

- `hud/hud.gd` (`class_name HUD`): `status: HUDStatus`, `show_component()`, `update_flight_mode()` (ACRO muestra vacío). `hud/hud_status.gd`: `set_message(msg)` (antepone 7 saltos de línea), `clear_message()`, `message_timer`; `_on_arm_failed` muestra «*** THROTTLE HIGH ***» 1 s. `hud/hud_stick_input.tscn` (`HUDStickInput.update_stick_input(Vector2)`) es reutilizable para mostrar qué stick mover.
- Temas: `gui/menu_theme.tres` (32 px), `gui/countdown_theme.tres` (64 px, contorno 12), `gui/timer_theme.tres` (24 px), `gui/help_page_theme.tres` (24 px), `hud/hud_theme.tres` (mono 24 px). Fuentes `gui/RecursiveSansLnrSt-Med.otf`, `-Bold.otf`.
- `tracks/track.gd` (`@tool class_name Track`): `race_state_changed(state)`, exports `course` (índices de checkpoints, `Nb` = al revés, `lap_start`/`lap_end`) y `laps`. Crea en código el countdown, el cronómetro y el «Finished!». `start_countdown()`, `start_race()`, `stop_race()`, `end_race()` (escribe récords y replays), `reset_track()`, `get_random_launch_area()`, salida en falso al salir del launchpad. Crea 5 `Ghost` que nunca entran al árbol (fuga conocida).
- `tracks/checkpoint.gd` (`@tool class_name Checkpoint extends Area3D`): señales `entered`, `exited`, `passed` (emitida con `self`); `active` muestra la malla generada a partir de sus `CollisionShape3D` (Box o Cylinder); valida dirección con el producto punto de la velocidad; respaldo por raycast desde el dron (`drone.gd:118-128`). `setup_checkpoint_mesh()` es diferido y termina con `area_visible = true` (línea 90), así que todos quedan visibles salvo que se oculten después.
- `tracks/gate.gd` es un marcador vacío. `tracks/objects/Launchpad.tscn` = plataforma + 4 `LaunchArea`. Puertas listas: `tracks/gates/Gate_7x6_Simple.tscn` (checkpoint 2.1×1.8 m a 0.9 m), `Gate_Double_1.tscn` (postes, 2.8×3 m), etc. Props: `tracks/objects/Flag.tscn`, `ConePattern_Up1.tscn`, `RacingCone_1.mesh`.
- `tracks/tracks/Track_DoubleGateTraining.tscn` = launchpad + 3 `Gate_Double_1` en línea, `laps` por defecto 3.
- `tracks/time_table.gd` se cierra sola al salir de RACE (línea 71) y captura el mouse al cerrarse.

### 2.4 Autoloads, menús, input y exportación

- `autoloads/global.gd`: `signal game_mode_changed` (declarada sin parámetro, emitida con uno), `enum GameMode {FREE, RACE}`, `enum RaceState`, `game_mode`, `active_track`, `_unhandled_input` alterna carrera con la tecla R (acción `race_mode`) en cualquier escena. `config_dir = "user://config"`, `show_error_popup()`, `log_error()`.
- `autoloads/game_settings.gd`: `hud_config` guardado con `ConfigFile` en `user://config/GameSettings.cfg`, sección `[hud_config]`; `load_hud_config()` / `save_hud_config()` (líneas 41-50) son el patrón a copiar.
- `autoloads/controls.gd`: `action_list`, `load_input_map()` (solo reescribe las acciones listadas), `restore_keyboard_shortcuts()` (M, Espacio, Retroceso).
- `autoloads/audio.gd`: solo volumen maestro; no hay API de efectos ni sonidos de UI (solo WAV de hélices).
- Acciones (`project.godot`): ejes `throttle/pitch/roll/yaw_*` solo en joypad (ejes 1, 3, 2, 0); `toggle_arm` = botón 9 (LB) + Espacio; `respawn` = Retroceso + botón 4 (BACK); `cycle_flight_modes` = botón 0 (A) + M; `change_camera` = botón 3 (Y) + C; `pause_menu` = botón 6 (START) + Esc; `race_mode` = R. Libres: botones 1 (B), 2 (X), 10 (RB).
- `gui/main_menu.gd:38-39`: «Fly» abre `level1.tscn` con la ruta fija; no hay lista de niveles. Los submenús se instancian como hijos, el padre oculta su contenedor y hace `await sub.back`.
- Sin `tr()`, sin archivos de traducción, sin `[internationalization]`. Todo hardcodeado en inglés.
- Convenciones: tipado estático obligatorio (`untyped_declaration` y `return_value_discarded` como avisos), `var _discard := x.connect(...)`, señales conectadas en código, `@onready var x := %X as Tipo`, `preload` en `var packed_*`, archivos en snake_case, `class_name` en PascalCase para lo reutilizable, `@export` para datos de juego, `@tool` para contenido editable. Sin tests ni addons. Mensajes de commit en español.
- Web: `export_presets.cfg` con un solo preset Web, `thread_support=false`. `docs/optimizacion.md`: los 218 `Area3D` de level1 cuestan 0.39 ms por tick; un nivel nuevo debe tener pocas áreas. El gamepad en el navegador aparece recién al pulsar un botón.

## 3. Diseño

| Tema | Decisión | Motivo |
|---|---|---|
| Nivel | `level.gd` recibe `class_name Level`; `sceneries/tutorial_level.gd` es `class_name TutorialLevel extends Level` | Hereda cámaras, pausa, `tracks`, reset y retorno al menú |
| Lecciones | Un nodo por lección: `TutorialStep extends Node` (base) + 6 subclases, 8 instancias hijas de `TutorialSequencer` | Los `@export var x: NodePath` se resuelven contra la escena (zonas, checkpoints, pista) |
| Modo de vuelo | HORIZON forzado en 1–6, ACRO en 7–8; `cycle_flight_modes` bloqueado en 1–7 | HORIZON autonivela pero el acelerador es directo: ideal para aprender |
| Tecla R | Nuevo `Global.race_mode_toggle_enabled := true`; el tutorial lo pone en `false` | Evita entrar en carrera en cualquier momento |
| Lección 8 | `Global.game_mode = RACE` por código + `Track_Tutorial` con `laps = 1` | Reutiliza countdown, salida en falso, `LapTimer` y `TimeTable` |
| UI | `tutorial/tutorial_hud.tscn` = `CanvasLayer` propio | El HUD del dron se oculta fuera de la cámara FPV |
| Choque | `flight_mode is FlightModeRecover` + volcado en el suelo (`pos.y < 0.5` y \|pitch\| o \|roll\| > 60° durante 0,5 s) | No hay colisiones en el dron; alcanza sin `contact_monitor` |
| Progreso | Sección `[tutorial]` en `GameSettings.cfg`: `completed_mask` (bits) + `last_lesson` | Mismo patrón que `hud_config` |
| Acciones nuevas | `tutorial_next` = joy 2 (X) + Enter; `tutorial_skip` = joy 10 (RB) + N; repetir = `respawn` existente | Botones libres del mapa actual |

### 3.1 Nivel

`sceneries/level.gd`: agregar `class_name Level` en la línea 1.

`sceneries/tutorial_level.gd` (`class_name TutorialLevel extends Level`):

- `@onready`: `tutorial_drone := $Drone as Drone`, `radio := $RadioController as RadioController`, `sequencer := $TutorialSequencer as TutorialSequencer`, `tutorial_hud := $TutorialHUD as TutorialHUD`, `respawn := $Respawn as Node3D`. `@export var persist_progress := true` (el checker lo pone en `false`).
- `_ready()`: `super()`; `Global.race_mode_toggle_enabled = false`; `Global.game_mode = FREE`; `Global.active_track = null`. Re-cablear el ciclo de modos: desconectar `radio.mode_changed` de `fc._on_cycle_flight_modes` y conectar `_on_mode_cycle_requested` (si `current_step.block_mode_cycling` muestra `TUT_WARN_MODE_LOCKED`, si no reenvía). Conectar `Input.joy_connection_changed(device, connected)` y `fc.arm_failed` (aviso `TUT_WARN_THROTTLE_HIGH`). Ocultar el checkpoint activo de `Track_Tutorial`. `GameSettings.load_tutorial_progress()`; si la primera lección incompleta es > 1 mostrar `StartPanel`, si no `sequencer.start_at.call_deferred(0)` (diferido para que el ACRO diferido del FC no pise el HORIZON).
- `_unhandled_input(event)`: `super(event)`; `tutorial_next` → `sequencer.confirm()`; `tutorial_skip` → `sequencer.skip_current()`.
- `_on_drone_reset()`: `super()`; `sequencer.on_drone_respawned()` → `current_step.restart()`; en lecciones 1–7 volver a ocultar el checkpoint del `Track`.
- `_on_return_to_menu()`: `Global.game_mode = FREE`, `active_track = null`, `race_mode_toggle_enabled = true`, guardar progreso, `super()`.
- `add_pause_menu()`: `super()` y ocultar `tutorial_hud` mientras el menú esté abierto (el `PauseMenu` está en la capa 0); reconectar `resumed` para mostrarlo de nuevo.
- Helpers para los steps: `set_flight_mode(type)`, `select_camera(name)`, `set_respawn_transform(xform)`, `respawn_drone()`.

`drone/flight_controller/flight_controller.gd`, agregar:

```gdscript
func select_flight_mode(mode: FlightMode.Type) -> void:
	flight_mode_idx = mode
	change_flight_mode(mode)
```

`autoloads/global.gd`: `var race_mode_toggle_enabled := true` comprobado en `_unhandled_input`, y corregir `signal game_mode_changed(mode: int)`.

### 3.2 Sistema de lecciones (`tutorial/`)

`tutorial/tutorial_step.gd` (`class_name TutorialStep extends Node`):

```gdscript
signal completed
@export var title_key := ""          # "TUT_L2_TITLE"
@export var objective_key := ""      # "TUT_L2_OBJECTIVE" (BBCode)
@export var flight_mode := FlightMode.Type.HORIZON
@export var block_mode_cycling := true
@export var camera_name := "FPVCamera"
@export var respawn_marker: NodePath   # vacío = origen
@export var respawn_on_start := true
var level: TutorialLevel; var drone: Drone; var radio: RadioController; var fc: FlightController
var active := false
func setup(p_level: TutorialLevel) -> void   # refs + conexiones (una sola vez)
func start() -> void    # Respawn, select_flight_mode, select_camera, respawn, _on_start(), active = true
func restart() -> void  # _on_restart(): progreso a cero; no respawnea
func stop() -> void; func finish() -> void   # finish: active = false, completed.emit()
func get_progress_text() -> String; func get_stick_hint() -> Array[Vector2]   # virtuales
func _physics_process(delta): if active: _tick(delta)
func _on_start() / _on_restart() / _on_stop() / _tick(delta)   # virtuales
```

Detección de choque en la base: Recover → `TUT_WARN_RECOVER`; volcado en el suelo 0,5 s → `TUT_WARN_CRASHED` («Presioná BACK para reiniciar la lección»). El aviso se limpia en `restart()`.

`tutorial/tutorial_sequencer.gd` (`class_name TutorialSequencer extends Node`): señales `lesson_started(index, step)`, `lesson_completed(index)`, `lesson_skipped(index)`, `tutorial_finished`; `enum State {IDLE, RUNNING, SUCCESS, FINISHED}`; `@export var success_delay := 2.5`; `steps` = hijos en orden; `setup(level)`, `start_at(index)`, `restart_current()`, `skip_current()`, `confirm()`, `advance()`, `on_drone_respawned()`, getter `current_step`. Al completar: `state = SUCCESS`, si `level.persist_progress` → `GameSettings.mark_lesson_completed(i + 1)`, timer → `advance()`. Omitir no marca la lección.

Lecciones y condiciones de éxito (se lee `fc` y `radio.input`; todos los umbrales son `@export`):

| # | Nodo / script | Modo | Éxito |
|---|---|---|---|
| 1 | `L1_Controller` / `steps/step_controller_check.gd` | HORIZON | Fases: joypad conectado → `power >= 0.9` y luego `<= 0.02` → yaw ≤ -0.5 y ≥ 0.5 → pitch ≥ 0.5 y ≤ -0.5 → roll ≤ -0.5 y ≥ 0.5 → señal `armed` → señal `disarmed` |
| 2 | `L2_Hover` / `steps/step_hover.gd` | HORIZON | Armado → `1.5 ≤ pos.y ≤ 2.5` durante 3 s continuos → aterrizar (`pos.y < 0.3`, velocidad < 1 m/s, 1 s) → desarmar. `HoverRing` cambia de color en banda. El texto aclara que el centro del stick no alcanza para flotar |
| 3 | `L3_Yaw` / `steps/step_yaw.gd` | HORIZON | Despegar (`pos.y ≥ 0.8`) → giro acumulado a la izquierda ≥ 90° (`angle_difference` entre ticks, solo en el aire) → a la derecha ≥ 90°. Aterrizar pausa la acumulación. 4 banderas a 10 m |
| 4 | `L4_Pitch` / `steps/step_reach_markers.gd` | HORIZON | `markers = [ZoneFront (0,0,-8), ZoneCenter (0,0,0)]`; zona alcanzada si distancia horizontal ≤ 1.5 m y `pos.y ≥ 0.5` |
| 5 | `L5_Roll` / mismo script | HORIZON | `markers = [ZoneRight (8,0,0), ZoneCenter, ZoneLeft (-8,0,0), ZoneCenter]` |
| 6 | `L6_GatesHorizon` / `steps/step_gates.gd` | HORIZON | `checkpoints = [Gates/Gate1..3/Checkpoint]`; al iniciar todos `active = false` y activa el primero; en `passed(cp)` si es el actual → siguiente o `finish()`. Sin `Track`: `end_race()` en FREE escribiría un récord |
| 7 | `L7_GatesAcro` / mismo script | ACRO | Idéntico; el texto explica que el stick manda velocidad de giro y hay que centrarlo |
| 8 | `L8_Race` / `steps/step_race.gd` | ACRO, `block_mode_cycling = false`, `respawn_on_start = false` | `_on_start`: `Global.game_mode = RACE` (→ pista más cercana → `drone.reset()` → spawn en el launchpad → countdown). Éxito: `race_state_changed` con `END`; el flash muestra `track.timers[0].get_time_string()`. `_on_stop`: `Global.game_mode = FREE` |

### 3.3 UI: `tutorial/tutorial_hud.tscn` + `tutorial_hud.gd` (`class_name TutorialHUD extends CanvasLayer`, `layer = 1`)

Control raíz full-rect con `mouse_filter = IGNORE`:

- `%Title` (arriba-centro, 36 px con contorno, `RecursiveSansLnrSt-Bold.otf`): «Lección 2/8 · Despegue y altura».
- `%Panel` (arriba-izquierda, ~560 px, alpha 0.85) → `%Objective` (RichTextLabel BBCode, `fit_content`, `help_page_theme.tres`) + `%Progress` (Label, `hud_theme.tres`).
- `%Warning` (ámbar bajo el título; vacío = oculto).
- `%StickHints` (abajo-izquierda): dos `hud/hud_stick_input.tscn` animados con `v * (0.6 + 0.4 * sin(t * 4))`, etiquetas «Izq: acelerador / guiñada», «Der: alabeo / cabeceo». Mismo convenio de vector que `drone.gd:207-208`.
- `%Flash` (centrado en y ≈ 0.35, `countdown_theme.tres`): «¡Bien!» con `Tween` de alpha. Deja libre el centro para el countdown y `HUDStatus`.
- `%Footer` (abajo-centro): `tr("TUT_FOOTER") % [next, skip, repeat, pause]` con `InputMap.action_get_events(action)[0].as_text()`.
- `%StartPanel` / `%EndPanel` (centrados, `menu_theme.tres`): «Retomar en la lección %d» / «Empezar de nuevo»; «Volar libre» (→ `level1.tscn`) / «Menú principal» / «Repetir tutorial». Con `grab_focus()` y mouse visible. Señales `continue_requested`, `restart_requested`, `fly_requested`, `menu_requested`.

API: `set_lesson(index, total, title)`, `set_objective(bbcode)`, `set_progress(text)`, `set_stick_hint(left, right)`, `set_warning(text)`, `flash(text, duration := 2.5)`, `show_start_panel(resume_lesson)`, `show_end_panel()`, `hide_panels()`. El nivel refresca progreso y hints con un `Timer` de 0.1 s.

### 3.4 Localización

- `localization/translations.csv`, UTF-8 sin BOM, encabezado `keys,en,es`, celdas con comas o saltos entre comillas. BBCode en objetivos; placeholders `%d`, `%.1f`, `%s` para `tr(key) % [...]`.
- Godot genera `translations.csv.import` y `localization/translations.{en,es}.translation`. Commitear los tres.
- `project.godot`:

```
[internationalization]
locale/translations=PackedStringArray("res://localization/translations.en.translation", "res://localization/translations.es.translation")
locale/fallback="en"
```

- Si el import headless no agrega la lista, escribirla a mano. No commitear `locale/test`.
- Locale: `TranslationServer` usa el del sistema (`es_AR` → `es`; en Web, `navigator.language`). Para probar en Windows en inglés: `--language es`. Selector de idioma en la pestaña «Gameplay» (hoy vacía): seguimiento.
- Uso: `tr("TUT_L2_TITLE")` en código; en los `.tscn` nuevos poner la clave en `text`. Los textos en inglés de `HUDStatus`, `Track` («Finished!», «GO!», «False Start!») y menús quedan como están.
- Claves: `MENU_TUTORIAL`; genéricas `TUT_LESSON_LABEL`, `TUT_WELL_DONE`, `TUT_FOOTER`, `TUT_WARN_NO_JOYPAD`, `TUT_WARN_THROTTLE_HIGH`, `TUT_WARN_RECOVER`, `TUT_WARN_CRASHED`, `TUT_WARN_MODE_LOCKED`, `TUT_START_*`, `TUT_END_*`, `TUT_RACE_TIME`; por lección `TUT_L{n}_TITLE`, `TUT_L{n}_OBJECTIVE` y las de progreso `TUT_L1_P_JOYPAD/THROTTLE/YAW/PITCH/ROLL/ARM/DISARM`, `TUT_L2_P_ARM/HOLD/LAND/DISARM`, `TUT_L3_P_TAKEOFF/LEFT/RIGHT`, `TUT_ZONE_P`, `TUT_GATE_P`, `TUT_L8_P_WAIT/GATE`.
- Títulos (es): 1 «Tu control», 2 «Despegue y altura», 3 «Guiñada», 4 «Cabeceo», 5 «Alabeo», 6 «Puertas en modo Horizon», 7 «Puertas en modo Acro», 8 «Tu primer circuito».
- Confirmar que las fuentes Recursive rendericen «¡ ¿ ñ á» con `--language es`.

### 3.5 Escena `sceneries/tutorial_level.tscn` y pista

Raíz `TutorialLevel` (Node3D, `process_mode = 1`). Spawn en el origen, frente = -Z.

| Nodo | Detalle |
|---|---|
| `WorldEnvironment`, `DirectionalLight3D`, `CameraFixed`, `FollowCamera`, `FlyaroundCamera`, `Drone` + `FPVCamera`, `RadioController` | Copiar de `level1.tscn` líneas 70-107 y 245 |
| `Respawn` | Node3D en (0,0,0) |
| `Objects/Ground` | StaticBody3D con **un** `BoxShape3D` 120×1×120 en y = -0.5 + `BoxMesh` 120×120 con `Assets/grid_material.tres` |
| `Objects/StartPad` | BoxMesh 2×0.02×2, solo visual |
| `Props/HoverRing` | `TorusMesh` (inner 1.4, outer 1.6) en (0,2,0), material transparente con emisión, sin cull |
| `Props/FlagN/E/S/W` | `tracks/objects/Flag.tscn` en (0,0,-10), (10,0,0), (0,0,10), (-10,0,0) |
| `Props/ZoneFront/Right/Left/Center` | `tutorial/tutorial_zone.tscn` (Marker3D + `CylinderMesh` r 1.5 h 4 translúcido + `ConePattern_Up1.tscn`; `tutorial_zone.gd` con `set_state(IDLE/ACTIVE/DONE)`) |
| `Gates/Gate1..3` | `tracks/gates/Gate_7x6_Simple.tscn` en (0,0,-15), (0,0,-27), (0,0,-39), rotación identidad |
| `Track_Tutorial` | Instancia de `tracks/tracks/Track_Tutorial.tscn` en (30,0,0), **hijo directo** del nivel |
| `TutorialSequencer` | Node + 8 hijos `TutorialStep` |
| `TutorialHUD` | Instancia de `tutorial/tutorial_hud.tscn` |

`tracks/tracks/Track_Tutorial.tscn` (script `track.gd`, `laps = 1`, `course` vacío): `Launchpad` en (0,0,10); `Gate1` (0,0,-10) rot 0; `Gate2` (12,0,-20) rot_y -90°; `Gate3` (24,0,-10) rot_y 180°; `Gate4` (12,0,20) rot_y +90°. Rectángulo ~24×30 m con giros a la derecha; ajustar en el editor con `edit_track`.

`Area3D` totales: 3 + 4 + 4 launch areas = 11 (level1 tiene 218).

Detalle: como `setup_checkpoint_mesh()` es diferido y deja todo visible, `StepGates` y `TutorialLevel._ready` deben ocultar los checkpoints después (también diferido o esperando un frame), y repetirlo en cada `_on_drone_reset` hasta la lección 8.

### 3.6 Menú, input y persistencia

- `gui/main_menu.tscn`: `Button` `ButtonTutorial` (`unique_name_in_owner`, `text = "MENU_TUTORIAL"`) entre `ButtonFly` y `ButtonQuad`. `gui/main_menu.gd`: `@onready var button_tutorial := %ButtonTutorial as Button`, conexión en `_ready`, handler → `change_scene_to_file("res://sceneries/tutorial_level.tscn")`.
- `project.godot` `[input]`: `tutorial_next` (JoypadButton 2 + Enter), `tutorial_skip` (JoypadButton 10 + N). No se agregan a `Controls.action_list`.
- `autoloads/game_settings.gd`: `signal tutorial_progress_updated`, `var tutorial_progress := {"completed_mask": 0, "last_lesson": 1}`, `load_tutorial_progress()` (sección `tutorial`, FILE_NOT_FOUND silencioso), `save_tutorial_progress()` (cargar antes de `set_value` para conservar `[hud_config]`; `make_dir_recursive_absolute(Global.config_dir)`), `is_lesson_completed(n)`, `mark_lesson_completed(n)`, `get_first_incomplete_lesson(total)`, `reset_tutorial_progress()`.

## 4. Casos borde

| Caso | Manejo |
|---|---|
| Vuelco / RECOVER | Aviso; el FC desarma bajo 1 m y vuelve a `flight_mode_idx` (HORIZON gracias a `select_flight_mode`); BACK reinicia la lección |
| Volcado en el suelo (ACRO) | Detector de la base del step → `TUT_WARN_CRASHED` |
| Armar con acelerador alto | `arm_failed(THROTTLE_HIGH)` → aviso localizado 2 s |
| Desarme a mitad de lección | Las fases que exigen `state_armed` vuelven a esperar; L2 reinicia `held`, L3 pausa la acumulación |
| Control desconectado | `Input.joy_connection_changed` → `TUT_WARN_NO_JOYPAD` hasta reconectar; L1 vuelve a la fase de espera |
| Salida en falso en L8 | El `Track` muestra «False Start!» y no reanuda: el progreso indica BACK |
| Salir al menú | Siempre `FREE`, `active_track = null`, `race_mode_toggle_enabled = true` |
| Escena corrida directa | `Global.startup` queda `true`, valen los bindings de `project.godot`; `save_tutorial_progress` crea el dir |
| Fuga de 5 `Ghost` por `Track` | Aceptable con una sola pista; no se corrige acá |
| Highscores y replays de `Track_Tutorial` | `end_race()` los escribe; aceptable |

## 5. Verificación

`GODOT` = `C:/Users/Mauri/Godot/Godot_4.7/Godot_v4.7-stable_win64_console.exe`.

1. `GODOT --headless --path . --import` → aparecen los `.translation` y la lista en `project.godot`; cero errores.
2. `GODOT --headless --path . --quit-after 120 res://sceneries/tutorial_level.tscn` → sin errores de script ni «Node not found».
3. Checker `tools/checks/tutorial_check.tscn` + `.gd` (agregar `exclude_filter="tools/*"` al preset Web): instancia el nivel con `persist_progress = false`, lo agrega a **root** con `add_child.call_deferred` (último hijo, por `drone.gd:219`); `TranslationServer.set_locale("es")` y `assert(tr("TUT_L1_TITLE") != "TUT_L1_TITLE")`. Simula L1 con `Input.action_press("throttle_up", 1.0)` / `throttle_down`, barrido de `yaw/pitch/roll_*`, `radio.arm_input.emit()`, `radio.disarm_input.emit()`; L2 con un control P sobre `throttle_up` (`0.25` ya hace flotar según `docs/optimizacion.md`) hasta `held ≥ 3 s`, aterrizar y desarmar; L3 con `yaw_left 0.5` ~0.6 s y luego `yaw_right`. `quit(0)` al llegar a L4 con «CHECK OK», `quit(1)` a los 60 s.
4. Proxy Web: `GODOT --path . --windowed --resolution 1280x720 --rendering-method gl_compatibility --language es res://sceneries/tutorial_level.tscn`.
5. Playtest manual con el pad de Xbox: 8 lecciones, BACK, RB, X, START, Y, desconectar el pad.
6. Avisos GDScript: `GODOT --headless --path . --check-only -s <script>` por script nuevo y el panel del editor; cero `UNTYPED_DECLARATION` / `RETURN_VALUE_DISCARDED`.
7. CI: el job `import-assets` debe pasar (todo push corre import y export).

## 6. Hitos (commits en español)

1. **M1 – i18n, botón y nivel vacío.** Nuevos: `localization/translations.csv` (+ import y `.translation`), `sceneries/tutorial_level.tscn` sin props, `sceneries/tutorial_level.gd` mínimo. Modificados: `project.godot`, `sceneries/level.gd`, `gui/main_menu.tscn`, `gui/main_menu.gd`, `autoloads/global.gd`. Verificar pasos 1, 2 y 4.
2. **M2 – Sequencer, HUD, lecciones 1–2.** Nuevos: `tutorial/tutorial_step.gd`, `tutorial/tutorial_sequencer.gd`, `tutorial/tutorial_hud.tscn/.gd`, `tutorial/steps/step_controller_check.gd`, `tutorial/steps/step_hover.gd`. Modificados: `flight_controller.gd` (`select_flight_mode`), escena y nivel, CSV.
3. **M3 – Lecciones 3–5.** Nuevos: `steps/step_yaw.gd`, `steps/step_reach_markers.gd`, `tutorial/tutorial_zone.tscn/.gd`; banderas y zonas; CSV.
4. **M4 – Lecciones 6–7.** Nuevo: `steps/step_gates.gd`; 3 `Gate_7x6_Simple`; CSV.
5. **M5 – Lección 8 y persistencia.** Nuevos: `tracks/tracks/Track_Tutorial.tscn`, `steps/step_race.gd`. Modificados: `autoloads/game_settings.gd`, paneles inicio/fin, CSV.
6. **M6 – Pulido y verificación.** Nuevos: `tools/checks/tutorial_check.tscn/.gd`, `docs/tutorial.md` (arquitectura, cómo agregar una lección, cómo probar), mención en `README.md`. Hints de sticks, avisos, ajuste de umbrales tras playtest, corrida en `gl_compatibility`.

Estimación: ~19 archivos nuevos (+3 generados por el import) y 7 modificados (`project.godot`, `level.gd`, `main_menu.tscn`, `main_menu.gd`, `global.gd`, `game_settings.gd`, `flight_controller.gd`).

## 7. Riesgos y rarezas del código existente

- `drone.gd:219`: el nivel debe ser el último hijo de root (afecta al checker).
- `hud/hud_status.gd:53-60` compara un objeto `FlightMode` con enteros: siempre muestra «ARMED». Inofensivo.
- `checkpoint.gd:90` deja visibles todos los checkpoints tras el setup diferido.
- `track.gd:211-218` `end_race()` en modo FREE también escribe récords (por eso 6–7 usan checkpoints sueltos).
- `time_table.gd:37` pone el mouse visible y `delete()` lo captura; en L8 se cierra sola al volver a FREE.
- Web: `Input.get_connected_joypads()` está vacío hasta el primer botón.
- El acelerador con stick de resorte (centro = 50 %) sigue siendo incómodo para armar; el tutorial lo explica pero no lo cambia (es el ítem P0 «adaptación del acelerador para gamepad» del análisis, fuera de alcance).

## 8. Fuera de alcance (posibles seguimientos)

- Teclado para volar (acelerador incremental) y presets radio/gamepad.
- Traducir al español los menús existentes con el mismo CSV.
- Selector de idioma en Opciones → Game Settings → Gameplay.
- Sonidos de UI para el tutorial (no existe API de efectos en `Audio`).
- Selector de pistas y de niveles en el menú principal.
