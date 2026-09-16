class_name TutorialStep
extends Node
## Base class of a flight instructor lesson. Each lesson is a node under the
## TutorialSequencer of the tutorial level, so its exported NodePaths point at the props of
## the scene. Subclasses override the virtual methods at the end of this file.
##
## Life cycle: `setup()` once, then `start()` every time the lesson begins, `restart()` after
## every respawn of the drone and `stop()` when the lesson is left. A lesson calls `finish()`
## when its goal is reached.


signal completed

## Lesson title and description (translation keys)
@export var title_key := ""
@export var objective_key := ""
## Flight mode forced while the lesson runs
@export var flight_mode := FlightMode.Type.HORIZON
## Refuse the "cycle flight modes" action during the lesson
@export var block_mode_cycling := true
## Where the drone appears when the lesson starts (empty: origin of the level)
@export var respawn_marker: NodePath = ^""
@export var respawn_on_start := true
## Seconds between reaching the goal and the next lesson
@export var success_delay := 3.0

## Upright vector below this dot product with UP counts as tipped over
const TIPPED_OVER_DOT := 0.5
const TIPPED_OVER_ALTITUDE := 0.6
const TIPPED_OVER_SECONDS := 0.6
## A drone lying tipped over this long goes back to the start of the lesson by itself
const AUTO_RESPAWN_SECONDS := 3.0

var level: TutorialLevel = null
var drone: Drone = null
var fc: FlightController = null
var radio: RadioController = null
var active := false
## Persistent warning of the lesson (translation key), empty when everything is fine
var warning_key := ""

var _tipped_time := 0.0


func setup(p_level: TutorialLevel) -> void:
	level = p_level
	drone = level.tutorial_drone
	fc = drone.flight_controller
	radio = level.radio
	_setup()


func start() -> void:
	if respawn_on_start:
		var marker := get_node_or_null(respawn_marker) as Node3D
		level.set_respawn_transform(marker.global_transform if marker else Transform3D.IDENTITY)
	level.set_flight_mode(flight_mode)
	_on_start()
	restart()
	active = true
	if respawn_on_start:
		level.respawn_drone()


## Clears the progress of the lesson (the drone was just respawned).
func restart() -> void:
	warning_key = ""
	_tipped_time = 0.0
	_on_restart()


func stop() -> void:
	active = false
	warning_key = ""
	_on_stop()


func finish() -> void:
	if not active:
		return
	active = false
	warning_key = ""
	completed.emit()


func _physics_process(delta: float) -> void:
	if not active:
		return
	_check_crash(delta)
	_tick(delta)


func is_airborne(min_altitude: float) -> bool:
	return fc.state_armed and fc.pos.y >= min_altitude


func _check_crash(delta: float) -> void:
	var upright := drone.global_transform.basis.y.dot(Vector3.UP)
	if fc.pos.y < TIPPED_OVER_ALTITUDE and upright < TIPPED_OVER_DOT:
		# On the ground and tipped over. The flight controller keeps a tilted drone in
		# recovery mode, which refuses to arm: only a respawn gets it flying again.
		_tipped_time += delta
		if _tipped_time >= AUTO_RESPAWN_SECONDS:
			_tipped_time = 0.0
			level.respawn_drone()
		elif _tipped_time >= TIPPED_OVER_SECONDS:
			warning_key = "TUT_WARN_CRASHED"
		return
	_tipped_time = 0.0
	if fc.flight_mode is FlightModeRecover and fc.state_armed:
		warning_key = "TUT_WARN_RECOVER"
	elif warning_key == "TUT_WARN_CRASHED" or warning_key == "TUT_WARN_RECOVER":
		warning_key = ""


# --- Virtual methods -----------------------------------------------------------------------

## Called once, after the level is ready.
func _setup() -> void:
	pass


func _on_start() -> void:
	pass


func _on_restart() -> void:
	pass


func _on_stop() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


## Instruction for the current phase (translation key or already translated text).
func get_task_text() -> String:
	return ""


## Live progress line, already translated.
func get_progress_text() -> String:
	return ""


## Progress of the lesson between 0 and 1, or a negative value to hide the bar.
func get_progress() -> float:
	return -1.0


## Stick directions to suggest: [left, right] in screen convention (x right, y down, so
## "stick up" is Vector2(0, -1)). Vector2.ZERO means no suggestion for that stick.
func get_stick_hint() -> Array[Vector2]:
	return [Vector2.ZERO, Vector2.ZERO]


## Extra line under "Well done!" when the lesson is completed (already translated).
func get_success_text() -> String:
	return ""
