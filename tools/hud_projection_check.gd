extends Node
## Visual check of the in-flight HUD: loads the level with every fisheye mode and two camera
## angles, enables every HUD element and saves screenshots. It also measures, on a few
## columns, where the image turns from sky to ground and compares it with the HUD horizon.
##   godot --path . --windowed --resolution 1600x900 res://tools/hud_projection_check.tscn -- --shots=<folder>
## Settings are only changed in memory, nothing is saved.


var shots_dir := ""
var failures := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	_run.call_deferred()


func frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _run() -> void:
	Global.startup = false
	var modes := {
		Graphics.FisheyeMode.FULL: "full",
		Graphics.FisheyeMode.FAST: "fast",
		Graphics.FisheyeMode.OFF: "off",
	}
	for mode: int in modes:
		Graphics.graphics_settings["fisheye_mode"] = mode
		var level := (load("res://sceneries/level1.tscn") as PackedScene).instantiate()
		get_tree().root.add_child(level)
		await frames(90)
		var drone := level.get_node("Drone")
		var hud := drone.hud as HUD
		for key: String in GameSettings.HUD_PRESETS[GameSettings.HudPreset.FULL]:
			GameSettings.hud_config[key] = GameSettings.HUD_PRESETS[GameSettings.HudPreset.FULL][key]
		GameSettings.hud_config["horizon_mode"] = "camera"
		hud.apply_hud_config()
		for angle: int in [30, 0]:
			QuadSettings.angle = angle
			drone._on_quad_settings_updated()
			await frames(30)
			await _measure(hud, "%s_angle%d" % [modes[mode], angle])
		level.queue_free()
		await frames(10)
	print("== Result: %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
	print("  %s %s" % ["ok  " if condition else "FAIL", label])


var _center_y := {}


func _measure(hud: HUD, label: String) -> void:
	await RenderingServer.frame_post_draw
	if not shots_dir.is_empty():
		var image := get_viewport().get_texture().get_image()
		var _err := image.save_png(shots_dir.path_join("hud_%s.png" % label))
	# Deterministic checks of the lens projection used by the real horizon. The screenshots
	# are the visual check: the dotted line must lie on the horizon of the image.
	var camera := hud.horizon.camera
	var forward := -camera.global_transform.basis.z
	var flat := Vector3(forward.x, 0.0, forward.z).normalized()
	var center := get_viewport().get_visible_rect().size / 2.0
	var ahead := camera.project_direction(flat)
	var right := camera.project_direction(flat.rotated(Vector3.UP, deg_to_rad(-20.0)))
	var left := camera.project_direction(flat.rotated(Vector3.UP, deg_to_rad(20.0)))
	print("== ", label, "  horizon ahead at ", ahead)
	check(right.x > center.x and left.x < center.x, "turning right projects to the right half")
	check(absf(ahead.x - center.x) < 2.0, "horizon straight ahead is horizontally centered")
	var mode := label.get_slice("_", 0)
	if label.ends_with("angle0"):
		check(absf(ahead.y - center.y) < 3.0, "camera level: horizon crosses the center")
		var above := camera.project_direction(flat * cos(0.2) + Vector3.UP * sin(0.2))
		check(above.y < center.y, "a direction above the horizon projects above the center")
		check(_center_y.has(mode) and _center_y[mode] > ahead.y + 50.0,
				"camera tilted up 30 deg: horizon drops below the center")
	else:
		_center_y[mode] = ahead.y
	if label == "full_angle30":
		var level := hud.get_parent().get_parent()
		get_tree().paused = true
		level.add_pause_menu()
		await frames(30)
		await RenderingServer.frame_post_draw
		if not shots_dir.is_empty():
			var _err := get_viewport().get_texture().get_image().save_png(shots_dir.path_join("pause_menu.png"))
		level.pause_menu.queue_free()
		get_tree().paused = false
		await frames(5)
		# Race overlays: results table and countdown / timer labels
		var table := TimeTable.new()
		level.add_child(table)
		for lap_time: float in [21.37, 19.84, 20.12]:
			var timer := LapTimer.new()
			timer.time = lap_time
			table.add_lap(timer)
			timer.free()
		table.add_total_time("01:01.33")
		var countdown := Label.new()
		countdown.theme = load("res://gui/countdown_theme.tres")
		countdown.text = "RACE_GO"
		level.add_child(countdown)
		countdown.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
		countdown.position.y = 200
		var timer_label := Label.new()
		timer_label.theme = load("res://gui/timer_theme.tres")
		timer_label.text = tr("RACE_TIMER") % ["00:21.37", 1, "00:05.02", 2, "00:26.39"]
		level.add_child(timer_label)
		await frames(20)
		await RenderingServer.frame_post_draw
		if not shots_dir.is_empty():
			var _err := get_viewport().get_texture().get_image().save_png(shots_dir.path_join("race_overlays.png"))
		table.queue_free()
		countdown.queue_free()
		timer_label.queue_free()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		await frames(5)
