extends Node


const BUS_MASTER := &"Master"
const BUS_MOTORS := &"Motors"
const BUS_UI := &"UI"

var audio_settings_path := "%s/Audio.cfg" % [Global.config_dir]

var audio_settings := {
	"master_volume": 1.0,
	"motors_volume": 1.0,
	"ui_volume": 0.8,
	"muted": false,
}


func _ready() -> void:
	update_volumes()


func load_audio_settings() -> String:
	var config := ConfigFile.new()
	var text := ""
	var err := config.load(audio_settings_path)
	if err == OK:
		for key: String in audio_settings.keys():
			if config.has_section_key("audio", key):
				audio_settings[key] = config.get_value("audio", key)
		update_volumes()
	elif err == ERR_PARSE_ERROR:
		Global.log_error(err, "Parse error while loading audio configuration file.")
		text = "ERR_AUDIO_PARSE"
	elif err != ERR_FILE_NOT_FOUND:
		Global.log_error(err, "Could not open audio config file.")
		text = "ERR_AUDIO_OPEN"
	return text


func save_audio_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(audio_settings_path)
	if err == OK or err == ERR_FILE_NOT_FOUND or err == ERR_PARSE_ERROR:
		for key: String in audio_settings.keys():
			config.set_value("audio", key, audio_settings[key])
		err = config.save(audio_settings_path)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		Global.log_error(err, "Error while saving audio settings.")


func update_master_volume() -> void:
	update_volumes()


func update_volumes() -> void:
	_set_bus(BUS_MASTER, float(audio_settings["master_volume"]))
	_set_bus(BUS_MOTORS, float(audio_settings["motors_volume"]))
	_set_bus(BUS_UI, float(audio_settings["ui_volume"]))
	var master := AudioServer.get_bus_index(BUS_MASTER)
	if master >= 0:
		AudioServer.set_bus_mute(master, bool(audio_settings["muted"]))


func _set_bus(bus_name: StringName, volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(volume, 0.0, 1.0)))
