extends Node
## Plays the studio card at startup and checks that it types the full name and then opens
## the main menu. With `--skip` it presses a key halfway through the typing instead.
##   godot --path . --windowed --resolution 1280x720 res://tools/boot_check.tscn -- --shots=<folder>


const BOOT_SCENE := "res://gui/boot/boot_sequence.tscn"
const TIMEOUT_MSEC := 8000

var shots_dir := ""
var press_skip := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
		elif arg == "--skip":
			press_skip = true
	# Survive the scene change: this node stops being the current scene
	get_tree().current_scene = null
	_run.call_deferred()


func _shot(file_name: String) -> void:
	if shots_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var _err := get_viewport().get_texture().get_image().save_png(shots_dir.path_join(file_name))


func _fail(message: String) -> void:
	push_error("boot_check: " + message)
	get_tree().quit(1)


func _run() -> void:
	var start := Time.get_ticks_msec()
	var err := get_tree().change_scene_to_file(BOOT_SCENE)
	if err != OK:
		_fail("could not open the boot scene (%s)" % error_string(err))
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var boot := get_tree().current_scene as BootSequence
	if boot == null:
		_fail("the current scene is not a BootSequence")
		return
	if Global.startup:
		_fail("the settings were not loaded before the card")
		return

	if press_skip:
		await get_tree().create_timer(0.6).timeout
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.physical_keycode = KEY_SPACE
		key.pressed = true
		Input.parse_input_event(key)
	else:
		while not boot.is_typing_done():
			if Time.get_ticks_msec() - start > TIMEOUT_MSEC:
				_fail("the name was never fully typed")
				return
			await get_tree().process_frame
		print("typed in %d ms: %s" % [Time.get_ticks_msec() - start, boot.terminal_text()])
		await _shot("boot_card.png")

	while not get_tree().current_scene or get_tree().current_scene.scene_file_path != "res://gui/main_menu.tscn":
		if Time.get_ticks_msec() - start > TIMEOUT_MSEC:
			_fail("the main menu never opened")
			return
		await get_tree().process_frame
	while SceneTransition.is_busy():
		await get_tree().process_frame
	print("main menu shown after %d ms" % [Time.get_ticks_msec() - start])
	await get_tree().create_timer(0.5).timeout
	await _shot("boot_menu.png")
	print("boot_check OK")
	get_tree().quit(0)
