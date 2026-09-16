class_name StepYaw
extends TutorialStep
## Lesson 3: while flying, turn at least `turn_degrees` to the left and then to the right.


enum Phase {TAKEOFF, LEFT, RIGHT}

@export var turn_degrees := 90.0
@export var min_altitude := 0.8

var phase := Phase.TAKEOFF
var turned := 0.0
var _previous_yaw := 0.0
var _has_previous := false


func _on_restart() -> void:
	phase = Phase.TAKEOFF
	turned = 0.0
	_has_previous = false


func _tick(_delta: float) -> void:
	var yaw := fc.angles.y
	var change := angle_difference(_previous_yaw, yaw) if _has_previous else 0.0
	_previous_yaw = yaw
	_has_previous = true
	var airborne := is_airborne(min_altitude)
	var target := deg_to_rad(turn_degrees)
	match phase:
		Phase.TAKEOFF:
			if airborne:
				phase = Phase.LEFT
				turned = 0.0
		Phase.LEFT:
			# A positive yaw angle turns the nose to the left
			if airborne:
				turned += maxf(change, 0.0)
			if turned >= target:
				UI.play("tick")
				phase = Phase.RIGHT
				turned = 0.0
		Phase.RIGHT:
			if airborne:
				turned += maxf(-change, 0.0)
			if turned >= target:
				finish()


func get_task_text() -> String:
	if phase != Phase.TAKEOFF and not is_airborne(min_altitude):
		return "TUT_T_BACK_UP"
	match phase:
		Phase.LEFT:
			return "TUT_L3_T_LEFT"
		Phase.RIGHT:
			return "TUT_L3_T_RIGHT"
	return "TUT_T_TAKEOFF"


func get_progress() -> float:
	var fraction := clampf(turned / deg_to_rad(turn_degrees), 0.0, 1.0)
	match phase:
		Phase.LEFT:
			return 0.1 + 0.45 * fraction
		Phase.RIGHT:
			return 0.55 + 0.45 * fraction
	return 0.0


func get_progress_text() -> String:
	if phase == Phase.TAKEOFF:
		return tr("TUT_ALTITUDE") % [fc.pos.y]
	return tr("TUT_L3_P_TURN") % [roundi(rad_to_deg(turned)), roundi(turn_degrees)]


func get_stick_hint() -> Array[Vector2]:
	if not is_airborne(min_altitude):
		return [Vector2(0, -0.6), Vector2.ZERO]
	match phase:
		Phase.LEFT:
			return [Vector2.LEFT, Vector2.ZERO]
		Phase.RIGHT:
			return [Vector2.RIGHT, Vector2.ZERO]
	return [Vector2.ZERO, Vector2.ZERO]
