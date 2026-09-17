extends Node
## Checks the level skies: every SkyCatalog sky with the fisheye off and full, the random draw
## and a sky change while paused. Saves a screenshot per sky with --shots and prints the
## average luminance. Run it again with --rendering-method gl_compatibility for the web look:
##   godot --path . --windowed --resolution 1280x720 res://tools/sky_check.tscn -- --shots=<folder>
## Exits with code 0 when every check passes. Settings are only changed in memory.


const LEVEL := "res://sceneries/level1.tscn"

var shots_dir := ""
var failures := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	print("  %s %s" % ["ok  " if condition else "FAIL", label])
	if not condition:
		failures += 1


func frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _run() -> void:
	Global.startup = false
	var saved_game := GameSettings.game_config.duplicate()
	var saved_fisheye: int = Graphics.graphics_settings["fisheye_mode"]
	var renderer := "compat" if Graphics.is_compatibility_renderer() else "forward"

	print("== Random draw")
	GameSettings.game_config["sky"] = GameSettings.SKY_RANDOM
	var previous := ""
	var repeated := false
	var seen := {}
	for _i in 12:
		var drawn := GameSettings.pick_sky()
		repeated = repeated or drawn == previous
		seen[drawn] = true
		previous = drawn
	check(not repeated, "random never repeats the previous sky")
	check(seen.size() > 1, "random draws more than one sky (%d)" % seen.size())
	GameSettings.game_config["sky"] = "unknown"
	check(GameSettings.get_sky_choice() == GameSettings.SKY_RANDOM, "an unknown option counts as random")

	var modes := {Graphics.FisheyeMode.OFF: "off", Graphics.FisheyeMode.FULL: "full"}
	for mode: int in modes:
		Graphics.graphics_settings["fisheye_mode"] = mode
		for id in SkyCatalog.get_ids():
			print("== %s, fisheye %s" % [id, modes[mode]])
			GameSettings.game_config["sky"] = id
			var level := await _load_level()
			_check_sky(level, id)
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var label := "sky_%s_%s_%s" % [renderer, modes[mode], id]
			if not shots_dir.is_empty():
				var _err := image.save_png(shots_dir.path_join(label + ".png"))
			print("  luminance %.3f" % _luminance(image))
			level.queue_free()
			await frames(5)

	print("== Change while paused")
	Graphics.graphics_settings["fisheye_mode"] = Graphics.FisheyeMode.OFF
	GameSettings.game_config["sky"] = "clear-day"
	var paused_level := await _load_level()
	var environment := (paused_level.get_node("WorldEnvironment") as WorldEnvironment).environment
	get_tree().paused = true
	var sky_before := environment.sky
	# Another setting saved (language, navigation): same sky option, the sky stays
	GameSettings.game_settings_updated.emit()
	check(environment.sky == sky_before, "saving another setting keeps the sky")
	GameSettings.game_config["sky"] = "night"
	GameSettings.game_settings_updated.emit()
	await frames(10)
	check(environment.sky != sky_before, "a new sky option replaces the sky while paused")
	_check_sky(paused_level, "night")
	GameSettings.game_config["sky"] = "clear-day"
	GameSettings.game_settings_updated.emit()
	_check_sky(paused_level, "clear-day")
	get_tree().paused = false
	paused_level.queue_free()
	await frames(5)

	GameSettings.game_config = saved_game
	Graphics.graphics_settings["fisheye_mode"] = saved_fisheye
	print("== Result: %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _load_level() -> Node:
	var level := (load(LEVEL) as PackedScene).instantiate()
	get_tree().root.add_child(level)
	var drone := level.get_node("Drone") as Drone
	drone.freeze = true
	drone.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(20.0)), Vector3(0.0, 3.0, 8.0))
	await frames(60)
	return level


func _check_sky(level: Node, id: String) -> void:
	var preset := SkyCatalog.resolve(id)
	var environment := (level.get_node("WorldEnvironment") as WorldEnvironment).environment
	var material := environment.sky.sky_material as ShaderMaterial
	check(material != null and material.shader == SkyCatalog.SKY_SHADER, "%s: sky uses the catalog shader" % id)
	if material:
		check(material.get_shader_parameter("sky_day") == preset["sky_day"], "%s: shader colors come from the preset" % id)
	var sun := level.get_node("DirectionalLight3D") as DirectionalLight3D
	var lux: float = preset["sun_lux"]
	if Graphics.is_compatibility_renderer():
		lux *= Graphics.COMPATIBILITY_SUN_MULTIPLIER
	check(is_equal_approx(sun.light_intensity_lux, lux), "%s: sun at %d lux (got %d)" % [id, lux, sun.light_intensity_lux])
	var sun_basis := SkyCatalog.get_sun_basis(id)
	if material:
		var direction: Vector3 = material.get_shader_parameter("sun_direction")
		check(material.get_shader_parameter("use_sun_direction") and direction.is_equal_approx(sun_basis.z),
				"%s: the shader gets the sun direction" % id)
	check(sun.sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_ONLY, "%s: the level light does not drive the sky" % id)
	check(level.find_children("*", "DirectionalLight3D", true, false).size() == 1, "%s: a single directional light" % id)
	if preset["moonlight"]:
		check(sun.global_basis.z.is_equal_approx(-sun_basis.z), "%s: moonlight comes from the moon side" % id)
	else:
		check(sun.global_basis.is_equal_approx(sun_basis), "%s: the level light is the sun" % id)


func _luminance(image: Image) -> float:
	var small := image.duplicate() as Image
	small.resize(64, 36)
	var total := 0.0
	for y in small.get_height():
		for x in small.get_width():
			total += small.get_pixel(x, y).get_luminance()
	return total / (small.get_width() * small.get_height())
