class_name StepReachZones
extends TutorialStep
## Lessons 4 and 5: fly through a list of zones in order (the same zone may appear twice).


## Zones to reach, in order
@export var zone_paths: Array[NodePath] = []
## Instruction for each zone (translation keys, same order as the zones)
@export var task_keys: Array[String] = []
## Suggested right stick direction for each zone (screen convention, up = Vector2(0, -1))
@export var right_stick_hints: Array[Vector2] = []
@export var min_altitude := 0.5

var zones: Array[TutorialZone] = []
var index := 0


func _setup() -> void:
	for path in zone_paths:
		var zone := get_node_or_null(path) as TutorialZone
		if zone:
			zones.append(zone)
		else:
			push_error("Tutorial zone not found: %s" % [path])


func _on_start() -> void:
	index = 0
	_update_zones()


func _on_stop() -> void:
	for zone in zones:
		zone.set_state(TutorialZone.State.HIDDEN)


func _on_restart() -> void:
	index = 0
	_update_zones()


func _update_zones() -> void:
	for zone in zones:
		zone.set_state(TutorialZone.State.HIDDEN)
	for i in zones.size():
		if i < index:
			zones[i].set_state(TutorialZone.State.DONE)
		elif i == index:
			zones[i].set_state(TutorialZone.State.ACTIVE)
		elif i == index + 1:
			zones[i].set_state(TutorialZone.State.IDLE)


func _tick(_delta: float) -> void:
	if index >= zones.size():
		return
	var zone := zones[index]
	if fc.pos.y >= min_altitude and zone.contains_horizontal(fc.pos):
		index += 1
		if index >= zones.size():
			finish()
		else:
			UI.play("tick")
			_update_zones()


func get_task_text() -> String:
	if not is_airborne(min_altitude):
		return "TUT_T_TAKEOFF"
	if index < task_keys.size():
		return task_keys[index]
	return ""


func get_progress() -> float:
	if zones.is_empty():
		return -1.0
	return float(index) / float(zones.size())


func get_progress_text() -> String:
	if index >= zones.size():
		return ""
	var distance := zones[index].horizontal_distance(fc.pos)
	return tr("TUT_ZONE_P") % [index + 1, zones.size(), distance]


func get_stick_hint() -> Array[Vector2]:
	if not is_airborne(min_altitude):
		return [Vector2(0, -0.6), Vector2.ZERO]
	if index < right_stick_hints.size():
		return [Vector2.ZERO, right_stick_hints[index]]
	return [Vector2.ZERO, Vector2.ZERO]
