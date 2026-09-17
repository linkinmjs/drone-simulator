@tool
extends EditorPlugin
## Track editor: numbers every checkpoint in the 3D viewport, draws the course, and adds the
## pieces of a race track without leaving the viewport. See docs/desafios.md.
##
## No script of this addon declares a class_name on purpose: class names are registered
## globally and an exported build would try to load these Editor* classes, which do not exist
## in a release template.


const Bar := preload("res://addons/track_editor/track_editor_bar.gd")
const TrackGraph := preload("res://addons/track_editor/track_graph.gd")
const Actions := preload("res://addons/track_editor/track_editor_actions.gd")
const Overlay := preload("res://addons/track_editor/track_editor_overlay.gd")
const Validator := preload("res://addons/track_editor/track_validator.gd")
const TrackPieces := preload("res://addons/track_editor/track_pieces.gd")

var _bar: HBoxContainer = null
var _track: Node3D = null
var _editable := true
var _show_numbers := true
var _font: Font = null
var _font_size := 16
var _last_camera: Camera3D = null
var _last_state := 0.0


func _enter_tree() -> void:
	var base := EditorInterface.get_base_control()
	if base != null:
		_font = base.get_theme_font(&"font", &"Label")
		_font_size = base.get_theme_font_size(&"font_size", &"Label")
	if _font == null:
		_font = ThemeDB.fallback_font

	_bar = Bar.new()
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _bar)
	_bar.hide()
	var _discard: int = _bar.piece_requested.connect(_on_piece_requested)
	_discard = _bar.course_requested.connect(_on_course_requested)
	_discard = _bar.floor_requested.connect(_on_floor_requested)
	_discard = _bar.snap_requested.connect(_on_snap_requested)
	_discard = _bar.validate_requested.connect(_on_validate_requested)
	_discard = _bar.numbers_toggled.connect(_on_numbers_toggled)
	set_process(false)


func _exit_tree() -> void:
	if _bar != null:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _bar)
		_bar.queue_free()
		_bar = null
	_track = null


## Also accepts the children of a track: without this the numbers would vanish as soon as a
## gate is clicked to move it, which is exactly when they are needed.
func _handles(object: Object) -> bool:
	return _find_track(object) != null


func _edit(object: Object) -> void:
	_track = _find_track(object)
	_editable = _track == null or _is_editable(_track)
	if _track != null and not _editable:
		push_warning("Track Editor: abri %s como escena para editarla; instanciada dentro de un nivel, las piezas se guardarian en el nivel."
				% [_track.scene_file_path])
	_last_state = 0.0


func _make_visible(visible: bool) -> void:
	if _bar != null:
		_bar.visible = visible
	set_process(visible)
	if not visible:
		_track = null


func _forward_3d_gui_input(viewport_camera: Camera3D, _event: InputEvent) -> int:
	_last_camera = viewport_camera
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _forward_3d_draw_over_viewport(viewport_control: Control) -> void:
	if _track == null or not _show_numbers:
		return
	var camera := _resolve_camera(viewport_control)
	if camera == null:
		return
	var entries := TrackGraph.collect(_track)
	if entries.is_empty():
		return
	var tokens := TrackGraph.course_tokens(_track.get("course"), entries.size())
	var selected := int(_track.get("selected_checkpoint"))
	Overlay.draw(viewport_control, camera, entries, tokens, selected, _font, _font_size)


## Redraws only when something moved: forcing it every frame keeps the editor from idling.
func _process(_delta: float) -> void:
	if _track == null or not _show_numbers:
		return
	var state := _state_signature()
	if is_equal_approx(state, _last_state):
		return
	_last_state = state
	var _discard := update_overlays()


func _state_signature() -> float:
	var total := 0.0
	if _last_camera != null:
		var xform := _last_camera.global_transform
		total += xform.origin.x + xform.origin.y * 3.0 + xform.origin.z * 7.0
		total += xform.basis.z.x * 11.0 + xform.basis.z.y * 13.0 + xform.basis.z.z * 17.0
	for child in _track.get_children():
		var node := child as Node3D
		if node != null:
			var origin := node.transform.origin
			total += origin.x + origin.y * 3.0 + origin.z * 7.0
	return total


## The overlay does not say which viewport it belongs to, and a split layout has up to four.
func _resolve_camera(overlay: Control) -> Camera3D:
	var parent := overlay.get_parent()
	if parent != null:
		for i in 4:
			var viewport := EditorInterface.get_editor_viewport_3d(i)
			if viewport != null and parent.is_ancestor_of(viewport):
				return viewport.get_camera_3d()
	return _last_camera


func _find_track(object: Object) -> Node3D:
	var node := object as Node
	if node == null:
		var selected := EditorInterface.get_selection().get_selected_nodes()
		if selected.is_empty():
			return null
		node = selected[0]
	while node != null:
		if node is Track:
			return node as Node3D
		node = node.get_parent()
	return null


## A track instanced inside a level is edited in the level, so the pieces would be stored
## there instead of in the track scene.
func _is_editable(track: Node3D) -> bool:
	var root := EditorInterface.get_edited_scene_root()
	return track == root or track.scene_file_path.is_empty()


func _on_piece_requested(id: StringName) -> void:
	if not _require_editable():
		return
	var piece := TrackPieces.get_piece(id)
	if piece.is_empty():
		return
	var node := Actions.add_piece(get_undo_redo(), _track, piece, _anchor(),
			EditorInterface.get_edited_scene_root())
	if node == null:
		return
	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(node)
	_last_state = 0.0


## Where a new piece is chained from: the selected piece, or the last child of the track.
func _anchor() -> Node3D:
	var selected := _selection_in_track()
	if not selected.is_empty():
		return selected[-1]
	for i in range(_track.get_child_count() - 1, -1, -1):
		var child := _track.get_child(i) as Node3D
		if child != null:
			return child
	return null


func _selection_in_track() -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	if _track == null:
		return nodes
	for node in EditorInterface.get_selection().get_selected_nodes():
		var node_3d := node as Node3D
		if node_3d != null and node_3d != _track and _track.is_ancestor_of(node_3d):
			# Only the piece itself, not a mesh deeper inside it.
			while node_3d.get_parent() != _track and node_3d.get_parent() is Node3D:
				node_3d = node_3d.get_parent() as Node3D
			if not nodes.has(node_3d):
				nodes.append(node_3d)
	return nodes


func _on_course_requested(by_proximity: bool) -> void:
	if not _require_editable():
		return
	var entries := TrackGraph.one_per_gate(TrackGraph.collect(_track))
	if entries.is_empty():
		push_warning("Track Editor: la pista no tiene checkpoints.")
		return
	var course := TrackGraph.course_from_proximity(_track, entries) if by_proximity \
			else TrackGraph.course_from_order(entries)
	Actions.set_course(get_undo_redo(), _track, course)
	print_rich("[b]Track Editor[/b] recorrido de %d checkpoints: %s"
			% [entries.size(), course])
	_last_state = 0.0


func _on_floor_requested() -> void:
	if not _require_editable():
		return
	var nodes := _selection_in_track()
	if nodes.is_empty():
		push_warning("Track Editor: elegi una pieza de la pista para apoyarla.")
		return
	var moved := Actions.drop_to_floor(get_undo_redo(), nodes)
	if moved == 0:
		print_rich("[b]Track Editor[/b] las piezas ya estaban apoyadas.")
	_last_state = 0.0


func _on_snap_requested(degrees: float, yaw_only: bool) -> void:
	if not _require_editable():
		return
	var nodes := _selection_in_track()
	if nodes.is_empty():
		push_warning("Track Editor: elegi una pieza de la pista para rotarla.")
		return
	Actions.snap_rotation(get_undo_redo(), nodes, degrees, yaw_only)
	_last_state = 0.0


func _on_validate_requested() -> void:
	if _track == null:
		return
	var findings := Validator.validate(_track)
	print_rich("[b]Track Editor[/b] verificacion de %s" % [_track.name])
	var errors := 0
	var warnings := 0
	for finding: Dictionary in findings:
		var level: String = finding["level"]
		var color := "gray"
		if level == "error":
			color = "tomato"
			errors += 1
		elif level == "warn":
			color = "goldenrod"
			warnings += 1
		print_rich("  [color=%s]%s[/color]" % [color, finding["text"]])
	if errors == 0 and warnings == 0:
		print_rich("  [color=green]La pista esta lista.[/color]")
	else:
		print_rich("  %d error(es), %d aviso(s)." % [errors, warnings])


func _on_numbers_toggled(pressed: bool) -> void:
	_show_numbers = pressed
	var _discard := update_overlays()


func _require_editable() -> bool:
	if _track == null:
		return false
	if not _editable:
		push_warning("Track Editor: abri %s como escena para poder editarla."
				% [_track.scene_file_path])
		return false
	return true
