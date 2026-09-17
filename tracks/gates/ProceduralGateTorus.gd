@tool
extends ProceduralGate
class_name ProceduralGateTorus
## Ring gate built from a torus. The drone flies through the hole, whose radius is
## `inner_radius`; the checkpoint fills that hole.


@export var inner_radius := 1.5 :
	set(value):
		inner_radius = maxf(value, 0.1)
		_rebuild_deferred()
@export var outer_radius := 2.0 :
	set(value):
		outer_radius = maxf(value, inner_radius + 0.01)
		_rebuild_deferred()
@export var sides := 32 :
	set(value):
		sides = maxi(value, 3)
		_rebuild_deferred()
@export var ring_sides := 16 :
	set(value):
		ring_sides = maxi(value, 3)
		_rebuild_deferred()
@export var collision_shape_count := 16 :
	set(value):
		collision_shape_count = maxi(value, 3)
		_rebuild_deferred()


func _add_geometry() -> void:
	var torus := CSGTorus3D.new()
	torus.inner_radius = inner_radius
	torus.outer_radius = outer_radius
	torus.sides = sides
	torus.ring_sides = ring_sides
	geometry = torus
	add_child(torus)
	torus.rotate(Vector3.RIGHT, PI / 2.0)


func _add_collision() -> void:
	# Capsules laid around the ring: a torus has no collision shape of its own.
	var shape := CapsuleShape3D.new()
	shape.radius = (outer_radius - inner_radius) / 2.0
	var offset := inner_radius + shape.radius
	shape.height = 2 * PI * offset / collision_shape_count
	for i in collision_shape_count:
		var collision_shape := CollisionShape3D.new()
		collision_shape.shape = shape
		static_body.add_child(collision_shape)
		collision_shape.rotate_y(2 * PI * i / collision_shape_count)
		collision_shape.translate_object_local(Vector3(offset, 0, 0))
	static_body.rotate(Vector3.RIGHT, PI / 2.0)


func _add_checkpoint() -> void:
	var shape := CylinderShape3D.new()
	shape.height = 0.05
	shape.radius = inner_radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	checkpoint.add_child(collision)
	collision.rotate(Vector3.RIGHT, PI / 2.0)
