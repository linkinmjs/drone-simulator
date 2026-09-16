extends MenuScreen


var packed_quad_settings_menu := preload("res://gui/quad_settings_menu.tscn")
var packed_options_menu := preload("res://gui/options_menu/options_menu.tscn")
var packed_help_page := preload("res://gui/help_page.tscn")

@onready var button_fly := %ButtonFly as Button
@onready var button_tutorial := %ButtonTutorial as Button
@onready var button_quad := %ButtonQuad as Button
@onready var button_help := %ButtonHelp as Button
@onready var button_options := %ButtonOptions as Button
@onready var button_quit := %ButtonQuit as Button
@onready var menu_container := %MenuColumn as Control


func _ready() -> void:
	allow_back = false
	initial_focus = button_fly
	super()
	var _discard := button_fly.pressed.connect(_on_fly_pressed)
	_discard = button_tutorial.pressed.connect(_on_tutorial_pressed)
	_discard = button_quad.pressed.connect(_on_quad_settings_pressed)
	_discard = button_help.pressed.connect(_on_help_pressed)
	_discard = button_options.pressed.connect(_on_options_pressed)
	_discard = button_quit.pressed.connect(_on_quit_pressed)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false

	if Global.startup:
		Global.initialize()
		GameSettings.load_game_settings()
		var error := Graphics.load_graphics_settings()
		if error:
			Global.show_error_popup(self, error)
		error = Audio.load_audio_settings()
		if error:
			Global.show_error_popup(self, error)
		error = Controls.load_input_map(true)
		if error:
			Global.show_error_popup(self, error)


func _on_fly_pressed() -> void:
	SceneTransition.change_scene("res://sceneries/level1.tscn", true)


func _on_tutorial_pressed() -> void:
	SceneTransition.change_scene("res://sceneries/tutorial_level.tscn", true)


func _on_quad_settings_pressed() -> void:
	open_submenu(packed_quad_settings_menu, menu_container)


func _on_help_pressed() -> void:
	open_submenu(packed_help_page, menu_container)


func _on_options_pressed() -> void:
	open_submenu(packed_options_menu, menu_container)


func _on_quit_pressed() -> void:
	if await UI.confirm("MENU_QUIT_CONFIRM", "MENU_QUIT", "UI_CANCEL", true):
		get_tree().quit()
