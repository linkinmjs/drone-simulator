extends Node
## Flight instructor check, run as a scene so the autoloads exist:
##   godot --path . --windowed --resolution 1600x900 res://tools/tutorial_check.tscn -- --shots=<folder>
## Flies lessons 1 to 6 with simulated stick input (a small autopilot), triggers the gates of
## lesson 7 and the race of lesson 8 directly, and checks the menus and the pause entries.
## Nothing is saved: progress persistence is off and settings only change in memory.
## Exits with code 0 when every check passes.


const TIME_SCALE := 2.0
const AXES := [&"throttle_up", &"throttle_down", &"pitch_up", &"pitch_down", &"roll_left",
		&"roll_right", &"yaw_left", &"yaw_right"]

var failures := 0
var shots_dir := ""
var level: TutorialLevel = null
var fc: FlightController = null


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


func physics(count := 1) -> void:
	for _i in count:
		await get_tree().physics_frame


func shot(file_name: String) -> void:
	if shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(shots_dir.path_join(file_name))
	if err != OK:
		print("  could not save ", file_name, " (", err, ")")


func action(action_name: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action_name
	press.pressed = true
	press.strength = 1.0
	Input.parse_input_event(press)
	await frames(1)
	var release := InputEventAction.new()
	release.action = action_name
	release.pressed = false
	Input.parse_input_event(release)
	await frames(2)


## Sets a stick axis like the radio would: -1..1 between the negative and positive actions.
func set_axis(negative: StringName, positive: StringName, value: float) -> void:
	value = clampf(value, -1.0, 1.0)
	if value > 0.0:
		Input.action_release(negative)
		Input.action_press(positive, value)
	elif value < 0.0:
		Input.action_release(positive)
		Input.action_press(negative, -value)
	else:
		Input.action_release(negative)
		Input.action_release(positive)


func release_sticks() -> void:
	for axis: StringName in AXES:
		Input.action_release(axis)


## Throttle command that holds an altitude in Horizon mode (power = (stick + 1) / 2).
func hold_altitude(target: float) -> void:
	# The drone hovers with the throttle stick slightly below the center (power about 0.45)
	var command := -0.1 + (target - fc.pos.y) * 0.5 - fc.lin_vel.y * 0.4
	set_axis(&"throttle_down", &"throttle_up", clampf(command, -0.6, 1.0))


## Horizontal autopilot: pitch and roll toward a point, in the frame of the drone so a changed
## heading does not matter. Gentle and damped: abrupt reversals can tip Horizon mode past its
## recovery angle. Pitch down (stick up) flies forward, roll right flies right.
func fly_toward(target: Vector3, min_altitude: float, max_speed := 3.0) -> void:
	if fc.pos.y < min_altitude:
		set_axis(&"pitch_up", &"pitch_down", 0.0)
		set_axis(&"roll_left", &"roll_right", 0.0)
		return
	var to_target := (target - fc.pos).rotated(Vector3.UP, -fc.angles.y)
	var velocity := fc.lin_vel.rotated(Vector3.UP, -fc.angles.y)
	var forward_error := clampf(-to_target.z, -max_speed / 0.4, max_speed / 0.4)
	var right_error := clampf(to_target.x, -max_speed / 0.4, max_speed / 0.4)
	var forward := clampf((forward_error * 0.4 + velocity.z) * 0.08, -0.3, 0.3)
	var right := clampf((right_error * 0.4 - velocity.x) * 0.08, -0.3, 0.3)
	set_axis(&"pitch_up", &"pitch_down", forward)
	set_axis(&"roll_left", &"roll_right", right)


## Calls `control` every physics frame until `done` returns true or the timeout (seconds).
func fly_until(done: Callable, control: Callable, timeout: float) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < timeout * 1000.0 / TIME_SCALE * 1.5:
		control.call()
		await physics(1)
		if done.call():
			return true
	return false


## Like fly_until, but takes off again whenever the drone is disarmed (first takeoff or crash).
## Prints why the drone was disarmed, to tell test flakiness from real problems.
func fly_armed_until(done: Callable, control: Callable, timeout: float) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < timeout * 1000.0 / TIME_SCALE * 1.5:
		if not fc.state_armed:
			await arm()
			if not fc.state_armed:
				print("    arming refused: mode %s, power %.2f, pos %s" % [fc.flight_mode, fc.input.power, fc.pos])
				await physics(20)
			continue
		control.call()
		await physics(1)
		if done.call():
			return true
	print("    timeout: armed %s, mode %s, pos %s" % [fc.state_armed, fc.flight_mode, fc.pos])
	return false


func arm() -> void:
	release_sticks()
	set_axis(&"throttle_down", &"throttle_up", -1.0)
	await physics(3)
	level.radio.arm_input.emit()
	await physics(2)


func step_index() -> int:
	return level.sequencer.current_index


## Starts the lesson when a previous block failed to get there, so failures stay isolated.
func ensure_lesson(index: int) -> void:
	if step_index() != index:
		print("    (starting lesson %d directly)" % [index + 1])
		level.sequencer.start_at(index)
	await physics(10)


func wait_for_lesson(index: int, timeout := 6.0) -> bool:
	return await fly_until(func() -> bool: return step_index() == index, func() -> void: pass, timeout)


func new_level(show_start_menu: bool, first_lesson := 0) -> TutorialLevel:
	var instance := (load("res://sceneries/tutorial_level.tscn") as PackedScene).instantiate() as TutorialLevel
	instance.persist_progress = false
	instance.show_start_menu = show_start_menu
	instance.first_lesson = first_lesson
	# The drone looks for the Respawn node of the last child of the root
	get_tree().root.add_child(instance)
	await frames(20)
	return instance


func free_level() -> void:
	release_sticks()
	get_tree().paused = false
	level.queue_free()
	await frames(10)
	level = null


func _run() -> void:
	Global.startup = false
	Engine.time_scale = TIME_SCALE
	Engine.max_physics_steps_per_frame = 16
	StickNavigation.assume_joypad = true
	Graphics.graphics_settings["fisheye_mode"] = Graphics.FisheyeMode.OFF
	var saved_progress := GameSettings.tutorial_progress.duplicate()

	print("== Translations")
	TranslationServer.set_locale("en")
	check(tr("MENU_TUTORIAL") == "Flight instructor", "English MENU_TUTORIAL")
	TranslationServer.set_locale("es")
	check(tr("TUT_L1_TITLE") == "Tu control", "Spanish TUT_L1_TITLE")
	check(tr("TUT_L2_P_HOLD") % [1.5, 2.0, 3.0] != "", "formatted progress text")

	await _check_lessons()
	await _check_menus()

	GameSettings.tutorial_progress = saved_progress
	Engine.time_scale = 1.0
	print("== Result: %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _check_lessons() -> void:
	print("== Level setup")
	level = await new_level(false)
	fc = level.tutorial_drone.flight_controller
	check(level.sequencer.steps.size() == 8, "eight lessons")
	check(step_index() == 0, "starts on lesson 1")
	check(fc.flight_mode is FlightModeHorizon, "lesson 1 forces Horizon")
	check(not Global.race_mode_toggle_enabled, "R key disabled in the tutorial")
	var track := level.get_node("Track_Tutorial") as Track
	var visible_checkpoints := 0
	for checkpoint in track.checkpoints:
		if checkpoint.active:
			visible_checkpoints += 1
	check(visible_checkpoints == 0, "tutorial track checkpoints hidden before the race")
	await shot("tutorial_l1.png")

	print("== Lesson 1: controller")
	var l1 := level.sequencer.steps[0] as StepControllerCheck
	await physics(3)
	check(l1.phase == StepControllerCheck.Phase.THROTTLE_UP, "joypad detected")
	for pair: Array in [[&"throttle_down", &"throttle_up"]]:
		set_axis(pair[0], pair[1], 1.0)
		await physics(3)
		set_axis(pair[0], pair[1], -1.0)
		await physics(3)
	check(l1.phase == StepControllerCheck.Phase.YAW, "throttle up and down")
	for pair: Array in [[&"yaw_left", &"yaw_right"], [&"pitch_down", &"pitch_up"], [&"roll_left", &"roll_right"]]:
		set_axis(pair[0], pair[1], -1.0)
		await physics(3)
		set_axis(pair[0], pair[1], 1.0)
		await physics(3)
		set_axis(pair[0], pair[1], 0.0)
	check(l1.phase == StepControllerCheck.Phase.ARM, "sticks swept")
	await arm()
	check(l1.phase == StepControllerCheck.Phase.DISARM, "armed")
	level.radio.disarm_input.emit()
	await physics(3)
	check(level.sequencer.state == TutorialSequencer.State.SUCCESS, "lesson 1 completed")
	await action(&"tutorial_next")
	check(await wait_for_lesson(1), "tutorial_next moves to lesson 2")

	print("== Lesson 2: hover")
	var l2 := level.sequencer.steps[1] as StepHover
	await ensure_lesson(1)
	var held := await fly_armed_until(func() -> bool: return l2.phase == StepHover.Phase.LAND,
			func() -> void: hold_altitude(2.0), 25.0)
	check(held, "held the altitude band for %.0f s (altitude %.2f)" % [l2.hold_time, fc.pos.y])
	await shot("tutorial_l2.png")
	var landed := await fly_until(func() -> bool: return fc.pos.y < 0.25 and fc.lin_vel.length() < 0.3,
			func() -> void: set_axis(&"throttle_down", &"throttle_up", -0.3 if fc.pos.y > 0.6 else 0.0), 25.0)
	check(landed, "landed")
	level.radio.disarm_input.emit()
	await physics(3)
	check(level.sequencer.state == TutorialSequencer.State.SUCCESS, "lesson 2 completed")
	check(await wait_for_lesson(2, 8.0), "moves to lesson 3 by itself")

	print("== Lesson 3: yaw")
	var l3 := level.sequencer.steps[2] as StepYaw
	await ensure_lesson(2)
	var turned_left := await fly_armed_until(func() -> bool: return l3.phase == StepYaw.Phase.RIGHT,
			func() -> void:
				hold_altitude(1.6)
				set_axis(&"yaw_left", &"yaw_right", -0.3 if fc.pos.y > 1.0 else 0.0), 20.0)
	check(turned_left, "yaw_left turns left (turned %.0f deg)" % [rad_to_deg(l3.turned)])
	var turned_right := await fly_armed_until(func() -> bool: return level.sequencer.state == TutorialSequencer.State.SUCCESS,
			func() -> void:
				hold_altitude(1.6)
				set_axis(&"yaw_left", &"yaw_right", 0.3), 20.0)
	check(turned_right, "yaw_right turns right, lesson 3 completed")
	set_axis(&"yaw_left", &"yaw_right", 0.0)
	level.sequencer.confirm()
	check(await wait_for_lesson(3), "moves to lesson 4")

	print("== Lesson 4: pitch")
	await ensure_lesson(3)
	await _fly_zones(level.sequencer.steps[3] as StepReachZones, "pitch")
	level.sequencer.confirm()
	check(await wait_for_lesson(4), "moves to lesson 5")

	print("== Lesson 5: roll")
	await ensure_lesson(4)
	await _fly_zones(level.sequencer.steps[4] as StepReachZones, "roll")
	level.sequencer.confirm()
	check(await wait_for_lesson(5), "moves to lesson 6")

	print("== Lesson 6: gates in Horizon")
	var l6 := level.sequencer.steps[5] as StepGates
	await ensure_lesson(5)
	check(fc.pos.distance_to(Vector3(-30, 0, 8)) < 1.0, "respawned at the gate start")
	await frames(3)
	var active_count := 0
	for gate: Array in l6.gate_checkpoints:
		for checkpoint: Checkpoint in gate:
			if checkpoint.active:
				active_count += 1
	check(active_count == 2, "only the first gate is highlighted (%d active checkpoints)" % [active_count])
	var through := await _fly_gates(l6)
	check(through, "flew through the three gates (reached gate %d, pos %s)" % [l6.index + 1, fc.pos])
	await shot("tutorial_l6.png")
	release_sticks()
	level.sequencer.confirm()
	check(await wait_for_lesson(6), "moves to lesson 7")

	print("== Lesson 7: gates in Acro")
	var l7 := level.sequencer.steps[6] as StepGates
	await ensure_lesson(6)
	check(fc.flight_mode is FlightModeAcro, "lesson 7 forces Acro")
	level._on_mode_cycle_requested()
	check(fc.flight_mode is FlightModeAcro, "mode cycling refused")
	# Wrong gate first: nothing happens
	(l7.gate_checkpoints[1][0] as Checkpoint).passed.emit(l7.gate_checkpoints[1][0])
	check(l7.index == 0, "a gate out of order does not count")
	for gate: Array in l7.gate_checkpoints:
		(gate[1] as Checkpoint).passed.emit(gate[1])
	check(level.sequencer.state == TutorialSequencer.State.SUCCESS, "lesson 7 completed")

	print("== Pause menu entries")
	get_tree().paused = true
	level.add_pause_menu()
	await frames(5)
	var labels: Array[String] = []
	for child in level.pause_menu.menu_container.get_children():
		if child is Button:
			labels.append((child as Button).text)
	check(labels.has("TUT_PAUSE_SKIP") and labels.has("TUT_PAUSE_CHOOSE"), "tutorial entries in the pause menu")
	await shot("tutorial_pause.png")
	level._on_pause_skip()
	check(await wait_for_lesson(7, 10.0), "skip from the pause menu starts lesson 8")
	await fly_until(func() -> bool: return not get_tree().paused, func() -> void: pass, 5.0)

	print("== Lesson 8: race")
	var l8 := level.sequencer.steps[7] as StepRace
	await physics(20)
	check(Global.game_mode == Global.GameMode.RACE, "race mode on")
	check(Global.active_track == track, "tutorial track selected")
	check(fc.pos.distance_to(track.global_position + Vector3(0, 0, 10)) < 2.0, "drone on the launch pad")
	var started := await fly_until(func() -> bool: return track.race_state == Global.RaceState.RACE,
			func() -> void: pass, 12.0)
	check(started, "countdown reaches GO")
	await shot("tutorial_l8.png")
	var guard := 0
	while track.race_state == Global.RaceState.RACE and guard < 10:
		track.current_checkpoint.passed.emit(track.current_checkpoint)
		guard += 1
		await physics(2)
	check(track.race_state == Global.RaceState.END, "race finished after %d gates" % [guard])
	check(not l8.finished_time.is_empty(), "finish time recorded (%s)" % [l8.finished_time])
	var ended := await fly_until(func() -> bool: return level._menu_open, func() -> void: pass, 8.0)
	check(ended, "end menu shown")
	check(Global.game_mode == Global.GameMode.FREE, "race mode off after the last lesson")
	await frames(10)
	await shot("tutorial_end.png")
	await free_level()
	check(Global.race_mode_toggle_enabled, "R key enabled again after leaving")


func _fly_zones(step: StepReachZones, label: String) -> void:
	var respawns := 0
	var deadline := Time.get_ticks_msec() + int(60000.0 / TIME_SCALE * 1.5)
	while step.active and Time.get_ticks_msec() < deadline:
		if not fc.state_armed:
			# First takeoff, or the drone crashed and the lesson brought it back
			await arm()
			if not fc.state_armed:
				await physics(10)
			else:
				respawns += 1
			continue
		hold_altitude(1.5)
		var target := step.zones[mini(step.index, step.zones.size() - 1)]
		fly_toward(target.global_position, 1.2)
		await physics(1)
	release_sticks()
	var completed := level.sequencer.state == TutorialSequencer.State.SUCCESS
	check(completed, "%s lesson reaches the %d zones in order (%d takeoffs, zone %d, pos %s)" % [label,
			step.zones.size(), respawns, step.index + 1, fc.pos])


## Flies the gates of a lesson: line up 5 m in front of the current gate, then go straight
## through its upper opening (between 1.5 and 3 m). Takes off again after a crash.
func _fly_gates(step: StepGates) -> bool:
	var deadline := Time.get_ticks_msec() + int(90000.0 / TIME_SCALE * 1.5)
	var lined_up := false
	var last_index := -1
	while step.active and Time.get_ticks_msec() < deadline:
		if not fc.state_armed:
			await arm()
			if not fc.state_armed:
				await physics(10)
			lined_up = false
			continue
		if step.index != last_index:
			last_index = step.index
			lined_up = false
		var target := step.get_current_gate_position()
		if not target.is_finite():
			break
		hold_altitude(2.2)
		var approach := Vector3(target.x, 0.0, target.z + 5.0)
		if not lined_up:
			fly_toward(approach, 1.2, 2.0)
			var offset := Vector2(fc.pos.x - approach.x, fc.pos.z - approach.z)
			lined_up = offset.length() < 0.7 and absf(fc.pos.y - 2.2) < 0.4
		else:
			fly_toward(Vector3(target.x, 0.0, target.z - 6.0), 1.2, 2.5)
			if fc.pos.z < target.z - 4.0:
				# Went past without counting: try again from the front
				lined_up = false
		await physics(1)
	release_sticks()
	return level.sequencer.state == TutorialSequencer.State.SUCCESS


func _check_menus() -> void:
	print("== Start menu")
	GameSettings.tutorial_progress = {"completed": 7, "last_lesson": 3}
	UI.set_input_kind(UI.InputKind.KEYBOARD)
	level = await new_level(true)
	await frames(10)
	check(level._menu_open and get_tree().paused, "start menu open and game paused")
	await shot("tutorial_start_menu.png")
	if get_viewport().gui_get_focus_owner() == null:
		# First key press after the mouse only shows the focus
		await action(&"ui_down")
	var focus := get_viewport().gui_get_focus_owner() as Button
	check(focus != null and focus.text.contains("4"), "focus on 'continue with lesson 4' (%s)" % [focus.text if focus else "none"])
	await action(&"ui_down")
	await action(&"ui_accept")
	await frames(10)
	check(level._menu_open, "lesson picker open")
	await shot("tutorial_picker.png")
	await action(&"ui_cancel")
	await frames(15)
	check(level._menu_open and level.sequencer.current_index == -1, "back from the picker returns to the start menu")
	if get_viewport().gui_get_focus_owner() == null:
		await action(&"ui_down")
	await action(&"ui_accept")
	await fly_until(func() -> bool: return not get_tree().paused, func() -> void: pass, 5.0)
	check(level.sequencer.current_index == 3 and not get_tree().paused, "continue starts lesson 4 and resumes")
	await free_level()
