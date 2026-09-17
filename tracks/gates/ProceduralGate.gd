@tool
extends Gate
class_name ProceduralGate
## Base of the gates whose geometry, collision and checkpoint are built from parameters
## instead of a model. It is a @tool script so the gate is visible while a track is being
## laid out: without it the editor shows an empty node and the track has to be built blind.


var geometry: GeometryInstance3D
var static_body: StaticBody3D
var checkpoint: Checkpoint


func _ready() -> void:
	rebuild()


## Rebuilds the gate from scratch. In the editor this runs again on every parameter change,
## so whatever was generated before is dropped first. The generated nodes get no owner: they
## belong to the gate at run time and must not be saved into the track scene.
func rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.has_meta(&"procedural"):
			remove_child(child)
			child.queue_free()
	geometry = null
	static_body = null
	checkpoint = null

	_add_geometry()
	if geometry != null:
		geometry.set_meta(&"procedural", true)

	static_body = StaticBody3D.new()
	static_body.set_meta(&"procedural", true)
	add_child(static_body)
	_add_collision()

	checkpoint = Checkpoint.new()
	checkpoint.set_meta(&"procedural", true)
	add_child(checkpoint)
	_add_checkpoint()


## Called from the setters of the parameters so the gate follows them in the editor.
func _rebuild_deferred() -> void:
	if is_inside_tree():
		rebuild.call_deferred()


func _add_geometry() -> void:
	pass


func _add_collision() -> void:
	pass


func _add_checkpoint() -> void:
	pass
