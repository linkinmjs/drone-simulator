extends PanelContainer
class_name TimeTable


const AUTO_CLOSE_SECONDS := 10.0

var vbox: VBoxContainer
var grid: GridContainer
var button: Button

var laps := 0


func _ready() -> void:
	theme_type_variation = &"Card"
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(420, 0)

	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 20)
	add_child(vbox)

	var title := Label.new()
	title.text = "RACE_RESULTS"
	title.theme_type_variation = &"HeadingLabel"
	vbox.add_child(title)

	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 48)
	grid.add_theme_constant_override(&"v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)

	button = Button.new()
	button.text = "RACE_DISMISS"
	button.theme_type_variation = &"PrimaryButton"
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	vbox.add_child(button)
	var _discard := button.pressed.connect(_on_button_pressed)

	add_labels("RACE_LAP", "RACE_TIME", true)

	_discard = Global.game_mode_changed.connect(_on_game_mode_changed)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# The table does not take the keyboard focus: Space / Enter keep arming and flying the
	# drone. It closes with the mouse, the gamepad B button or by itself.
	button.focus_mode = Control.FOCUS_NONE

	var timer := get_tree().create_timer(AUTO_CLOSE_SECONDS)
	_discard = timer.timeout.connect(_on_auto_close)


func _input(event: InputEvent) -> void:
	# Only the gamepad button: Escape must still open the pause menu
	var is_back_button := event is InputEventJoypadButton \
			and event.is_action_pressed(&"ui_cancel", false, true)
	if is_back_button and not get_tree().paused:
		get_viewport().set_input_as_handled()
		delete()


func add_lap(time: LapTimer) -> void:
	laps += 1
	add_labels("%d" % [laps], time.get_time_string())


func add_labels(lap: String, time: String, header := false) -> void:
	var label := Label.new()
	label.text = lap
	label.theme_type_variation = &"SectionLabel" if header else &"Label"
	grid.add_child(label)
	label = Label.new()
	label.text = time
	label.theme_type_variation = &"SectionLabel" if header else &"Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)


func add_total_time(time: String) -> void:
	var separator := HSeparator.new()
	grid.add_child(separator)
	grid.add_child(HSeparator.new())
	add_labels("RACE_TOTAL", time)


func delete() -> void:
	if is_queued_for_deletion():
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()


func _on_button_pressed() -> void:
	delete()


func _on_auto_close() -> void:
	if is_instance_valid(self) and is_inside_tree():
		delete()


func _on_game_mode_changed(mode: Global.GameMode) -> void:
	if mode != Global.GameMode.RACE:
		delete()


func _on_race_state_changed(state: int) -> void:
	if state == Global.RaceState.START:
		delete()
