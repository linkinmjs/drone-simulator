extends Node


signal hud_config_updated
signal game_settings_updated
signal tutorial_progress_updated
signal challenge_progress_updated

enum HudPreset {MINIMAL, STANDARD, FULL, CUSTOM}

const LANGUAGES: Array[String] = ["es", "en"]
const SKY_RANDOM := "random"
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

## `sky`: "random" or a SkyCatalog id. `sandbox_unlocked`: the debug level was revealed
## with the secret sequence of the main menu.
var game_config := {"language": "", "nav_scheme": 0, "sky": SKY_RANDOM,
		"sandbox_unlocked": false}

## Flight instructor progress. `completed` is a bit mask: bit 0 = lesson 1.
var tutorial_progress := {"completed": 0, "last_lesson": 1}

## Best time of each finished challenge, in seconds, by challenge id. A challenge with no
## entry here was never finished, which is also what keeps the next one locked.
var challenge_progress := {}

## Last sky drawn by "random", so the next flight gets a different one
var _last_random_sky := ""


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


## "random" or a SkyCatalog id; anything unknown counts as random.
func get_sky_choice() -> String:
	var choice := str(game_config["sky"])
	return choice if SkyCatalog.has_sky(choice) else SKY_RANDOM


func set_sky(choice: String) -> void:
	game_config["sky"] = choice if SkyCatalog.has_sky(choice) else SKY_RANDOM
	save_game_settings()


## The sky for the level being loaded. A random choice never repeats the previous draw.
func pick_sky() -> String:
	var choice := get_sky_choice()
	if choice != SKY_RANDOM:
		return choice
	var ids := SkyCatalog.get_ids()
	if ids.size() > 1 and ids.has(_last_random_sky):
		ids.remove_at(ids.find(_last_random_sky))
	_last_random_sky = ids[randi() % ids.size()]
	return _last_random_sky


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


func load_tutorial_progress() -> void:
	var config := ConfigFile.new()
	var err := config.load(game_settings_path)
	if err == OK:
		for key: String in tutorial_progress.keys():
			var value: Variant = config.get_value("tutorial", key, tutorial_progress[key])
			if value is int or value is float:
				tutorial_progress[key] = maxi(int(value), 0)
	elif err != ERR_FILE_NOT_FOUND:
		Global.log_error(err, "Error while loading the tutorial progress.")


func save_tutorial_progress() -> void:
	var _dir_err := DirAccess.make_dir_recursive_absolute(Global.config_dir)
	var config := ConfigFile.new()
	var err := config.load(game_settings_path)
	if err == OK or err == ERR_FILE_NOT_FOUND or err == ERR_PARSE_ERROR:
		for key: String in tutorial_progress.keys():
			config.set_value("tutorial", key, tutorial_progress[key])
		err = config.save(game_settings_path)
		if err != OK:
			Global.log_error(err, "Error while saving the tutorial progress.")
	else:
		Global.log_error(err, "Error while saving the tutorial progress.")
	tutorial_progress_updated.emit()


## Lessons are numbered from 1.
func is_lesson_completed(lesson: int) -> bool:
	return ((int(tutorial_progress["completed"]) >> (lesson - 1)) & 1) == 1


func mark_lesson_completed(lesson: int) -> void:
	tutorial_progress["completed"] = int(tutorial_progress["completed"]) | (1 << (lesson - 1))
	tutorial_progress["last_lesson"] = lesson
	save_tutorial_progress()


func set_tutorial_last_lesson(lesson: int) -> void:
	if int(tutorial_progress["last_lesson"]) == lesson:
		return
	tutorial_progress["last_lesson"] = lesson
	save_tutorial_progress()


func has_tutorial_progress() -> bool:
	return int(tutorial_progress["completed"]) != 0


func get_completed_lesson_count(total: int) -> int:
	var count := 0
	for lesson in range(1, total + 1):
		if is_lesson_completed(lesson):
			count += 1
	return count


## First lesson not completed yet, or `total + 1` when every lesson is done.
func get_first_incomplete_lesson(total: int) -> int:
	for lesson in range(1, total + 1):
		if not is_lesson_completed(lesson):
			return lesson
	return total + 1


func reset_tutorial_progress() -> void:
	tutorial_progress["completed"] = 0
	tutorial_progress["last_lesson"] = 1
	save_tutorial_progress()


func load_challenge_progress() -> void:
	challenge_progress.clear()
	var config := ConfigFile.new()
	var err := config.load(game_settings_path)
	if err == OK and config.has_section("challenges"):
		for key: String in config.get_section_keys("challenges"):
			if not key.begins_with("best_"):
				continue
			var value: Variant = config.get_value("challenges", key)
			if value is float or value is int:
				var time := float(value)
				if time > 0.0:
					challenge_progress[key.trim_prefix("best_")] = time
	elif err != OK and err != ERR_FILE_NOT_FOUND:
		Global.log_error(err, "Error while loading the challenge progress.")


func save_challenge_progress() -> void:
	var _dir_err := DirAccess.make_dir_recursive_absolute(Global.config_dir)
	var config := ConfigFile.new()
	var err := config.load(game_settings_path)
	if err == OK or err == ERR_FILE_NOT_FOUND or err == ERR_PARSE_ERROR:
		if config.has_section("challenges"):
			config.erase_section("challenges")
		for id: String in challenge_progress.keys():
			config.set_value("challenges", "best_%s" % [id], float(challenge_progress[id]))
		err = config.save(game_settings_path)
		if err != OK:
			Global.log_error(err, "Error while saving the challenge progress.")
	else:
		Global.log_error(err, "Error while saving the challenge progress.")
	challenge_progress_updated.emit()


## Best time of a challenge in seconds, or 0.0 when it was never finished.
func get_best_time(id: String) -> float:
	return float(challenge_progress.get(id, 0.0))


## Stores the time of a finished run. Returns true when it is a new personal best.
func record_time(id: String, seconds: float) -> bool:
	if id.is_empty() or seconds <= 0.0:
		return false
	var previous := get_best_time(id)
	if previous > 0.0 and previous <= seconds:
		return false
	challenge_progress[id] = seconds
	save_challenge_progress()
	return true


## The first challenge is always open; the rest need the previous one finished.
func is_challenge_unlocked(index: int) -> bool:
	if index <= 0:
		return true
	var previous := ChallengeCatalog.get_challenge(index - 1)
	if previous.is_empty():
		return false
	return get_best_time(str(previous["id"])) > 0.0


func get_challenge_medal(index: int) -> ChallengeCatalog.Medal:
	var challenge := ChallengeCatalog.get_challenge(index)
	if challenge.is_empty():
		return ChallengeCatalog.Medal.NONE
	return ChallengeCatalog.medal_for(index, get_best_time(str(challenge["id"])))


func get_finished_challenge_count() -> int:
	var count := 0
	for i in ChallengeCatalog.count():
		if get_best_time(str(ChallengeCatalog.get_challenge(i)["id"])) > 0.0:
			count += 1
	return count


## First challenge without a time, or the last one when every challenge is done.
func get_first_unfinished_challenge() -> int:
	for i in ChallengeCatalog.count():
		if get_best_time(str(ChallengeCatalog.get_challenge(i)["id"])) <= 0.0:
			return i
	return maxi(ChallengeCatalog.count() - 1, 0)


func reset_challenge_progress() -> void:
	challenge_progress.clear()
	save_challenge_progress()


func is_sandbox_unlocked() -> bool:
	return bool(game_config["sandbox_unlocked"])


func unlock_sandbox() -> void:
	if is_sandbox_unlocked():
		return
	game_config["sandbox_unlocked"] = true
	save_game_settings()
