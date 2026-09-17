# Editor de pistas y modo Desafíos

Rama `editor-de-pistas`. Este documento explica cómo armar una pista con las herramientas del
editor, cómo se agrega un desafío al juego y cómo probarlo todo.

## 1. Qué ve el jugador

El menú principal tiene cuatro formas de volar:

| Entrada | Escena | Qué es |
|---|---|---|
| **Desafíos** | `sceneries/challenge_level.tscn` | Diez circuitos cronometrados con medallas que se van desbloqueando |
| **Instructor de vuelo** | `sceneries/tutorial_level.tscn` | Las ocho lecciones (ver [tutorial.md](tutorial.md)) |
| **Freestyle** | `sceneries/freestyle_level.tscn` | Vuelo libre sobre el terreno, sin pistas ni cronómetro |
| **Sandbox (debug)** | `sceneries/level1.tscn` | El campo con las nueve pistas MultiGP, oculto |

El Sandbox aparece al teclear **↑ ↑ ↓ ↓ ← → ← →** en el menú principal. Son solo direcciones,
así que la secuencia mueve el foco y nada más; como `StickNavigation` convierte los sticks en
acciones `ui_*`, también sale desde la radio. Queda desbloqueado para siempre en
`[game] sandbox_unlocked`.

### Los diez desafíos

La curva arranca **muy suave y se endurece de a poco**: primero aros grandes en espacios
abiertos, donde lo único que hay que hacer es volar derecho; después curvas amplias, después
velocidad, altura y precisión; y recién sobre el final las puertas angostas de competencia y
la acrobacia. Cada escalón agrega **una sola** dificultad nueva.

| # | Desafío | Qué agrega | Aros / puertas | Vueltas |
|---|---|---|---|---|
| 1 | Cuatro aros en línea | Nada: volar derecho | Aros grandes (6 m de paso) | 1 |
| 2 | Diez aros en círculo | Un giro amplio y constante | Aros grandes | 1 |
| 3 | Óvalo con rectas | Velocidad en la recta, frenar en la curva | Aros medianos (4,6 m) | 2 |
| 4 | Subidas y bajadas | El eje vertical | Aros medianos | 1 |
| 5 | Serpentina | Cambiar de lado, y menos margen | Aros chicos (3,2 m) | 1 |
| 6 | Ida y vuelta | Girar 180° y volver por los mismos aros | Aros medianos | 1 |
| 7 | Slalom de columnas | Pasar al costado de un obstáculo | Columnas | 1 |
| 8 | Puertas de carrera | Las puertas angostas de competencia (2,1 m) | 7x6 altas y bajas | 2 |
| 9 | Figura en ocho | Cruce de trayectoria sostenido | 5x5 | 2 |
| 10 | Picada y Split-S | Picada de 30° e inversión | 7x6 + puerta inclinada | 2 |

Los tres tamaños de aro (`Gate_Torus_Large`, `Gate_Torus` y los medianos, que salen del mismo
`ProceduralGateTorus` con otro radio) son la herramienta principal para graduar la exigencia:
un aro grande perdona casi cualquier trazada, uno chico no.

> **Los tiempos de las medallas son provisionales.** Están puestos a ojo y hay que volar cada
> pista para ajustarlos. Cambiarlos es editar una línea de `challenges/challenge_catalog.gd`.

## 2. Piezas

| Pieza | Archivo | Qué hace |
|---|---|---|
| `ChallengeCatalog` | `challenges/challenge_catalog.gd` | La lista de desafíos, las medallas y el formato de los tiempos. Mismo patrón que `SkyCatalog`. |
| `ChallengeLevel` | `sceneries/challenge_level.gd` | Hereda de `Level`. Carga la pista del desafío elegido, arranca la carrera, guarda la marca y muestra el resultado. |
| Nivel de desafío | `sceneries/challenge_level.tscn` | El terreno, el dron, las cámaras y la radio. **Uno solo para todos los desafíos.** |
| Menú de desafíos | `gui/challenges_menu.gd/.tscn` | Una línea por desafío con su medalla y su mejor marca; abajo, la habilidad y los tiempos objetivo del que tiene el foco. |
| `ChoiceMenu` | `gui/choice_menu.gd` | Menú de opciones armado en código. Lo usan el tutorial, el selector de desafíos y la pantalla de resultado. |
| Progreso | `autoloads/game_settings.gd` | Sección `[challenges]` de `GameSettings.cfg`. |
| Addon | `addons/track_editor/` | Las herramientas del editor (sección 4). |
| Pistas | `tracks/tracks/Track_Challenge_*.tscn` | Una escena `Track` por desafío. |
| Columna | `tracks/gates/Gate_Column.tscn` | Columna con el área de paso a un costado: la pieza del slalom. |
| Aro circular | `tracks/gates/Gate_Torus.tscn` | `ProceduralGateTorus` listo para instanciar. |

## 3. Cómo agregar un desafío

1. **Armá la pista**: escena nueva con un nodo `Node3D` raíz llamado `Track` y el script
   `res://tracks/track.gd`. Guardala en `tracks/tracks/`.
2. Seleccioná el `Track` y usá la barra del editor (sección 4) para agregar la plataforma de
   largada y las puertas. **Siempre hace falta un `Launchpad`**: sin él no hay cuenta regresiva
   ni detección de salida en falso.
3. Apretá **Recorrido → Por orden en el árbol** y revisá el string que quedó en `Course`.
4. Apretá **Verificar** y corregí lo que aparezca en la salida.
5. Agregá la entrada en `ChallengeCatalog.CHALLENGES`, al final de la lista (el orden de la
   lista es el orden en que se desbloquean):

```gdscript
{
    "id": "mi-desafio",                  # no cambia nunca: es la clave del récord guardado
    "name": "CHAL_MI_DESAFIO_NAME",      # clave de traducción
    "goal": "CHAL_MI_DESAFIO_GOAL",      # qué habilidad entrena
    "track": "res://tracks/tracks/Track_Challenge_11_MiDesafio.tscn",
    "laps": 2,
    "gold": 30.0, "silver": 40.0, "bronze": 55.0,
},
```

6. Agregá `CHAL_MI_DESAFIO_NAME` y `CHAL_MI_DESAFIO_GOAL` a `localization/translations.csv`
   (en orden alfabético, español primero) y reimportá:
   `godot --headless --path . --import`.
7. Corré `tools/challenge_check.tscn` (sección 6) y después volalo para ajustar los tiempos.

**El `id` es para siempre**: es la clave con la que se guarda el récord. Si lo cambiás, el
jugador pierde su marca y el desafío vuelve a aparecer bloqueado.

## 4. El addon del editor de pistas

Se activa en Proyecto → Ajustes → Plugins (ya viene activado en `project.godot`). Con una
escena `Track` abierta y el nodo `Track` seleccionado aparece una barra arriba de la vista 3D:

| Botón | Qué hace |
|---|---|
| **Agregar** | Instancia una pieza como hijo directo del `Track`, encadenada delante de la pieza seleccionada sobre su -Z, y la deja seleccionada para moverla con el gizmo de siempre. |
| **Recorrido** | Escribe el campo `Course`: por orden en el árbol, o por cercanía desde la plataforma de largada (agregando solo el sufijo `b` donde hace falta). |
| **Piso** | Apoya la pieza seleccionada sobre el piso (`y = 0`). |
| **Rotación** | Redondea la rotación a 15, 45 o 90 grados. Por defecto solo el giro: los tres ejes arruinarían una puerta inclinada como la de picada. |
| **Verificar** | Revisa la pista e informa los problemas en la salida del editor. |
| **Números** | Muestra u oculta la numeración y el recorrido. |

Sobre cada checkpoint se dibuja **su número** y, debajo, **en qué momentos del recorrido se
cruza** (`#0`, `#7b`…), y el recorrido se traza con líneas: las naranjas son los tramos que se
cruzan al revés. Los checkpoints marcados con `*` todavía no existen (los arma
`ProceduralGate` al arrancar el juego), pero ya ocupan su número.

Todo pasa por el sistema de deshacer del editor: **Ctrl+Z revierte cualquier acción** y la
escena queda marcada como modificada.

### El campo `Course`

Es la lista de checkpoints, por índice, en el orden en que hay que cruzarlos:
`lap_start,0,1,2,5b,6,lap_end`.

- El índice es **el orden de los hijos del `Track`**: mover una puerta en el árbol renumera
  todo. Por eso el addon inserta las piezas nuevas justo después de la seleccionada.
- El sufijo **`b`** significa cruzar la puerta en sentido contrario.
- `lap_start` y `lap_end` marcan qué parte se repite en cada vuelta. Si faltan, `Track` los
  agrega al principio y al final.
- Una puerta triple o doble aporta **varios** checkpoints: el recorrido tiene que nombrar solo
  uno. El auto-recorrido ya toma uno por puerta.

### Cosas a tener en cuenta

- **Abrí la escena de la pista para editarla.** Si seleccionás un `Track` instanciado dentro de
  un nivel, el addon se niega: las piezas se guardarían en el nivel y no en la pista.
- Un `Checkpoint` tiene que colgar del `Track` o de un `Gate` hijo directo. Más profundo, el
  juego lo ignora (y el verificador lo avisa).
- Los avisos de «quizás le falte el sufijo b» comparan la línea recta entre dos puertas contra
  el frente de la segunda. En circuitos con curvas cerradas puede equivocarse; las puertas muy
  inclinadas se saltean porque ahí la línea recta no dice nada.
- Los scripts del addon **no declaran `class_name` y quedan fuera del export web**: las clases
  `Editor*` no existen en el template de release y romperían la publicación.
- Los textos de la barra están escritos en español dentro del código, no en el CSV: adentro del
  editor `tr()` resuelve contra las traducciones del propio editor, no contra las del juego.

## 5. Persistencia

`user://config/GameSettings.cfg`, sección `[challenges]`, una clave por desafío terminado:

```ini
[challenges]
best_gate-and-back=23.41
best_slalom=31.08
```

- **El mejor tiempo en segundos es el único dato guardado.** El desbloqueo y la medalla se
  deducen de ahí, así que no hay dos estados que puedan contradecirse.
- API en `GameSettings`: `load_challenge_progress`, `save_challenge_progress`, `get_best_time`,
  `record_time` (devuelve si es récord), `is_challenge_unlocked`, `get_challenge_medal`,
  `get_finished_challenge_count`, `get_first_unfinished_challenge`, `reset_challenge_progress`.
- El sandbox desbloqueado va aparte, en `[game] sandbox_unlocked`.
- Los récords y las repeticiones de `Track` (`user://highscores.sav` y `user://replays/`) se
  siguen escribiendo como en cualquier pista: de ahí salen los fantasmas.

## 6. Pruebas por línea de comandos

Binario: `C:/Users/Mauri/Godot/Godot_4.7/Godot_v4.7-stable_win64_console.exe`.

```
godot --headless --path . res://tools/track_check.tscn
godot --headless --path . res://tools/challenge_check.tscn
godot --path . --windowed --resolution 1280x720 res://tools/ui_smoke_test.tscn
```

- **`track_check`** revisa las veinte pistas y las doce piezas de la paleta con el mismo
  código que el botón Verificar, y comprueba que la numeración que muestra el editor sea la
  misma que arma el juego. También **dibuja el overlay fuera del editor**, con una pista y una
  cámara de verdad, para que un error en el código de dibujo salte acá y no al seleccionar un
  `Track`. Los avisos de las pistas MultiGP heredadas son previos y no fallan.
- **`challenge_check`** revisa el catálogo, los bordes exactos de cada medalla, la regla de
  desbloqueo y que los diez desafíos carguen y arranquen la cuenta regresiva. Además **corre
  un desafío entero sin volarlo**, marcando los checkpoints en el orden del recorrido: así
  quedan probadas las vueltas, la llegada, el tiempo guardado y el desbloqueo del siguiente.
  Con `-- --shots=<carpeta>` y sin `--headless` guarda una foto de cada pista desde arriba.
- **`ui_smoke_test`** recorre el menú, entra a Desafíos y prueba la secuencia del sandbox.

Ninguno deja tocada la configuración del jugador: lo que cambian lo restauran al terminar.

### Pendiente de probar con hardware

- Volar los diez desafíos con la radio y **ajustar los tiempos de las medallas**, que hoy son
  estimaciones sin volar.
- La secuencia del sandbox con los sticks de la radio (con teclado ya está probada).
- El desafío 10: que la picada sea alcanzable y que la puerta inclinada se cruce bajando.
- La versión web en itch.io: que el addon quede afuera del paquete y que los niveles carguen.

## 7. Decisiones y desvíos

- **Un solo nivel de desafío** en vez de una escena por desafío: agregar uno es escribir la
  pista y una línea del catálogo, sin duplicar terreno, dron ni cámaras.
- **El desbloqueo no se guarda**, se deduce del mejor tiempo del desafío anterior.
- **La curva de dificultad se rehizo empezando por aros**: la primera versión arrancaba con
  puertas MultiGP de 2,1 m de paso y columnas, que ya es nivel intermedio. Ahora los primeros
  cinco desafíos son de aros en espacios abiertos y las puertas angostas aparecen recién en el
  octavo, agregando una dificultad nueva por escalón.
- **Herramientas en el editor de Godot, no un editor dentro del juego**: el proyecto ya tenía
  las piezas y el motor de carreras; lo que faltaba era ver los números de los checkpoints y
  no escribir el `Course` a mano.
- **`ProceduralGate` y sus hijas pasaron a `@tool`**: antes un aro circular era un nodo vacío
  en el editor y había que ubicarlo a ciegas. De paso se corrigieron sus `CSGBox3D` y sus
  `BoxShape3D`, que seguían usando la API de Godot 3.
- La numeración se dibuja **sobre la vista 3D** y no con un gizmo, porque un gizmo no puede
  dibujar texto.
- `tutorial/tutorial_menu.gd` pasó a `gui/choice_menu.gd` (`ChoiceMenu`): ya era genérico y
  solo tenía nombre de tutorial.

## 8. Observaciones abiertas

- `Track` crea 5 `Ghost` que nunca libera (fuga conocida, ver [tutorial.md](tutorial.md)).
  Entrar y salir de desafíos repetidamente los acumula.
- `drone.gd` busca el nodo `Respawn` con `get_tree().root.get_children()[-1]`: cualquier nodo
  agregado al root después del nivel rompe la reaparición. Por eso las pantallas del desafío
  van dentro del nivel.
- El menú de desafíos no muestra el fantasma ni la repetición de la mejor vuelta, aunque el
  juego las guarda.
