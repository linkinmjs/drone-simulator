# Análisis y oportunidades de mejora del simulador de drones

Fecha: 16 de septiembre de 2026.

La recomendación principal es convertir la base técnica existente en una experiencia de aprendizaje y carreras fácil de iniciar, consistente y capaz de mostrar progreso. Antes de ampliar mucho los escenarios o incorporar multijugador, conviene resolver la entrada de controles, validar el comportamiento físico y mejorar la selección y devolución de las carreras.

Este informe combina investigación de simuladores FPV con revisión estática del proyecto. No se ejecutó el juego, no se midieron FPS o latencia y no se realizaron pruebas con una radio. Por eso se distinguen hechos observados en archivos, riesgos que requieren reproducción y propuestas de diseño. Las descripciones comerciales de otros simuladores acreditan funciones anunciadas, no superioridad física demostrada. No se modificó el juego ni se realizaron commits.

## 1. Referencias y aprendizajes aplicables

Se eligieron cuatro referencias que representan carreras, personalización, exploración y una propuesta más acotada. La comparación se concentra en FPV recreativo y deportivo, acorde con los modos y circuitos del proyecto; no busca evaluar simulación industrial o entrenamiento de navegación autónoma.

| Referencia | Información publicada | Aplicación posible a nuestro proyecto |
| --- | --- | --- |
| VelociDrone | Su manual documenta calibración, adaptación del acelerador para gamepad, indicación de la siguiente puerta, contrarreloj, rankings, modo Nemesis, editor de pistas y ajustes de vuelo. | Reducir fricción con el mando y hacer que cada intento entregue información útil. El proyecto ya cuenta con carreras y fantasmas sobre los que construir. |
| Liftoff: FPV Drone Racing | La actualización 1.7.0 anuncia Physics 6.0, viento, límites físicos del hardware y efectos de lente. | Priorizar coherencia entre sistemas de vuelo y validar cambios físicos; incorporar efectos ambientales después de contar con una referencia estable. |
| TRYP FPV | La ficha del desarrollador presenta escenarios amplios, carreras, desafíos y seguimiento de sujetos como motos o wingsuits. | Dar objetivos al vuelo libre mediante desafíos pequeños y variados; no es necesario comenzar con mapas enormes. |
| FPV Freerider | Su página ofrece modos autoestabilizado y Acro, y una demo con un escenario para probar compatibilidad. | Una experiencia limitada en contenido puede ser útil si permite configurar el control y empezar a practicar rápidamente. |

Fuentes directas: [manual de VelociDrone](https://www.velocidrone.com/desktop_manual), [Liftoff 1.7.0](https://www.liftoff-game.com/news/milestone-170-released), [TRYP FPV, ficha del desarrollador en Steam](https://store.steampowered.com/app/1881200/TRYP_FPV_Drone_Racer_Simulator/) y [FPV Freerider en itch.io](https://fpv-freerider.itch.io/fpv-freerider). Consultadas el 16/09/2026. No se utilizaron precios, opiniones de usuarios ni promesas futuras como criterios de prioridad.

La inferencia de diseño es que el valor del simulador surge de la combinación de control predecible, práctica accesible y devolución sobre lo realizado. La cantidad de funciones, por sí sola, no garantiza ninguna de esas tres cosas.

## 2. Qué tenemos y conviene aprovechar

| Área | Evidencia del repositorio | Lectura |
| --- | --- | --- |
| Física | [drone.gd](drone/drone.gd), [propeller.gd](drone/propeller.gd), [motor.gd](drone/motor.gd) | Hay empuje y resistencia por hélice, efecto suelo, respuesta gradual de RPM y resistencia del cuerpo. La oportunidad es validar y completar su integración. |
| Control de vuelo | [flight_controller.gd](drone/flight_controller/flight_controller.gd), [modos](drone/flight_controller/flight_mode), [control_profile.gd](drone/control_profile.gd) | Existen PID, Acro, Horizon y modos asistidos, además de curvas Actual, Raceflight, Kiss y Quickrates. No hace falta empezar desde cero. |
| Configuración | [controls.gd](autoloads/controls.gd), [calibration_menu.gd](gui/options_menu/controls_menu/calibration_menu.gd), [quad_settings.gd](autoloads/quad_settings.gd) | Hay asignación de ejes, inversión, configuración por GUID, masas, inclinación de cámara y rates. |
| Carreras | [track.gd](tracks/track.gd), [checkpoint.gd](tracks/checkpoint.gd), [ghost.gd](drone/ghost.gd) | Existen vueltas, cuenta regresiva, checkpoints, récords locales y fantasmas de registros anteriores. Proponer estas funciones como ausentes sería incorrecto. |
| Contenido | [level1.tscn](sceneries/level1.tscn), [circuitos](tracks/tracks) | Hay un escenario principal con varios circuitos, incluidos trazados MultiGP y entrenamiento. Un escenario no equivale a una sola pista. |
| Presentación | [cámara FPV](drone/fpv_camera/fpv_camera.gd), [HUD](hud/hud.gd), [graphics.gd](autoloads/graphics.gd) | Hay ojo de pez completo y rápido, HUD configurable y tratamiento de Compatibility. |
| Diagnóstico y distribución | [controlador](drone/flight_controller/flight_controller.gd), [telemetry.py](telemetry/telemetry.py), [workflow](.github/workflows/deploy-to-itch.yml) | Existe telemetría opcional y automatización de importación/exportación Web. La publicación está restringida a pushes a master. |

## 3. Mejoras recomendadas y justificación

### 3.1. Hacer confiable el recorrido desde conectar el mando hasta despegar

**Prioridad P0.** Es una dependencia del resto de la experiencia: si el jugador no logra volar, no llega a aprovechar la simulación.

**Evidencia.** En `calibration_menu.gd`, `_process()` consulta los índices 0 a 3, aunque la detección guarda los ejes realmente movidos en `axes`. Los pasos requieren superar 0,9 y volver cerca del centro; `save_input_map()` guarda asignación e inversión, sin una calibración persistida de mínimos, máximos y centro. Esto presenta riesgos para dispositivos con otro orden de canales o recorridos menores. En `controls.gd`, `load_input_map()` utiliza la posición del GUID en una lista como dispositivo, aunque los identificadores conectados no necesariamente coinciden con esas posiciones.

Además, `radio_controller.gd` transforma el acelerador con `(eje + 1) / 2`: un stick centrado representa 50 %. El menú ofrece acciones de modos específicos, pero el controlador conserva un `TODO` para otras acciones y manejadores comentados. No todas las opciones configurables tienen un recorrido funcional evidente.

**Propuesta.** Usar los identificadores reales de dispositivos y ejes; medir extremos y centro; normalizar recorrido; filtrar entradas del dispositivo seleccionado; permitir repetir pasos. Diferenciar presets de radio y gamepad, haciendo explícito el comportamiento del acelerador. Completar o retirar de la interfaz las acciones sin implementación. Conservar perfiles existentes mediante migración y valores por defecto.

**Justificación.** Reduce configuraciones aparentemente exitosas que luego no permiten controlar el dron. El manual de VelociDrone documenta una adaptación específica del acelerador para gamepad: confirma que esta diferencia merece tratamiento explícito, no que debamos copiar exactamente su implementación.

**Aceptación.** Probar radio y gamepad, ejes fuera de 0–3, recorridos incompletos, dos dispositivos simultáneos y reconexión. El dispositivo equivocado no debe activar acciones; la configuración debe sobrevivir al reinicio; todas las acciones ofrecidas deben funcionar. Son casos propuestos, todavía no ejecutados.

### 3.2. Incorporar una primera sesión guiada y opcional

**Prioridad P1.** Aprovecha los modos existentes y ayuda a ampliar el público.

**Evidencia.** [main_menu.gd](gui/main_menu.gd) abre directamente `level1.tscn`; [help_page.gd](gui/help_page.gd) explica controles mediante texto en inglés. El controlador inicia en Acro. No se identificó una secuencia de lecciones interactivas en los archivos revisados.

**Propuesta.** Ofrecer «Aprender», «Vuelo libre» y «Carreras». La ruta inicial debería verificar el mando, explicar el armado, practicar despegue y altura, cruzar una puerta y completar un circuito sencillo. Presentar los modos asistidos como ayudas del simulador y explicar la transición a Acro. Permitir omitirla y repetir ejercicios.

**Justificación.** Un texto que describe el armado no comprueba que el jugador pueda realizarlo. Un ejercicio con respuesta inmediata permite identificar si el problema está en la configuración, el acelerador o la interpretación del movimiento. Localizar al español instrucciones, errores y acciones prioritarias haría coherente la experiencia para el público de este proyecto.

**Aceptación.** En una sesión observada, registrar tiempo hasta el primer despegue, pasos que requieren ayuda y porcentaje que termina una vuelta sencilla. Establecer objetivos después de medir la versión actual, sin inventar una tasa de abandono.

### 3.3. Validar la física antes de prometer más realismo

**Prioridad P0 para diagnóstico; P1 para ajustes sustentados en mediciones.**

**Evidencia confirmada.** `propeller.gd::update_forces()` calcula cinco componentes: empuje, resistencia, torque y momentos de roll y pitch. `drone.gd::_integrate_forces()` consume las dos primeras, suma `motor.torque` y el momento del empuje; no utiliza directamente los otros tres componentes. Esto describe una integración parcial del modelo, pero no demuestra por sí solo cómo se siente el vuelo.

`project.godot` fija 100 ticks físicos por segundo. El integrador realiza diez subpasos cuando el dron está armado. Eso representa nominalmente 1.000 iteraciones internas por segundo, **no** colisiones ni lectura de radio a 1.000 Hz. La escena del dron ya tiene integración personalizada y detección continua de colisiones activadas.

**Propuesta.** Crear un banco de escenarios repetibles: empuje frente a RPM, sustentación en estacionario, respuesta a un escalón de mando, desaceleración horizontal y efecto suelo. Documentar unidades, masas, coeficientes y condiciones. Comparar con datos de banco o registros de un cuadricóptero de referencia y complementar con evaluación de pilotos.

Antes de incorporar los momentos calculados, revisar qué representa `motor.torque`, marcos de referencia y signos para evitar doble contabilización. Auditar también el uso de `state.inverse_inertia` frente al marco en que se calcula el torque, y la conversión de `theta_tip` en `propeller.gd`; son preguntas de validación, no fallos físicos demostrados. Verificar parámetros derivados al cambiar masa o hélices.

**Justificación.** Un modelo más complejo puede empeorar el resultado si sus parámetros o transformaciones son inconsistentes. El objetivo es obtener respuestas explicables y repetibles. La evolución de física anunciada por Liftoff sirve como referencia de alcance, no como validación de nuestras ecuaciones.

**Aceptación.** Publicar curvas de referencia y tolerancias por escenario; repetir a distintas tasas de render manteniendo el paso físico. Las tolerancias deben acordarse a partir de datos y precisión objetivo. No subir indiscriminadamente la frecuencia de simulación antes de medir costo y beneficio.

### 3.4. Proteger la validez de vueltas y repeticiones

**Prioridad P0 para cruces; P1 para persistencia robusta.**

**Evidencia.** El respaldo de checkpoints en `drone.gd::_physics_process()` limita su rayo a un metro. A 100 Hz, una velocidad de 100 m/s implica un metro por tick: es una relación matemática, no una velocidad medida del juego. Conviene probar velocidades y puertas del contenido real, además de márgenes extremos. `checkpoint.gd` usa `bsearch()` sobre una lista de cuerpos agregados con `append()`, sin ordenamiento visible en ese recorrido.

Las repeticiones guardan transformaciones por muestra y `ghost.gd` avanza una muestra por tick, sin marcas temporales por muestra. Los récords se identifican por pista, sin una clave visible de versión física o configuración. `read_replay()` accede a `replay[0][0]` después de leer un archivo existente: un archivo vacío merece manejo explícito.

**Propuesta.** Validar el cruce mediante el segmento entre posiciones anterior y actual, dirección y límites de la puerta; impedir dobles registros y saltos de orden. Revisar la búsqueda de cuerpos. Versionar replays, registrar tiempo y configuración, validar su estructura y separar récords cuando cambia la física o la clase de dron.

**Justificación.** Una vuelta perdida o un fantasma incompatible deterioran la confianza en el entrenamiento. La detección continua del cuerpo no reemplaza automáticamente la validación lógica de puertas.

**Aceptación.** Casos de cruce frontal, inverso, tangencial, rápido, doble notificación, reinicio dentro del área y archivo vacío/corrupto. Una repetición debe mantener su duración al cambiar la frecuencia de reproducción o rechazarse claramente si es incompatible.

### 3.5. Hacer visibles las pistas y el progreso del piloto

**Prioridad P1.**

**Evidencia.** `sceneries/level.gd` selecciona el circuito por cercanía a una zona de salida cuando se activa el modo carrera. [time_table.gd](tracks/time_table.gd) muestra vueltas y total. Los fantasmas y récords ya proporcionan una base para comparación.

**Propuesta.** Añadir un selector con nombre, miniatura, dificultad y récord. Durante el vuelo, ofrecer indicación opcional de la siguiente puerta y diferencia por sector. Al terminar, mostrar mejor vuelta, consistencia, sectores donde se perdió tiempo y una acción clara para repetir. Distinguir medallas de objetivos diseñados de posiciones entre récords personales: no son el mismo incentivo.

**Justificación.** El usuario puede elegir una práctica deliberada y entender qué mejorar en el siguiente intento. Reutilizar la infraestructura local aporta valor sin el costo de servidores o sincronización multijugador.

**Aceptación.** Entrar a cualquier pista desde el menú y reiniciarla con una acción; comparar dos vueltas y localizar el sector de mayor pérdida. Definir una política para asistencias y categorías de récord antes de incorporar rankings compartidos.

### 3.6. Medir rendimiento y percepción FPV en el destino Web

**Prioridad P0 para establecer una referencia; P1 para optimizar lo medido.**

**Evidencia.** La cámara completa utiliza cinco subcámaras, la rápida dos, y los subviewports se actualizan con `UPDATE_ALWAYS`. Los valores iniciales en `graphics.gd` seleccionan ojo de pez completo a 720p. Hay cuatro motores con ocho reproductores de audio cada uno; esto merece perfilado, pero no demuestra un cuello de botella. El preset Web desactiva hilos y ya existen correcciones para Compatibility.

**Propuesta.** Medir tiempo de CPU y GPU, percentiles de duración de cuadros, lectura de controles y picos durante grabación de replays. Comparar ojo de pez completo, rápido y desactivado. Revisar si cámaras no visibles siguen consumiendo render. Crear presets «Rendimiento» y «Calidad» y conservar un ajuste manual. Medir escritorio y navegador por separado.

**Justificación.** Una respuesta visual irregular dificulta controlar y evaluar la física. La documentación de Godot indica que Web utiliza Compatibility/WebGL 2.0 y distingue las limitaciones de exportar sin hilos; una prueba en Forward+ no certifica la experiencia Web. [Documentación oficial de exportación Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).

**Aceptación.** Elegir equipo, navegador y resolución de referencia. Como objetivo inicial propuesto, buscar 60 FPS sostenidos y examinar el percentil 95 frente al presupuesto de 16,7 ms; no es una medición actual. Verificar además foco, reconexión del mando, audio y persistencia tras recargar. Agregar una prueba básica del artefacto exportado a la verificación existente.

### 3.7. Completar batería y viento como opciones de entrenamiento

**Prioridad P2, después de estabilizar la referencia física.**

**Evidencia.** [battery.gd](drone/battery.gd) declara capacidad, corriente y voltaje, pero `_physics_process()` conserva el comentario pendiente de actualizarlos. `motor.gd` limita RPM sin recibir voltaje de esa batería. Ajustar el peso de batería no equivale a simular descarga. La resistencia revisada utiliza velocidad del dron sin un campo explícito de viento.

**Propuesta.** Conectar un modelo sencillo de consumo y caída de voltaje con límites de motor, indicador de carga y opción de batería infinita. Incorporar luego viento constante y ráfagas reproducibles, aplicando velocidad relativa del aire tanto al cuerpo como a las hélices. Mantener un preset sin viento para comparar vueltas.

**Justificación.** Introduce decisiones de potencia y adaptación al entorno, pero agrega parámetros difíciles de ajustar sin mediciones. Conviene preservar condiciones comparables y permitir práctica sin interrupciones.

**Aceptación.** A igual configuración, un consumo mayor debe reducir autonomía; el cambio de voltaje debe tener un efecto definido y medible. Una misma semilla de viento debe repetir condiciones. Documentar unidades y calibrar parámetros con datos, evitando convertir el indicador de batería en un temporizador decorativo.

### 3.8. Ampliar desafíos y escenarios con una función concreta

**Prioridad P2.**

**Propuesta.** Aprovechar puertas y patrones existentes para aterrizaje de precisión, mantenimiento de altura, slalom y recorrido bajo obstáculos. Crear después un entorno compacto con referencias claras de escala, alturas y distancias. El seguimiento de un objeto móvil puede ser una expansión posterior inspirada en los escenarios de TRYP.

**Justificación.** Cada zona debería enseñar una habilidad o habilitar una maniobra. La variedad de objetivos puede extender el uso del escenario actual con menos costo que un mundo grande y detallado. Las herramientas `@tool` de `track.gd` facilitan crear contenido dentro de Godot; no equivalen a un editor disponible para jugadores.

**Aceptación.** Cada desafío debe especificar objetivo, condición de éxito, devolución y reinicio. Evaluar editor para jugadores y contenido compartido cuando exista un formato de pistas estable y validado.

## 4. Orden de implementación sugerido

P0 significa dependencia de confiabilidad; P1, mejora directa de experiencia; P2, expansión. El esfuerzo es relativo, no una estimación contractual: bajo = cambio acotado; medio = varios sistemas; alto = modelado o validación especializada.

| Orden | Entrega | Prioridad | Esfuerzo | Dependencia y evidencia de éxito |
| --- | --- | --- | --- | --- |
| 1 | Identificación y calibración robusta de controles | P0 | Medio | Matriz de dispositivos y acciones funcionales. |
| 2 | Validación de checkpoints y manejo de replays inválidos | P0 | Medio | Cruces correctos y carga sin fallos ante archivos dañados. |
| 3 | Banco de física y perfilado de la versión Web | P0 | Medio/alto | Mediciones repetibles antes de ajustar parámetros. |
| 4 | Primera sesión, español y selector de pistas | P1 | Medio | Usuarios nuevos despegan y eligen una pista sin asistencia. |
| 5 | Sectores, resumen de progreso y formato de replay versionado | P1 | Medio | Comparaciones útiles y compatibles. |
| 6 | Correcciones físicas y presets gráficos según resultados | P1 | Variable | Mejora contra las referencias del paso 3. |
| 7 | Batería, viento y desafíos adicionales | P2 | Alto en física; medio en contenido | Modelo estable y condiciones reproducibles. |

No priorizaría todavía multijugador en tiempo real, mapas extensos ni integrar Betaflight completo. Son inversiones posibles, pero necesitan un objetivo específico y aumentan el costo de mantenimiento. Las curvas de rates existentes tampoco deben presentarse como equivalentes a ejecutar el firmware real.

## 5. Cómo verificar que las mejoras valen la pena

1. **Medir una línea de base:** primera conexión, primer despegue, primera vuelta, fallos de puertas y duración de cuadros. Usar siempre las mismas condiciones para comparar versiones.
2. **Probar con dos públicos:** personas nuevas en FPV y pilotos con radio. Los primeros revelan barreras de comprensión; los segundos ayudan a contrastar respuesta y configuración.
3. **Aprovechar la telemetría existente:** está desactivada por defecto en el controlador. El script de gráficos usa una ruta Linux fija con el nombre `Drone`; conviene recibir la ruta del CSV como argumento y registrar versión, unidades y preset. Esto permitiría investigar sin depender solamente de impresiones.
4. **Separar verificación funcional y física:** un checkpoint puede funcionar correctamente aunque el dron esté mal calibrado; una curva de empuje correcta no garantiza una interfaz comprensible.
5. **Cerrar cada entrega con evidencia:** resultados observados, regresiones y comparación con la base. Revisar prioridades después de esas pruebas.

El primer incremento recomendable reúne controles confiables, elección explícita de pista, una lección breve y un resumen útil de carrera. El trabajo de validación física y rendimiento debe acompañarlo, para que el aprendizaje y los récords se apoyen en un comportamiento estable.
