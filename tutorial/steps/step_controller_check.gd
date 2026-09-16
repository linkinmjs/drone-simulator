class_name StepControllerCheck
extends TutorialStep
## Lesson 1: the controller answers, every stick reaches both ends and the pilot can arm
## and disarm with the throttle all the way down.


enum Phase {JOYPAD, THROTTLE_UP, THROTTLE_DOWN, YAW, PITCH, ROLL, ARM, DISARM}

const TASKS := {
	Phase.JOYPAD: "TUT_L1_T_JOYPAD",
	Phase.THROTTLE_UP: "TUT_L1_T_THROTTLE_UP",
	Phase.THROTTLE_DOWN: "TUT_L1_T_THROTTLE_DOWN",
	Phase.YAW: "TUT_L1_T_YAW",
	Phase.PITCH: "TUT_L1_T_PITCH",
	Phase.ROLL: "TUT_L1_T_ROLL",
	Phase.ARM: "TUT_L1_T_ARM",
	Phase.DISARM: "TUT_L1_T_DISARM",
}

@export var axis_threshold := 0.6
@export var throttle_high := 0.9
@export var throttle_low := 0.05

var phase := Phase.JOYPAD
var _negative := false
var _positive := false


func _on_restart() -> void:
	_set_phase(Phase.JOYPAD)


func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	_negative = false
	_positive = false


func _tick(_delta: float) -> void:
	var input := radio.input
	if phase < Phase.ARM and fc.state_armed:
		# Arming now would launch the drone while the pilot sweeps the sticks
		fc._on_disarm_input()
		level.tutorial_hud.flash_warning("TUT_WARN_NOT_YET")
	match phase:
		Phase.JOYPAD:
			if level.has_joypad():
				_advance()
		Phase.THROTTLE_UP:
			if input.power >= throttle_high:
				_advance()
		Phase.THROTTLE_DOWN:
			if input.power <= throttle_low:
				_advance()
		Phase.YAW:
			_sweep(input.yaw)
		Phase.PITCH:
			_sweep(input.pitch)
		Phase.ROLL:
			_sweep(input.roll)
		Phase.ARM:
			if fc.state_armed:
				_advance()
		Phase.DISARM:
			if not fc.state_armed:
				finish()


func _sweep(value: float) -> void:
	if value <= -axis_threshold:
		_negative = true
	if value >= axis_threshold:
		_positive = true
	if _negative and _positive:
		_advance()


func _advance() -> void:
	UI.play("tick")
	_set_phase((phase + 1) as Phase)


func get_task_text() -> String:
	return TASKS[phase]


func get_progress() -> float:
	return float(phase) / float(Phase.size())


func get_progress_text() -> String:
	return tr("TUT_STEP_OF") % [phase + 1, Phase.size()]


func get_stick_hint() -> Array[Vector2]:
	match phase:
		Phase.THROTTLE_UP:
			return [Vector2.UP, Vector2.ZERO]
		Phase.THROTTLE_DOWN, Phase.ARM:
			return [Vector2.DOWN, Vector2.ZERO]
		Phase.YAW:
			return [Vector2.RIGHT if _negative else Vector2.LEFT, Vector2.ZERO]
		Phase.PITCH:
			# Negative pitch input (nose down) is the stick pushed up
			return [Vector2.ZERO, Vector2.DOWN if _negative else Vector2.UP]
		Phase.ROLL:
			return [Vector2.ZERO, Vector2.RIGHT if _negative else Vector2.LEFT]
	return [Vector2.ZERO, Vector2.ZERO]
