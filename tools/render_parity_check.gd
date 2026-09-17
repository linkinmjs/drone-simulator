extends Node
## Compares what the desktop (Forward+) and web (Compatibility) renderers draw. Loads level1
## with every fisheye mode, holds the drone still above the ground and saves a screenshot plus
## the average luminance. Run it twice, once with --rendering-method gl_compatibility:
##   godot --path . --windowed --resolution 1280x720 res://tools/render_parity_check.tscn -- --shots=<folder>
## Add --mode=full|fast|off to capture a single fisheye mode, --fisheye-res=480p to change the
## resolution of the fisheye cameras, --sky=<id> to pick a SkyCatalog sky (default: the saved
## option) and --bench to also time 300 frames without vsync.
## Settings are only changed in memory, nothing is saved.


var shots_dir := ""
var only_mode := ""
var fisheye_res := ""
var bench := false
var sky := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
		elif arg.begins_with("--mode="):
			only_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--fisheye-res="):
			fisheye_res = arg.trim_prefix("--fisheye-res=")
		elif arg.begins_with("--sky="):
			sky = arg.trim_prefix("--sky=")
		elif arg == "--bench":
			bench = true
	_run.call_deferred()


func frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _run() -> void:
	Global.startup = false
	var renderer := "compat" if Graphics.is_compatibility_renderer() else "forward"
	if not fisheye_res.is_empty():
		Graphics.update_fisheye_resolution(fisheye_res)
	if not sky.is_empty():
		GameSettings.game_config["sky"] = sky
	if bench:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	var modes := {
		Graphics.FisheyeMode.FULL: "full",
		Graphics.FisheyeMode.FAST: "fast",
		Graphics.FisheyeMode.OFF: "off",
	}
	for mode: int in modes:
		if not only_mode.is_empty() and only_mode != modes[mode]:
			continue
		Graphics.graphics_settings["fisheye_mode"] = mode
		var level := (load("res://sceneries/level1.tscn") as PackedScene).instantiate()
		get_tree().root.add_child(level)
		var drone := level.get_node("Drone") as Drone
		drone.freeze = true
		drone.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(20.0)), Vector3(0.0, 3.0, 8.0))
		await frames(90)
		await RenderingServer.frame_post_draw
		var label := "%s_%s" % [renderer, modes[mode]]
		if not sky.is_empty():
			label += "_" + sky
		var image := get_viewport().get_texture().get_image()
		if not shots_dir.is_empty():
			var _err := image.save_png(shots_dir.path_join("parity_%s.png" % label))
		print("== %s  luminance %.3f" % [label, _luminance(image)])
		if bench:
			await frames(180)
			var start := Time.get_ticks_usec()
			await frames(300)
			print("   %s  %.2f ms/frame (fisheye %dp)" % [label,
					(Time.get_ticks_usec() - start) / 300000.0, Graphics.fisheye_resolution])
		level.queue_free()
		await frames(10)
	get_tree().quit()


func _luminance(image: Image) -> float:
	var small := image.duplicate() as Image
	small.resize(64, 36)
	var total := 0.0
	for y in small.get_height():
		for x in small.get_width():
			total += small.get_pixel(x, y).get_luminance()
	return total / (small.get_width() * small.get_height())
