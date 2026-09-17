@tool
extends RefCounted
## Every change the toolbar makes to the scene, always through EditorUndoRedoManager so Ctrl+Z
## works and the scene is marked as modified.
##
## Note on EditorUndoRedoManager: add_do_method() takes (Object, StringName, ...), not a
## Callable like the plain UndoRedo does.


const TrackGraph := preload("res://addons/track_editor/track_graph.gd")


## Adds a piece as a direct child of the track, chained ahead of `anchor` along its -Z, and
## right after it in the tree: the checkpoint index is the child order, so appending at the
## end would renumber nothing but force reordering by hand when inserting in the middle.
static func add_piece(undo: EditorUndoRedoManager, track: Node3D, piece: Dictionary,
		anchor: Node3D, scene_root: Node) -> Node3D:
	var path: String = piece["path"]
	if not ResourceLoader.exists(path):
		push_warning("Track Editor: falta la escena %s" % [path])
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var node := packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	if node == null:
		return null

	node.transform = _chained_transform(anchor, piece["offset"] as float)
	var insert_at := track.get_child_count()
	if anchor != null and anchor.get_parent() == track:
		insert_at = anchor.get_index() + 1

	undo.create_action("Agregar %s" % [piece["label"]], UndoRedo.MERGE_DISABLE, track)
	undo.add_do_method(track, &"add_child", node, true)
	undo.add_do_method(track, &"move_child", node, insert_at)
	undo.add_do_method(node, &"set_owner", scene_root)
	undo.add_do_reference(node)
	undo.add_undo_method(track, &"remove_child", node)
	undo.commit_action()
	return node


static func _chained_transform(anchor: Node3D, offset: float) -> Transform3D:
	if anchor == null:
		return Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var basis := anchor.transform.basis.orthonormalized()
	return Transform3D(basis, anchor.transform.origin - basis.z * offset)


static func set_course(undo: EditorUndoRedoManager, track: Node3D, course: String) -> void:
	undo.create_action("Recorrido de la pista", UndoRedo.MERGE_DISABLE, track)
	undo.add_do_property(track, &"course", course)
	undo.add_undo_property(track, &"course", track.get("course"))
	# The multiline field of the inspector does not refresh on its own.
	undo.add_do_method(track, &"notify_property_list_changed")
	undo.add_undo_method(track, &"notify_property_list_changed")
	undo.commit_action()


## Puts the bottom of the piece on the ground. The ground lives in the level, not in the track
## scene, so there is nothing to raycast against while editing a track on its own: y = 0 is
## the floor, which is also where the Gate_* scenes have their base.
static func drop_to_floor(undo: EditorUndoRedoManager, nodes: Array[Node3D]) -> int:
	var moved := 0
	undo.create_action("Apoyar en el piso", UndoRedo.MERGE_DISABLE, nodes[0] if not nodes.is_empty() else null)
	for node in nodes:
		var bottom := _visual_bottom(node)
		if is_inf(bottom):
			bottom = node.global_transform.origin.y
		if is_zero_approx(bottom):
			continue
		var target := node.transform
		target.origin.y -= bottom
		undo.add_do_property(node, &"transform", target)
		undo.add_undo_property(node, &"transform", node.transform)
		moved += 1
	undo.commit_action()
	return moved


## Lowest point of the visual geometry in world space, or INF when the node draws nothing
## (a ProceduralGate builds its mesh at run time, so in the editor it has no bounds).
static func _visual_bottom(node: Node3D) -> float:
	var bottom := INF
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is VisualInstance3D:
			var visual := current as VisualInstance3D
			var aabb := visual.get_aabb()
			var xform := visual.global_transform
			for i in 8:
				bottom = minf(bottom, (xform * aabb.get_endpoint(i)).y)
		stack.append_array(current.get_children())
	return bottom


## Rounds the rotation to a step. Only the yaw by default: snapping the three axes would
## flatten a gate that is deliberately tilted, like the 30 degree dive one.
static func snap_rotation(undo: EditorUndoRedoManager, nodes: Array[Node3D], degrees: float,
		yaw_only := true) -> void:
	var step := deg_to_rad(degrees)
	undo.create_action("Redondear la rotacion", UndoRedo.MERGE_DISABLE,
			nodes[0] if not nodes.is_empty() else null)
	for node in nodes:
		var xform := node.transform
		var euler := xform.basis.get_euler()
		if yaw_only:
			euler.y = snappedf(euler.y, step)
		else:
			euler = euler.snapped(Vector3(step, step, step))
		var target := Transform3D(Basis.from_euler(euler).scaled(xform.basis.get_scale()), xform.origin)
		undo.add_do_property(node, &"transform", target)
		undo.add_undo_property(node, &"transform", xform)
	undo.commit_action()
