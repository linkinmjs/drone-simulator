extends Control
## Draws the editor overlay outside the editor, so the check can prove the drawing code runs.
## The addon normally paints this over the 3D viewport of the editor.


const Overlay := preload("res://addons/track_editor/track_editor_overlay.gd")

signal drawn(error: String)

var entries: Array[Dictionary] = []
var tokens := PackedStringArray()
var camera: Camera3D = null
var selected := -1
var draw_count := 0


func _draw() -> void:
	var font := ThemeDB.fallback_font
	Overlay.draw(self, camera, entries, tokens, selected, font, 16)
	draw_count += 1
	drawn.emit("")
