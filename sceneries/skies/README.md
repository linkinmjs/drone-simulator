# Cielos

Fondos de nivel traídos de [procedural](https://github.com/linkinmjs/procedural) (`assets/skies/` y `scripts/environment/sky_catalog.gd`).

| Archivo | Qué es |
|---|---|
| `sky.gdshader` | Shader de cielo: degradado de día, atardecer y noche, nubes animadas con dos texturas de ruido, sol, luna y estrellas. La hora del día sale de la dirección de la primera luz direccional (`LIGHT0_DIRECTION`). |
| `sky_catalog.gd` | `SkyCatalog`: los cuatro cielos (Día despejado, Nublado, Atardecer, Noche) y `apply()`, que pone el cielo en el `WorldEnvironment` y orienta el sol. |
| `noise/clouds_0*.png` | Las `NoiseTexture2D` de procedural horneadas a imagen con `tools/bake_sky_noise.gd` (mismo ruido, diferencia máxima 1/255). |
| `clear_day_sky.tres` | Día despejado como material fijo, solo para que el editor muestre el cielo en `level1.tscn` y `tutorial_level.tscn`. En el juego lo reemplaza `SkyCatalog.apply()`. |

## Cambios respecto de procedural

- `sun_glow`, `moon_glow` y `night_blend` llamaban a `clamp(0.0, 1.0, x)`, con los argumentos en otro orden. En Vulkan da `x`, pero en OpenGL/WebGL el resultado no está definido y el brillo del sol cubría todo el cielo. Ahora es `clamp(x, 0.0, 1.0)`, que en Forward+ da lo mismo.
- Presets en unidades físicas: `sun_lux` en vez de `light_energy`, `sky_energy` para el brillo del cielo y `ambient_sky` / `ambient_color` para la luz ambiente.
- El shader puede recibir la dirección del sol como parámetro (`use_sun_direction`, `sun_direction`) en lugar de leerla de la primera luz direccional. `SkyCatalog` la usa siempre, así en Noche la luz del nivel pasa a ser luz de luna (sale de donde el shader dibuja la luna) mientras el cielo sigue viendo el sol bajo el horizonte. No hace falta una segunda luz direccional solo para el cielo.

## Licencia pendiente

El shader salió de un tutorial o sitio de shaders libre, pero no está identificado cuál ni su licencia. Hay que confirmarlo y dejar el crédito acá antes de considerar resuelta la atribución.
