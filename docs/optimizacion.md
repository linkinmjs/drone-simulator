# Diagnóstico de rendimiento

Fecha: 16 de septiembre de 2026. Commit medido: `d31681d`. Godot 4.7 stable.

Máquina de prueba: Intel Core i7-12700KF, NVIDIA GeForce RTX 3060, 32 GB de RAM, Windows 10. Todas las cifras son de esta máquina a 1920×1080 y sirven como referencia relativa; en el navegador (exportación Web) hay que asumir CPU dos o tres veces más lenta para GDScript y un solo hilo para física, audio y render.

## Resumen

- El render y la física están holgados en escritorio: 172 fps con el ojo de pez completo y física al 14 % de un núcleo volando.
- Lo que pesa no son los scripts por frame sino dos cosas: los 218 `Area3D` de checkpoints que monitorean colisiones en cada tick, y las cinco vistas del ojo de pez.
- Para la versión web conviene bajar el ojo de pez a Fast y aligerar la física, porque ahí el margen se reduce mucho.

## Método

Todas las mediciones se hicieron con escenas de chequeo lanzadas por línea de comandos, sin el editor:

```
Godot_v4.7-stable_win64_console.exe --path . --windowed --resolution 960x540 --quit-after N <escena_de_chequeo.tscn>
```

Para el renderizador de la versión web se agrega `--rendering-method gl_compatibility`. La escena de chequeo instancia `res://sceneries/level1.tscn` como hija y mide desde `_ready`.

Técnicas usadas:

- **Render**: `RenderingServer.viewport_set_measure_render_time(rid, true)` y luego `viewport_get_measured_render_time_gpu(rid)` sobre el viewport raíz y sobre cada SubViewport del ojo de pez. Draw calls, objetos y triángulos con `Performance.get_monitor`. Vsync desactivado y `Engine.max_fps = 0`. Promedio de 300 frames tras 180 de calentamiento.
- **Física**: con `RenderingServer.render_loop_enabled = false` y `Engine.physics_ticks_per_second = 5000` más `Engine.max_physics_steps_per_frame = 1000` el bucle queda limitado por la física, y el tiempo de pared dividido por `Engine.get_physics_frames()` da el costo real de un tick. Luego se desactivan partes (scripts, áreas, cuerpos, `PhysicsServer3D.set_active(false)`) para bisecar.
- **Funciones calientes**: cronómetro con `Time.get_ticks_usec()` alrededor de 5000 a 20000 llamadas directas.
- **Armado en las pruebas**: con `Input.action_press("throttle_down", 1.0)`, esperar un tick, emitir `arm_input` del `RadioController`, y después `Input.action_press("throttle_up", 0.25)` para que el dron flote.

Advertencia: los monitores `Performance.TIME_PROCESS` y `TIME_PHYSICS_PROCESS` devuelven el máximo del último segundo, no un promedio. No sirven para medir costos típicos.

## Resultados

### Render (Forward+, 1920×1080)

| Métrica | Fisheye Full | Fisheye Fast | Fisheye Off |
|---|---|---|---|
| Tiempo de frame | 5.8 ms (172 fps) | 3.3 ms (305 fps) | 3.0 ms (335 fps) |
| GPU del viewport raíz | 0.9 ms | 0.8 ms | 2.5 ms |
| GPU de los SubViewports | 4.4 ms | 1.9 ms | 0 |
| Draw calls | 1313 | 887 | 303 |
| Objetos dibujados | 1721 | 1292 | 401 |
| Triángulos por frame | 2.1 M | 1.4 M | 0.5 M |
| VRAM total | 472 MB | 344 MB | 265 MB |
| VRAM de texturas | 370 MB | 273 MB | 207 MB |

Compatibility (el renderizador de la versión web) en la misma máquina: Full 3.9 ms con picos de 13 ms y 1707 draw calls; Off 1.5 ms. VRAM 192 MB en Full.

### Física (100 Hz, Jolt)

| Estado | ms por tick | Equivalente por frame a 60 fps |
|---|---|---|
| Dron desarmado en el suelo | 0.71 | 1.2 ms |
| Dron armado flotando | 1.42 | 2.4 ms |

Desglose del tick desarmado (bisección):

| Componente | ms por tick |
|---|---|
| 218 `Area3D` con `monitoring` activo (checkpoints, zonas de despegue) | 0.39 |
| Cuerpo del dron con su integrador (1 subpaso) | 0.21 |
| Sobrecarga del bucle sin servidor de física | 0.10 |
| Todos los scripts con `_physics_process` (174 checkpoints, motores, radio, etc.) | 0.02 |
| Los 5 `RayCast3D` | 0.00 |

Con solo los 25 checkpoints de una pista monitoreando el tick baja de 0.71 a 0.35 ms.

Al armar, `_integrate_forces` pasa de 1 a 10 subpasos y agrega 0.70 ms por tick. Costos de sus funciones:

| Función | µs por llamada | Llamadas por tick armado |
|---|---|---|
| `FlightController.integrate_loop` (armado) | 16.5 | 10 |
| `FlightController.integrate_loop` (desarmado) | 1.2 | 1 |
| `Propeller.update_forces` | 2.3 | 40 |
| `Motor.update_thrust` | 0.45 | 40 |
| `Motor.update_sound` | 4.7 | 4 |
| Cadena de replay en `Drone._physics_process` | 8.4 | 1 |
| `HUD.update_data` (por frame) | 0.9 | 1 |

### Otros datos

- Scripts de `_process` de todo el nivel: 0.09 ms por frame.
- Escena: 3618 nodos, 2042 `CollisionShape3D`, 142 `StaticBody3D`, 218 `Area3D` (todas en capa 1 y máscara 1), 409 `MeshInstance3D`, 76 `MultiMeshInstance3D`, 18 `CSGTorus3D`, 32 `AudioStreamPlayer`.
- 45 nodos huérfanos al salir: cada pista crea 5 `Ghost` en `Track._ready` que nunca entran al árbol ni se liberan.
- Solo 3 objetos de pista tienen LOD (`Flag`, `Gate_Dive_7x6_30deg`, `Gate_Launch_7x6`).
- Carga: `level1.tscn` tarda 435 ms en cargar, 90 ms en `_ready` y 250 ms en los dos primeros frames; el menú principal 163 ms. Assets 10 MB, recursos importados 13 MB.

## Recomendaciones por orden de impacto

1. **Monitorear solo los checkpoints necesarios.** Ahorra 0.39 ms por tick, más de la mitad del tick desarmado. Opciones: activar `monitoring` solo en la pista activa o en las áreas cercanas al dron, o invertir la detección con un `Area3D` en el dron y checkpoints solo `monitorable`. Además, mover los checkpoints a una capa propia con máscara limitada a la capa del dron. Archivos: `tracks/checkpoint.gd`, `tracks/launch_area.gd`, `sceneries/level.gd`. Riesgo bajo; hay que conservar el respaldo por raycast para pasadas a alta velocidad.

2. **Ojo de pez Fast por defecto en web.** GPU de 4.4 a 1.9 ms, 130 MB menos de VRAM, 5 vistas a 2. Aplicar en `autoloads/graphics.gd` cuando `OS.has_feature("web")` y no exista configuración guardada. Escritorio queda en Full.

3. **Aligerar `_integrate_forces` sin cambiar el modelo.** En cada subpaso se consultan dos `global_transform` por motor y se recalculan transformadas constantes (`prop_local_pos`, `prop_xform`); `get_drag` y `update_forces` crean arrays por llamada. Sacar eso del bucle debería recortar entre 20 y 30 % de los 0.70 ms. Bajar de 10 a 5 subpasos reduciría a la mitad, pero cambia la fidelidad de la integración: dejarlo como opción solo para web. Archivos: `drone/drone.gd`, `drone/propeller.gd`.

4. **No formatear la cadena de replay en cada tick.** `Drone._physics_process` arma y emite un `String` 100 veces por segundo aunque no se esté grabando. Emitir la `Transform3D` y formatear solo al grabar. Archivo: `drone/drone.gd`, `tracks/track.gd`.

5. **Reproducir solo los sonidos de motor activos.** Hay 8 reproductores por motor y los 32 suenan a la vez, 24 de ellos a -80 dB. Con dos por motor alcanza. En web el mezclado corre en el hilo principal. Archivo: `drone/motor.gd`.

6. **Liberar los `Ghost` huérfanos.** Fuga de 45 nodos por partida. Archivo: `tracks/track.gd`.

7. **Geometría de las puertas.** 526 mil triángulos por vista sin LOD y 18 `CSGTorus3D` que no admiten LOD. Convertir los toros a mallas y generar LOD al importar. Solo vale la pena para GPUs integradas.

## Lo que no conviene tocar

- La tasa de física de 100 Hz es adecuada para un simulador de vuelo.
- Los scripts de `_process`, el HUD y los `_physics_process` de los checkpoints son despreciables.
- Los draw calls en Forward+ están dentro de lo normal para escritorio.
- La carga del nivel tarda menos de un segundo.

## Consideraciones para la versión web

- No hay hilos: física, audio y envío de comandos de render comparten el hilo principal.
- GDScript en wasm corre dos o tres veces más lento, así que la física armada puede llevarse 5 ms de los 16 ms del frame antes de cualquier mejora.
- El renderizador es Compatibility. `Graphics.apply_compatibility_workarounds` apaga la exposición automática y sube la exposición 1.4 veces. El cielo ya no es el físico de Godot sino el shader de `sceneries/skies/` (ver `sceneries/skies/README.md`). `SkyCatalog.apply()` usa en Compatibility la mitad de los lux del sol (`COMPATIBILITY_SUN_MULTIPLIER`), porque la exposición extra quemaba el suelo iluminado, y 1.15 veces la energía del cielo (`COMPATIBILITY_SKY_MULTIPLIER`). Noche usa su propio `compat_sky_energy` (1.8), porque en las cámaras del ojo de pez solo el cielo ilumina lo que está en sombra.
- El shader de cielo de procedural tenía `clamp(0.0, 1.0, x)` con los argumentos en otro orden. En WebGL eso deja el brillo del sol en 1 en todo el cielo (amarillo o quemado). Si se trae otro shader, revisar que no dependa de comportamientos indefinidos de GLSL.
- Costo del cielo nuevo (nubes animadas con `TIME`), `render_parity_check --bench --sky=clear-day` a 1280×720 con el ojo de pez a 720p, comparado con el cielo anterior: Forward+ Full 5.46 → 4.79 ms, Off 2.42 → 2.65 ms; Compatibility Full 4.29 → 4.85 ms, Off 3.30 → 3.54 ms. Si en la web molesta el medio milisegundo de Full, la salida es una variante del shader sin `TIME` (nubes quietas) solo para Compatibility.
- Luz ambiente en Compatibility: las cámaras del ojo de pez (SubViewports) ignoran `AMBIENT_SOURCE_COLOR` y dibujan negro todo lo que queda en sombra, y `ambient_light_energy` no cambia nada con ambiente de cielo. No usarlos para calibrar.
- El suelo usaba un VisualShader con *instance uniforms* y un *global uniform* de textura. En Compatibility de escritorio funcionaba, pero en WebGL se dibujaba negro y espejado. Ahora `Assets/grid_material.tres` es un `StandardMaterial3D` triplanar en coordenadas de mundo (una textura cada 4 m) que se ve igual en los dos renderizadores.
- Ojo de pez: las texturas de las SubViewports se muestrean con `filter_linear, repeat_disable`. En Fast, las esquinas de la pantalla quedan fuera de los 160° de la cámara lateral: la UV se recorta al borde en vez de repetir la imagen (el efecto espejo).
- Por defecto en web el ojo de pez es **Full a 480p** (mismo lente que en escritorio, sin costura entre cámaras). En Compatibility, a 1920×1080 en la máquina de prueba: Full 480p 4.0 ms por frame, Full 720p 4.2 ms, Fast 720p 3.0 ms, Off 3.4 ms. Manda la cantidad de draw calls, no la resolución. `Graphics.WEB_DEFAULTS_REVISION` aplica estos valores una vez sobre la configuración que el navegador ya tenía guardada.
- Para probar localmente sin exportar, usar `--rendering-method gl_compatibility`. `tools/render_parity_check.tscn` guarda capturas y luminancia de cada modo de ojo de pez para comparar los dos renderizadores (`--mode`, `--fisheye-res`, `--sky`, `--bench`). `tools/sky_check.tscn` hace lo mismo para los cuatro cielos.

## Seguimiento

- [ ] Checkpoints con monitoreo selectivo y capa propia
- [x] Ojo de pez por defecto en web (se eligió Full a 480p por paridad visual)
- [ ] Bucle de vuelo sin consultas ni arrays repetidos
- [ ] Cadena de replay solo al grabar
- [ ] Dos reproductores de sonido por motor
- [ ] Liberar los `Ghost` huérfanos
- [ ] LOD y mallas para las puertas
