class_name TutorialHUD
extends CanvasLayer
## Instructor overlay: lesson card (title, description, current task, progress, warnings,
## stick hints and shortcuts) plus a big message when a lesson is completed.
## It is a separate layer from the drone HUD, so it stays visible with every camera.
## Built in code, like the race overlays.


const CARD_POSITION := Vector2(56, 236)
const CARD_WIDTH := 560.0
const REFRESH_SECONDS := 0.1
const WARNING_COLOR := Color("#FFC04D")
const TASK_COLOR := Color("#9CC8FF")
const JOY_BUTTON_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
		JOY_BUTTON_BACK: "BACK", JOY_BUTTON_START: "START", JOY_BUTTON_LEFT_SHOULDER: "LB",
		JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3"}

var level: TutorialLevel = null

var _root: Control = null
var _card: PanelContainer = null
var _caption: Label = null
var _title: Label = null
var _objective: Label = null
var _task: Label = null
var _progress_bar: ProgressBar = null
var _progress_label: Label = null
var _warning: Label = null
var _sticks_row: HBoxContainer = null
var _stick_left: TutorialStickHint = null
var _stick_right: TutorialStickHint = null
var _shortcuts: HFlowContainer = null
var _flash: VBoxContainer = null
var _flash_title: Label = null
var _flash_subtitle: Label = null
var _flash_tween: Tween = null

var _refresh_time := 0.0
var _transient_warning := ""
var _transient_until_msec := 0
var _lesson_index := -1
var _lesson_total := 0
var _shortcuts_signature := ""


func setup(p_level: TutorialLevel) -> void:
	level = p_level


func _ready() -> void:
	layer = 1
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_card()
	_build_flash()
	_card.visible = false


# --- Construction --------------------------------------------------------------------------

func _label_settings(font_path: String, font_size: int, color := HUDDraw.WHITE, outline := 0) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = load(font_path) as Font
	settings.font_size = font_size
	settings.font_color = color
	if outline > 0:
		settings.outline_size = outline
		settings.outline_color = Color(0, 0, 0, 0.45)
	return settings


func _make_label(font_path: String, font_size: int, color := HUDDraw.WHITE, wrapped := true) -> Label:
	var label := Label.new()
	label.label_settings = _label_settings(font_path, font_size, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrapped:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(CARD_WIDTH - 48.0, 0)
	return label


func _build_card() -> void:
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.66)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(24)
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	_card.add_theme_stylebox_override(&"panel", style)
	_card.position = CARD_POSITION
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	_root.add_child(_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(vbox)

	_caption = _make_label(UIPalette.FONT_BOLD, 17, Color(HUDDraw.WHITE, 0.62), false)
	vbox.add_child(_caption)
	_title = _make_label(UIPalette.FONT_BOLD, 34)
	vbox.add_child(_title)
	_objective = _make_label(UIPalette.FONT_REGULAR, 21, Color(HUDDraw.WHITE, 0.86))
	vbox.add_child(_objective)

	var separator := ColorRect.new()
	separator.color = Color(1, 1, 1, 0.14)
	separator.custom_minimum_size = Vector2(0, 1)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(separator)

	_task = _make_label(UIPalette.FONT_BOLD, 25, TASK_COLOR)
	vbox.add_child(_task)

	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	_progress_bar.max_value = 1.0
	_progress_bar.step = 0.0
	_progress_bar.custom_minimum_size = Vector2(0, 8)
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(1, 1, 1, 0.14)
	background.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = TASK_COLOR
	fill.set_corner_radius_all(4)
	_progress_bar.add_theme_stylebox_override(&"background", background)
	_progress_bar.add_theme_stylebox_override(&"fill", fill)
	vbox.add_child(_progress_bar)

	_progress_label = _make_label(UIPalette.FONT_MONO, 20, Color(HUDDraw.WHITE, 0.9))
	vbox.add_child(_progress_label)

	_warning = _make_label(UIPalette.FONT_BOLD, 21, WARNING_COLOR)
	vbox.add_child(_warning)

	_sticks_row = HBoxContainer.new()
	_sticks_row.add_theme_constant_override(&"separation", 18)
	_sticks_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_sticks_row)
	_stick_left = _make_stick_column("TUT_STICK_LEFT")
	_stick_right = _make_stick_column("TUT_STICK_RIGHT")

	_shortcuts = HFlowContainer.new()
	_shortcuts.add_theme_constant_override(&"h_separation", 16)
	_shortcuts.add_theme_constant_override(&"v_separation", 6)
	_shortcuts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shortcuts.custom_minimum_size = Vector2(CARD_WIDTH - 48.0, 0)
	vbox.add_child(_shortcuts)


func _make_stick_column(caption_key: String) -> TutorialStickHint:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sticks_row.add_child(column)
	var hint := TutorialStickHint.new()
	column.add_child(hint)
	var caption := _make_label(UIPalette.FONT_REGULAR, 15, Color(HUDDraw.WHITE, 0.7), false)
	caption.text = caption_key
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	return hint


func _build_flash() -> void:
	_flash = VBoxContainer.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.add_theme_constant_override(&"separation", 6)
	_root.add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_flash.anchor_left = 0.0
	_flash.anchor_right = 1.0
	_flash.offset_left = 0
	_flash.offset_right = 0
	_flash.offset_top = 250
	_flash_title = Label.new()
	_flash_title.label_settings = _label_settings(UIPalette.FONT_BOLD, 64, HUDDraw.WHITE, 14)
	_flash_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.add_child(_flash_title)
	_flash_subtitle = Label.new()
	_flash_subtitle.label_settings = _label_settings(UIPalette.FONT_BOLD, 28, HUDDraw.WHITE, 8)
	_flash_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.add_child(_flash_subtitle)
	_flash.modulate.a = 0.0


# --- Public API ----------------------------------------------------------------------------

func show_lesson(index: int, total: int, step: TutorialStep) -> void:
	_lesson_index = index
	_lesson_total = total
	_card.visible = true
	_title.text = step.title_key
	_objective.text = step.objective_key
	_transient_warning = ""
	refresh()


func hide_lesson() -> void:
	_card.visible = false


func flash(title: String, subtitle := "", seconds := 2.4) -> void:
	_flash_title.text = title
	_flash_subtitle.text = subtitle
	_flash_subtitle.visible = not subtitle.is_empty()
	if _flash_tween:
		_flash_tween.kill()
	_flash.modulate.a = 0.0
	_flash_tween = create_tween()
	var _step1 := _flash_tween.tween_property(_flash, "modulate:a", 1.0, 0.18)
	var _step2 := _flash_tween.tween_interval(seconds)
	var _step3 := _flash_tween.tween_property(_flash, "modulate:a", 0.0, 0.4)


func flash_warning(key: String, seconds := 3.0) -> void:
	if _transient_warning != key or Time.get_ticks_msec() > _transient_until_msec:
		UI.play("error")
	_transient_warning = key
	_transient_until_msec = Time.get_ticks_msec() + int(seconds * 1000.0)
	refresh()


# --- Refresh -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _card.visible or level == null:
		return
	_update_sticks()
	_refresh_time += delta
	if _refresh_time >= REFRESH_SECONDS:
		_refresh_time = 0.0
		refresh()


func _update_sticks() -> void:
	var step := level.sequencer.get_current_step()
	var hint: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	if step and level.sequencer.is_running():
		hint = step.get_stick_hint()
	var input := level.radio.input
	# Same sticks as the radio (up is negative y). Pitch up means nose up, which is the
	# right stick pulled back, so it is drawn downward like in the flight HUD.
	_stick_left.set_values(Vector2(input.yaw, 1.0 - 2.0 * input.power), hint[0])
	_stick_right.set_values(Vector2(input.roll, input.pitch), hint[1])


func refresh() -> void:
	if level == null or _lesson_index < 0:
		return
	var sequencer := level.sequencer
	var step := sequencer.get_current_step()
	if step == null:
		return
	_caption.text = tr("TUT_LESSON_OF") % [_lesson_index + 1, _lesson_total]

	var succeeded := sequencer.state == TutorialSequencer.State.SUCCESS
	if succeeded:
		_task.text = tr("TUT_NEXT_SOON") if _lesson_index + 1 < _lesson_total else tr("TUT_LAST_DONE")
		_progress_bar.value = 1.0
		_progress_bar.visible = true
		_progress_label.text = ""
	else:
		_task.text = tr(step.get_task_text())
		var progress := step.get_progress()
		_progress_bar.visible = progress >= 0.0
		_progress_bar.value = clampf(progress, 0.0, 1.0)
		_progress_label.text = step.get_progress_text()
	_progress_label.visible = not _progress_label.text.is_empty()

	var warning := ""
	if not level.has_joypad():
		warning = "UI_NO_CONTROLLER_WEB" if OS.has_feature("web") else "TUT_WARN_NO_JOYPAD"
	elif not _transient_warning.is_empty() and Time.get_ticks_msec() <= _transient_until_msec:
		warning = _transient_warning
	elif not succeeded:
		warning = step.warning_key
	_warning.text = tr(warning) if not warning.is_empty() else ""
	_warning.visible = not warning.is_empty()

	var hint: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	if not succeeded:
		hint = step.get_stick_hint()
	_sticks_row.visible = not succeeded and (hint[0] != Vector2.ZERO or hint[1] != Vector2.ZERO)
	_update_shortcuts(succeeded)


func _update_shortcuts(succeeded: bool) -> void:
	var entries: Array = []
	if succeeded:
		entries.append([action_label(&"tutorial_next"), "TUT_KEY_NEXT"])
	entries.append([action_label(&"respawn"), "TUT_KEY_RESTART"])
	entries.append([action_label(&"tutorial_skip"), "TUT_KEY_SKIP"])
	entries.append([action_label(&"pause_menu"), "TUT_KEY_PAUSE"])
	var signature := "%s|%s" % [entries, TranslationServer.get_locale()]
	if signature == _shortcuts_signature:
		return
	_shortcuts_signature = signature
	for child in _shortcuts.get_children():
		child.queue_free()
	for entry: Array in entries:
		if str(entry[0]).is_empty():
			continue
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override(&"separation", 6)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key := Label.new()
		key.text = entry[0]
		key.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		key.label_settings = _label_settings(UIPalette.FONT_BOLD, 15, Color("#14181D"))
		var key_style := StyleBoxFlat.new()
		key_style.bg_color = Color(1, 1, 1, 0.9)
		key_style.set_corner_radius_all(5)
		key_style.content_margin_left = 7
		key_style.content_margin_right = 7
		key_style.content_margin_top = 1
		key_style.content_margin_bottom = 2
		key.add_theme_stylebox_override(&"normal", key_style)
		chip.add_child(key)
		var label := _make_label(UIPalette.FONT_REGULAR, 16, Color(HUDDraw.WHITE, 0.75), false)
		label.text = entry[1]
		chip.add_child(label)
		_shortcuts.add_child(chip)


## Name of the first binding of an action for the device in use (gamepad button name or key).
func action_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	# Flying with a gamepad only moves axes, so the last device kind may still say "mouse"
	var prefer_joypad := level != null and level.has_joypad() and UI.input_kind != UI.InputKind.KEYBOARD
	var key_text := ""
	var joy_text := ""
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and joy_text.is_empty():
			var index := (event as InputEventJoypadButton).button_index
			joy_text = JOY_BUTTON_NAMES.get(index, "B%d" % [index])
		elif event is InputEventKey and key_text.is_empty():
			var key_event := event as InputEventKey
			var code := key_event.keycode if key_event.keycode != KEY_NONE else key_event.physical_keycode
			key_text = OS.get_keycode_string(code)
	if prefer_joypad and not joy_text.is_empty():
		return joy_text
	return key_text if not key_text.is_empty() else joy_text
