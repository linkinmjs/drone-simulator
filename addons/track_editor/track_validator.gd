@tool
extends RefCounted
## Checks a Track for the mistakes that only show up once the race is running: no launchpad
## (no countdown and no false start), a course pointing at checkpoints that do not exist,
## gates the runtime will not see, and legs that are suspiciously short, long or backwards.
## Returns findings so the same code serves the editor button and the headless check.
## Each finding: {"level": "error" | "warn" | "info", "text": String}.


const TrackGraph := preload("res://addons/track_editor/track_graph.gd")

const MIN_LEG := 3.0
const MAX_LEG := 80.0


static func validate(track: Node3D) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if track == null:
		findings.append(_finding("error", "No hay ninguna pista para verificar."))
		return findings

	var entries := TrackGraph.collect(track)
	_check_launchpad(track, findings)
	_check_gates(track, entries, findings)

	if entries.is_empty():
		findings.append(_finding("error", "La pista no tiene ningun checkpoint."))
		return findings

	var course: String = track.get("course")
	var tokens := TrackGraph.course_tokens(course, entries.size())
	_check_tokens(tokens, entries, findings)
	_check_unused(tokens, entries, findings)
	_check_legs(entries, tokens, findings)
	return findings


static func _finding(level: String, text: String) -> Dictionary:
	return {"level": level, "text": text}


static func _check_launchpad(track: Node3D, findings: Array[Dictionary]) -> void:
	var launchpad := TrackGraph.find_launchpad(track)
	if launchpad == null:
		findings.append(_finding("error",
				"Falta la plataforma de largada: sin ella no hay cuenta regresiva ni salida en falso."))
		return
	var areas := TrackGraph.count_launch_areas(launchpad)
	if areas == 0:
		findings.append(_finding("error",
				"La plataforma de largada no tiene ninguna LaunchArea."))
	else:
		findings.append(_finding("info", "Plataforma de largada con %d posiciones." % [areas]))


static func _check_gates(track: Node3D, entries: Array[Dictionary], findings: Array[Dictionary]) -> void:
	for child in track.get_children():
		if not child is Gate:
			continue
		var has_checkpoint := false
		for sub in child.get_children():
			if sub is Checkpoint:
				has_checkpoint = true
				break
		if has_checkpoint:
			continue
		if TrackGraph.is_procedural_gate(child):
			findings.append(_finding("info",
					"%s arma su checkpoint al arrancar el juego (no se ve en el editor)." % [child.name]))
		else:
			findings.append(_finding("error",
					"%s no tiene ningun Checkpoint: la pista no lo va a contar." % [child.name]))

	var deep := _find_deep_checkpoints(track, entries)
	for node: Node in deep:
		findings.append(_finding("warn",
				"%s cuelga demasiado profundo y la pista lo ignora: tiene que ser hijo directo de la pista o de un Gate."
				% [String(track.get_path_to(node))]))


static func _find_deep_checkpoints(track: Node3D, entries: Array[Dictionary]) -> Array[Node]:
	var known: Array[Node] = []
	for entry in entries:
		known.append(entry["node"])
	var deep: Array[Node] = []
	var stack: Array[Node] = track.get_children()
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Checkpoint and not known.has(node):
			deep.append(node)
		stack.append_array(node.get_children())
	return deep


static func _check_tokens(tokens: PackedStringArray, entries: Array[Dictionary],
		findings: Array[Dictionary]) -> void:
	for i in tokens.size():
		var parsed := TrackGraph.parse_token(tokens[i], entries.size())
		if parsed["valid"]:
			continue
		findings.append(_finding("error",
				"El recorrido tiene \"%s\" en la posicion %d y no es un checkpoint valido (hay %d)."
				% [tokens[i], i, entries.size()]))


static func _check_unused(tokens: PackedStringArray, entries: Array[Dictionary],
		findings: Array[Dictionary]) -> void:
	var used: Array[int] = []
	for token in tokens:
		var parsed := TrackGraph.parse_token(token, entries.size())
		if parsed["valid"] and str(parsed["marker"]).is_empty():
			used.append(parsed["index"])
	var unused := PackedStringArray()
	for entry in entries:
		if not used.has(entry["index"]):
			unused.append(str(entry["index"]))
	if not unused.is_empty():
		findings.append(_finding("warn",
				"El recorrido no pasa por los checkpoints %s." % [", ".join(unused)]))


static func _check_legs(entries: Array[Dictionary], tokens: PackedStringArray,
		findings: Array[Dictionary]) -> void:
	var legs := TrackGraph.leg_distances(entries, tokens)
	if legs.is_empty():
		return
	var total := 0.0
	var shortest := INF
	var longest := 0.0
	for leg: Dictionary in legs:
		var distance: float = leg["distance"]
		total += distance
		shortest = minf(shortest, distance)
		longest = maxf(longest, distance)
		if distance <= 0.001:
			findings.append(_finding("error",
					"El recorrido repite el checkpoint %d dos veces seguidas." % [leg["to"]]))
		elif distance < MIN_LEG:
			findings.append(_finding("warn",
					"Del checkpoint %d al %d hay %.1f m: quedaron muy pegados."
					% [leg["from"], leg["to"], distance]))
		elif distance > MAX_LEG:
			findings.append(_finding("warn",
					"Del checkpoint %d al %d hay %.1f m: es un tramo largo."
					% [leg["from"], leg["to"], distance]))
		_check_direction(entries, leg, findings)
	findings.append(_finding("info",
			"%d tramos, %.1f m en total (el mas corto %.1f m, el mas largo %.1f m)."
			% [legs.size(), total, shortest, longest]))


static func _check_direction(entries: Array[Dictionary], leg: Dictionary,
		findings: Array[Dictionary]) -> void:
	var from_entry: Dictionary = entries[leg["from"]]
	var to_entry: Dictionary = entries[leg["to"]]
	var approach := TrackGraph.entry_origin(to_entry) - TrackGraph.entry_origin(from_entry)
	if approach.length_squared() <= 0.001:
		return
	var aligned := approach.normalized().dot(TrackGraph.entry_forward(to_entry))
	var backward: bool = leg["backward"]
	if aligned < 0.0 and not backward:
		findings.append(_finding("warn",
				"Al checkpoint %d se llega por atras: quizas le falte el sufijo \"b\"." % [leg["to"]]))
	elif aligned > 0.0 and backward:
		findings.append(_finding("warn",
				"Al checkpoint %d se llega de frente pero el recorrido dice \"b\"." % [leg["to"]]))
