# Plan: lavado de cara "AAA" de la UI + navegación con joystick/radio

Fecha: 2026-09-16. Estado: **implementado en la rama `ui-lavado-de-cara`, pendiente de prueba con hardware y sin mergear**. La arquitectura resultante, los comandos de prueba y los desvíos respecto de este plan están en [ui.md](ui.md).

Actualización del mismo día: se agregó el **HUD de orientación** (sección 4.K y Fase 6) a partir de una captura de otro simulador que aportó el usuario.

---

## 1. Pedido y decisiones

Pedido del usuario: sin modificar lo que ya funciona, mejorar la interfaz, la UI y las opciones para que se vea como un juego triple A, y poder manipular los menús con el joystick para usar un solo periférico.

Decisiones tomadas con el usuario:
- **Periférico**: gamepad (D-pad + A/B) **y** radio RC sin botones (gestos de stick estilo menú OSD de Betaflight sobre los ejes ya calibrados; el throttle nunca navega).
- **Idioma**: español + inglés con `TranslationServer` (CSV), español por defecto, selector en Opciones.
- **Alcance**: rediseño de todas las pantallas existentes + animaciones/transiciones/sonidos + navegación por joystick + opciones nuevas + reparar lo roto. **Sin pantallas nuevas** (ni selector de pista ni resumen post-carrera).
- **Estilo**: minimal claro (Apple / Microsoft Flight Simulator).
- **HUD de vuelo**: se rediseña como OSD de orientación tomando como referencia la captura aportada (brújula en cinta, horizonte punteado con hueco central, cintas laterales, lecturas ALT/SPD arriba a la derecha, mira, visor de sticks, insignia de modo, indicador REC). Esto reemplaza la idea inicial de no tocar el HUD. El menú sigue claro; el HUD es blanco sobre el video, como en la referencia.

### Captura de referencia (descripción)
Vista FPV con fisheye sobre un campo. Elementos, en blanco con sombra suave y trazo fino:
- Arriba a la izquierda, insignia redondeada con el modo de vuelo ("3D").
- Arriba al centro, brújula en cinta con marcas y letras S · W · N · E.
- Centro, mira circular con cuatro marcas y una línea de horizonte punteada que rota con el alabeo, con un hueco alrededor de la mira.
- A izquierda y derecha del centro, dos columnas verticales de marcas que enmarcan la zona central.
- Arriba a la derecha, "ALT m 9" y "SPD km/h 79": etiqueta chica con unidad y valor grande.
- Abajo al centro, dos cajas oscuras semitransparentes con cruz punteada y un círculo por stick.
- Abajo a la izquierda, punto rojo y "Rec.".

---

## 2. Estado actual (análisis del 2026-09-16)

### Pantallas (18 escenas: 9 en `gui/`, 9 en `hud/`)
Todas las de menú usan `MarginContainer > PanelContainer > VBoxContainer`, sin fondo, sin logo, un panel gris chico centrado:
- `gui/main_menu.tscn/.gd` (escena principal): Fly / Quad Settings / Help / Options / Quit. Quit usa un `ConfirmationDialog` nativo creado en código. Fly hace `change_scene_to_file("res://sceneries/level1.tscn")`.
- `gui/pause_menu.tscn/.gd` (`class_name PauseMenu`, `process_mode = 2`): Resume / Quad Settings / Help / Options / Return to Main Menu (otro `ConfirmationDialog` en código). F2 oculta el menú sin despausar.
- `gui/options_menu/options_menu.tscn/.gd`: hub Game / Graphics / Audio / Controls; agrega submenús a `get_parent()`.
- `gui/options_menu/graphics_menu.tscn/.gd`: 8 `OptionButton` (Window Mode, Resolution, MSAA, Anisotropic Filter, Shadows, Fisheye Camera, Fisheye Resolution, Fisheye MSAA), ítems llenados en código.
- `gui/options_menu/audio_menu.tscn/.gd`: sólo Master Volume.
- `gui/options_menu/game_settings_menu.tscn/.gd`: `TabContainer` con Gameplay (placeholder vacío) y HUD (`hud_config.tscn`: SpinBox FPS + 8 CheckButton + preview vivo del HUD).
- `gui/options_menu/controls_menu/controls_menu.tscn/.gd` (345 líneas): lista de mandos, 8 ejes + 16 botones visuales, SubViewport con dron 3D, SubViewport con emisora 3D, 11 filas de binding (`gui_controller_binding.gd`), rango de eje con handles arrastrables (`gui_controller_axis_range.gd`), Calibrate / Reset / Back.
- `gui/options_menu/controls_menu/calibration_menu.tscn/.gd` (14 pasos), `binding_popup.gd` (construido en código), `gui/confirmation_popup.tscn` (tipo `Popup`).
- `gui/quad_settings_menu.tscn/.gd` (435/386 líneas): sliders + spinbox de cámara/pesos, curva de rates, 9 sliders de rates, `gui/rate_graph.gd` (dibujo custom), tooltips largos en español.
- `gui/help_page.tscn/.gd`: RichTextLabel construido con `append_text`.
- HUD (`hud/hud.tscn`, se instancia dentro del dron en `drone/drone.gd`): mezcla containers y offsets absolutos (HUDRPM a 1328/930, cableado a 1080p).
- Carrera (todo creado en código en `tracks/track.gd` y `tracks/time_table.gd`): countdown, "Finished!", timer y tabla de tiempos con botón "Dismiss".

### HUD de vuelo (detalle)
- `hud/hud.gd` (`class_name HUD`), hijo del `Drone` (`drone/drone.gd:11`). `enum Component {CROSSHAIR, STATUS, HEADING, SPEED, ALTITUDE, LADDER, HORIZON, STICKS, RPM}`; `show_component()` oculta con `modulate` alfa.
- Datos: `drone.gd:75-76` llama a `update_hud_data()` en `_process`; `HUD.update_data()` acumula y promedia, y `update_display()` refresca a `hud_config.fps` (**10 FPS por defecto**). Todo, incluido el horizonte, se mueve a 10 Hz.
- Defaults de `GameSettings.hud_config`: sólo `crosshair` y `horizon` encendidos. Brújula, velocidad, altura, sticks, escalera y RPM vienen apagados. `drone.gd:279-288` aplica la config.
- `HUDHeadingScale`: número "000" + barra de velocidad de giro. No hay brújula con puntos cardinales.
- `HUDLadder` (`hud_ladder.gd`): línea sólida `NinePatchRect` dentro de una caja de 500×500 con `clip_contents` (`hud.tscn:50-56`); desplaza 20 px por grado de **pitch del dron**. No compensa la inclinación de la cámara FPV (30° por defecto) ni el fisheye, así que no coincide con el horizonte que se ve.
- `HUDSpeedScale` / `HUDAltitudeScale`: números pegados a la caja y barra bidireccional. La altitud usa formato "-0000.0". `update_radio_altitude()` no tiene llamadas: muestra siempre "R---".
- `HUDStickInput`: texturas de 128 px, API `update_stick_input(Vector2)` (el plan del tutorial en `docs/tutorial_plan.md` la reutiliza).
- `FlightMode` (Label arriba a la derecha): `update_flight_mode()` deja el texto vacío en ACRO (`hud.gd:111-119`).
- `HUDStatus`: indentado con 7 `\n`; `_on_armed` compara un `FlightMode` con enteros (siempre "ARMED").
- Grabación: `tracks/track.gd:68` `record_replay` indica si se graba la vuelta; no hay indicador en pantalla.
- Fisheye (`drone/fpv_camera/fpv_camera.gdshader:40-60`): proyección equidistante. Un rayo a θ del eje de la cámara cae a `θ / (hfov/2) · min(ancho, alto)` píxeles del centro. Esto permite proyectar el horizonte real sobre el HUD.

### Theme, assets, animación
- 5 themes mínimos (`gui/menu_theme.tres` = fuente + tamaño 32; `help_page_theme`, `countdown_theme`, `timer_theme`, `hud/hud_theme`). **Cero StyleBox** en el proyecto; títulos con `LabelSettings` locales repetidos.
- Fuentes: `gui/RecursiveSansLnrSt-Med.otf` (usada), `gui/RecursiveSansLnrSt-Bold.otf` (huérfana), `hud/RecursiveMonoLnrSt-Regular.otf`.
- Sin logo, sin íconos, sin fondos. Modelos 3D reutilizables: `controls_menu_drone.tscn` y `controls_menu_radio_transmitter.tscn`.
- Cero `Tween` activos, cero `AnimationPlayer`, cero transiciones de escena, cero sonidos de UI (sólo WAV de motores).

### Navegación e input
- Sólo mouse: ningún `grab_focus()`, ningún `focus_neighbor`. Patrón único: `instantiate → add_child → ocultar padre → await <menu>.back → queue_free`. El `_input` de `ui_cancel` está copiado 8 veces. El mouse mode se toca en 5 archivos.
- `project.godot [input]`: ejes de vuelo `throttle` (eje 1), `yaw` (eje 0), `pitch` (eje 3), `roll` (eje 2), deadzone 0.01; `cycle_flight_modes` = botón A + M; `change_camera` = Y + C; `pause_menu` = START + Escape; `respawn` = BACK + Backspace; `toggle_arm` = LB + Space.
- **`ui_*` no redefinidas** → defaults del motor: `ui_up/down` incluyen el eje 1 (throttle: en una radio el stick en reposo dispara `ui_down` permanente), `ui_left/right` el eje 0, `ui_accept` = botón A (= `cycle_flight_modes`), `ui_cancel` = B.
- La captura de binding está en `_unhandled_input` (`controls_menu.gd:110-134`): con un Control enfocado, la GUI consume A/D-pad antes.
- El `RadioController` es PAUSABLE (no procesa en pausa).

### Configuración
`ConfigFile` en `user://config/`: `Graphics.cfg`, `Audio.cfg` (master), `GameSettings.cfg` (hud_config), `Quad.cfg` (quad + rates), `InputMap.cfg` (secciones `controls` y `controls_<GUID>`). Guardado inmediato en cada cambio de widget. No hay VSync, límite de FPS, FOV, idioma, ni buses separados.

### Web
Único preset `Web` (`export_presets.cfg`), CI `.github/workflows/deploy-to-itch.yml` exporta y publica en itch.io en cada push a `master`. Renderer Compatibility. **No hay stretch mode** (la UI no escala en el canvas). En navegador el gamepad sólo aparece tras pulsar un botón y no hay aviso.

### Bugs conocidos en la UI
- `controls_menu.gd:17`: `%ButtonReset` ("Reset to Defaults") nunca conecta `pressed`.
- `calibration_menu.gd:69,195`: `popup.show_modal(true)` no existe en Godot 4.
- `calibration_menu.gd:32-47`: valida con ejes fijos 0..3 en vez de los detectados.
- `graphics.gd:106-108`: Anisotropic Filter es `pass` (en Godot 4 no se puede cambiar en runtime).
- `time_table.gd:14,18-19`: `set("custom_constants/...")` es API de Godot 3.
- `calibration_menu.tscn` y `confirmation_popup.tscn` sin theme; `hud/hud_base.png` y la fuente Bold huérfanas.

---

## 3. Hechos verificados que condicionan el diseño

| Hecho | Consecuencia |
|---|---|
| `drone/fpv_camera/fpv_camera.gd:5-8`: `fov_h` tiene setter que hace `mat.set_shader_parameter("hfov", ...)` | El FOV se puede cambiar en caliente en modos FULL/FAST. En modo OFF no se aplica (la cámara usa `fov` vertical 75); ahí se aplica con `keep_aspect = KEEP_WIDTH; fov = fov_h` sólo si el usuario cambió el valor. |
| `autoloads/quad_settings.gd:4,80`: `settings_updated` se emite en cada `save_quad_settings()` | Hook listo para que la cámara FPV reaplique el FOV sin tocar `drone.gd`. |
| `autoloads/graphics.gd:87-97`: `update_resolution()` cambia el tamaño de ventana vía `DisplayServer` y `get_viewport().size` | Con stretch `canvas_items` la UI escala en vez de recortarse; la lógica queda igual en escritorio y se oculta en web. Verificar manualmente en ventana 75 % y 50 %. |
| `autoloads/graphics.gd:106-108`: `update_af()` es `pass`; en Godot 4 la anisotropía es un project setting de arranque sin API en runtime | Se quita la opción de la UI; la clave `af` del `.cfg` se ignora (compatibilidad hacia atrás). |
| `controls_menu.gd:110-134`: la captura de binding está en `_unhandled_input`, que corre después de la GUI | La captura pasa a `_input` + `set_input_as_handled()` mientras el popup escucha. |
| `tracks/time_table.gd:14,18-19`: API de Godot 3 | Se reemplaza por `add_theme_constant_override`. |
| `Tween` creado con `create_tween()` sobre un nodo con `process_mode = WHEN_PAUSED` corre en pausa (`TWEEN_PAUSE_BOUND`) | Las animaciones del menú de pausa funcionan con el árbol pausado. |
| Un run `--script` (`-s`) no registra autoloads | La prueba de humo de UI es una **escena** pasada como argumento, no un script `-s`. El generador de theme sí puede ser `-s` porque no usa autoloads. |
| Orden de input en Godot 4: `_input` → GUI → `_unhandled_input`; `accept_event()` en el menú más profundo frena a los padres | Un solo `_input` de `ui_cancel` en la clase base reemplaza las 8 copias sin cambiar el comportamiento. |

---

## 4. Arquitectura

### A. `MenuScreen`: clase base para las 10 pantallas (sin cambiar flujo ni `%UniqueName`)

Nuevo `gui/menu_screen.gd` (`class_name MenuScreen extends Control`). Cada script de pantalla cambia `extends Control` → `extends MenuScreen`, borra su `signal back` y su `_input` de `ui_cancel`, y sus botones "Volver" llaman a `request_back()`. `PauseMenu` sobreescribe `request_back()` para llamar a `unpause_game()`.

```gdscript
class_name MenuScreen
extends Control

signal back

@export var initial_focus: NodePath
@export var animate := true
var _closing := false

func _ready() -> void:
	StickNavigation.push_screen()
	if animate:
		_play_open()  # modulate 0→1 + position.y +24→0, 0.18 s, EASE_OUT
	grab_initial_focus.call_deferred()

func _exit_tree() -> void:
	StickNavigation.pop_screen()

func _input(event: InputEvent) -> void:
	if event.is_action("ui_cancel") and event.is_pressed() and not event.is_echo():
		accept_event()
		request_back()

func request_back() -> void:
	if _closing: return
	_closing = true
	UI.play("back")
	if animate: await _play_close()
	back.emit()

func grab_initial_focus() -> void:
	if UI.input_kind == UI.InputKind.MOUSE: return
	var target := get_node_or_null(initial_focus) as Control
	if target == null: target = UI.find_first_focusable(self)
	if target: target.grab_focus()

## Reemplaza el bloque repetido instantiate/add_child/ocultar/await/queue_free.
func open_submenu(packed: PackedScene, hide_node: CanvasItem, parent: Node = self) -> void:
	var opener := get_viewport().gui_get_focus_owner()
	var sub := packed.instantiate()
	parent.add_child(sub)
	hide_node.visible = false
	await sub.back
	sub.queue_free()
	hide_node.visible = true
	if is_instance_valid(opener) and UI.input_kind != UI.InputKind.MOUSE:
		opener.grab_focus()
```

`options_menu.gd` sigue agregando los submenús a `get_parent()` (pasa `parent = get_parent()`); `pause_menu.gd` mantiene `can_resume = false/true` alrededor de la llamada.

### B. Autoload `UI` (`autoloads/ui.gd`, `PROCESS_MODE_ALWAYS`): feedback, foco, overlays

- **Dispositivo activo** (`input_kind`: MOUSE / KEYBOARD / GAMEPAD / STICKS, señal `input_kind_changed`): se detecta en `_input`. Con mouse se libera el foco (`gui_release_focus()`) salvo que el foco sea un `LineEdit`, así no hay anillos de foco al usar mouse; con teclado/gamepad sin foco se llama a `grab_initial_focus()` de la pantalla activa.
- **Feedback global sin tocar escenas**: `get_tree().node_added` → para cada `BaseButton` conecta `mouse_entered`/`focus_entered` (sonido *hover* + micro-tween de `modulate` o escala 1.0→1.02→1.0 en 0.12 s) y `pressed` (*click*); para `Range` (no `ScrollBar`) `value_changed` (*tick*, limitado a uno cada 40 ms porque `HSlider.share(SpinBox)` dispara dos veces); `TabBar.tab_changed` (*click*). Se silencia durante la animación de apertura (el `grab_initial_focus` dispara `focus_entered`). Comprobar `is_connected` antes de conectar.
- **Sonidos**: 5 `AudioStreamPlayer` en bus `UI` con `Assets/Audio/UI/{hover,click,back,tick,error}.wav`; si el stream no existe, `play()` no hace nada (permite implementar la fase 1 antes que la 3).
- **Overlays**: `CanvasLayer` propio (layer 90). `await UI.confirm(text, ok_text, cancel_text, danger := false) -> bool` y `await UI.alert(text)` instancian `gui/components/confirm_overlay.tscn` (un `Control` a pantalla completa con scrim blanco al 60 % + tarjeta; foco inicial en Cancelar; `ui_cancel` devuelve `false`). Reemplazan los 2 `ConfirmationDialog` nativos (`gui/main_menu.gd:72-79`, `gui/pause_menu.gd:91-103`), el `AcceptDialog` de `autoloads/global.gd:57-64` y `gui/confirmation_popup.tscn` (tipo `Popup`, que se borra).
- `find_first_focusable(root)`: DFS por Controls visibles con `focus_mode == FOCUS_ALL`.

### C. Autoload `StickNavigation` (`autoloads/stick_navigation.gd`, `PROCESS_MODE_ALWAYS`)

Traduce los ejes **ya calibrados** a acciones `ui_*` sintéticas. Sólo activo con al menos un `MenuScreen` abierto (`push_screen/pop_screen`), nunca en `suspended` (binding/calibración) y nunca en vuelo (el `TimeTable` no es `MenuScreen`).

```gdscript
enum Scheme {BETAFLIGHT, YAW_SELECT}
const THRESHOLD := 0.6      # entra
const RELEASE := 0.4        # sale (histéresis)
const INITIAL_DELAY := 0.35
const REPEAT := 0.12
var scheme := Scheme.BETAFLIGHT   # persistido en GameSettings.cfg [game] nav_scheme
var suspended := false
var _screens := 0
var _dir := {"pitch": 0, "roll": 0, "yaw": 0}
var _timer := {}

func _process(delta: float) -> void:
	if _screens <= 0 or suspended or Input.get_connected_joypads().is_empty(): return
	_update("pitch", Input.get_axis("pitch_down", "pitch_up"), delta)
	_update("roll", Input.get_axis("roll_left", "roll_right"), delta)
	_update("yaw", Input.get_axis("yaw_left", "yaw_right"), delta)

func _update(axis: String, value: float, delta: float) -> void:
	var prev: int = _dir[axis]
	var dir := prev
	if prev == 0 and absf(value) > THRESHOLD: dir = signi(value)
	elif prev != 0 and absf(value) < RELEASE: dir = 0
	if dir != prev:
		_dir[axis] = dir
		if dir != 0:
			_fire(axis, dir)
			_timer[axis] = INITIAL_DELAY
	elif dir != 0 and _is_navigation(axis, dir):   # sólo repiten arriba/abajo/izq/der
		_timer[axis] -= delta
		if _timer[axis] <= 0.0:
			_fire(axis, dir)
			_timer[axis] = REPEAT

func _fire(axis: String, dir: int) -> void:
	var action := _map(axis, dir)
	if action.is_empty(): return
	UI.set_input_kind(UI.InputKind.STICKS)
	var press := InputEventAction.new()
	press.action = action; press.pressed = true; press.strength = 1.0
	Input.parse_input_event(press)
	var release := press.duplicate() as InputEventAction
	release.pressed = false
	Input.parse_input_event(release)

func _map(axis: String, dir: int) -> String:
	match axis:
		"pitch": return "ui_up" if dir > 0 else "ui_down"
		"roll":
			if scheme == Scheme.YAW_SELECT or _focus_is_value_control():
				return "ui_right" if dir > 0 else "ui_left"
			return "ui_accept" if dir > 0 else "ui_cancel"
		"yaw":
			if scheme == Scheme.YAW_SELECT:
				return "ui_accept" if dir > 0 else "ui_cancel"
	return ""

func _focus_is_value_control() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is Range or f is OptionButton or f is TabBar or f is CheckButton \
			or f is GUIControllerAxisRange

func any_axis_deflected() -> bool:   # usado por level.gd antes de despausar
	return absf(Input.get_axis("pitch_down", "pitch_up")) > RELEASE \
			or absf(Input.get_axis("roll_left", "roll_right")) > RELEASE \
			or absf(Input.get_axis("yaw_left", "yaw_right")) > RELEASE
```

Esquemas: **BETAFLIGHT** (default) = pitch navega; roll derecha acepta / roll izquierda vuelve, salvo que el foco sea un control de valor (slider, OptionButton, pestañas, toggle, rango de eje), donde roll ajusta. **YAW_SELECT** = pitch navega, roll siempre ajusta/izquierda-derecha, yaw derecha acepta, yaw izquierda vuelve.

### D. `project.godot`

- `[display]`: agregar `window/stretch/mode="canvas_items"` y `window/stretch/aspect="expand"` (sin barras negras; la UI escala en el canvas de itch.io y en cualquier resolución).
- `[input]`: definir `ui_up/ui_down/ui_left/ui_right` (flecha + D-pad 11/12/13/14, **sin** `InputEventJoypadMotion`), `ui_accept` (Enter 4194309, KP Enter 4194310, Space 32, botón 0), `ui_cancel` (Escape 4194305, botón 1). Formato: copiar el bloque de la acción `pause_menu` existente (líneas 133-138) cambiando `keycode`/`button_index`. Keycodes: izquierda 4194319, arriba 4194320, derecha 4194321, abajo 4194322. Las acciones de vuelo no se tocan.
- `[autoload]`: `UI`, `StickNavigation`, `SceneTransition` (después de `Global`).
- `[gui]`: `theme/custom="res://gui/theme/main_theme.tres"` (theme global; `hud_theme`, `countdown_theme` y `timer_theme` ganan `Label/colors/font_color = blanco` explícito porque el theme claro pone el texto oscuro).
- `[internationalization]`: `locale/translations` con los dos `.translation`, `locale/fallback="en"`.

### E. Layout y componentes (`gui/components/`)

- `menu_background.tscn`: `TextureRect` full-rect con `GradientTexture2D` (`#FAFBFC` → `#EEF1F5`), sin shader.
- `menu_header.tscn`: título (`TitleLabel`) + subtítulo/breadcrumb (`SubtitleLabel`).
- `control_hints.tscn`: footer con chips (`Chip` + `KeyCap`, StyleBoxFlat + texto, sin texturas) que cambian según `UI.input_kind`: "↑↓ Navegar · Enter Aceptar · Esc Volver" / "D-pad · A · B" / "Pitch navegar · Roll → aceptar · Roll ← volver" (o yaw según esquema). En el menú principal incluye el indicador de mando: nombre del joypad activo, o en web sin joypads "Presioná un botón del mando para activarlo" (`Input.joy_connection_changed`).
- `menu_hero.tscn`: `SubViewportContainer` + `SubViewport` (`transparent_bg`, `own_world_3d`, MSAA x4, 800×800 máx.) que instancia `gui/options_menu/controls_menu/controls_menu_drone.tscn` tal cual y lo rota lento (`rotate_y(delta * 0.25)`); `@export var enabled_on_web := true` para poder apagarlo si mide mal.
- **Menú principal**: marca "Drone Simulator" arriba a la izquierda (`DisplayLabel`), lista vertical de botones grandes alineados a la izquierda (`MenuButton`: transparentes, barra de acento de 4 px a la izquierda al enfocar), hero a la derecha, footer de hints. **Pausa**: mismo layout sobre un scrim blanco al 70 % (sin blur). **Opciones y submenús**: header + tarjeta (`Card`) con el contenido existente + footer; los `.tscn` conservan sus nodos `%UniqueName`, sólo se re-parentan dentro de `MarginContainer(48) > VBoxContainer > [Header, Card > contenido, Footer]`.
- `gui/options_menu/game_settings_menu.tscn`: la pestaña Gameplay deja de ser placeholder y contiene Idioma.
- `hud_config.tscn`: el `SpinBox` de HUD FPS pasa a `HSlider` + valor (navegable con D-pad/roll).
- `calibration_menu.tscn`: quitar offsets ±960/±540 (`anchors_preset = 15`) y poner el theme.

### F. Theme (`gui/theme/`)

`ui_palette.gd` (`class_name UIPalette`, constantes) + `tools/build_theme.gd` (script `-s` que construye el `Theme` con `StyleBoxFlat`/íconos generados con `Image` y lo guarda con `ResourceSaver` en `gui/theme/main_theme.tres` y `gui/theme/icons/*.png`). Reemplaza `gui/menu_theme.tres` y `gui/help_page_theme.tres`. Fuentes: `RecursiveSansLnrSt-Med` (cuerpo) y `RecursiveSansLnrSt-Bold` (títulos, hoy huérfana).

**Paleta**

| Token | Hex | Uso |
|---|---|---|
| BG / BG_TOP / BG_BOTTOM | `#F5F6F8` / `#FAFBFC` / `#EEF1F5` | fondo, fade, gradiente |
| SURFACE / SURFACE_ALT / SURFACE_PRESSED | `#FFFFFF` / `#F2F4F7` / `#E8ECF1` | tarjetas y botones, hover, pressed |
| BORDER / BORDER_STRONG | `#DCE1E7` / `#C5CCD5` | bordes 1 px, hover |
| TEXT / TEXT_2 / TEXT_DISABLED | `#1B1F24` / `#5B6470` / `#A0A8B3` | texto |
| ACCENT / ACCENT_HOVER / ACCENT_PRESSED / ACCENT_SOFT | `#2F7CF6` / `#1F6BE0` / `#1859C2` / `#E8F0FE` | foco, primario, fill de slider, selección |
| DANGER / DANGER_SOFT / DANGER_BORDER | `#B3261E` / `#FDECEC` / `#F3B6B4` | Salir, Reset, binding rojo |
| SHADOW | `#0F172A` α 0.08 | sombra de tarjetas (size 16, offset 0,6) |
| GRAPH_PITCH / ROLL / YAW / GRID | `#E5484D` / `#30A46C` / `#0091FF` / `#E6EAEE` | `gui/rate_graph.gd:8-13` |

**Tipografía** (diseño a 1080p): default 22 Med TEXT; `DisplayLabel` 60 Bold; `TitleLabel` 40 Bold; `SubtitleLabel` 24 TEXT_2; `CaptionLabel` 17 TEXT_2; `MenuButton` 26; `KeyCap` 15 Bold blanco sobre TEXT; `BodyText` (RichTextLabel) 20; tooltip 18 blanco sobre TEXT.

**Estilos clave** (StyleBoxFlat, borde 1 px, anti-aliasing): `Button` radio 10, márgenes 20/12, normal SURFACE+BORDER, hover SURFACE_ALT+BORDER_STRONG, pressed SURFACE_PRESSED, disabled `#F7F8FA`, **focus** sin centro con borde ACCENT 2 px y sombra ACCENT α 0.25; `PrimaryButton` ACCENT con texto blanco; `DangerButton` DANGER_SOFT/DANGER_BORDER; `MenuButton` transparente, hover SURFACE, focus ACCENT_SOFT con `border_width_left = 4` ACCENT; `PanelContainer` radio 12 márgenes 24; `Card` igual + sombra; `RowPanel` (filas de binding) transparente/SURFACE_ALT/ACCENT_SOFT; `OptionButton` = Button con `arrow_margin 12`; `PopupMenu` panel radio 12 con sombra, hover ACCENT_SOFT; `HSlider` pista SURFACE_ALT alto 6, fill ACCENT, grabber círculo 22 px blanco con borde ACCENT 2 px (24 px ACCENT al enfocar); `CheckButton` píldora 48×26 ACCENT/BORDER_STRONG con nudo blanco; `TabContainer` pestañas con borde superior redondeado, seleccionada texto ACCENT; scrollbars de 8 px BORDER_STRONG; `LineEdit`/`SpinBox` radio 8 con focus ACCENT; `HSeparator` línea BORDER; `TooltipPanel` fondo TEXT radio 8. Constantes: `VBox/HBox separation 12`, `Grid h 20 / v 14`.

Colores hardcodeados a migrar a `UIPalette`: `gui/rate_graph.gd:8-13,64-66`, `gui_controller_axis.gd:7`, `gui_controller_button.gd:8`, `gui_controller_binding.gd:34,48,58`, `game_settings_menu.tscn:36`.

### G. Navegación en el menú de controles (el archivo con más riesgo)

- `GUIControllerBinding` (`gui_controller_binding.gd`): `focus_mode = FOCUS_ALL`, `theme_type_variation = "RowPanel"`, `ui_accept` en `_gui_input` equivale al click; el pulso de hover por `_process` se reemplaza por el estilo focus.
- `GUIControllerAxisRange` (`gui_controller_axis_range.gd:45-46`): handles enfocables; `ui_accept` alterna handle activo (min/max), `ui_left/right` mueven 0.05; el arrastre con mouse sigue igual.
- `BindingPopup` → `binding_popup.tscn` (tarjeta) con estados **LISTENING** ("Mové un switch o pulsá un botón"; `StickNavigation.suspended = true`; `controls_menu._input` captura el evento y llama a `get_viewport().set_input_as_handled()`; Escape cancela) → **CAPTURED** (muestra "Botón 3" / "Eje 4", foco en Confirmar; A confirma, B cancela, botón "Escuchar de nuevo"). La captura de `controls_menu.gd:110-134` se mueve a `_input` y se ejecuta sólo con popup abierto o auto-detección.
- Calibración (`calibration_menu.gd`): `suspended = true` mientras dura; `_process()` valida con los ejes detectados en `axes` en lugar de `0..3` fijos; `popup.show_modal(true)` (líneas 69 y 195) → `await UI.confirm(...)`.
- Reset to Defaults (`controls_menu.gd:17`, nunca conectado): `await UI.confirm(...)` → nuevo `Controls.reset_controller_bindings()` que borra la sección `controls_<GUID>` de `InputMap.cfg`, hace `InputMap.load_from_project_settings()`, `restore_keyboard_shortcuts()` y refresca la lista.
- `%ControllerCheckButton` (`controls_menu.tscn:55`): quitar `focus_mode = 0`.
- Nuevo `OptionButton` "Navegación con sticks" (Betaflight / Yaw) → `StickNavigation.scheme` + `GameSettings`.

### H. Pausa, transiciones, carrera

- `sceneries/level.gd:93-99` `_on_resume()`: antes de `paused = false`, `while Input.is_action_pressed("ui_accept") or Input.is_action_pressed("pause_menu") or StickNavigation.any_axis_deflected(): await get_tree().process_frame`. Así el botón A que aceptó "Reanudar" no llega como `cycle_flight_modes` y un gesto de roll no inclina el dron al volver (el `RadioController` es PAUSABLE y no ve nada mientras dura la espera).
- `gui/pause_menu.gd`: F2 sigue ocultando el menú; al ocultarlo `StickNavigation.suspended = true` para que mover sticks no navegue.
- `autoloads/scene_transition.gd`: `CanvasLayer` layer 100 + `ColorRect` BG; `change_scene(path)` = fade out 0.25 s → `change_scene_to_file` → fade in. Reemplaza `gui/main_menu.gd:39` y `sceneries/level.gd:102`.
- `tracks/time_table.gd`: `theme_type_variation = "Card"`, constantes con `add_theme_constant_override`, quitar `modulate/self_modulate` (33-34), botón "Cerrar" con `grab_focus()` en `_ready`, `_input` con `ui_cancel` → `delete()`, autocierre a 10 s. No es `MenuScreen` (el dron sigue en vuelo).
- `hud/hud.tscn:85-88` HUDRPM: anclar abajo-derecha (`anchors_preset = 3`, offsets relativos) en lugar de 1328/930; `hud/hud_status.gd:40`: quitar los 7 `\n` y centrar con anchors/offset. El rediseño completo del HUD está en la sección K.

### I. Opciones nuevas (misma persistencia `ConfigFile`, guardado inmediato como hoy)

| Pantalla | Opción | Implementación |
|---|---|---|
| Gráficos | Preset de calidad (Bajo/Medio/Alto/Ultra/Personalizado) | dict en `graphics.gd`: Bajo = MSAA off, sombras LOW, fisheye FAST 480p; Medio = x2, MEDIUM, FAST 720p; Alto = x4, HIGH, FULL 720p; Ultra = x8, ULTRA, FULL 1080p. Se muestra "Personalizado" si los valores no coinciden con ninguno. Web: default Medio (fisheye Fast, recomendación de `docs/optimizacion.md`). |
| Gráficos | VSync (Off/On/Adaptativo) | `DisplayServer.window_set_vsync_mode`; clave `vsync`. |
| Gráficos | Límite de FPS (30/60/120/144/240/Sin límite) | `Engine.max_fps`; clave `max_fps`. |
| Gráficos | Anisotropic Filter | se elimina de la UI (no aplicable en runtime). |
| Gráficos (web) | Pantalla completa | en `OS.has_feature("web")` se ocultan Modo de ventana, Resolución, VSync y FPS y aparece un toggle que llama a `DisplayServer.window_set_mode` (funciona porque el click es un gesto de usuario). |
| Audio | Master, Motores, Interfaz + Silenciar | `default_bus_layout.tres` con buses Master, Motors, UI, Music (reservado); `drone/motor.gd:52` agrega `sounds[-1].bus = &"Motors"`; `audio.gd` pasa a `{"master_volume", "motors_volume", "ui_volume", "muted"}`. |
| Juego | Idioma (Español/English) | `TranslationServer.set_locale`; `GameSettings.cfg [game] language`; primer arranque usa `OS.get_locale_language()` si es "es" o "en". |
| Quad | FOV horizontal de la cámara FPV (90–170, default 150) | `QuadSettings.fov_h` en `Quad.cfg [quad] fov`; `fpv_camera.gd` se suscribe a `QuadSettings.settings_updated` y reaplica; en modo OFF sólo si el usuario lo cambió (ver sección 3). |
| Controles | Esquema de navegación con sticks | ver C y G. |

### J. Localización

- `localization/translations.csv` (`keys,es,en`) → Godot genera `translations.es.translation` / `translations.en.translation` al importar (se commitean).
- `.tscn`: todos los `text = "..."` visibles pasan a claves (los Controls traducen solos con `auto_translate`).
- `.gd`: `tr("CLAVE")`; los textos construidos en código se reconstruyen en `_notification(NOTIFICATION_TRANSLATION_CHANGED)`: `help_page.gd:17-49`, ítems de `OptionButton` en `graphics_menu.gd:20-87` (usar índices/metadata, nunca `.text` como dato), tooltips `HELP_*` de `quad_settings_menu.gd:9-69` (ya en español: se llevan al CSV y se agrega el inglés), `controls.gd:129-135` (mensajes de error), etiquetas de `create_action_list()` (`controls.gd:140-150`), `track.gd:279-313,371` (countdown, "GO!", "False Start!", "Finished!", "Prev. lap/Curr. lap/Total"), `time_table.gd` ("Lap", "Time", "Total", "Dismiss"), `hud_status.gd` (ARMED/DISARMED/THROTTLE HIGH/CRASH RECOVERY), popups de binding/calibración.
- Convención de claves por grupo: `MENU_*` (principal/pausa), `OPT_*` (hub), `GFX_*`, `AUD_*`, `GAME_*`, `HUD_*`, `CTRL_*`, `CAL_*`, `QUAD_*`, `HELP_*`, `RACE_*`, `UI_*` (Aceptar/Cancelar/Volver/hints), `ERR_*`.

### K. HUD de orientación (OSD) inspirado en la captura de referencia

**Principios**
- Blanco puro con sombra suave (outline 2 px negro α 0.35) en lugar del contorno negro de 4 px de `hud/hud_theme.tres`. Trazos de 2 px. Nada tapa el centro de la imagen.
- Todo dibujado con `_draw()` (líneas, arcos, `draw_string` con la fuente del theme): sin texturas nuevas, nítido con el stretch `canvas_items` y barato en web.
- Se conserva la tubería de datos y la API pública: `HUD.update_data()`, `show_component()`, `status`, `HUDStickInput.update_stick_input()`. `drone.gd` no se modifica: los componentes nuevos leen `GameSettings.hud_config_updated` desde el propio `hud.gd`, y el transform de la cámara desde `get_parent()` (el Drone).
- **Fluidez**: horizonte, brújula, cintas y marcador de puerta se actualizan **cada frame** con el transform actual de la `FPVCamera`, sin promediar. Sólo los números siguen el ritmo de "HUD FPS", que pasa a llamarse "Frecuencia de números" en la UI.

**Mapa captura → HUD actual → propuesta**

| Marca de la captura | Qué aporta al piloto | Hoy | Propuesta |
|---|---|---|---|
| Brújula en cinta arriba al centro | Rumbo absoluto de un vistazo | `HUDHeadingScale`: "000" + barra de giro, apagado | Nuevo `hud/hud_compass_tape.gd`: cinta de 420 px que cubre ±90°, marca cada 15° (larga cada 45°), letras N, NE, E, SE, S, SO, O, NO traducidas, caret central y rumbo numérico opcional debajo. Reemplaza el visual del componente HEADING. |
| Horizonte punteado con hueco central | Actitud (alabeo y cabeceo) sin tapar la mira | `HUDLadder`: línea sólida recortada a 500 px; no compensa cámara | Nuevo dibujo en `hud_ladder.gd`: segmentos de 10 px con 14 px de separación, hueco de 120 px alrededor del centro, largo 700 px, sin `clip_contents`. Dos modos, ver abajo. |
| Columnas verticales de marcas a los lados | Enmarcan la zona central; el desplazamiento de las marcas transmite velocidad y ascenso | Números y barra pegados a la caja | Nuevo `hud/hud_side_tape.gd`: dos cintas a ±310 px del centro y 540 px de alto. Marcas cada 5 unidades que se desplazan con la velocidad (izquierda) y la altura (derecha), con desvanecido en los extremos y sin números. |
| ALT (m) y SPD (km/h) arriba a la derecha | Valores exactos lejos del centro | Números junto a la caja, "-0000.0", "R---" fijo | Nuevo `hud/hud_readouts.tscn`: etiqueta chica con unidad apilada y valor grande con fuente mono. ALT con 1 decimal bajo 10 m y entero arriba. SPD entero. VS opcional con flecha ▲▼. Se elimina "R---" porque nunca se actualiza. |
| Mira circular con 4 marcas | Referencia de hacia dónde apunta la cámara | `Crosshair.png` de 48 px | Redibujar con `_draw()`: círculo de 10 px y cuatro marcas de 6 px. Queda nítido a cualquier resolución. |
| Visor de sticks abajo al centro | Ver qué hace el piloto; útil para aprender y en replays | Texturas de 128 px, apagado | Mismo nodo y API. Fondo negro α 0.25 con radio 4, cruz punteada, círculo de 10 px con borde. Anclado abajo al centro con 12 px de margen. |
| Insignia de modo arriba a la izquierda | Modo de vuelo siempre visible | Label arriba a la derecha, vacío en ACRO | Nuevo `hud/hud_mode_badge.gd`: píldora con borde de 3 px y radio 12. Muestra siempre ACRO, HORIZON, SPEED, POSITION, TURTLE, LAUNCH o RECOVER (claves `HUD_MODE_*`). Parpadea en RECOVER. |
| "● Rec." abajo a la izquierda | Aviso de que la vuelta se está grabando | Nada | Nuevo `hud/hud_rec_indicator.gd`: punto rojo que parpadea a 1 Hz + "REC". Visible cuando `Global.active_track` existe y `record_replay` es verdadero (lectura, sin tocar `track.gd`). |

**Horizonte: dos modos** (nueva opción `horizon_mode` en la configuración del HUD)
- **Real, alineado a la cámara** (default): la línea cae exactamente sobre el horizonte que se ve, incluida la inclinación de la cámara y la curvatura del fisheye. Se toman 13 direcciones horizontales (elevación 0) repartidas en ±60° alrededor del rumbo de la cámara, se proyectan a pantalla y se dibujan como polilínea punteada, salteando los puntos a menos de 60 px del centro. Los peldaños de la escalera, si están activos, se proyectan igual a ±10°, ±20° y ±30° de elevación.
- **Actitud del dron** (clásico): el comportamiento actual, 20 px por grado de pitch del dron, con el nuevo estilo punteado.

Proyección: se agrega un método de sólo lectura `FPVCamera.project_direction(dir: Vector3) -> Vector2` en `drone/fpv_camera/fpv_camera.gd`.
- Fisheye OFF: `unproject_position(global_position + dir)`.
- Fisheye FULL/FAST: pasar `dir` a coordenadas locales de la cámara; `θ = acos(-local.z)`; distancia al centro en px `θ / (deg_to_rad(fov_h) / 2) · min(ancho, alto)` del viewport; dirección `Vector2(local.x, -local.y).normalized()`. Devuelve NaN si `θ` supera el campo visible.
- Riesgo: el vertex shader invierte X e Y (`vec4(-1, -1, 1, 1)`); confirmar el signo con una captura de prueba antes de dar el modo por bueno.

**Marcador de la próxima puerta** (opcional, no está en la captura; lo propone también `ANALISIS_SIMULADOR_DRONES.md` §3.5)
- Sólo en modo carrera. Rombo de 16 px sobre la puerta cuando está en cuadro, con la distancia en metros debajo. Si está fuera de cuadro, flecha en el borde de una elipse al 80 % de la pantalla apuntando hacia ella.
- Posición: `Global.active_track.current_checkpoint.global_position` (`track.gd:43,200-208`), proyectada con `project_direction`. Apagado por defecto.

**Distribución** (referencia 1920×1080, todo con anclas)

| Zona | Elemento |
|---|---|
| Arriba izquierda (margen 48) | Insignia de modo |
| Arriba centro (y 150) | Brújula |
| Arriba derecha (margen 48) | ALT / SPD / VS |
| Centro | Mira, horizonte, cintas laterales, marcador de puerta |
| Centro, 90 px bajo la mira | `HUDStatus` (ARMED, THROTTLE HIGH, …) |
| Abajo centro | Visor de sticks |
| Abajo izquierda | REC |
| Abajo derecha | RPM (existente) |

Coordinación con el plan del tutorial (`docs/tutorial_plan.md` §3.3): su panel de objetivo va arriba a la izquierda y sus pistas de sticks abajo a la izquierda. Bajar el panel del tutorial 110 px para no tapar la insignia de modo; REC sólo aparece en carrera, así que no choca con las lecciones 1–7.

**Configuración** (`GameSettings.cfg [hud_config]`, pantalla existente `hud_config.tscn` con preview en vivo)
- Claves nuevas: `flight_mode` (true), `rec` (true), `side_tapes` (true), `gate_marker` (false), `horizon_mode` ("camera" o "attitude"). `load_hud_config()` hoy sólo acepta `bool` y `fps` (`game_settings.gd:23-26`): agregar el caso string para `horizon_mode`.
- Defaults nuevos para instalaciones nuevas: mira, horizonte, brújula, velocidad, altura, cintas, modo y REC encendidos; sticks, escalera, RPM y marcador de puerta apagados. Quien ya tiene `GameSettings.cfg` conserva sus valores y recibe los defaults sólo en las claves nuevas.
- Presets rápidos arriba de la lista: **Mínimo** (mira + horizonte + modo), **Estándar** (defaults), **Completo** (todo). Tocar un toggle muestra "Personalizado", igual que el preset de gráficos.
- `hud_config.gd` agrega los toggles y el `OptionButton` de modo de horizonte; la preview (`hud_config.tscn:106-111`) muestra los componentes nuevos sin cambios extra.

**Traducción**: `HUD_ALT`, `HUD_SPD`, `HUD_VS`, `HUD_REC`, `HUD_MODE_*`, `HUD_COMPASS_N` … `HUD_COMPASS_NW`, `HUD_STATUS_*`, `HUD_UNIT_M`, `HUD_UNIT_KMH`.

---

## 5. Fases (cada una entregable y probable por separado)

### Fase 1: infraestructura invisible (navegación completa sin cambio visual)
- **Crear**: `gui/menu_screen.gd`, `autoloads/ui.gd`, `autoloads/stick_navigation.gd`, `gui/components/confirm_overlay.tscn/.gd`, `gui/options_menu/controls_menu/binding_popup.tscn` (reescribe `binding_popup.gd`), `tools/ui_smoke_test.tscn/.gd`.
- **Modificar**: `project.godot` (stretch, `ui_*`, autoloads), los 10 scripts de pantalla (`gui/main_menu.gd`, `gui/pause_menu.gd`, `gui/help_page.gd`, `gui/quad_settings_menu.gd`, `gui/options_menu/{options_menu,graphics_menu,audio_menu,game_settings_menu,hud_config}.gd`, `gui/options_menu/controls_menu/{controls_menu,calibration_menu}.gd`), `gui_controller_binding.gd`, `gui_controller_axis_range.gd`, `controls_menu.tscn:55`, `calibration_menu.tscn`, `autoloads/global.gd:57-64` (→ `UI.alert`), `autoloads/controls.gd` (`reset_controller_bindings`), `autoloads/game_settings.gd` (`[game] nav_scheme`, `load_game_settings()`), `sceneries/level.gd:93-99`, `tracks/time_table.gd`, `hud/hud.tscn`, `hud/hud_status.gd:40`, `hud_config.tscn` (slider FPS).
- **Borrar**: `gui/confirmation_popup.tscn/.gd`.
- Orden sugerido: `project.godot` → `MenuScreen` + migrar `options_menu` y `graphics_menu` (probar con teclado) → `UI` → `StickNavigation` → smoke test (valida temprano que el `InputEventAction` sintetizado mueve el foco) → overlay + reemplazo de diálogos → controles/calibración/reset → HUD/anclajes → espera de neutral en pausa.
- Riesgos: `_ensure_focus` robando foco a un `LineEdit` (excluir); radios ruidosas (umbral 0.6 + histéresis); `PopupMenu` embebido de `OptionButton` ignorando acciones sintéticas (mitigación: `ui_left/right` ya ciclan sin abrir el popup).

### Fase 2: theme + layout
- **Crear**: `gui/theme/ui_palette.gd`, `tools/build_theme.gd`, `gui/theme/main_theme.tres` (+ `icons/`), `gui/components/{menu_background,menu_header,control_hints,menu_hero}.tscn/.gd`.
- **Modificar**: `project.godot` (`gui/theme/custom`), todos los `.tscn` de `gui/` (estructura header/card/footer y variaciones), `gui/rate_graph.gd`, `gui_controller_axis.gd:7`, `gui_controller_button.gd:8`, `gui_controller_binding.gd`, `hud/hud_theme.tres`, `gui/countdown_theme.tres`, `gui/timer_theme.tres` (font_color blanco), `controls_menu.gd:145,150` (`$MenuPanel.modulate` → `visible`).
- **Borrar**: `gui/menu_theme.tres`, `gui/help_page_theme.tres`.
- Riesgos: `ScrollContainer` recorta la sombra de la tarjeta (tarjeta afuera, scroll adentro); hero caro en web (`enabled_on_web`); `TabContainer` necesita `focus_neighbor_bottom` explícito hacia el contenido.

### Fase 3: sonidos, micro-animaciones, transiciones
- **Crear**: `tools/generate_ui_sounds.gd` (`-s`, sintetiza `AudioStreamWAV` 16 bit 22 050 Hz: hover 1 200 Hz 40 ms, click 900→600 Hz 60 ms, back 600→400 Hz 80 ms, tick 2 000 Hz 15 ms, error 300 Hz 120 ms; `save_to_wav`), `Assets/Audio/UI/*.wav`, `default_bus_layout.tres`, `autoloads/scene_transition.gd`.
- **Modificar**: `project.godot` (autoload), `autoloads/ui.gd` (activar `play`), `gui/main_menu.gd:39`, `sceneries/level.gd:101-103`, `drone/motor.gd:52`.

### Fase 4: opciones nuevas
- **Modificar**: `autoloads/graphics.gd` + `graphics_menu.tscn/.gd`, `autoloads/audio.gd` + `audio_menu.tscn/.gd`, `autoloads/quad_settings.gd` + `quad_settings_menu.tscn/.gd`, `drone/fpv_camera/fpv_camera.gd` (sólo suscripción y `_apply_fov`), `controls_menu.tscn/.gd` (esquema), `game_settings_menu.tscn/.gd` (Idioma), `autoloads/game_settings.gd`.
- Riesgos: presets pisando ajustes (sólo se aplican al elegir un preset); `Engine.max_fps`/VSync ignorados en web (filas ocultas); `AudioServer.get_bus_index` devolviendo −1 si el layout no cargó (guard).

### Fase 5: localización
- **Crear**: `localization/translations.csv` (+ `.translation`), `tools/check_translations.gd`.
- **Modificar**: `project.godot` (`[internationalization]`), todos los `.tscn` con texto, los `.gd` listados en J.
- Riesgos: claves olvidadas visibles como `MENU_X` (chequeo automático); textos largos desbordando botones (`text_overrun_behavior` + ancho mínimo 380 en la lista principal).

### Fase 6: HUD de orientación (sección K)
- Independiente de las fases de menús salvo por la pantalla de configuración del HUD. Se puede adelantar si se prioriza la experiencia de vuelo.
- **Crear**: `hud/hud_compass_tape.gd/.tscn`, `hud/hud_side_tape.gd/.tscn`, `hud/hud_readouts.gd/.tscn`, `hud/hud_mode_badge.gd/.tscn`, `hud/hud_rec_indicator.gd/.tscn`, `hud/hud_gate_marker.gd/.tscn` (opcional), `tools/hud_projection_check.tscn/.gd`.
- **Modificar**: `hud/hud.tscn` (nueva distribución con anclas), `hud/hud.gd` (componentes nuevos al final del enum, actualización por frame de lo orientativo, suscripción a `hud_config_updated` para las claves nuevas), `hud/hud_ladder.gd` (punteado, sin recorte, dos modos), `hud/hud_stick_input.gd/.tscn` (dibujo propio, misma API), `hud/hud_speed_scale.gd` y `hud/hud_altitude_scale.gd` (quedan como fuente de datos de las lecturas o se retiran de la escena), `hud/hud_status.gd`, `hud/hud_theme.tres`, `drone/fpv_camera/fpv_camera.gd` (`project_direction`), `autoloads/game_settings.gd`, `gui/options_menu/hud_config.tscn/.gd`.
- Orden sugerido: estilo común y distribución → insignia de modo y lecturas → brújula → horizonte en modo actitud → `project_direction` + chequeo de proyección → horizonte real → cintas → sticks → REC → configuración y presets → marcador de puerta.
- Riesgos: signo invertido en la proyección fisheye (chequeo con captura); horizonte real inestable cuando la cámara mira casi vertical (ocultarlo si |elevación del eje| > 80°); costo de `queue_redraw()` por frame en web (medir con el proxy Compatibility; bajar a 30 Hz si hace falta); textos que cambian de ancho con el valor (fuente mono y ancho mínimo fijo).

### Fase 7: carrera + documentación
- `tracks/track.gd` (sólo `tr()`), `tracks/time_table.gd` (estilo Card, autocierre), `docs/ui.md` (arquitectura, contrato `MenuScreen`, paleta, cómo regenerar theme y sonidos, flujo de traducción, componentes del HUD, checklist).

---

## 6. Verificación

Binario: `C:/Users/Mauri/Godot/Godot_4.7/Godot_v4.7-stable_win64_console.exe`. Sin export templates Web locales: el proxy es el renderer Compatibility en escritorio.

**Automático (sin mando)**
1. `--headless --path . --import` tras agregar CSV/theme/WAV (mismo comando que el CI).
2. Regenerar artefactos: `--headless --path . -s tools/build_theme.gd` y `-s tools/generate_ui_sounds.gd`, luego `--import`.
3. Carga de cada escena de UI y del nivel: `--headless --path . --quit-after 3 res://gui/main_menu.tscn` (y `pause_menu`, `options_menu/*`, `controls_menu/*`, `quad_settings_menu`, `help_page`, `sceneries/level1.tscn`). Exit 0 y sin `SCRIPT ERROR`.
4. `tools/ui_smoke_test.tscn` (escena, no `-s`, para tener autoloads): instancia cada `MenuScreen`, fuerza `UI.input_kind = GAMEPAD`, comprueba `gui_get_focus_owner() != null`, inyecta `ui_down` press/release con `Input.parse_input_event` y verifica que el foco cambió; `ui_accept` sobre Opciones del menú principal abre `OptionsMenu`; `ui_cancel` lo cierra; `UI.confirm` arranca con foco en Cancelar y `ui_cancel` devuelve `false`; `Input.action_press("pitch_up", 1.0)` durante 0.4 s produce un cambio de foco y ninguno tras `action_release`. Termina con `get_tree().quit(código)`. Si la GUI no procesa foco en headless, correr con `--windowed --resolution 960x540`.
5. `tools/check_translations.gd`: claves usadas en `.tscn`/`.gd` vs. primera columna del CSV, en ambas direcciones.
6. Proxy web: `--path . --rendering-method gl_compatibility --windowed --resolution 1280x720 res://gui/main_menu.tscn` (hero con `transparent_bg`, sin errores de shader). Web real: artefacto `HTML5` del workflow en cada push/PR.
7. `tools/hud_projection_check.tscn` (ventana, no headless, porque necesita render): instancia `level1`, apoya el dron quieto en el suelo, espera 60 frames y guarda una captura por cada modo de fisheye (OFF, FULL, FAST) con el horizonte real activo. En cada captura mide, en 5 columnas, la fila donde el cielo pasa a suelo (salto de luminancia) y la compara con la fila de la polilínea del HUD. Tolerancia: 6 px. Repetir con la cámara a 0° y a 45°.

**Manual con hardware** (mouse, teclado, gamepad Xbox 360 del usuario, radio, web)
- Menú principal: foco inicial en Volar sólo con teclado/gamepad; sin anillo con mouse; D-pad recorre los 5 botones; B en Salir no hace nada; Salir → overlay con foco en Cancelar; hero gira; chips cambian al alternar dispositivo; en web sin mando aparece el aviso y al pulsar un botón el nombre del mando.
- Gráficos: cada OptionButton cicla con ←/→ y con roll (Betaflight) sin abrir popup; A abre el popup; el preset cambia los 5 valores y tocar uno muestra Personalizado; VSync/FPS medibles con `Performance.TIME_FPS`; en web sólo Pantalla completa.
- Audio: 3 sliders con ←/→ (tick audible); en vuelo, Motores baja los motores y Interfaz no.
- Juego: idioma retraduce todo en vivo (incluidos tooltips, popup de binding, countdown, HUD); pestaña HUD con ←/→, ↓ entra al contenido.
- Controles: filas con ↑/↓, A abre el popup en LISTENING, otro A lo captura como "Botón 0" y pasa a CAPTURED con foco en Confirmar; con radio, un switch se captura y roll derecha confirma; handles del rango con ←/→; calibración de 14 pasos con radio y cancelable con B desde gamepad; Reset pide confirmación y limpia la sección del `.cfg`; cambiar el esquema cambia chips y comportamiento al instante.
- Quad: sliders con ←/→ y roll; FOV cambia la imagen al volver a volar en FULL/FAST; B guarda (`Quad.cfg`).
- Pausa en vuelo: START abre con fundido y scrim; F2 oculta y los sticks no navegan; Reanudar con A no cambia el modo de vuelo ni arma; con radio, roll derecha en Reanudar no inclina el dron; Volver al menú → overlay → transición.
- Carrera: R, countdown traducido, fin de vuelta → tabla con foco en Cerrar; A cierra sin cambiar modo de vuelo; autocierre a 10 s; mouse capturado al cerrar.
- HUD en vuelo: la brújula marca N al mirar hacia -Z del mundo y gira en el sentido correcto al guiñar; el horizonte real queda sobre el horizonte visible en vuelo estacionario, en picada y con alabeo de 60°, en los tres modos de fisheye; el modo actitud se comporta como hoy; horizonte, brújula y cintas se mueven fluidos con "Frecuencia de números" en 5; la insignia muestra ACRO y cambia al ciclar modos; REC aparece sólo mientras se graba la vuelta; el visor de sticks refleja los sticks; los presets Mínimo, Estándar y Completo cambian la preview y se guardan; un `GameSettings.cfg` viejo conserva sus toggles.
- Escalado: 1280×800, 2560×1080, 3840×2160 y ventana 75 %/50 %: HUD RPM abajo-derecha, estado centrado, menús sin recorte.

---

## 7. Lo que NO se toca (garantía de gameplay intacto)

- `drone/**` salvo `fpv_camera.gd` (sólo suscripción a `settings_updated` + `_apply_fov` + el método de lectura `project_direction`) y `motor.gd:52` (sólo `bus`). Intactos: `drone.gd`, `flight_controller/**`, `radio_controller.gd`, `propeller*`, `control_profile.gd`, `controller_action.gd`.
- `sceneries/level.gd`: sólo `_on_resume` y `_on_return_to_menu`. `level1.tscn` y `cameras/**` intactos.
- `tracks/track.gd`: sólo `tr()` en textos. `checkpoint.gd`, `launch_area.gd`, `lap_timer.gd`, `ghost.gd`, `gates/**` intactos.
- `hud/**` se rediseña (sección K), pero se conservan la API pública (`HUD.update_data()`, `show_component()`, `status`, `HUDStickInput.update_stick_input()`), los valores existentes del enum `Component` y las claves existentes de `[hud_config]`. `drone.gd:202-211` y `drone.gd:279-288` no cambian.
- Acciones de vuelo en `project.godot` (`throttle_*`, `pitch_*`, `roll_*`, `yaw_*`, `cycle_flight_modes`, `change_camera`, `camera_*`, `pause_menu`, `race_mode`, `respawn`, `toggle_arm`, `arm`, `mode_*`, `altitude_hold`); `[physics]`, `[rendering]`, `[shader_globals]`; `export_presets.cfg`; `.github/workflows/deploy-to-itch.yml`.
- Formato de `user://config/*.cfg`: sólo se agregan claves (`af` se ignora). `Controls.load_input_map()` y `restore_keyboard_shortcuts()` sin cambios.
- `controls_menu_drone.tscn/.gd`, `controls_menu_radio_transmitter.tscn/.gd`, `radio_transmitter.tscn`: se reutilizan tal cual.

---

## 8. Notas para la implementación

- El Bash tool en esta máquina corta comandos de más de ~8 KB y colapsa barras dobles: escribir archivos con Write/Edit, no con heredocs.
- Regenerar theme y sonidos con los scripts `-s` y commitear los artefactos; el CI sólo hace `--import`.
- Commits por fase, en español, con la línea `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- La fuente de verdad es este archivo. La copia en `C:\Users\Mauri\.claude\plans\quiero-que-armemos-un-adaptive-kernighan.md` no incluye la sección K ni la Fase 6.
