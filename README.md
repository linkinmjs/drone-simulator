# Godot Drone
This is a drone simulation made in Godot. You can fly around as you want or try racing along some MultiGP tracks I recreated.

## Godot 4.7 fork
This copy is based on the `big-refactoring` branch of [Cykyrios/GodotDrone](https://github.com/Cykyrios/GodotDrone) (the upstream port to Godot 4.6) and has been adapted to run on **Godot 4.7** (Forward+ renderer, built-in Jolt physics). The original project is licensed under the GPL-3.0, see `LICENSE`. Upstream history is kept in git under the `upstream` remote.

## Quad customization
You can tweak the camera angle as well as the weight of both the drone itself and the battery. Want to do some freestyle? 700g is about right for a quad equipped with an action camera. Fancy a race? 300g is probably closer to actual racers.

You can also adjust the rates and expo of the pitch, roll and yaw axes. PIDs are not customizable at this time, I would need to either change my flight controller implementation or try to get BetaFlight in, but that would probably require quite a bit of work.

## Controls
A controller or radio transmitter is necessary to play! Or anything that your computer recognizes as having 4 axes, really. You can rebind controls in the options and auto-calibrate the 4 main axes. You can also use other axes to trigger actions, similar to what BetaFlight does.

You can consult the Help screen in game for some drone basics and keyboard shortcuts. Do not forget to bind a button or axis to either Arm or Toggle Arm, or you won't be able to fly!

## Graphics
The FPV camera has an optional fisheye mode, which feels more realistic than the standard game camera, but is also more expensive on your GPU. A cheaper version is available at the cost of visual quality.

You will notice the only level is rather bland, I hope to change that at some point.

## Godot 4
I started this project on Godot 3 a few years back. Now that Godot 4 is out and I have ported the game to it, I am in the process of refactoring my admittedly poor code. I definitely wouldn't call this version "stable" by any mean, but it is now more or less on par with the Godot 3 version.

## Development
I started this project as a hobby, and am not currently looking for pull requests - but do feel free to open issues and leave feedback. Also, the codebase is probably horrible and I am in the process of refactoring most of it after porting the project to Godot 4.

## Sobre este repositorio

Este repositorio sirve entrega del trabajo práctico 1 del trayecto de image campus 2025 de Desarrollo de Videojuegos con Godot.

## Instructor de vuelo

El menú principal incluye un **Instructor de vuelo** con ocho lecciones cortas: mando y armado, despegue y altura, guiñada, cabeceo, alabeo, puertas en Horizon y en Acro, y un primer circuito cronometrado. La arquitectura y las pruebas están en [docs/tutorial.md](docs/tutorial.md).

## Publicación automática en itch.io

Cada push a la rama `master` dispara la acción de GitHub definida en `.github/workflows/deploy-to-itch.yml`: importa los recursos con Godot 4.7, exporta el preset **Web** de `export_presets.cfg` y sube el resultado a itch.io con butler.

### Paso 1

Crear el proyecto en itch

   <img height="300" alt="image" src="https://github.com/user-attachments/assets/289a1dd2-72b3-40af-b76a-81bef6d9212f" />

### Paso 2

Ponerle un título al juego, y configurar el **Kind of project** como HTML

   <img height="600" alt="image" src="https://github.com/user-attachments/assets/12ba7e65-e05a-4106-a8f0-69ce8415a851" />

### Paso 3

Clickear Save & view page

   <img width="631" height="190" alt="image" src="https://github.com/user-attachments/assets/bea9ca55-ddf6-4043-87b3-78b079718dac" />

### Paso 4

Configurar los siguientes secretos en el repositorio (Settings > Secrets and Variables > Actions):

   - BUTLER_API_KEY -> se obtiene aquí: https://itch.io/user/settings/api-keys
   - ITCHIO_GAME -> nombre del juego en itch
   - ITCHIO_USERNAME -> usuario de itch

### Paso 5

Hacer un commit y un push al repositorio; eso dispara la acción que exporta el juego y lo sube a itch:

<img width="1910" height="369" alt="image" src="https://github.com/user-attachments/assets/06312139-8854-4d35-8670-552dda17ff6c" />

### Paso 6

Tras subirlo por primera vez, volver a itch y marcar la opción **This file will be played in the browser**, luego guardar de nuevo.

<img width="627" height="410" alt="image" src="https://github.com/user-attachments/assets/0c5c671d-248e-457c-963e-9144a240f687" />

A partir de ahí, cada push a `master` actualiza el juego en itch automáticamente.
