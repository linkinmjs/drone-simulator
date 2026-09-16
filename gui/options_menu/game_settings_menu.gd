extends MenuScreen


const LANGUAGE_NAMES: Array[String] = ["Español", "English"]

@onready var button_back := %ButtonBack as Button
@onready var tab_container := %TabContainer as TabContainer
@onready var language_options := %LanguageOptions as OptionButton
@onready var nav_options := %NavOptions as OptionButton
@onready var nav_help := %NavHelp as Label


func _ready() -> void:
	initial_focus = language_options
	super()
	tab_container.set_tab_title(0, "GAME_TAB_GAMEPLAY")
	tab_container.set_tab_title(1, "GAME_TAB_HUD")

	for language_name in LANGUAGE_NAMES:
		language_options.add_item(language_name)
	language_options.select(maxi(GameSettings.LANGUAGES.find(str(GameSettings.game_config["language"])), 0))
	var _discard := language_options.item_selected.connect(_on_language_selected)

	nav_options.add_item("GAME_STICK_NAVIGATION_BETAFLIGHT")
	nav_options.add_item("GAME_STICK_NAVIGATION_YAW")
	nav_options.select(GameSettings.get_nav_scheme())
	_update_nav_help()
	_discard = nav_options.item_selected.connect(_on_nav_scheme_selected)

	bind_back_button(button_back)


func _on_language_selected(idx: int) -> void:
	GameSettings.set_language(GameSettings.LANGUAGES[idx])


func _on_nav_scheme_selected(idx: int) -> void:
	GameSettings.set_nav_scheme(idx)
	_update_nav_help()


func _update_nav_help() -> void:
	if GameSettings.get_nav_scheme() == StickNavigation.Scheme.YAW_SELECT:
		nav_help.text = "GAME_STICK_NAVIGATION_HELP_YAW"
	else:
		nav_help.text = "GAME_STICK_NAVIGATION_HELP_BETAFLIGHT"
