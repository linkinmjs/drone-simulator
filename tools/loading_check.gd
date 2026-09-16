extends Node
## Runs the real menu → level transition with the loading screen and reports how long it
## took and the longest frames right after the flight is revealed.
##   godot --path . --rendering-method gl_compatibility --windowed --resolution 1280x720 res://tools/loading_check.tscn -- --shots=<folder>


var shots_dir := ""
## `--plain`: old behavior (fade only, no loading screen or warm-up) for comparison
var plain := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
		elif arg == "--plain":
			plain = true
	# Survive the scene change: this node stops being the current scene
	get_tree().current_scene = null
	Global.startup = false
	_run.call_deferred()


func _shot(file_name: String) -> void:
	if shots_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var _err := get_viewport().get_texture().get_image().save_png(shots_dir.path_join(file_name))


func _run() -> void:
	var start := Time.get_ticks_msec()
	SceneTransition.change_scene("res://sceneries/level1.tscn", not plain)
	await get_tree().create_timer(0.4).timeout
	await _shot("loading_screen.png")
	while SceneTransition.is_busy():
		await get_tree().process_frame
	var revealed := Time.get_ticks_msec()
	print("loading screen visible for %d ms" % [revealed - start])

	var worst := 0.0
	var hitches := 0
	var last := Time.get_ticks_usec()
	var end := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var frame_ms := (now - last) / 1000.0
		last = now
		worst = maxf(worst, frame_ms)
		if frame_ms > 70.0:
			hitches += 1
	print("after reveal (3 s): worst frame %.1f ms, frames over 70 ms: %d" % [worst, hitches])
	await _shot("after_loading.png")
	get_tree().quit(0)
