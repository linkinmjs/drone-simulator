# Interfaz: arquitectura y mantenimiento

Implementación del plan de [plan-ui.md](plan-ui.md), rama `ui-lavado-de-cara`. Este documento explica cómo está armada la interfaz nueva, cómo regenerar sus recursos y cómo probarla.

## 1. Piezas principales

| Pieza | Archivo | Qué hace |
|---|---|---|
| `MenuScreen` | `gui/menu_screen.gd` | Clase base de las 10 pantallas. Señal `back`, `ui_cancel`, fundido de entrada y salida, fondo (degradado claro o velo sobre el nivel), pie con ayudas de control, foco inicial y `open_submenu()`. |
| `UI` (autoload) | `autoloads/ui.gd` | Dispositivo en uso (mouse, teclado, gamepad, sticks), convivencia foco/mouse, sonidos y micro-animaciones enganchados con `node_added`, pila de contextos de foco, `confirm()` y `alert()`. |
| `StickNavigation` (autoload) | `autoloads/stick_navigation.gd` | Convierte pitch, roll y yaw calibrados en acciones `ui_*`. Umbral 0.6, histéresis 0.4, repetición 350 ms + 120 ms. El acelerador nunca navega. |
| `SceneTransition` (autoload) | `autoloads/scene_transition.gd` | Fundido al color de fondo al cambiar entre menú y nivel. |
| `ConfirmOverlay` | `gui/components/confirm_overlay.gd` | Diálogo modal dibujado dentro de la interfaz. Reemplaza los `ConfirmationDialog`/`AcceptDialog` nativos y `confirmation_popup.tscn`. |
| `ControlHints` | `gui/components/control_hints.gd` | Pie de cada pantalla con las teclas del dispositivo en uso y el mando conectado. |
| `MenuHero` | `gui/components/menu_hero.gd` | Dron 3D girando en el menú principal; reutiliza `controls_menu_drone.tscn`. `enabled_on_web` permite apagarlo en web. |
| `ThemeBuilder` / `UIPalette` | `gui/theme/` | Paleta única y generador del theme global. |

### Contrato de `MenuScreen`

- La pantalla hereda de `MenuScreen` y llama a `super()` al principio de `_ready()`. Antes de `super()` puede fijar `initial_focus`, `backdrop`, `allow_back` o `show_hints`.
- Los botones "Volver" se enlazan con `bind_back_button(button)`. El trabajo previo a salir (guardar, restaurar atajos) va en `_before_back()`.
- Los submenús se abren con `open_submenu(escena, nodo_a_ocultar, padre)`. El flujo original sigue igual: instanciar, agregar, ocultar, esperar `back`, liberar. Al volver, el foco regresa al botón que abrió el submenú.
- Un submenú agregado dentro de un contenedor se marca `top_level` para cubrir toda la pantalla.

### Foco y dispositivos

- Con mouse no se muestra anillo de foco. La primera tecla, botón o gesto de stick después de usar el mouse sólo muestra el foco, sin ejecutar la acción.
- Sobre un `OptionButton`, izquierda y derecha recorren las opciones sin abrir la lista. Sobre un `CheckButton`, izquierda apaga y derecha prende.
- `UI.register_context(control)` agrega una pantalla o un modal a la pila. El contexto activo es el último visible. Un contexto con el meta `no_sticks` no se maneja con los sticks.
- Mientras se escucha una asignación de control o se calibra, `StickNavigation.suspended` está activo.

### Acciones `ui_*`

`project.godot` redefine `ui_up`, `ui_down`, `ui_left`, `ui_right` (flechas y cruceta), `ui_accept` (Enter, Enter numérico, Espacio y botón A) y `ui_cancel` (Escape y botón B). Ya no incluyen ejes de joystick, así que el acelerador de una radio en reposo no mueve el foco. Las acciones de vuelo no cambiaron.

### Pausa

`sceneries/level.gd` espera a que se suelte el botón o el stick usado para reanudar antes de despausar. Así el botón A no cambia el modo de vuelo y un gesto de roll no inclina el dron.

## 2. Theme

- Colores, fuentes y márgenes en `gui/theme/ui_palette.gd`.
- Estilos en `gui/theme/theme_builder.gd`. Los íconos (grabber de slider, interruptores, flechas) se generan por código.
- Para regenerar `gui/theme/main_theme.tres` después de cambiar paleta o estilos:

```
godot --headless --path . -s res://tools/build_theme.gd
```

- El theme se aplica a todo el proyecto con `gui/theme/custom`. El HUD y las etiquetas de carrera tienen su propio theme con texto blanco explícito.
- Variaciones disponibles: `DisplayLabel`, `TitleLabel`, `HeadingLabel`, `SubtitleLabel`, `CaptionLabel`, `SectionLabel`, `HintLabel`, `ValueLabel`, `KeyCap`, `BodyText`, `MenuItemButton`, `PrimaryButton`, `DangerButton`, `GhostButton`, `Card`, `InsetPanel`, `Chip`, `ClearPanel`, `OverlayScrim`, `HudPreviewPanel` y los estilos `RowPanel` de las filas de asignación.

## 3. Sonidos de interfaz

`Assets/Audio/UI/{hover,click,back,tick,error}.wav` se sintetizan con:

```
godot --headless --path . -s res://tools/generate_ui_sounds.gd
godot --headless --path . --import
```

Suenan en el bus `UI`. `default_bus_layout.tres` define los buses Master, Motors, UI y Music (reservado).

## 4. Traducciones

- Fuente única: `localization/translations.csv` (columnas `keys,es,en`). Godot genera los `.translation` al importar.
- En escenas, el texto visible es la clave (`text = "MENU_FLY"`) y se traduce solo. En código, `tr("CLAVE")` cuando hay formato; los textos armados en código se reconstruyen en `NOTIFICATION_TRANSLATION_CHANGED`.
- Prefijos: `MENU_`, `OPT_`, `GFX_`, `AUD_`, `GAME_`, `HUD_`, `CTRL_`, `CAL_`, `QUAD_`, `HELP_`, `RACE_`, `UI_`, `ERR_`.
- Idioma en Opciones > Juego y HUD. Primer arranque: idioma del sistema si es español o inglés, si no español.

## 5. HUD de orientación

| Componente | Archivo | Notas |
|---|---|---|
| Horizonte y escalera | `hud/hud_horizon.gd` | Modo `camera`: horizonte real proyectado con la lente. Modo `attitude`: actitud del dron como antes. |
| Brújula | `hud/hud_compass_tape.gd` | Norte = -Z del mundo. |
| Cintas laterales | `hud/hud_side_tapes.gd` | Velocidad (izquierda) y altura (derecha), sin números. |
| Lecturas | `hud/hud_readouts.gd` | ALT, VEL y VS arriba a la derecha. |
| Insignia de modo | `hud/hud_mode_badge.gd` | Parpadea en recuperación. |
| REC | `hud/hud_rec_indicator.gd` | Visible mientras `Track.record_replay`. |
| Próxima puerta | `hud/hud_gate_marker.gd` | Opcional, apagado por defecto. |
| Mira y sticks | `hud/hud_crosshair.gd`, `hud/hud_stick_input.gd` | `update_stick_input(Vector2)` conserva su API. |

- Horizonte, brújula, cintas y marcador se redibujan cada frame. Los números siguen la "Frecuencia de números" (antes "HUD FPS").
- `FPVCamera.project_direction()` replica la lente: `unproject_position` sin ojo de pez, proyección equidistante con ojo de pez. Está validado con `tools/hud_projection_check.tscn`.
- Configuración en `GameSettings.cfg [hud_config]`. Claves nuevas: `flight_mode`, `rec`, `side_tapes`, `gate_marker`, `horizon_mode`. Un archivo existente conserva sus valores.
- Presets Mínimo, Estándar y Completo en la pestaña HUD.

## 6. Opciones nuevas

| Pantalla | Opción | Persistencia |
|---|---|---|
| Gráficos | Preset de calidad, VSync, límite de FPS | `Graphics.cfg`: `vsync`, `max_fps` (el preset se deduce de los valores) |
| Gráficos (web) | Pantalla completa | no se guarda |
| Audio | Motores, Interfaz, Silenciar | `Audio.cfg`: `motors_volume`, `ui_volume`, `muted` |
| Juego y HUD | Idioma, navegación con sticks | `GameSettings.cfg [game]`: `language`, `nav_scheme` |
| Ajustes del dron | Campo de visión FPV | `Quad.cfg [quad]`: `fov` |
| Controles | Restablecer (ahora funciona) | borra la sección `controls_<GUID>` de `InputMap.cfg` |

El filtro anisotrópico se quitó de la pantalla porque Godot 4 no permite cambiarlo en ejecución. La clave `af` se sigue leyendo sin efecto.

En web se ocultan modo de ventana, resolución, VSync y FPS, y el preset por defecto es Medio (ojo de pez rápido).

## 7. Pruebas

Binario local: `C:/Users/Mauri/Godot/Godot_4.7/Godot_v4.7-stable_win64_console.exe`.

```
godot --headless --path . --import
godot --path . --windowed --resolution 1600x900 res://tools/ui_smoke_test.tscn -- --shots=<carpeta>
godot --path . --windowed --resolution 1600x900 res://tools/hud_projection_check.tscn -- --shots=<carpeta>
godot --path . --rendering-method gl_compatibility --windowed --resolution 1280x720 res://tools/ui_smoke_test.tscn
```

- `ui_smoke_test`: traducciones, navegación con acciones `ui_*` por todas las pantallas, retorno del foco, diálogo modal y gestos de stick (navegar, repetir, aceptar, volver, acelerador ignorado). Termina con código 0 si todo pasa.
- `hud_projection_check`: carga el nivel con los tres modos de ojo de pez y dos ángulos de cámara, verifica la proyección del horizonte y guarda capturas del HUD, el menú de pausa y los overlays de carrera.
- Ninguna de las dos guarda configuración del usuario.

### Pendiente de probar con hardware

- Radio real: navegación estilo Betaflight y con yaw, asignación de switches, calibración completa.
- Gamepad: asignación con A/B, reanudar la pausa con A sin cambiar el modo de vuelo.
- Web en itch.io: aviso "Presioná un botón", pantalla completa, rendimiento del dron 3D del menú.
- Carrera completa: tabla de resultados, cierre con B, REC y marcador de puerta.

## 8. Decisiones y desvíos respecto del plan

- La opción de navegación con sticks quedó en Opciones > Juego y HUD, junto al idioma, en lugar del menú de controles: es una preferencia de interfaz y el menú de controles ya está muy cargado.
- La tabla de resultados de carrera no toma el foco del teclado: Espacio sigue armando el dron. Se cierra con el mouse, con el botón B o sola a los 10 segundos.
- El theme se genera como `.tres` con íconos embebidos en lugar de PNG sueltos, para no depender de un segundo paso de importación.
- Los componentes viejos del HUD (`hud_heading_scale`, `hud_speed_scale`, `hud_altitude_scale`, `hud_bidirectional_gauge`, `hud_pitch_marker`, `hud_ladder`) se borraron porque el HUD nuevo los reemplaza.
- Coordinación con `docs/tutorial_plan.md`: su panel de objetivos va arriba a la izquierda y debe bajar unos 110 px para no tapar la insignia de modo.
