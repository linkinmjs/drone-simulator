extends Node


signal hud_config_updated
signal game_settings_updated

enum HudPreset {MINIMAL, STANDARD, FULL, CUSTOM}

const LANGUAGES: Array[String] = ["es", "en"]
const HUD_BOOL_KEYS: Array[String] = ["crosshair", "horizon", "ladder", "speed", "altitude",
		"heading", "sticks", "rpm", "flight_mode", "rec", "side_tapes", "gate_marker"]
const HUD_PRESETS := [
	{"crosshair": true, "horizon": true, "ladder": false, "speed": false, "altitude": false,
			"heading": false, "sticks": false, "rpm": false, "flight_mode": true, "rec": true,
			"side_tapes": false, "gate_marker": false},
	{"crosshair": true, "horizon": true, "ladder": false, "speed": true, "altitude": true,
			"heading": true, "sticks": false, "rpm": false, "flight_mode": true, "rec": true,
			"side_tapes": true, "gate_marker": false},
	{"crosshair": true, "horizon": true, "ladder": true, "speed": true, "altitude": true,
			"heading": true, "sticks": true, "rpm": true, "flight_mode": true, "rec": true,
			"side_tapes": true, "gate_marker": true},
]

var game_settings_path := "%s/GameSettings.cfg" % [Global.config_dir]

var hud_config := {"fps": 10, "crosshair": true, "horizon": true, "ladder": false,
		"speed": true, "altitude": true, "heading": true, "sticks": false, "rpm": false,
		"flight_mode": true, "rec": true, "side_tapes": true, "gate_marker": false,
		"horizon_mode": "camera"}

var game_config := {"language": "", "nav_scheme": 0}


func _ready() -> void:
	# Apply the language as early as possible so the first screen is already translated
	load_game_settings()


func load_game_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(game_settings_path)
	if err == OK and config.has_section("game"):
		for key: String in game_config.keys():
			if config.has_section_key("game", key):
				game_config[key] = config.get_value("game", key)
	if not LANGUAGES.has(str(game_config["language"])):
		var system := OS.get_locale_language()
		game_config["language"] = system if LANGUAGES.has(system) else "es"
	apply_game_settings()


func save_game_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(game_settings_path)
	if err == OK or err == ERR_FILE_NOT_FOUND or err == ERR_PARSE_ERROR:
		for key: String in game_config.keys():
			config.set_value("game", key, game_config[key])
		var _discard := config.save(game_settings_path)
	else:
		Global.log_error(err, "Error while saving game settings.")
	game_settings_updated.emit()


func apply_game_settings() -> void:
	TranslationServer.set_locale(str(game_config["language"]))
	# StickNavigation is registered after this autoload: it reads the scheme itself
	# in its _ready, and later changes are pushed from here.
	var stick_navigation := get_node_or_null(^"/root/StickNavigation")
	if stick_navigation:
		stick_navigation.set(&"scheme", get_nav_scheme())


func get_nav_scheme() -> int:
	return clampi(int(game_config["nav_scheme"]), 0, 1)


func set_language(language: String) -> void:
	if not LANGUAGES.has(language):
		return
	game_config["language"] = language
	apply_game_settings()
	save_game_settings()


func set_nav_scheme(scheme: int) -> void:
	game_config["nav_scheme"] = scheme
	apply_game_settings()
	save_game_settings()


func load_hud_config() -> void:
	var config := ConfigFile.new()
	var text := ""
	var err := config.load(game_settings_path)
	if err == OK:
		var hud_section := "hud_config"
		if config.has_section(hud_section):
			for key in config.get_section_keys(hud_section):
				var value: Variant = config.get_value(hud_section, key)
				if hud_config.has(key):
					if key == "fps" and (value is int or value is float):
						hud_config[key] = clampf(value, 5, 60) as int
					elif key == "horizon_mode" and value is String:
						hud_config[key] = "attitude" if value == "attitude" else "camera"
					elif value is bool:
						hud_config[key] = value
		return
	elif err == ERR_PARSE_ERROR:
		Global.log_error(err, "Parse error while loading HUD config.")
		text = "ERR_SETTINGS_PARSE"
	elif err == ERR_FILE_NOT_FOUND:
		# First run: no settings file yet, write the defaults silently
		save_hud_config()
		return
	else:
		Global.log_error(err, "Error while loading HUD config.")
		text = "ERR_SETTINGS_OPEN"
	Global.show_error_popup(get_tree().root.get_children()[-1], text)


func save_hud_config() -> void:
	var config := ConfigFile.new()
	var err := config.load(game_settings_path)
	if err == OK or err == ERR_FILE_NOT_FOUND or err == ERR_PARSE_ERROR:
		for key: String in hud_config.keys():
			config.set_value("hud_config", key, hud_config[key])
		var _discard := config.save(game_settings_path)
		hud_config_updated.emit()
	else:
		Global.log_error(err, "Error while saving HUD config.")


func apply_hud_preset(preset: HudPreset) -> void:
	if preset < 0 or preset >= HUD_PRESETS.size():
		return
	var values: Dictionary = HUD_PRESETS[preset]
	for key: String in values:
		hud_config[key] = values[key]
	save_hud_config()


func get_hud_preset() -> HudPreset:
	for i in HUD_PRESETS.size():
		var values: Dictionary = HUD_PRESETS[i]
		var matches := true
		for key: String in values:
			if bool(hud_config[key]) != bool(values[key]):
				matches = false
				break
		if matches:
			return i as HudPreset
	return HudPreset.CUSTOM
