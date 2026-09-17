extends Node


signal shadows_updated
signal fisheye_mode_changed
signal fisheye_resolution_changed
signal fisheye_msaa_changed


enum WindowMode {FULLSCREEN, WINDOW, BORDERLESS_WINDOW}
enum GameMSAA {OFF, X2, X4, X8, X16}
enum GameAF {OFF, X2, X4, X8, X16}
enum Shadows {VERY_LOW, LOW, MEDIUM, HIGH, ULTRA}
enum FisheyeMode {OFF, FULL, FAST}
enum FisheyeResolution {FISHEYE_2160P, FISHEYE_1440P, FISHEYE_1080P,
		FISHEYE_720P, FISHEYE_480P, FISHEYE_240P}
enum FisheyeMSAA {OFF, X2, X4, X8, X16, SAME_AS_GAME}
enum VSync {OFF, ON, ADAPTIVE}
enum Quality {LOW, MEDIUM, HIGH, ULTRA, CUSTOM}

const MAX_FPS_OPTIONS: Array[int] = [30, 60, 120, 144, 240, 0]
## Bump to apply new web defaults once over the settings already saved in the browser.
const WEB_DEFAULTS_REVISION := 1
## Values applied by each quality preset (the order follows the Quality enum).
const QUALITY_PRESETS := [
	{"msaa": GameMSAA.OFF, "shadows": Shadows.LOW, "fisheye_mode": FisheyeMode.FAST,
			"fisheye_resolution": FisheyeResolution.FISHEYE_480P},
	{"msaa": GameMSAA.X2, "shadows": Shadows.MEDIUM, "fisheye_mode": FisheyeMode.FAST,
			"fisheye_resolution": FisheyeResolution.FISHEYE_720P},
	{"msaa": GameMSAA.X4, "shadows": Shadows.HIGH, "fisheye_mode": FisheyeMode.FULL,
			"fisheye_resolution": FisheyeResolution.FISHEYE_720P},
	{"msaa": GameMSAA.X8, "shadows": Shadows.ULTRA, "fisheye_mode": FisheyeMode.FULL,
			"fisheye_resolution": FisheyeResolution.FISHEYE_1080P},
]


var graphics_settings_path := "%s/Graphics.cfg" % [Global.config_dir]

var graphics_settings := {
	"window_mode": WindowMode.FULLSCREEN,
	"resolution": "100",
	"msaa": GameMSAA.X4,
	"af": GameAF.X4,
	"shadows": Shadows.MEDIUM,
	"fisheye_mode": FisheyeMode.FULL,
	"fisheye_resolution": FisheyeResolution.FISHEYE_720P,
	"fisheye_msaa": FisheyeMSAA.SAME_AS_GAME,
	"vsync": VSync.ON,
	"max_fps": 0,
	"web_defaults_revision": 0,
}
var fisheye_resolution := 720


func _ready() -> void:
	if OS.has_feature("web"):
		# The browser owns the canvas and the frame pacing; start with the light preset
		# recommended in docs/optimizacion.md.
		graphics_settings["window_mode"] = WindowMode.WINDOW
		for key: String in QUALITY_PRESETS[Quality.MEDIUM]:
			graphics_settings[key] = QUALITY_PRESETS[Quality.MEDIUM][key]
		apply_web_fisheye_defaults()


## On the web the full fisheye (same lens as the desktop, no seam between cameras) runs at a
## lower resolution per camera to keep the frame rate.
func apply_web_fisheye_defaults() -> void:
	graphics_settings["fisheye_mode"] = FisheyeMode.FULL
	graphics_settings["fisheye_resolution"] = FisheyeResolution.FISHEYE_480P
	graphics_settings["web_defaults_revision"] = WEB_DEFAULTS_REVISION
	update_fisheye_resolution()


func is_web() -> bool:
	return OS.has_feature("web")


func load_graphics_settings() -> String:
	var config := ConfigFile.new()
	var text := ""
	var err := config.load(graphics_settings_path)
	if err == OK:
		for key: String in graphics_settings.keys():
			if config.has_section_key("graphics", key):
				graphics_settings[key] = config.get_value("graphics", key)
		# Read from the file: on the web _ready() already set the current revision in memory
		var saved_revision := int(config.get_value("graphics", "web_defaults_revision", 0))
		var outdated_web_settings := is_web() and saved_revision < WEB_DEFAULTS_REVISION
		if outdated_web_settings:
			apply_web_fisheye_defaults()
		update_window_mode()
		update_resolution()
		update_msaa()
		update_af()
		update_shadows()
		update_fisheye_mode()
		update_fisheye_resolution()
		update_fisheye_msaa()
		update_vsync()
		update_max_fps()
		if outdated_web_settings:
			save_graphics_settings()
	elif err == ERR_PARSE_ERROR:
		Global.log_error(err, "Parse error while loading graphics configuration file.")
		text = "ERR_GRAPHICS_PARSE"
	elif err != ERR_FILE_NOT_FOUND:
		Global.log_error(err, "Could not open graphics config file.")
		text = "ERR_GRAPHICS_OPEN"
	return text


func save_graphics_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(graphics_settings_path)
	if err == OK or err == ERR_FILE_NOT_FOUND or err == ERR_PARSE_ERROR:
		for key: String in graphics_settings.keys():
			config.set_value("graphics", key, graphics_settings[key])
		err = config.save(graphics_settings_path)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		Global.log_error(err, "Error while saving graphics settings.")


func update_window_mode() -> void:
	if is_web():
		return
	var mode := graphics_settings["window_mode"] as WindowMode
	var window := get_tree().root as Window
	if mode == WindowMode.FULLSCREEN:
		window.mode = Window.MODE_FULLSCREEN
		window.size = DisplayServer.screen_get_size()
	else:
		window.mode = Window.MODE_WINDOWED
		window.unresizable = false
		if window.size > DisplayServer.screen_get_size():
			window.size = DisplayServer.screen_get_size()
		window.borderless = true if mode == WindowMode.BORDERLESS_WINDOW else false


func update_resolution() -> void:
	if is_web():
		return
	var resolution_multiplier := float(graphics_settings["resolution"]) / 100.0
	var screen_resolution := DisplayServer.screen_get_size()
	var mode: int = graphics_settings["window_mode"]
	if mode == WindowMode.FULLSCREEN:
		DisplayServer.window_set_size(DisplayServer.screen_get_size())
	else:
		DisplayServer.window_set_size(screen_resolution * resolution_multiplier)
		var window_offset := DisplayServer.screen_get_size() - DisplayServer.window_get_size()
		DisplayServer.window_set_position(Vector2i(Vector2(window_offset) / 2.0))
	get_viewport().size = screen_resolution * resolution_multiplier


func update_msaa() -> void:
	get_viewport().msaa_3d = graphics_settings["msaa"]
	if graphics_settings["fisheye_msaa"] == FisheyeMSAA.SAME_AS_GAME:
		update_fisheye_msaa()


## Anisotropic filtering is a project setting read at startup in Godot 4: it cannot be changed
## at runtime, so the option is no longer shown. The saved key is kept for compatibility.
func update_af() -> void:
	pass


func update_vsync() -> void:
	if is_web():
		return
	var mode := DisplayServer.VSYNC_ENABLED
	match int(graphics_settings["vsync"]):
		VSync.OFF:
			mode = DisplayServer.VSYNC_DISABLED
		VSync.ADAPTIVE:
			mode = DisplayServer.VSYNC_ADAPTIVE
	DisplayServer.window_set_vsync_mode(mode)


func update_max_fps() -> void:
	if is_web():
		return
	Engine.max_fps = maxi(int(graphics_settings["max_fps"]), 0)


func apply_quality_preset(preset: Quality) -> void:
	if preset < 0 or preset >= QUALITY_PRESETS.size():
		return
	var values: Dictionary = QUALITY_PRESETS[preset]
	for key: String in values:
		graphics_settings[key] = values[key]
	update_msaa()
	update_shadows()
	update_fisheye_mode()
	update_fisheye_resolution()
	update_fisheye_msaa()
	save_graphics_settings()


## Returns the preset matching the current values, or Quality.CUSTOM.
func get_quality_preset() -> Quality:
	for i in QUALITY_PRESETS.size():
		var values: Dictionary = QUALITY_PRESETS[i]
		var matches := true
		for key: String in values:
			if int(graphics_settings[key]) != int(values[key]):
				matches = false
				break
		if matches:
			return i as Quality
	return Quality.CUSTOM


func toggle_web_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func update_shadows(viewport: Viewport = null) -> void:
	if not viewport:
		viewport = get_viewport() as Viewport
	match graphics_settings["shadows"]:
		Shadows.VERY_LOW:
			viewport.positional_shadow_atlas_size = 512
			RenderingServer.directional_shadow_atlas_set_size(512, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		Shadows.LOW:
			viewport.positional_shadow_atlas_size = 1024
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		Shadows.MEDIUM:
			viewport.positional_shadow_atlas_size = 4096
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
		Shadows.HIGH:
			viewport.positional_shadow_atlas_size = 8192
			RenderingServer.directional_shadow_atlas_set_size(8192, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
		Shadows.ULTRA:
			viewport.positional_shadow_atlas_size = 16384
			RenderingServer.directional_shadow_atlas_set_size(16384, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
	shadows_updated.emit()


func update_fisheye_mode() -> void:
	fisheye_mode_changed.emit()


func update_fisheye_resolution(resolution_string: String = "") -> void:
	var new_resolution: int
	match resolution_string:
		"2160p":
			new_resolution = FisheyeResolution.FISHEYE_2160P
		"1440p":
			new_resolution = FisheyeResolution.FISHEYE_1440P
		"1080p":
			new_resolution = FisheyeResolution.FISHEYE_1080P
		"720p":
			new_resolution = FisheyeResolution.FISHEYE_720P
		"480p":
			new_resolution = FisheyeResolution.FISHEYE_480P
		"240p":
			new_resolution = FisheyeResolution.FISHEYE_240P
		"":
			new_resolution = graphics_settings["fisheye_resolution"]
	graphics_settings["fisheye_resolution"] = new_resolution
	match graphics_settings["fisheye_resolution"]:
		FisheyeResolution.FISHEYE_2160P:
			fisheye_resolution = 2160
		FisheyeResolution.FISHEYE_1440P:
			fisheye_resolution = 1440
		FisheyeResolution.FISHEYE_1080P:
			fisheye_resolution = 1080
		FisheyeResolution.FISHEYE_720P:
			fisheye_resolution = 720
		FisheyeResolution.FISHEYE_480P:
			fisheye_resolution = 480
		FisheyeResolution.FISHEYE_240P:
			fisheye_resolution = 240
	fisheye_resolution_changed.emit()


func update_fisheye_msaa() -> void:
	fisheye_msaa_changed.emit()


func get_fisheye_resolution(resolution_setting: int) -> int:
	var resolution: int
	match resolution_setting:
		FisheyeResolution.FISHEYE_2160P:
			resolution = 2160
		FisheyeResolution.FISHEYE_1440P:
			resolution = 1440
		FisheyeResolution.FISHEYE_1080P:
			resolution = 1080
		FisheyeResolution.FISHEYE_720P:
			resolution = 720
		FisheyeResolution.FISHEYE_480P:
			resolution = 480
		FisheyeResolution.FISHEYE_240P:
			resolution = 240
	return resolution


# The Compatibility renderer (used by the Web export) has no auto exposure, which leaves the
# whole level looking too dark. These helpers bring it close to the Forward+ look without
# touching the desktop build.
const COMPATIBILITY_EXPOSURE_MULTIPLIER := 1.4
## The exposure boost burns out the sunlit ground: SkyCatalog dims the sun...
const COMPATIBILITY_SUN_MULTIPLIER := 0.5
## ...but the sky needs a little more energy than on Forward+ to keep the same blue
const COMPATIBILITY_SKY_MULTIPLIER := 1.15


func is_compatibility_renderer() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


func new_camera_attributes() -> CameraAttributesPractical:
	var attributes := CameraAttributesPractical.new()
	if is_compatibility_renderer():
		attributes.exposure_multiplier = COMPATIBILITY_EXPOSURE_MULTIPLIER
	return attributes


func apply_compatibility_workarounds(world_environment: WorldEnvironment) -> void:
	if not is_compatibility_renderer():
		return
	var attributes := world_environment.camera_attributes
	if attributes is CameraAttributesPractical:
		attributes.auto_exposure_enabled = false
		attributes.exposure_multiplier = COMPATIBILITY_EXPOSURE_MULTIPLIER
