extends Node
## Checks every track scene with the same code the editor toolbar uses, so a broken course or
## a missing launchpad shows up without opening the editor:
##   godot --headless --path . res://tools/track_check.tscn
## Exits with code 0 when no track has errors. Warnings are printed but do not fail the run.


const TRACKS_DIR := "res://tracks/tracks"

const TrackGraph := preload("res://addons/track_editor/track_graph.gd")
const Validator := preload("res://addons/track_editor/track_validator.gd")
const TrackPieces := preload("res://addons/track_editor/track_pieces.gd")

var failures := 0


func _ready() -> void:
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	print("  %s %s" % ["ok  " if condition else "FAIL", label])
	if not condition:
		failures += 1


func _run() -> void:
	Global.startup = false
	var paths := _track_paths()
	print("== %d pistas en %s" % [paths.size(), TRACKS_DIR])
	check(not paths.is_empty(), "hay pistas para revisar")

	for path in paths:
		await _check_track(path)

	await _check_pieces()
	await _check_overlay()

	print("== Result: %d failure(s)" % [failures])
	get_tree().quit(1 if failures > 0 else 0)


func _track_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	var dir := DirAccess.open(TRACKS_DIR)
	if dir == null:
		return paths
	for file in dir.get_files():
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tscn"):
			paths.append("%s/%s" % [TRACKS_DIR, name])
	paths.sort()
	return paths


func _check_track(path: String) -> void:
	print("\n== %s" % [path.get_file()])
	var packed := load(path) as PackedScene
	if packed == null:
		check(false, "la escena carga")
		return
	var track := packed.instantiate() as Node3D
	add_child(track)
	await get_tree().process_frame

	var entries := TrackGraph.collect(track)
	var runtime_count := (track.get("checkpoints") as Array).size()
	check(not entries.is_empty(), "tiene checkpoints (%d)" % [entries.size()])
	# What the editor numbers must match what Track built for the race.
	check(entries.size() == runtime_count,
			"la numeracion del editor coincide con la del juego (%d vs %d)"
			% [entries.size(), runtime_count])

	var errors := 0
	for finding: Dictionary in Validator.validate(track):
		var level: String = finding["level"]
		if level == "error":
			errors += 1
			print("     error: %s" % [finding["text"]])
		elif level == "warn":
			print("     aviso: %s" % [finding["text"]])
	check(errors == 0, "no tiene errores de armado")

	remove_child(track)
	track.queue_free()


## Every piece the editor toolbar offers must load, and the ones that take part in the course
## must bring a checkpoint with them.
func _check_pieces() -> void:
	print("
== Piezas de la paleta")
	for piece: Dictionary in TrackPieces.PIECES:
		var path: String = piece["path"]
		var label: String = piece["label"]
		if not ResourceLoader.exists(path):
			check(false, "%s existe" % [label])
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			check(false, "%s carga" % [label])
			continue
		var node := packed.instantiate() as Node3D
		add_child(node)
		await get_tree().process_frame
		if piece["gate"]:
			var holder := Node3D.new()
			remove_child(node)
			holder.add_child(node)
			add_child(holder)
			await get_tree().process_frame
			var entries := TrackGraph.collect(holder)
			check(not entries.is_empty(), "%s aporta checkpoint" % [label])
			holder.queue_free()
		else:
			check(true, "%s carga" % [label])
			node.queue_free()


## The numbering drawn over the 3D viewport is the heart of the addon, and it only runs inside
## the editor: this paints it here, with a real track and a real camera, so a mistake in the
## drawing code shows up in the check instead of in the editor.
func _check_overlay() -> void:
	print("
== Numeracion sobre la vista 3D")
	var packed := load("%s/Track_FigureEight.tscn" % [TRACKS_DIR]) as PackedScene
	var track := packed.instantiate() as Node3D
	add_child(track)
	await get_tree().process_frame

	var camera := Camera3D.new()
	add_child(camera)
	camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 30, 60))
	camera.current = true

	var probe := (load("res://tools/overlay_probe.gd") as Script).new() as Control
	probe.size = Vector2(1280, 720)
	probe.entries = TrackGraph.collect(track)
	probe.tokens = TrackGraph.course_tokens(track.get("course"), probe.entries.size())
	probe.camera = camera
	probe.selected = 3
	add_child(probe)
	probe.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame

	check(probe.draw_count > 0, "el overlay se dibujo")
	check(probe.tokens.size() > 2, "el recorrido tiene tramos para dibujar (%d)"
			% [probe.tokens.size()])

	# Behind the camera, too far away and an empty course must not break the drawing.
	camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 30, -400))
	probe.tokens = TrackGraph.course_tokens("", probe.entries.size())
	probe.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	check(probe.draw_count > 1, "el overlay se dibujo con la pista detras de la camara")

	probe.queue_free()
	camera.queue_free()
	track.queue_free()
