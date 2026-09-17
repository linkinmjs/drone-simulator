# Editor de pistas

Addon de Godot para armar circuitos de carrera sin escribir a mano el recorrido. Vive en
`addons/track_editor/` y ya viene activado en `project.godot`. Los desafíos que usan estas
pistas están documentados aparte, en [desafios.md](desafios.md).

## 1. Para qué existe

Una pista es una escena `Track` con puertas adentro. Dos cosas la hacían incómoda de armar:

- **El número de cada checkpoint es el orden de los hijos en el árbol**, y no se ve por ningún
  lado. Había que contar nodos en el panel de escena para saber cuál era el 7.
- **El recorrido se escribe a mano** en el campo `Course`, con una lista de índices como
  `lap_start,0,1,2,5b,6,lap_end`. Los circuitos heredados tienen cadenas de cincuenta tokens
  que nadie puede leer ni corregir con confianza.

El addon dibuja los números sobre la vista 3D, traza el recorrido, genera el `Course` solo y
avisa de los errores antes de que aparezcan volando.

## 2. Armar una pista, de cero

1. **Escena nueva** → nodo raíz `Node3D`, renombralo `Track` y asignale el script
   `res://tracks/track.gd`. Guardala en `tracks/tracks/`.
2. Seleccioná el nodo `Track`. Arriba de la vista 3D aparece la barra del editor.
3. **Agregar → Plataforma de largada.** Va primero: sin ella no hay cuenta regresiva ni
   detección de salida en falso, y el dron no sabe dónde nacer.
4. **Agregar → el aro o la puerta que quieras.** Cada pieza se instancia encadenada delante de
   la que tengas seleccionada, a lo largo de su -Z, y queda seleccionada para que la muevas
   con el gizmo de siempre. Si no hay nada seleccionado, se engancha al último hijo.
5. Repetí. Para insertar una pieza en el medio, seleccioná la que va antes: la nueva entra
   justo después de ella en el árbol, así la numeración sigue el orden del circuito.
6. **Recorrido → Por orden en el árbol.** Mirá el `Course` que quedó en el inspector.
7. **Verificar.** Corregí lo que aparezca en la salida del editor.
8. Probala con F6.

Todo lo que hace la barra pasa por el historial del editor: **Ctrl+Z deshace cualquier paso** y
la escena queda marcada como modificada.

## 3. La barra

| Botón | Qué hace |
|---|---|
| **Agregar** | Instancia una pieza como hijo directo del `Track`, encadenada delante de la seleccionada. |
| **Recorrido** | Escribe el `Course`. *Por orden en el árbol* sigue el orden de los hijos; *por cercanía desde la largada* encadena el más próximo cada vez y agrega el sufijo `b` donde corresponde. |
| **Piso** | Baja la pieza seleccionada hasta apoyarla en `y = 0`. Sirve para varias a la vez. |
| **Rotación** | Redondea la rotación a 15, 45 o 90 grados. Por defecto **solo el giro**; la opción de los tres ejes está aparte porque aplanaría una puerta inclinada a propósito. |
| **Verificar** | Revisa la pista e imprime los problemas. |
| **Números** | Muestra u oculta la numeración y el trazado. |

### Lo que se dibuja sobre la vista 3D

- El **número de cada checkpoint**, que es el que va en el `Course`.
- Debajo, **en qué momentos del recorrido se cruza**: `#0`, `#7b`… Una puerta que se pasa dos
  veces muestra las dos.
- Las **líneas del recorrido**, en orden. Las naranjas son los tramos que se cruzan al revés.
- Un `*` después del número marca un checkpoint que **todavía no existe**: lo arma
  `ProceduralGate` al arrancar el juego, pero ya ocupa su lugar en la numeración.
- El checkpoint que elijas en `selected_checkpoint` se pinta en amarillo.

Los números se redibujan cuando movés la cámara o una pieza. Si no ves nada, fijate que el
`Track` (o algo adentro) esté seleccionado y que el interruptor **Números** esté encendido.

## 4. Las piezas de la paleta

| Pieza | Escena | Paso libre | Para qué |
|---|---|---|---|
| Aro 7x6 | `gates/Gate_7x6_Simple.tscn` | 2,1 × 1,8 m | La puerta estándar de competencia |
| Aro 7x6 doble | `gates/Gate_7x6_Double.tscn` | dos huecos | Se elige por cuál pasar |
| Aro 5x5 | `gates/Gate_5x5_Simple.tscn` | 1,5 × 1,5 m | Más chica que la anterior |
| Aro 5x5 triple | `gates/Gate_5x5_Triple.tscn` | tres huecos | Aporta **tres** checkpoints |
| Aro con picada 30° | `gates/Gate_7x6_Dive_30deg.tscn` | inclinada | Se cruza bajando |
| Aro circular grande | `gates/Gate_Torus_Large.tscn` | 6 m | Los primeros desafíos |
| Aro circular chico | `gates/Gate_Torus.tscn` | 3,2 m | Precisión |
| Valla 10x5 | `gates/Gate_Hurdle_10x5.tscn` | por arriba | Obliga a subir |
| Columna con paso lateral | `gates/Gate_Column.tscn` | 4,4 m al costado | Slalom |
| Plataforma de largada | `objects/Launchpad.tscn` | — | Obligatoria |
| Banderín | `objects/Flag.tscn` | — | Decoración y referencia visual |
| Conos en flecha | `objects/ConePattern_Arrow1.tscn` | — | Marca la dirección |

Los aros circulares son `ProceduralGateTorus`: el tamaño sale de `inner_radius` y
`outer_radius` en el inspector, así que con la misma escena tenés todos los diámetros que
quieras. Es la forma más directa de graduar la dificultad de un circuito.

**Una puerta puede aportar más de un checkpoint.** La triple aporta tres y la doble dos: el
recorrido tiene que nombrar solo uno de ellos. El auto-recorrido ya toma uno por puerta.

### Agregar una pieza a la paleta

Una entrada en `const PIECES` de `addons/track_editor/track_pieces.gd`:

```gdscript
{
    "id": &"mi_pieza",
    "label": "Mi pieza",                      # en español, va al menú del editor
    "path": "res://tracks/gates/Mi_Pieza.tscn",
    "offset": 12.0,                           # cuánto se adelanta al encadenarla
    "gate": true,                             # true si trae Checkpoint
},
```

Para que la pista la cuente, la escena tiene que tener **un nodo raíz con `tracks/gate.gd`**
(`class_name Gate`) y **un `Area3D` con `tracks/checkpoint.gd`** como hijo directo. Nada más:
`Track` la encuentra sola. `tools/track_check` verifica que todas las piezas de la paleta
carguen y aporten checkpoint.

## 5. El campo `Course`

La lista de checkpoints, por índice, en el orden en que hay que cruzarlos:

```
lap_start,0,1,2,5b,6,lap_end
```

- El **índice** es el orden de los hijos del `Track`. Mover una puerta en el árbol renumera
  todo, por eso el addon inserta las piezas nuevas justo después de la seleccionada.
- El sufijo **`b`** significa cruzarla en sentido contrario. Sin él, pasar al revés no cuenta.
- **`lap_start` y `lap_end`** marcan el tramo que se repite en cada vuelta. Lo de afuera se
  vuela una sola vez: sirve para salir de la plataforma y entrar al circuito. Si faltan,
  `Track` los pone al principio y al final.
- Vacío significa "todos, en orden".

La dirección en que se cruza una puerta es su **-Z**. Si el recorrido entra por atrás y no
pusiste `b`, el checkpoint no se activa y la carrera se queda esperando ahí.

## 6. El verificador

**Verificar** imprime en la salida del editor lo que el juego no te va a perdonar:

| Nivel | Qué encuentra |
|---|---|
| Error | No hay plataforma de largada, o no tiene ninguna `LaunchArea` |
| Error | El recorrido apunta a un checkpoint que no existe |
| Error | Un `Gate` sin ningún `Checkpoint` (los procedurales quedan exentos) |
| Error | Dos checkpoints distintos en el mismo lugar |
| Aviso | Un `Checkpoint` colgado demasiado profundo: el juego lo ignora |
| Aviso | Checkpoints por los que el recorrido nunca pasa |
| Aviso | Tramos de menos de 3 m o de más de 80 m |
| Aviso | A una puerta se llega por atrás y no tiene `b`, o al revés |
| Info | Cantidad de tramos, distancia total, el más corto y el más largo |

El aviso de `b` compara la línea recta entre dos puertas contra el frente de la segunda: en
curvas cerradas puede equivocarse, y las puertas muy inclinadas se saltean porque ahí la línea
recta no dice nada. **Es una sugerencia, no una sentencia.**

La misma lógica corre sin abrir el editor:

```
godot --headless --path . res://tools/track_check.tscn
```

Revisa todas las pistas de `tracks/tracks/` y todas las piezas de la paleta, y comprueba que
la numeración que muestra el editor sea la misma que arma el juego al correr.

## 7. Cosas a tener en cuenta

- **Abrí la escena de la pista para editarla.** Si seleccionás un `Track` instanciado dentro de
  un nivel (como los del sandbox), el addon se niega: las piezas se guardarían en el nivel y no
  en la pista.
- Un `Checkpoint` tiene que colgar del `Track` o de un `Gate` que sea hijo directo. Más
  profundo, el juego no lo ve.
- **El piso no existe en la escena de la pista**: vive en el nivel. Por eso "Piso" apoya en
  `y = 0` en vez de tirar un rayo hacia abajo.
- Las puertas **procedurales** arman su geometría en `_ready()`. Son `@tool`, así que se ven en
  el editor, pero si tocás un parámetro y algo queda raro, cerrá y reabrí la escena.
- Los textos de la barra están **en español dentro del código**, no en el CSV de traducciones:
  adentro del editor, `tr()` resuelve contra las traducciones del propio editor.

## 8. Cómo está hecho

| Archivo | Responsabilidad |
|---|---|
| `track_editor_plugin.gd` | El `EditorPlugin`: ciclo de vida, qué nodo se está editando, el dibujo sobre el viewport y el cableado de la barra. |
| `track_editor_bar.gd` | La barra. Solo emite señales. |
| `track_graph.gd` | **Lógica pura**: numerar los checkpoints, leer y escribir el `Course`, calcular distancias. Sin nada del editor, por eso la reusa `tools/track_check`. |
| `track_editor_actions.gd` | Todo lo que modifica la escena, siempre con `EditorUndoRedoManager`. |
| `track_editor_overlay.gd` | El dibujo de números, etiquetas y líneas. |
| `track_validator.gd` | Los chequeos del botón Verificar. |
| `track_pieces.gd` | La tabla de piezas de la paleta. |

Dos reglas que conviene no romper si lo tocás:

- **Ningún script del addon declara `class_name`.** Los nombres de clase se registran global y
  permanentemente, y un build exportado intentaría cargar clases `Editor*` que no existen en el
  template de release: rompería la publicación web. Se usa `preload()` en su lugar, y
  `addons/*` está excluido del preset Web en `export_presets.cfg`.
- **Todo cambio de escena pasa por `EditorUndoRedoManager`**, y su `add_do_method()` recibe
  `(objeto, &"metodo", args…)`, no un `Callable` como el `UndoRedo` común.

El código de dibujo se prueba fuera del editor: `tools/overlay_probe.gd` lo pinta en un
`Control` normal para que `track_check` lo ejercite con una pista y una cámara de verdad.

## 9. Lo que todavía no tiene

- No se puede arrastrar un checkpoint desde su etiqueta ni reordenar el recorrido con el mouse.
- El auto-recorrido por cercanía es una heurística codiciosa: en circuitos que se cruzan a sí
  mismos hay que corregirlo a mano.
- Las líneas del recorrido se dibujan por encima de la geometría, sin oclusión.
- No hay vista previa del tiempo de vuelta ni de la trazada ideal.
