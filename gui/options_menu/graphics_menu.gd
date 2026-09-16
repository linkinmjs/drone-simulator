extends MenuScreen


const RESOLUTIONS: Array[String] = ["100", "75", "50"]
const FISHEYE_RESOLUTIONS: Array[String] = ["2160p", "1440p", "1080p", "720p", "480p", "240p"]

@onready var window_mode := %WindowOptions as OptionButton
@onready var resolution := %ResolutionOptions as OptionButton
@onready var vsync := %VSyncOptions as OptionButton
@onready var max_fps := %MaxFPSOptions as OptionButton
@onready var fullscreen_button := %FullscreenButton as Button
@onready var preset := %PresetOptions as OptionButton
@onready var game_msaa := %GameMSAAOptions as OptionButton
@onready var shadows := %ShadowsOptions as OptionButton
@onready var fisheye_mode := %FPVFisheyeOptions as OptionButton
@onready var fisheye_resolution := %FisheyeResolutionOptions as OptionButton
@onready var fisheye_msaa := %FisheyeMSAAOptions as OptionButton

@onready var button_back := %ButtonBack as Button


func _ready() -> void:
	super()
	_fill(window_mode, ["GFX_FULLSCREEN_MODE", "GFX_WINDOW", "GFX_BORDERLESS"])
	_fill(resolution, ["100%", "75%", "50%"])
	_fill(vsync, ["UI_OFF", "UI_ON", "GFX_VSYNC_ADAPTIVE"])
	_fill(max_fps, ["30", "60", "120", "144", "240", "GFX_UNLIMITED"])
	_fill(preset, ["GFX_QUALITY_LOW", "GFX_QUALITY_MEDIUM", "GFX_QUALITY_HIGH",
			"GFX_QUALITY_ULTRA", "GFX_QUALITY_CUSTOM"])
	_fill(game_msaa, ["UI_OFF", "2x", "4x", "8x", "16x"])
	_fill(shadows, ["GFX_QUALITY_VERY_LOW", "GFX_QUALITY_LOW", "GFX_QUALITY_MEDIUM",
			"GFX_QUALITY_HIGH", "GFX_QUALITY_ULTRA"])
	_fill(fisheye_mode, ["UI_OFF", "GFX_FISHEYE_FULL", "GFX_FISHEYE_FAST"])
	_fill(fisheye_resolution, FISHEYE_RESOLUTIONS)
	_fill(fisheye_msaa, ["UI_OFF", "2x", "4x", "8x", "16x", "GFX_SAME_AS_GAME"])
	# "Custom" is a state, not something the user picks directly
	preset.set_item_disabled(Graphics.Quality.CUSTOM, true)

	_refresh()

	var _discard := window_mode.item_selected.connect(_on_window_mode_changed)
	_discard = resolution.item_selected.connect(_on_resolution_changed)
	_discard = vsync.item_selected.connect(_on_vsync_changed)
	_discard = max_fps.item_selected.connect(_on_max_fps_changed)
	_discard = preset.item_selected.connect(_on_preset_changed)
	_discard = game_msaa.item_selected.connect(_on_msaa_changed)
	_discard = shadows.item_selected.connect(_on_shadows_changed)
	_discard = fisheye_mode.item_selected.connect(_on_fisheye_mode_changed)
	_discard = fisheye_resolution.item_selected.connect(_on_fisheye_resolution_changed)
	_discard = fisheye_msaa.item_selected.connect(_on_fisheye_msaa_changed)
	_discard = fullscreen_button.pressed.connect(Graphics.toggle_web_fullscreen)
	bind_back_button(button_back)

	# In the browser the page owns the window: only a fullscreen toggle makes sense
	var web := Graphics.is_web()
	%WindowRow.visible = not web
	%ResolutionRow.visible = not web
	%VSyncRow.visible = not web
	%MaxFPSRow.visible = not web
	%FullscreenRow.visible = web
	initial_focus = fullscreen_button if web else window_mode


func _fill(option: OptionButton, items: Array) -> void:
	option.clear()
	for item: String in items:
		option.add_item(item)


func _refresh() -> void:
	var settings := Graphics.graphics_settings
	window_mode.select(int(settings["window_mode"]))
	resolution.select(maxi(RESOLUTIONS.find(str(settings["resolution"])), 0))
	vsync.select(int(settings["vsync"]))
	max_fps.select(maxi(Graphics.MAX_FPS_OPTIONS.find(int(settings["max_fps"])), 0))
	game_msaa.select(int(settings["msaa"]))
	shadows.select(int(settings["shadows"]))
	fisheye_mode.select(int(settings["fisheye_mode"]))
	fisheye_resolution.select(int(settings["fisheye_resolution"]))
	fisheye_msaa.select(int(settings["fisheye_msaa"]))
	var fisheye_disabled := int(settings["fisheye_mode"]) == Graphics.FisheyeMode.OFF
	fisheye_resolution.disabled = fisheye_disabled
	fisheye_msaa.disabled = fisheye_disabled
	preset.select(Graphics.get_quality_preset())


func _on_window_mode_changed(idx: int) -> void:
	Graphics.graphics_settings["window_mode"] = idx
	Graphics.update_window_mode()
	Graphics.save_graphics_settings()


func _on_resolution_changed(idx: int) -> void:
	Graphics.graphics_settings["resolution"] = RESOLUTIONS[idx]
	Graphics.update_resolution()
	Graphics.save_graphics_settings()


func _on_vsync_changed(idx: int) -> void:
	Graphics.graphics_settings["vsync"] = idx
	Graphics.update_vsync()
	Graphics.save_graphics_settings()


func _on_max_fps_changed(idx: int) -> void:
	Graphics.graphics_settings["max_fps"] = Graphics.MAX_FPS_OPTIONS[idx]
	Graphics.update_max_fps()
	Graphics.save_graphics_settings()


func _on_preset_changed(idx: int) -> void:
	if idx == Graphics.Quality.CUSTOM:
		return
	Graphics.apply_quality_preset(idx as Graphics.Quality)
	_refresh()


func _on_msaa_changed(idx: int) -> void:
	Graphics.graphics_settings["msaa"] = idx
	Graphics.update_msaa()
	Graphics.save_graphics_settings()
	_refresh()


func _on_shadows_changed(idx: int) -> void:
	Graphics.graphics_settings["shadows"] = idx
	Graphics.update_shadows()
	Graphics.save_graphics_settings()
	_refresh()


func _on_fisheye_mode_changed(idx: int) -> void:
	Graphics.graphics_settings["fisheye_mode"] = idx
	Graphics.update_fisheye_mode()
	Graphics.save_graphics_settings()
	_refresh()


func _on_fisheye_resolution_changed(idx: int) -> void:
	Graphics.update_fisheye_resolution(FISHEYE_RESOLUTIONS[idx])
	Graphics.save_graphics_settings()
	_refresh()


func _on_fisheye_msaa_changed(idx: int) -> void:
	Graphics.graphics_settings["fisheye_msaa"] = idx
	Graphics.update_fisheye_msaa()
	Graphics.save_graphics_settings()
