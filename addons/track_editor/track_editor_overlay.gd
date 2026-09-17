@tool
extends RefCounted
## Draws the checkpoint numbers and the course path over the 3D viewport.
##
## This is what turns the `course` string into something readable: every checkpoint shows the
## index the Track will give it and the places where the course visits it, and the legs are
## drawn in order so a wrong turn is visible at a glance. Done in 2D over the viewport rather
## than with a gizmo because a gizmo cannot draw text.


const TrackGraph := preload("res://addons/track_editor/track_graph.gd")

const COLOR_PATH := Color(0.31, 0.61, 1.0, 0.9)
const COLOR_PATH_BACK := Color(1.0, 0.55, 0.15, 0.9)
const COLOR_LABEL := Color(1.0, 1.0, 1.0)
const COLOR_VIRTUAL := Color(0.65, 0.85, 1.0)
const COLOR_SELECTED := Color(1.0, 0.85, 0.2)
const COLOR_ORDER := Color(0.55, 0.85, 1.0)
const COLOR_BACKDROP := Color(0.0, 0.0, 0.0, 0.55)

const MAX_DISTANCE := 400.0
const LABEL_PADDING := Vector2(8, 5)


static func draw(overlay: Control, camera: Camera3D, entries: Array[Dictionary],
		tokens: PackedStringArray, selected: int, font: Font, font_size: int) -> void:
	if overlay == null or camera == null or font == null or entries.is_empty():
		return
	var positions := _screen_positions(overlay, camera, entries)
	_draw_path(overlay, entries, tokens, positions)
	_draw_labels(overlay, entries, tokens, positions, selected, font, font_size)


## Screen position of every checkpoint, or null when it is behind the camera or too far.
static func _screen_positions(overlay: Control, camera: Camera3D,
		entries: Array[Dictionary]) -> Array:
	var positions := []
	var scale := Vector2.ONE
	var viewport_size := camera.get_viewport().get_visible_rect().size
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		scale = overlay.size / viewport_size
	var eye := camera.global_transform.origin
	for entry in entries:
		var world := TrackGraph.entry_origin(entry)
		if camera.is_position_behind(world) or eye.distance_to(world) > MAX_DISTANCE:
			positions.append(null)
		else:
			positions.append(camera.unproject_position(world) * scale)
	return positions


static func _draw_path(overlay: Control, entries: Array[Dictionary], tokens: PackedStringArray,
		positions: Array) -> void:
	var previous := -1
	for token in tokens:
		var parsed := TrackGraph.parse_token(token, entries.size())
		if not parsed["valid"] or not str(parsed["marker"]).is_empty():
			continue
		var index: int = parsed["index"]
		if previous >= 0 and positions[previous] != null and positions[index] != null:
			var color: Color = COLOR_PATH_BACK if parsed["backward"] else COLOR_PATH
			overlay.draw_line(positions[previous], positions[index], color, 2.0, true)
		previous = index


static func _draw_labels(overlay: Control, entries: Array[Dictionary], tokens: PackedStringArray,
		positions: Array, selected: int, font: Font, font_size: int) -> void:
	var order := _order_by_checkpoint(entries, tokens)
	for entry in entries:
		var index: int = entry["index"]
		if positions[index] == null:
			continue
		var label := str(index)
		if entry["virtual"]:
			label += "*"
		var color := COLOR_VIRTUAL if entry["virtual"] else COLOR_LABEL
		if index == selected:
			color = COLOR_SELECTED
		_draw_label(overlay, positions[index], label, order[index], color, font, font_size)


## For each checkpoint, where it shows up in the course ("#2 #7b"), so a repeated gate reads
## as one label instead of forcing a count through the string.
static func _order_by_checkpoint(entries: Array[Dictionary], tokens: PackedStringArray) -> Array:
	var order := []
	for _i in entries.size():
		order.append(PackedStringArray())
	var step := 0
	for token in tokens:
		var parsed := TrackGraph.parse_token(token, entries.size())
		if not parsed["valid"] or not str(parsed["marker"]).is_empty():
			continue
		var text := "#%d" % [step]
		if parsed["backward"]:
			text += "b"
		(order[parsed["index"]] as PackedStringArray).append(text)
		step += 1
	return order


static func _draw_label(overlay: Control, position: Vector2, text: String,
		order: PackedStringArray, color: Color, font: Font, font_size: int) -> void:
	var small := maxi(font_size - 3, 8)
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var order_text := " ".join(order)
	var order_size := Vector2.ZERO
	if not order_text.is_empty():
		order_size = font.get_string_size(order_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, small)

	var width := maxf(size.x, order_size.x) + LABEL_PADDING.x * 2.0
	var height := size.y + order_size.y + LABEL_PADDING.y * 2.0
	var top_left := position - Vector2(width * 0.5, height + 10.0)
	overlay.draw_rect(Rect2(top_left, Vector2(width, height)), COLOR_BACKDROP, true)

	# draw_string places the baseline, not the top left corner.
	var baseline := top_left + Vector2((width - size.x) * 0.5, LABEL_PADDING.y + font.get_ascent(font_size))
	overlay.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
	if not order_text.is_empty():
		var order_pos := Vector2(top_left.x + (width - order_size.x) * 0.5,
				baseline.y + font.get_descent(font_size) + font.get_ascent(small))
		overlay.draw_string(font, order_pos, order_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				small, COLOR_ORDER)
