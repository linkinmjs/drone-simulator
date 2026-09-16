class_name StepGates
extends TutorialStep
## Lessons 6 and 7: fly through a row of gates in order. Any checkpoint of a gate counts
## (Gate_Double_1 has two stacked ones), crossed in its forward direction.


@export var gate_paths: Array[NodePath] = []
@export var min_altitude := 0.4

## Checkpoints of each gate, same order as `gate_paths`
var gate_checkpoints: Array[Array] = []
var index := 0


func _setup() -> void:
	for path in gate_paths:
		var gate := get_node_or_null(path)
		var checkpoints: Array[Checkpoint] = []
		if gate:
			for child in gate.get_children():
				if child is Checkpoint:
					var checkpoint := child as Checkpoint
					checkpoints.append(checkpoint)
					var _discard := checkpoint.passed.connect(_on_checkpoint_passed)
		else:
			push_error("Tutorial gate not found: %s" % [path])
		gate_checkpoints.append(checkpoints)
	# The checkpoints build their mesh deferred and show it: hide them afterwards
	_deactivate_all.call_deferred()


func _on_start() -> void:
	index = 0
	_update_gates()


func _on_stop() -> void:
	_deactivate_all()


func _on_restart() -> void:
	index = 0
	_update_gates()


func _deactivate_all() -> void:
	for checkpoints: Array in gate_checkpoints:
		for checkpoint: Checkpoint in checkpoints:
			checkpoint.active = false


func _update_gates() -> void:
	_deactivate_all()
	if index < gate_checkpoints.size():
		for checkpoint: Checkpoint in gate_checkpoints[index]:
			checkpoint.active = true


func _on_checkpoint_passed(checkpoint: Checkpoint) -> void:
	if not active or index >= gate_checkpoints.size():
		return
	if not gate_checkpoints[index].has(checkpoint):
		return
	index += 1
	if index >= gate_checkpoints.size():
		_deactivate_all()
		finish()
	else:
		UI.play("tick")
		_update_gates()


func get_current_gate_position() -> Vector3:
	if index < gate_checkpoints.size() and not gate_checkpoints[index].is_empty():
		var checkpoints: Array = gate_checkpoints[index]
		var sum := Vector3.ZERO
		for checkpoint: Checkpoint in checkpoints:
			sum += checkpoint.global_position
		return sum / checkpoints.size()
	return Vector3.INF


func get_task_text() -> String:
	if not is_airborne(min_altitude):
		return "TUT_T_TAKEOFF"
	return "TUT_GATES_T"


func get_progress() -> float:
	if gate_checkpoints.is_empty():
		return -1.0
	return float(index) / float(gate_checkpoints.size())


func get_progress_text() -> String:
	var target := get_current_gate_position()
	if not target.is_finite():
		return ""
	return tr("TUT_GATE_P") % [index + 1, gate_checkpoints.size(), fc.pos.distance_to(target)]


func get_stick_hint() -> Array[Vector2]:
	if not is_airborne(min_altitude):
		return [Vector2(0, -0.6), Vector2.ZERO]
	return [Vector2.ZERO, Vector2.ZERO]
