class_name StepHover
extends TutorialStep
## Lesson 2: take off, stay inside a height band for a few seconds, land and disarm.


enum Phase {ARM, HOLD, LAND}

@export var zone_path: NodePath = ^""
@export var altitude_min := 1.0
@export var altitude_max := 3.0
@export var hold_time := 3.0
## Disarming above this height does not count as a landing
@export var landed_altitude := 0.5

var phase := Phase.ARM
var held := 0.0
var zone: TutorialZone = null


func _setup() -> void:
	zone = get_node_or_null(zone_path) as TutorialZone


func _on_start() -> void:
	if zone:
		zone.set_state(TutorialZone.State.ACTIVE)


func _on_stop() -> void:
	if zone:
		zone.set_state(TutorialZone.State.HIDDEN)


func _on_restart() -> void:
	phase = Phase.ARM
	held = 0.0
	if zone:
		zone.set_state(TutorialZone.State.ACTIVE)


func _tick(delta: float) -> void:
	var altitude := fc.pos.y
	match phase:
		Phase.ARM:
			if fc.state_armed:
				phase = Phase.HOLD
		Phase.HOLD:
			if not fc.state_armed:
				_on_restart()
				return
			var inside := altitude >= altitude_min and altitude <= altitude_max \
					and (zone == null or zone.contains_horizontal(fc.pos))
			held = held + delta if inside else 0.0
			if zone:
				zone.set_state(TutorialZone.State.INSIDE if inside else TutorialZone.State.ACTIVE)
			if held >= hold_time:
				UI.play("tick")
				phase = Phase.LAND
				if zone:
					zone.set_state(TutorialZone.State.DONE)
		Phase.LAND:
			if not fc.state_armed:
				if altitude <= landed_altitude:
					finish()
				else:
					level.tutorial_hud.flash_warning("TUT_WARN_DISARM_AIR")
					_on_restart()


func get_task_text() -> String:
	match phase:
		Phase.ARM:
			return "TUT_L2_T_ARM"
		Phase.HOLD:
			if fc.pos.y < altitude_min:
				return "TUT_L2_T_CLIMB"
			if fc.pos.y > altitude_max:
				return "TUT_L2_T_DESCEND"
			return "TUT_L2_T_HOLD"
	return "TUT_L2_T_LAND"


func get_progress() -> float:
	match phase:
		Phase.ARM:
			return 0.0
		Phase.HOLD:
			return 0.1 + 0.7 * held / hold_time
	return 0.85


func get_progress_text() -> String:
	if phase == Phase.HOLD:
		return tr("TUT_L2_P_HOLD") % [fc.pos.y, held, hold_time]
	return tr("TUT_ALTITUDE") % [fc.pos.y]


func get_stick_hint() -> Array[Vector2]:
	match phase:
		Phase.ARM:
			return [Vector2.DOWN, Vector2.ZERO]
		Phase.HOLD:
			if fc.pos.y < altitude_min:
				return [Vector2(0, -0.6), Vector2.ZERO]
			if fc.pos.y > altitude_max:
				return [Vector2(0, 0.3), Vector2.ZERO]
		Phase.LAND:
			return [Vector2(0, 0.3), Vector2.ZERO]
	return [Vector2.ZERO, Vector2.ZERO]
