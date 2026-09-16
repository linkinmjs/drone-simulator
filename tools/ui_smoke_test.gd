extends Node
## Interface smoke test, run as a scene so the autoloads exist:
##   godot --path . --windowed --resolution 1280x720 res://tools/ui_smoke_test.tscn
## Add `-- --shots=<folder>` to also save a screenshot of every screen.
## Exits with code 0 when every check passes.


var failures := 0
var shots_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)


func frames(count := 2) -> void:
	for _i in count:
		await get_tree().process_frame


func action(name: StringName) -> void:
	var press := InputEventAction.new()
	press.action = name
	press.pressed = true
	press.strength = 1.0
	Input.parse_input_event(press)
	await frames(1)
	var release := InputEventAction.new()
	release.action = name
	release.pressed = false
	Input.parse_input_event(release)
	await frames(2)


func focus_name() -> String:
	var focus := get_viewport().gui_get_focus_owner()
	return str(focus.name) if focus else "<none>"


func shot(file_name: String) -> void:
	if shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(shots_dir.path_join(file_name))
	if err != OK:
		print("  could not save ", file_name, " (", err, ")")


func find_child_of_type(root: Node, script_path: String) -> Node:
	for child in root.get_children():
		var script := child.get_script() as Script
		if script and script.resource_path == script_path:
			return child
		var found := find_child_of_type(child, script_path)
		if found:
			return found
	return null


func _run() -> void:
	print("== Translations")
	TranslationServer.set_locale("en")
	check(tr("MENU_FLY") == "Fly", "English MENU_FLY")
	TranslationServer.set_locale("es")
	check(tr("MENU_FLY") == "Volar", "Spanish MENU_FLY")

	print("== Main menu with keyboard / gamepad actions")
	# Do not apply the user's saved window / input settings during the test
	Global.startup = false
	var menu :=(load("res://gui/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await frames(20)
	UI.set_input_kind(UI.InputKind.KEYBOARD)
	await action(&"ui_down")
	check(focus_name() == "ButtonFly", "first navigation press shows the focus on Fly (got %s)" % focus_name())
	await action(&"ui_down")
	check(focus_name() == "ButtonQuad", "ui_down moves to Quad settings (got %s)" % focus_name())
	await shot("01_main_menu.png")
	await action(&"ui_down")
	check(focus_name() == "ButtonOptions", "ui_down moves to Options (got %s)" % focus_name())
	await action(&"ui_accept")
	await frames(20)
	var options := find_child_of_type(menu, "res://gui/options_menu/options_menu.gd")
	check(options != null, "ui_accept opens the options menu")
	check(focus_name() == "ButtonGame", "options menu grabs its initial focus (got %s)" % focus_name())
	await shot("02_options.png")

	print("== Sub screens")
	var screens := {
		"ButtonGame": ["res://gui/options_menu/game_settings_menu.gd", "03_game.png"],
		"ButtonGraphics": ["res://gui/options_menu/graphics_menu.gd", "04_graphics.png"],
		"ButtonAudio": ["res://gui/options_menu/audio_menu.gd", "05_audio.png"],
		"ButtonControls": ["res://gui/options_menu/controls_menu/controls_menu.gd", "06_controls.png"],
	}
	for button_name: String in screens:
		var button := options.find_child(button_name, true, false) as Button
		button.grab_focus()
		await action(&"ui_accept")
		await frames(25)
		var sub := find_child_of_type(menu, screens[button_name][0])
		check(sub != null and sub.is_visible_in_tree(), "%s opens its screen" % button_name)
		check(get_viewport().gui_get_focus_owner() != null, "%s screen has focus (%s)" % [button_name, focus_name()])
		await shot(screens[button_name][1])
		if button_name == "ButtonGame":
			var tabs := sub.find_child("TabContainer", true, false) as TabContainer
			tabs.current_tab = 1
			await frames(30)
			await shot("03b_hud_settings.png")
			tabs.current_tab = 0
		await action(&"ui_cancel")
		await frames(25)
		check(not is_instance_valid(sub) or sub.is_queued_for_deletion() or not sub.is_inside_tree(),
				"ui_cancel closes %s" % button_name)
		check(focus_name() == button_name, "focus returns to %s (got %s)" % [button_name, focus_name()])

	await action(&"ui_cancel")
	await frames(25)
	check(not is_instance_valid(options) or not options.is_inside_tree(), "ui_cancel closes options")
	check(focus_name() == "ButtonOptions", "focus returns to Options (got %s)" % focus_name())

	print("== Quad settings and help")
	for button_name: String in ["ButtonQuad", "ButtonHelp"]:
		var button := menu.find_child(button_name, true, false) as Button
		button.grab_focus()
		await action(&"ui_accept")
		await frames(25)
		await shot("07_%s.png" % button_name.to_lower())
		check(get_viewport().gui_get_focus_owner() != null, "%s screen has focus (%s)" % [button_name, focus_name()])
		await action(&"ui_cancel")
		await frames(25)
		check(focus_name() == button_name, "focus returns to %s (got %s)" % [button_name, focus_name()])

	print("== Confirm overlay")
	var result := {"value": null}
	var ask := func() -> void:
		result["value"] = await UI.confirm("MENU_QUIT_CONFIRM", "MENU_QUIT", "UI_CANCEL", true)
	ask.call()
	await frames(10)
	check(focus_name() == "@Button@" or focus_name().begins_with("@Button") or UI.has_modal(), "overlay open")
	var focus := get_viewport().gui_get_focus_owner() as Button
	check(focus != null and focus.text == "UI_CANCEL", "overlay focuses Cancel")
	await shot("08_confirm.png")
	await action(&"ui_cancel")
	await frames(20)
	check(result["value"] == false, "ui_cancel answers false")
	check(not UI.has_modal(), "overlay closed")

	print("== Stick navigation (Betaflight scheme)")
	StickNavigation.assume_joypad = true
	StickNavigation.scheme = StickNavigation.Scheme.BETAFLIGHT
	(menu.find_child("ButtonFly", true, false) as Button).grab_focus()
	await frames(5)
	Input.action_press(&"pitch_down", 1.0)
	await frames(4)
	check(focus_name() == "ButtonQuad", "pitch down moves the focus down (got %s)" % focus_name())
	await get_tree().create_timer(0.5).timeout
	check(focus_name() != "ButtonQuad", "holding pitch repeats (got %s)" % focus_name())
	Input.action_release(&"pitch_down")
	await frames(4)
	var after_release := focus_name()
	await frames(20)
	check(focus_name() == after_release, "releasing pitch stops the navigation")
	(menu.find_child("ButtonOptions", true, false) as Button).grab_focus()
	await frames(3)
	Input.action_press(&"roll_right", 1.0)
	await frames(6)
	Input.action_release(&"roll_right")
	await frames(25)
	options = find_child_of_type(menu, "res://gui/options_menu/options_menu.gd")
	check(options != null, "roll right accepts (opens options)")
	Input.action_press(&"roll_left", 1.0)
	await frames(6)
	Input.action_release(&"roll_left")
	await frames(25)
	check(not is_instance_valid(options) or not options.is_inside_tree(), "roll left goes back")
	Input.action_press(&"throttle_down", 1.0)
	await frames(30)
	check(focus_name() == "ButtonOptions", "throttle never navigates (got %s)" % focus_name())
	Input.action_release(&"throttle_down")
	StickNavigation.assume_joypad = false

	print("== Result: %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
