extends SceneTree
## Bakes the noise textures of the sky shader into sceneries/skies/noise/*.png.
## Usage: godot --headless --path . -s res://tools/bake_sky_noise.gd
## They were NoiseTexture2D resources in procedural; generating 1024 px fractal noise while
## loading blocks for seconds on the web (no threads), so they ship as images instead.


const OUTPUT_DIR := "res://sceneries/skies/noise"

## name: [noise type, seed, octaves, frequency, size, invert, seamless skirt]
const TEXTURES := {
	"clouds_01": [FastNoiseLite.TYPE_SIMPLEX, 4, 6, 0.01, 1024, false, 0.2],
	"clouds_02": [FastNoiseLite.TYPE_PERLIN, 0, 8, 0.01, 1024, false, 0.4],
	"clouds_03": [FastNoiseLite.TYPE_CELLULAR, 0, 5, 0.008, 512, false, 0.2],
	"clouds_04": [FastNoiseLite.TYPE_CELLULAR, 0, 3, 0.01, 1024, true, 0.2],
}


func _init() -> void:
	var absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	var _err := DirAccess.make_dir_recursive_absolute(absolute)
	for texture_name: String in TEXTURES:
		var params: Array = TEXTURES[texture_name]
		var noise := FastNoiseLite.new()
		noise.noise_type = params[0]
		noise.seed = params[1]
		noise.fractal_octaves = params[2]
		noise.frequency = params[3]
		var size: int = params[4]
		var image := noise.get_seamless_image(size, size, params[5], false, params[6])
		var path := "%s/%s.png" % [absolute, texture_name]
		var err := image.save_png(path)
		print("%s -> %s (%s)" % [texture_name, path, error_string(err)])
	quit(0)
