class_name SkyCatalog
extends RefCounted
## The skies a level can use, taken from the game procedural (sky shader and presets).
##
## The shader works out the time of day from the sun direction, so every preset also places the
## directional light: moving the sun is what turns the sky from day to night, and it keeps the
## lighting of the track in line with what is drawn above. The project uses physical light
## units, so the sun is set in lux. `sky_energy` dims the shader colors, which were made for
## a non-physical setup and look washed out at full energy. `ambient_sky` is how much of the
## ambient light comes from the sky; the rest comes from `ambient_color`.
##
## The sky gets the sun direction as a shader parameter, not from the light. At night the sun
## sits under the horizon, where it would light the track from below, so the level light
## becomes moonlight instead, coming from where the shader draws the moon, without a second
## directional light in the level.


const SKY_SHADER := preload("res://sceneries/skies/sky.gdshader")
const CLOUD_TEXTURES: Array[Texture2D] = [
	preload("res://sceneries/skies/noise/clouds_01.png"),
	preload("res://sceneries/skies/noise/clouds_02.png"),
	preload("res://sceneries/skies/noise/clouds_03.png"),
	preload("res://sceneries/skies/noise/clouds_04.png"),
]

const DEFAULT_ID := "clear-day"

## `label` is the translation key shown in the options.
const SKIES := {
	"clear-day": {
		"label": "GAME_SKY_CLEAR_DAY",
		"sky_day": Color(0.06, 0.35, 0.75),
		"horizon_day": Color(0.72, 0.84, 0.9),
		"sky_sunset": Color(0.15, 0.2, 0.4),
		"horizon_sunset": Color(0.9, 0.45, 0.15),
		"sky_night": Color(0.05, 0.1, 0.15),
		"horizon_night": Color(0.1, 0.15, 0.2),
		"cloud_color": Color(0.97, 0.98, 1.0),
		"cloud_density": 0.55,
		"cloud_tiling": Vector2(1.0, 1.0),
		"wind_speed": Vector2(0.5, 0.3),
		"light_rotation": Vector3(-55.0, -35.0, 0.0),
		"light_color": Color(1.0, 0.96, 0.9),
		"sun_lux": 110000.0,
		"sky_energy": 0.6,
		"ambient_color": Color(0.55, 0.68, 0.82),
		"ambient_sky": 1.0,
		"moonlight": false,
	},
	"overcast": {
		"label": "GAME_SKY_OVERCAST",
		"sky_day": Color(0.32, 0.38, 0.45),
		"horizon_day": Color(0.6, 0.64, 0.68),
		"sky_sunset": Color(0.22, 0.24, 0.3),
		"horizon_sunset": Color(0.55, 0.45, 0.42),
		"sky_night": Color(0.05, 0.07, 0.1),
		"horizon_night": Color(0.12, 0.14, 0.18),
		"cloud_color": Color(0.62, 0.66, 0.72),
		"cloud_density": 1.9,
		"cloud_tiling": Vector2(0.7, 0.7),
		"wind_speed": Vector2(0.9, 0.6),
		"light_rotation": Vector3(-50.0, 20.0, 0.0),
		"light_color": Color(0.85, 0.88, 0.95),
		"sun_lux": 50000.0,
		"sky_energy": 0.6,
		"ambient_color": Color(0.55, 0.6, 0.68),
		"ambient_sky": 1.0,
		"moonlight": false,
	},
	"sunset": {
		"label": "GAME_SKY_SUNSET",
		"sky_day": Color(0.1, 0.32, 0.62),
		"horizon_day": Color(0.8, 0.7, 0.6),
		"sky_sunset": Color(0.22, 0.16, 0.38),
		"horizon_sunset": Color(0.98, 0.42, 0.12),
		"sky_night": Color(0.05, 0.08, 0.16),
		"horizon_night": Color(0.12, 0.1, 0.18),
		"cloud_color": Color(0.95, 0.6, 0.45),
		"cloud_density": 0.9,
		"cloud_tiling": Vector2(1.2, 1.2),
		"wind_speed": Vector2(0.35, 0.2),
		"light_rotation": Vector3(-7.0, 115.0, 0.0),
		"light_color": Color(1.0, 0.68, 0.42),
		"sun_lux": 100000.0,
		"sky_energy": 0.6,
		"ambient_color": Color(0.6, 0.45, 0.45),
		"ambient_sky": 1.0,
		"moonlight": false,
	},
	"night": {
		"label": "GAME_SKY_NIGHT",
		"sky_day": Color(0.06, 0.35, 0.75),
		"horizon_day": Color(0.5, 0.6, 0.7),
		"sky_sunset": Color(0.12, 0.14, 0.3),
		"horizon_sunset": Color(0.35, 0.22, 0.3),
		"sky_night": Color(0.03, 0.05, 0.11),
		"horizon_night": Color(0.06, 0.09, 0.16),
		"cloud_color": Color(0.3, 0.34, 0.45),
		"cloud_density": 0.45,
		"cloud_tiling": Vector2(1.0, 1.0),
		"wind_speed": Vector2(0.25, 0.15),
		# The sun is under the horizon: the shader paints the night and the moon opposite it
		"light_rotation": Vector3(24.0, -40.0, 0.0),
		"light_color": Color(0.55, 0.66, 0.95),
		"sun_lux": 35000.0,
		"sky_energy": 0.6,
		# The fisheye cameras on Compatibility drop the ambient color: only the sky lights the dark
		"compat_sky_energy": 1.8,
		"ambient_color": Color(0.3, 0.4, 0.6),
		"ambient_sky": 0.4,
		"moonlight": true,
	},
}


static func get_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for id: String in SKIES:
		var _discard := ids.append(id)
	return ids


static func has_sky(id: String) -> bool:
	return SKIES.has(id)


## The requested preset, or the default one for an unknown id.
static func resolve(id: String) -> Dictionary:
	return SKIES.get(id, SKIES[DEFAULT_ID]) as Dictionary


## Orientation of the sun as a directional light (it shines along -Z).
static func get_sun_basis(id: String) -> Basis:
	return Basis.from_euler(Vector3(resolve(id)["light_rotation"]) * PI / 180.0)


static func build_material(id: String) -> ShaderMaterial:
	var preset := resolve(id)
	var material := ShaderMaterial.new()
	material.shader = SKY_SHADER
	for key: String in ["sky_day", "horizon_day", "sky_sunset", "horizon_sunset", "sky_night",
			"horizon_night", "cloud_color", "cloud_density", "cloud_tiling", "wind_speed"]:
		material.set_shader_parameter(key, preset[key])
	material.set_shader_parameter("use_directional_light", false)
	material.set_shader_parameter("use_sun_direction", true)
	# The shader expects the direction towards the sun, the +Z axis of the light basis
	material.set_shader_parameter("sun_direction", get_sun_basis(id).z)
	material.set_shader_parameter("cloud_tex_01", CLOUD_TEXTURES[0])
	material.set_shader_parameter("cloud_tex_02", CLOUD_TEXTURES[1])
	material.set_shader_parameter("night_noise_01", CLOUD_TEXTURES[2])
	material.set_shader_parameter("night_noise_02", CLOUD_TEXTURES[3])
	return material


## Puts the sky on the environment and places the level light to match. Every value is set
## absolutely, so applying again (another sky while paused) does not pile anything up.
static func apply(id: String, world_environment: WorldEnvironment, sun: DirectionalLight3D) -> void:
	var preset := resolve(id)
	var environment := world_environment.environment
	var sky := Sky.new()
	sky.sky_material = build_material(id)
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	var energy: float = preset["sky_energy"]
	if Graphics.is_compatibility_renderer():
		energy = preset.get("compat_sky_energy", energy * Graphics.COMPATIBILITY_SKY_MULTIPLIER)
	environment.background_energy_multiplier = energy
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = preset["ambient_color"]
	environment.ambient_light_sky_contribution = preset["ambient_sky"]

	var sun_basis := get_sun_basis(id)
	var lux: float = preset["sun_lux"]
	if Graphics.is_compatibility_renderer():
		lux *= Graphics.COMPATIBILITY_SUN_MULTIPLIER
	sun.light_color = preset["light_color"]
	sun.light_intensity_lux = lux

	# The light only lights the track; the sky reads the sun from its parameters
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	if preset["moonlight"]:
		# The shader draws the moon at -sun_direction, the opposite side of the sun
		sun.global_basis = sun_basis * Basis(Vector3.UP, PI)
	else:
		sun.global_basis = sun_basis
