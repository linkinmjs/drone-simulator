@tool
extends ProceduralGate
class_name ProceduralGateRectangle
## Window gate: a panel with a rectangular hole the drone flies through.


@export var width := 1.5 :
	set(value):
		width = maxf(value, 0.1)
		_rebuild_deferred()
@export var height := 1.5 :
	set(value):
		height = maxf(value, 0.1)
		_rebuild_deferred()
@export var horizontal_panel_width := 0.2 :
	set(value):
		horizontal_panel_width = maxf(value, 0.01)
		_rebuild_deferred()
@export var vertical_panel_width := 0.2 :
	set(value):
		vertical_panel_width = maxf(value, 0.01)
		_rebuild_deferred()
@export var thickness := 0.05 :
	set(value):
		thickness = maxf(value, 0.01)
		_rebuild_deferred()


func _add_geometry() -> void:
	var box := CSGBox3D.new()
	box.size = Vector3(width + 2 * vertical_panel_width, height + 2 * horizontal_panel_width,
			thickness)
	geometry = box
	add_child(box)
	var hole := CSGBox3D.new()
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.size = Vector3(width, height, 2 * thickness)
	box.add_child(hole)


func _add_collision() -> void:
	var shape_horizontal := get_horizontal_panel_shape()
	var shape_vertical := get_vertical_panel_shape()
	add_shape(shape_horizontal, Vector3(0, -(height + horizontal_panel_width) / 2.0, 0))
	add_shape(shape_horizontal, Vector3(0, (height + horizontal_panel_width) / 2.0, 0))
	add_shape(shape_vertical, Vector3(-(width + vertical_panel_width) / 2.0, 0, 0))
	add_shape(shape_vertical, Vector3((width + vertical_panel_width) / 2.0, 0, 0))


func _add_checkpoint() -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, thickness)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	checkpoint.add_child(collision)


func get_horizontal_panel_shape() -> BoxShape3D:
	var shape_horizontal := BoxShape3D.new()
	shape_horizontal.size = Vector3(width + 2 * vertical_panel_width, horizontal_panel_width,
			thickness)
	return shape_horizontal


func get_vertical_panel_shape() -> BoxShape3D:
	var shape_vertical := BoxShape3D.new()
	shape_vertical.size = Vector3(2 * vertical_panel_width, height + 2 * horizontal_panel_width,
			thickness)
	return shape_vertical


func add_shape(shape: Shape3D, offset: Vector3) -> void:
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	collision_shape.translate_object_local(offset)
	static_body.add_child(collision_shape)
