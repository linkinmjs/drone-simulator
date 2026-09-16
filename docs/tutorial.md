# Instructor de vuelo: arquitectura y mantenimiento

Implementación del plan de [tutorial_plan.md](tutorial_plan.md), rama `instructor-de-vuelo`. Este documento explica cómo está armado el tutorial, cómo agregar o ajustar una lección y cómo probarlo.

## 1. Qué ve el jugador

El menú principal tiene la entrada **Instructor de vuelo**. Abre `sceneries/tutorial_level.tscn`, un nivel chico con ocho lecciones:

| # | Lección | Modo | Se completa cuando |
|---|---|---|---|
| 1 | Tu control | Horizon | Hay un mando, cada stick llega a ambos extremos, arma con el acelerador abajo y desarma |
| 2 | Despegue y altura | Horizon | Se mantiene 3 s dentro del cilindro (1 a 3 m), aterriza y desarma en el suelo |
| 3 | Guiñada | Horizon | En el aire gira 90° a la izquierda y después 90° a la derecha |
| 4 | Cabeceo | Horizon | Vuela a la zona de adelante y vuelve al centro |
| 5 | Alabeo | Horizon | Visita derecha, centro, izquierda y centro |
| 6 | Puertas en modo Horizon | Horizon | Cruza tres puertas en orden y de frente |
| 7 | Puertas en modo Acro | Acro | Las mismas puertas en Acro |
| 8 | Tu primer circuito | Acro (se puede cambiar) | Termina una vuelta cronometrada en `Track_Tutorial` |

- Al entrar aparece un menú: empezar, seguir en la primera lección pendiente, elegir lección, empezar de cero o volver.
- Durante el vuelo, una tarjeta a la izquierda muestra la lección, la tarea del momento, el progreso, avisos, qué stick mover y los atajos.
- Al completar una lección aparece «¡Bien hecho!» y la siguiente arranca sola a los 3 s. X o Enter la adelantan.
- BACK o Retroceso reinician la lección. RB o N la saltan. El menú de pausa suma Reiniciar, Saltar y Elegir lección.
- Si el dron queda volcado en el suelo 3 s, o cae fuera del mapa, vuelve solo al inicio de la lección.
- Al terminar la lección 8 aparece el menú final: volar libre, elegir lección, repetir o volver.

## 2. Piezas

| Pieza | Archivo | Qué hace |
|---|---|---|
| `TutorialLevel` | `sceneries/tutorial_level.gd` | Hereda de `Level`. Desactiva la tecla R, filtra el cambio de modo, conecta secuenciador, HUD y menús, agrega entradas al menú de pausa y restablece `Global` al salir. |
| `TutorialSequencer` | `tutorial/tutorial_sequencer.gd` | Corre sus hijos `TutorialStep` en orden. Estados `IDLE`, `RUNNING`, `SUCCESS`, `FINISHED`. |
| `TutorialStep` | `tutorial/tutorial_step.gd` | Base de una lección: modo de vuelo forzado, punto de reaparición, detección de vuelco y métodos virtuales. |
| Lecciones | `tutorial/steps/*.gd` | `StepControllerCheck`, `StepHover`, `StepYaw`, `StepReachZones` (4 y 5), `StepGates` (6 y 7), `StepRace`. |
| `TutorialHUD` | `tutorial/tutorial_hud.gd` | Tarjeta y mensaje grande en su propio `CanvasLayer`, visible con cualquier cámara. Construida en código. |
| `TutorialStickHint` | `tutorial/tutorial_stick_hint.gd` | Caja de stick: anillo con la posición actual y flecha pulsante con la sugerida. |
| `TutorialMenu` | `tutorial/tutorial_menu.gd` | `MenuScreen` construido en código para inicio, selector y final. Funciona con mouse, teclado, gamepad y sticks. |
| `TutorialZone` | `tutorial/tutorial_zone.gd` | Cilindro translúcido con anillos (`@tool`). Estados `HIDDEN`, `IDLE`, `ACTIVE`, `INSIDE`, `DONE`. |
| Pista | `tracks/tracks/Track_Tutorial.tscn` | Plataforma y cuatro `Gate_7x6_Simple` en un rectángulo, una vuelta. |

### Ciclo de una lección

1. `setup(level)` una vez, al cargar el nivel.
2. `start()` mueve `Respawn` al `respawn_marker`, fuerza `flight_mode` con `FlightController.select_flight_mode()`, llama a `_on_start()` y reaparece el dron.
3. Cada reaparición llama a `restart()`, que vuelve a cero el progreso con `_on_restart()`.
4. `_tick(delta)` corre en cada frame de física mientras la lección está activa y llama a `finish()` al cumplirse el objetivo.
5. `stop()` llama a `_on_stop()` al salir de la lección.

La tarjeta consulta cada 0,1 s `get_task_text()`, `get_progress()`, `get_progress_text()`, `get_stick_hint()` y `warning_key`.

Convención de sticks en pantalla: `Vector2(0, -1)` es el stick arriba. Arriba en el stick derecho es **pitch down** (nariz abajo, el dron avanza), igual que en la calibración y en el HUD de vuelo.

## 3. Agregar o ajustar una lección

1. Crear un script en `tutorial/steps/` que extienda `TutorialStep` e implemente `_tick` y los getters que necesite.
2. Agregar un nodo hijo de `TutorialSequencer` en `tutorial_level.tscn`, en la posición deseada. El orden de los hijos es el orden de las lecciones.
3. Completar en el inspector `title_key`, `objective_key`, `flight_mode`, `respawn_marker` y los parámetros propios. Los umbrales son `@export`: se ajustan sin tocar código.
4. Agregar las claves nuevas a `localization/translations.csv` (prefijo `TUT_`) y reimportar.
5. El progreso guardado es una máscara de bits por posición. Insertar una lección en el medio corre la numeración de las siguientes.

## 4. Progreso guardado

`GameSettings.cfg`, sección `[tutorial]`:

| Clave | Contenido |
|---|---|
| `completed` | Máscara de bits: bit 0 = lección 1 |
| `last_lesson` | Última lección iniciada (1 a 8) |

API en `autoloads/game_settings.gd`: `load_tutorial_progress`, `save_tutorial_progress`, `is_lesson_completed`, `mark_lesson_completed`, `get_first_incomplete_lesson`, `reset_tutorial_progress`. Saltar una lección no la marca como completada.

## 5. Cambios fuera del tutorial

| Archivo | Cambio | Motivo |
|---|---|---|
| `project.godot` | Acciones `tutorial_next` (X, Enter) y `tutorial_skip` (RB, N) | Atajos del tutorial |
| `project.godot` | `pitch_up` pasa al eje 3 positivo y `pitch_down` al negativo | Sin calibrar, empujar el stick derecho hacia arriba hacía retroceder al dron. La calibración ya usaba la convención correcta. |
| `autoloads/stick_navigation.gd` | Stick arriba (`pitch_down`) mueve el foco hacia arriba | Estaba escrito sobre el default invertido. Con una radio calibrada navegaba al revés. |
| `drone/flight_controller/flight_controller.gd` | `select_flight_mode()`. La recuperación automática solo actúa armado y sale sola al desarmar. | Un dron desarmado todavía inclinado quedaba en recuperación para siempre y no se podía armar. |
| `autoloads/global.gd` | `race_mode_toggle_enabled` y la señal `game_mode_changed(mode: int)` | La tecla R no debe cambiar de modo dentro del tutorial |
| `sceneries/level.gd` | `class_name Level` | Base de `TutorialLevel` |
| `gui/main_menu.*` | Botón «Instructor de vuelo» | Entrada |
| `autoloads/scene_transition.gd` | Consejo `UI_TIP_TUTORIAL` en la pantalla de carga | Descubrimiento |

## 6. Pruebas

```
godot --headless --path . --import
godot --path . --windowed --resolution 1600x900 res://tools/tutorial_check.tscn -- --shots=<carpeta>
godot --path . --rendering-method gl_compatibility --windowed --resolution 1280x720 res://tools/tutorial_check.tscn
```

`tutorial_check` no guarda nada y termina con código 0 si todo pasa. Recorre:

- Traducciones en español e inglés.
- Lecciones 1 a 6 voladas con entradas simuladas y un piloto automático, que despega de nuevo si el dron se estrella.
- Lección 7 cruzando checkpoints por código, incluido uno fuera de orden, y el bloqueo del cambio de modo.
- Entradas del menú de pausa, con Saltar hacia la lección 8.
- Lección 8: modo carrera, plataforma, cuenta regresiva, vuelta completa, menú final y estado de `Global` al salir.
- Menú de inicio con progreso: foco en «Seguir», selector de lecciones, volver y continuar.

Los vuelos simulados dependen de la física. Si una corrida falla en un vuelo y la siguiente pasa, mirar primero el piloto automático de la prueba. `ui_smoke_test` y `hud_projection_check` también deben pasar.

### Pendiente de probar con hardware

- Gamepad real: umbrales de las lecciones 1 y 2 (acelerador con resorte), atajos X, RB y BACK.
- Radio: armado con switch, lecciones sin botones (avanzan solas; saltar y elegir desde la pausa requiere teclado).
- Web en itch.io: aviso «Presioná un botón» en la lección 1 y rendimiento del nivel.

## 7. Observaciones abiertas

- En Horizon, cambios bruscos de alabeo a veces superan los 50° y disparan la recuperación. Es ajuste de PID del modo, no del tutorial.
- `Track` crea 5 `Ghost` que nunca libera (fuga conocida), también en `Track_Tutorial`.
- La lección 8 escribe récords y repeticiones de `Track_Tutorial` como cualquier pista.
