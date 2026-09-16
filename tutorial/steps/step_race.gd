class_name StepRace
extends TutorialStep
## Lesson 8: a one lap timed race on a real Track, with countdown and false start detection.
## It turns the race mode on by code (the R key is disabled in the tutorial).


@export var track_path: NodePath = ^""

var track: Track = null
var finished_time := ""


func _setup() -> void:
	track = get_node_or_null(track_path) as Track
	if track == null:
		push_error("Tutorial track not found: %s" % [track_path])
		return
	var _discard := track.race_state_changed.connect(_on_race_state_changed)


func _on_start() -> void:
	finished_time = ""
	if track == null:
		return
	drone.hud.show_component(HUD.Component.GATE_MARKER, true)
	if Global.game_mode == Global.GameMode.RACE:
		# Already racing (lesson restarted): a respawn restarts the countdown
		level.respawn_drone()
	else:
		# The level picks the track and respawns the drone on its launch pad
		Global.game_mode = Global.GameMode.RACE


func _on_stop() -> void:
	if track:
		# The finish label hides itself on a timer that the pause of the end menu freezes
		track.end_label.visible = false
	if Global.game_mode != Global.GameMode.FREE:
		Global.game_mode = Global.GameMode.FREE
	drone.hud.apply_hud_config()


func _on_race_state_changed(state: Global.RaceState) -> void:
	if not active or Global.active_track != track:
		return
	if state == Global.RaceState.END:
		finished_time = track.timers[0].get_time_string()
		finish()


func get_task_text() -> String:
	if track == null:
		return ""
	match track.race_state:
		Global.RaceState.START:
			return "TUT_L8_T_WAIT"
		Global.RaceState.RACE:
			return "TUT_L8_T_RACE"
	return ""


func get_progress() -> float:
	if track == null or track.course_array.is_empty() or track.race_state != Global.RaceState.RACE:
		return 0.0
	return float(maxi(track.current, 0)) / float(track.course_array.size())


func get_progress_text() -> String:
	if track == null or track.race_state != Global.RaceState.RACE:
		return ""
	return tr("TUT_L8_P_RACE") % [track.current + 1, track.course_array.size(),
			track.timers[0].get_time_string()]


func get_success_text() -> String:
	return tr("TUT_L8_SUCCESS") % [finished_time]
