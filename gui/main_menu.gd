extends MenuScreen


const FREESTYLE_SCENE := "res://sceneries/freestyle_level.tscn"
const SANDBOX_SCENE := "res://sceneries/level1.tscn"
const TUTORIAL_SCENE := "res://sceneries/tutorial_level.tscn"

## Reveals the debug sandbox. Only directions: they move the focus and nothing else, so the
## sequence cannot press a button by accident. StickNavigation turns the radio sticks into the
## same ui_* actions, so it also works from the transmitter.
const SANDBOX_SEQUENCE: Array[StringName] = [&"ui_up", &"ui_up", &"ui_down", &"ui_down",
		&"ui_left", &"ui_right", &"ui_left", &"ui_right"]

var packed_challenges_menu := preload("res://gui/challenges_menu.tscn")
var packed_quad_settings_menu := preload("res://gui/quad_settings_menu.tscn")
var packed_options_menu := preload("res://gui/options_menu/options_menu.tscn")
var packed_help_page := preload("res://gui/help_page.tscn")

@onready var button_challenges := %ButtonChallenges as Button
@onready var button_tutorial := %ButtonTutorial as Button
@onready var button_freestyle := %ButtonFreestyle as Button
@onready var button_quad := %ButtonQuad as Button
@onready var button_help := %ButtonHelp as Button
@onready var button_options := %ButtonOptions as Button
@onready var button_quit := %ButtonQuit as Button
@onready var button_sandbox := %ButtonSandbox as Button
@onready var menu_container := %MenuColumn as Control

var _sequence_step := 0


func _ready() -> void:
	allow_back = false
	initial_focus = button_challenges
	super()
	var _discard := button_challenges.pressed.connect(_on_challenges_pressed)
	_discard = button_tutorial.pressed.connect(_on_tutorial_pressed)
	_discard = button_freestyle.pressed.connect(_on_freestyle_pressed)
	_discard = button_quad.pressed.connect(_on_quad_settings_pressed)
	_discard = button_help.pressed.connect(_on_help_pressed)
	_discard = button_options.pressed.connect(_on_options_pressed)
	_discard = button_quit.pressed.connect(_on_quit_pressed)
	_discard = button_sandbox.pressed.connect(_on_sandbox_pressed)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false

	Global.load_startup_settings()
	button_sandbox.visible = GameSettings.is_sandbox_unlocked()
	for error in Global.startup_errors:
		Global.show_error_popup(self, error)
	Global.startup_errors.clear()


func _input(event: InputEvent) -> void:
	super(event)
	if button_sandbox.visible or not event.is_pressed() or event.is_echo():
		return
	_track_sandbox_sequence(event)


func _track_sandbox_sequence(event: InputEvent) -> void:
	var expected := SANDBOX_SEQUENCE[_sequence_step]
	if event.is_action_pressed(expected):
		_sequence_step += 1
		if _sequence_step >= SANDBOX_SEQUENCE.size():
			_sequence_step = 0
			_reveal_sandbox()
		return
	# A wrong direction restarts the sequence, but it may already be its first step.
	_sequence_step = 0
	if event.is_action_pressed(SANDBOX_SEQUENCE[0]):
		_sequence_step = 1


func _reveal_sandbox() -> void:
	GameSettings.unlock_sandbox()
	button_sandbox.visible = true
	UI.play("click")
	button_sandbox.grab_focus()


func _on_challenges_pressed() -> void:
	open_submenu(packed_challenges_menu, menu_container)


func _on_tutorial_pressed() -> void:
	SceneTransition.change_scene(TUTORIAL_SCENE, true)


func _on_freestyle_pressed() -> void:
	SceneTransition.change_scene(FREESTYLE_SCENE, true)


func _on_sandbox_pressed() -> void:
	SceneTransition.change_scene(SANDBOX_SCENE, true)


func _on_quad_settings_pressed() -> void:
	open_submenu(packed_quad_settings_menu, menu_container)


func _on_help_pressed() -> void:
	open_submenu(packed_help_page, menu_container)


func _on_options_pressed() -> void:
	open_submenu(packed_options_menu, menu_container)


func _on_quit_pressed() -> void:
	if await UI.confirm("MENU_QUIT_CONFIRM", "MENU_QUIT", "UI_CANCEL", true):
		get_tree().quit()
