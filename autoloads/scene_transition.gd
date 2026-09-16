extends CanvasLayer
## Fades to the menu background color while changing scenes.


const DURATION := 0.25

var _rect: ColorRect = null
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = UIPalette.BG
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	_rect.visible = false
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	_rect.visible = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	var _step1 := tween.tween_property(_rect, "modulate:a", 1.0, DURATION)
	await tween.finished
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Could not change scene to %s (error %d)" % [path, err])
	# Give the new scene a couple of frames to build before revealing it
	await get_tree().process_frame
	await get_tree().process_frame
	tween = create_tween()
	var _step2 := tween.tween_property(_rect, "modulate:a", 0.0, DURATION)
	await tween.finished
	_rect.visible = false
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
