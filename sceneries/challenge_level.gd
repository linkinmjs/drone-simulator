class_name ChallengeLevel
extends Level
## One challenge of the progression mode (see docs/desafios.md).
##
## There is a single challenge level: the track of the challenge picked in the menu is loaded
## into it, so adding a challenge is writing a Track scene and adding an entry to
## ChallengeCatalog. Everything about the race itself already exists in Track and Level:
## putting the game in race mode starts the countdown, the lap timers, the record and the
## ghosts of the previous runs. This level only picks the track, keeps the score and shows
## the result.


const MAIN_MENU_SCENE := "res://gui/main_menu.tscn"
const CHALLENGE_SCENE := "res://sceneries/challenge_level.tscn"
## Below this height the drone left the ground and keeps falling: bring it back.
const OUT_OF_BOUNDS_ALTITUDE := -3.0
## The "Finished!" sign of the track lasts two seconds; the result comes after it.
const RESULT_DELAY := 2.4

## Tests turn this off so a run does not touch the saved progress.
@export var persist_progress := true

var challenge := {}
var challenge_index := 0
var track: Track = null

var _menu_layer: CanvasLayer = null
var _menu_open := false
var _finishing := false


func _ready() -> void:
	challenge = ChallengeCatalog.get_by_id(Global.selected_challenge)
	if challenge.is_empty():
		challenge = ChallengeCatalog.get_challenge(0)
	challenge_index = ChallengeCatalog.get_index(str(challenge["id"]))

	# The track has to be in place before Level._ready() collects the tracks of the level.
	_load_track()
	super()

	Global.race_mode_toggle_enabled = false
	if persist_progress:
		GameSettings.load_challenge_progress()

	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 10
	_menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_menu_layer)

	if track != null:
		var _discard := track.race_state_changed.connect(_on_race_state_changed)
	_start_race.call_deferred()


func _load_track() -> void:
	var path := str(challenge.get("track", ""))
	if not ResourceLoader.exists(path):
		push_error("ChallengeLevel: falta la pista %s" % [path])
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	track = packed.instantiate() as Track
	if track == null:
		return
	track.laps = maxi(int(challenge.get("laps", 1)), 1)
	# The lap table would cover the result screen.
	track.show_time_table = false
	add_child(track)


## Race mode is global and survives a scene change, so it is cleared first: setting it to the
## value it already had would not tell the level to start.
func _start_race() -> void:
	Global.game_mode = Global.GameMode.FREE
	Global.active_track = null
	if track == null:
		return
	Global.game_mode = Global.GameMode.RACE


func _physics_process(_delta: float) -> void:
	if drone != null and drone.global_transform.origin.y < OUT_OF_BOUNDS_ALTITUDE:
		drone.reset()


func _exit_tree() -> void:
	Global.race_mode_toggle_enabled = true
	Global.game_mode = Global.GameMode.FREE
	Global.active_track = null


func _on_race_state_changed(state: int) -> void:
	if state == Global.RaceState.END and not _finishing:
		_finishing = true
		_show_result.call_deferred()


func total_time() -> float:
	var total := 0.0
	if track != null:
		for timer in track.timers:
			total += timer.time
	return total


func _show_result() -> void:
	var id := str(challenge["id"])
	var time := total_time()
	var previous := GameSettings.get_best_time(id)
	var is_record := false
	if persist_progress:
		is_record = GameSettings.record_time(id, time)
	var best := GameSettings.get_best_time(id) if persist_progress else time
	var medal := ChallengeCatalog.medal_for(challenge_index, time)

	var timer := get_tree().create_timer(RESULT_DELAY)
	await timer.timeout
	if not is_inside_tree():
		return

	var title := tr("CHAL_RESULT_MEDAL") % [tr(ChallengeCatalog.medal_key(medal))] \
			if medal != ChallengeCatalog.Medal.NONE else tr("CHAL_RESULT_NO_MEDAL")
	var subtitle := tr("CHAL_RESULT_TIME") % [ChallengeCatalog.format_time(time)]
	if is_record and previous > 0.0:
		subtitle += "\n" + tr("CHAL_RESULT_RECORD")
	elif best > 0.0:
		subtitle += "\n" + tr("CHAL_RESULT_BEST") % [ChallengeCatalog.format_time(best)]

	var entries: Array[Dictionary] = [{"id": "retry", "text": tr("CHAL_RETRY"), "primary": true}]
	if _has_next():
		entries.append({"id": "next", "text": tr("CHAL_NEXT"), "primary": true})
	entries.append({"id": "choose", "text": tr("CHAL_CHOOSE")})
	entries.append({"id": "menu", "text": tr("MENU_RETURN_TO_MAIN")})
	_handle_choice(await _show_menu(title, subtitle, entries))


func _has_next() -> bool:
	var next := challenge_index + 1
	return next < ChallengeCatalog.count() and GameSettings.is_challenge_unlocked(next)


func _handle_choice(id: String) -> void:
	match id:
		"retry":
			_restart()
		"next":
			_go_to_challenge(ChallengeCatalog.get_challenge(challenge_index + 1))
		"choose":
			if not await _open_picker():
				_restart()
		_:
			_go_to(MAIN_MENU_SCENE)


## Returns true when another challenge was chosen.
func _open_picker() -> bool:
	var entries := ChallengeCatalog.menu_entries(str(challenge["id"]))
	var open: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if not entry["locked"]:
			open.append(entry)
	open.append({"id": "back", "text": tr("UI_BACK")})
	var id := await _show_menu(tr("CHAL_PICK_TITLE"), tr("CHAL_PICK_SUBTITLE"), open, "back")
	if id == "back":
		return false
	_go_to_challenge(ChallengeCatalog.get_by_id(id))
	return true


func _restart() -> void:
	_finishing = false
	_resume_from_menu()
	drone.reset()


func _go_to_challenge(next: Dictionary) -> void:
	if next.is_empty():
		_go_to(MAIN_MENU_SCENE)
		return
	Global.selected_challenge = str(next["id"])
	_go_to(CHALLENGE_SCENE)


func _go_to(path: String) -> void:
	get_tree().paused = false
	SceneTransition.change_scene(path, true)


func _show_menu(title: String, subtitle: String, entries: Array[Dictionary],
		back_id := "") -> String:
	_menu_open = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var menu := ChoiceMenu.new()
	menu.setup(title, subtitle, entries, back_id)
	_menu_layer.add_child(menu)
	var id: String = await menu.chosen
	menu.queue_free()
	_menu_open = false
	return id


## Resumes the flight once the button or stick used in the menu is released, so it does not
## reach the drone.
func _resume_from_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	await get_tree().process_frame
	while is_inside_tree() and _resume_input_held():
		await get_tree().process_frame
	get_tree().paused = false


func add_pause_menu() -> void:
	super()
	var column := pause_menu.menu_container
	var position_in_column := pause_menu.button_resume.get_index() + 1
	for entry: Array in [["CHAL_RETRY", _on_pause_restart], ["CHAL_CHOOSE", _on_pause_choose]]:
		var button := Button.new()
		button.text = entry[0]
		button.theme_type_variation = &"MenuItemButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		column.add_child(button)
		column.move_child(button, position_in_column)
		position_in_column += 1
		var _discard := button.pressed.connect(entry[1])


func _on_pause_restart() -> void:
	pause_menu.queue_free()
	_restart()


func _on_pause_choose() -> void:
	pause_menu.queue_free()
	if not await _open_picker():
		_resume_from_menu()
