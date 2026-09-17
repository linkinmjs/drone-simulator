class_name TutorialLevel
extends Level
## Flight instructor: a small level with eight progressive lessons (see docs/tutorial.md).
## It reuses everything from Level (cameras, pause, tracks, race mode) and adds the lesson
## sequencer, the instructor overlay and the start / lesson picker / end menus.


const MAIN_MENU_SCENE := "res://gui/main_menu.tscn"
const FREE_FLIGHT_SCENE := "res://sceneries/level1.tscn"
## Below this height the drone left the ground area and keeps falling: bring it back.
const OUT_OF_BOUNDS_ALTITUDE := -3.0

## Tests turn these off: no saved progress and no start menu
@export var persist_progress := true
@export var show_start_menu := true
## Lesson started directly when the start menu is off (0 based)
@export var first_lesson := 0

@onready var tutorial_drone := $Drone as Drone
@onready var radio := $RadioController as RadioController
@onready var sequencer := $TutorialSequencer as TutorialSequencer
@onready var tutorial_hud := $TutorialHUD as TutorialHUD
@onready var respawn_point := $Respawn as Node3D

var _menu_layer: CanvasLayer = null
var _menu_open := false
var _respawn_pending := false


func _ready() -> void:
	super()
	Global.race_mode_toggle_enabled = false
	Global.active_track = null
	Global.game_mode = Global.GameMode.FREE

	var fc := tutorial_drone.flight_controller
	# Mode cycling goes through the level so a lesson can refuse it
	if radio.mode_changed.is_connected(fc._on_cycle_flight_modes):
		radio.mode_changed.disconnect(fc._on_cycle_flight_modes)
	var _discard := radio.mode_changed.connect(_on_mode_cycle_requested)
	_discard = fc.arm_failed.connect(_on_arm_failed)

	tutorial_hud.setup(self)
	sequencer.setup(self)
	_discard = sequencer.lesson_started.connect(_on_lesson_started)
	_discard = sequencer.lesson_succeeded.connect(_on_lesson_succeeded)
	_discard = sequencer.lesson_skipped.connect(_on_lesson_skipped)
	_discard = sequencer.tutorial_finished.connect(_on_tutorial_finished)

	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 10
	_menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_menu_layer)

	if persist_progress:
		GameSettings.load_tutorial_progress()
	# The track checkpoints build their meshes deferred and show them: hide them afterwards
	_update_track_checkpoints.call_deferred()
	_begin.call_deferred()


func _exit_tree() -> void:
	_leave_tutorial()


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if get_tree().paused or _menu_open:
		return
	if event.is_action_pressed(&"tutorial_next", false, true):
		sequencer.confirm()
	elif event.is_action_pressed(&"tutorial_skip", false, true):
		sequencer.skip_current()


func _physics_process(_delta: float) -> void:
	if tutorial_drone.global_position.y < OUT_OF_BOUNDS_ALTITUDE and not _respawn_pending:
		_respawn_pending = true
		tutorial_hud.flash_warning("TUT_WARN_OUT_OF_BOUNDS")
		respawn_drone()


func _begin() -> void:
	# Wait for the loading screen to go away before asking anything
	while SceneTransition.is_busy():
		await get_tree().process_frame
	if not show_start_menu:
		sequencer.start_at(first_lesson)
		return
	_open_start_menu()


func has_joypad() -> bool:
	return StickNavigation.assume_joypad or not Input.get_connected_joypads().is_empty()


func lesson_count() -> int:
	return sequencer.steps.size()


# --- Helpers used by the lessons -----------------------------------------------------------

func set_flight_mode(mode: FlightMode.Type) -> void:
	tutorial_drone.flight_controller.select_flight_mode(mode)


func set_respawn_transform(xform: Transform3D) -> void:
	respawn_point.global_transform = xform


func respawn_drone() -> void:
	tutorial_drone.reset()


# --- Level overrides -----------------------------------------------------------------------

func _on_drone_reset() -> void:
	_respawn_pending = false
	super()
	sequencer.on_drone_respawned()
	_update_track_checkpoints()


func add_pause_menu() -> void:
	super()
	tutorial_hud.visible = false
	var _discard := pause_menu.resumed.connect(func() -> void: tutorial_hud.visible = true)
	var column := pause_menu.menu_container
	var position_in_column := pause_menu.button_resume.get_index() + 1
	for entry: Array in [["TUT_PAUSE_RESTART", _on_pause_restart], ["TUT_PAUSE_SKIP", _on_pause_skip],
			["TUT_PAUSE_CHOOSE", _on_pause_choose]]:
		var button := Button.new()
		button.text = entry[0]
		button.theme_type_variation = &"MenuItemButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		column.add_child(button)
		column.move_child(button, position_in_column)
		position_in_column += 1
		_discard = button.pressed.connect(entry[1])


func _on_return_to_menu() -> void:
	_leave_tutorial()
	super()


func _leave_tutorial() -> void:
	Global.race_mode_toggle_enabled = true
	if Global.game_mode != Global.GameMode.FREE:
		Global.game_mode = Global.GameMode.FREE
	Global.active_track = null


## Only the race lesson uses the tutorial track: elsewhere its checkpoints stay hidden and
## inactive, so flying through them does nothing.
func _update_track_checkpoints() -> void:
	if sequencer.get_current_step() is StepRace and sequencer.state != TutorialSequencer.State.IDLE:
		return
	for track in tracks:
		for checkpoint in track.checkpoints:
			checkpoint.active = false


# --- Sequencer events ----------------------------------------------------------------------

func _on_lesson_started(index: int) -> void:
	tutorial_hud.show_lesson(index, lesson_count(), sequencer.steps[index])
	_update_track_checkpoints.call_deferred()
	if persist_progress:
		GameSettings.set_tutorial_last_lesson(index + 1)


func _on_lesson_succeeded(index: int) -> void:
	UI.play("click")
	tutorial_hud.flash(tr("TUT_WELL_DONE"), sequencer.steps[index].get_success_text())
	if persist_progress:
		GameSettings.mark_lesson_completed(index + 1)


func _on_lesson_skipped(_index: int) -> void:
	tutorial_hud.flash(tr("TUT_SKIPPED"), "", 1.2)


func _on_tutorial_finished() -> void:
	tutorial_hud.hide_lesson()
	# A skip from the pause menu may still be resuming the game
	while get_tree().paused and not _menu_open:
		await get_tree().process_frame
	_open_end_menu()


func _on_mode_cycle_requested() -> void:
	var step := sequencer.get_current_step()
	if sequencer.is_running() and step and step.block_mode_cycling:
		tutorial_hud.flash_warning("TUT_WARN_MODE_LOCKED")
		return
	tutorial_drone.flight_controller._on_cycle_flight_modes()


func _on_arm_failed(reason: FlightController.ArmFail) -> void:
	if reason == FlightController.ArmFail.THROTTLE_HIGH:
		tutorial_hud.flash_warning("TUT_WARN_THROTTLE_HIGH")


# --- Pause menu entries --------------------------------------------------------------------

func _on_pause_restart() -> void:
	pause_menu.unpause_game()
	sequencer.restart_current()


func _on_pause_skip() -> void:
	pause_menu.unpause_game()
	sequencer.skip_current()


func _on_pause_choose() -> void:
	# Keep the game paused: swap the pause menu for the lesson picker
	pause_menu.queue_free()
	pause_menu = null
	if not await _open_lesson_picker():
		add_pause_menu()


# --- Menus ---------------------------------------------------------------------------------

func _show_menu(title: String, subtitle: String, entries: Array[Dictionary], back_id := "") -> String:
	_menu_open = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	tutorial_hud.visible = false
	var menu := ChoiceMenu.new()
	menu.setup(title, subtitle, entries, back_id)
	_menu_layer.add_child(menu)
	var id: String = await menu.chosen
	menu.queue_free()
	_menu_open = false
	return id


## Resumes the flight once the button or stick used in the menu is released, so it does not
## reach the drone (A cycles the flight modes, a roll gesture would bank the drone).
func _resume_from_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	tutorial_hud.visible = true
	await get_tree().process_frame
	while is_inside_tree() and _resume_input_held():
		await get_tree().process_frame
	if is_inside_tree() and not _menu_open:
		get_tree().paused = false


func _start_lesson(index: int) -> void:
	sequencer.start_at(index)
	_resume_from_menu()


func _open_start_menu() -> void:
	var total := lesson_count()
	var first := GameSettings.get_first_incomplete_lesson(total)
	var entries: Array[Dictionary] = []
	var subtitle := tr("TUT_MENU_SUBTITLE") % [total]
	if not GameSettings.has_tutorial_progress():
		entries.append({"id": "start", "text": tr("TUT_MENU_START"), "primary": true})
	elif first <= total:
		subtitle = tr("TUT_MENU_PROGRESS") % [GameSettings.get_completed_lesson_count(total), total]
		entries.append({"id": "continue", "primary": true,
				"text": tr("TUT_MENU_CONTINUE") % [first, tr(sequencer.steps[first - 1].title_key)]})
	else:
		subtitle = tr("TUT_MENU_ALL_DONE")
		entries.append({"id": "free_flight", "text": tr("TUT_MENU_FREE_FLIGHT"), "primary": true})
	entries.append({"id": "choose", "text": tr("TUT_MENU_CHOOSE")})
	if GameSettings.has_tutorial_progress():
		entries.append({"id": "restart", "text": tr("TUT_MENU_RESTART")})
	entries.append({"id": "menu", "text": tr("MENU_RETURN_TO_MAIN")})

	var id := await _show_menu(tr("TUT_MENU_TITLE"), subtitle, entries)
	match id:
		"start":
			_start_lesson(0)
		"continue":
			_start_lesson(first - 1)
		"restart":
			if persist_progress:
				GameSettings.reset_tutorial_progress()
			_start_lesson(0)
		"choose":
			if not await _open_lesson_picker():
				_open_start_menu()
		"free_flight":
			_go_to(FREE_FLIGHT_SCENE, true)
		_:
			_go_to(MAIN_MENU_SCENE, false)


## Returns true when a lesson was started.
func _open_lesson_picker() -> bool:
	var entries: Array[Dictionary] = []
	var current := sequencer.current_index
	for i in lesson_count():
		var text := tr("TUT_PICK_ENTRY") % [i + 1, tr(sequencer.steps[i].title_key)]
		if GameSettings.is_lesson_completed(i + 1):
			text += "   " + tr("TUT_PICK_DONE")
		entries.append({"id": str(i), "text": text, "primary": i == maxi(current, 0)})
	entries.append({"id": "back", "text": tr("UI_BACK")})
	var id := await _show_menu(tr("TUT_PICK_TITLE"), tr("TUT_PICK_SUBTITLE"), entries, "back")
	if id == "back":
		return false
	_start_lesson(int(id))
	return true


func _open_end_menu() -> void:
	var entries: Array[Dictionary] = [
		{"id": "free_flight", "text": tr("TUT_MENU_FREE_FLIGHT"), "primary": true},
		{"id": "choose", "text": tr("TUT_MENU_CHOOSE")},
		{"id": "restart", "text": tr("TUT_MENU_REPEAT")},
		{"id": "menu", "text": tr("MENU_RETURN_TO_MAIN")},
	]
	var id := await _show_menu(tr("TUT_END_TITLE"), tr("TUT_END_SUBTITLE"), entries)
	match id:
		"free_flight":
			_go_to(FREE_FLIGHT_SCENE, true)
		"choose":
			if not await _open_lesson_picker():
				_open_end_menu()
		"restart":
			_start_lesson(0)
		_:
			_go_to(MAIN_MENU_SCENE, false)


func _go_to(path: String, show_loading: bool) -> void:
	sequencer.stop_current()
	_leave_tutorial()
	# The free flight level does not unpause the tree by itself (the main menu does)
	get_tree().paused = false
	SceneTransition.change_scene(path, show_loading)
