@tool
extends RefCounted
## Pure track geometry and course logic, shared by the editor toolbar and tools/challenge_check.
##
## It mirrors what Track does at runtime (see tracks/track.gd): the checkpoint index is the
## order of the Track children, a Gate contributes its Checkpoint children and a loose
## Checkpoint contributes itself. One thing is added on top: ProceduralGate is not a @tool
## script, so its checkpoint does not exist while editing. Such a gate is listed as a
## "virtual" checkpoint sitting at the gate origin, which is where ProceduralGate puts it at
## run time, so the indices shown in the editor match the ones the game will use.


const MARKER_START := "lap_start"
const MARKER_END := "lap_end"


## One entry per checkpoint, in the exact order Track.update_checkpoints() builds them.
## Keys: index, node, gate, xform, virtual.
static func collect(track: Node3D) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if track == null:
		return entries
	for child in track.get_children():
		if child is Gate:
			var found := 0
			for sub in child.get_children():
				if sub is Checkpoint:
					entries.append(_entry(entries.size(), sub, child, false))
					found += 1
			if found == 0 and is_procedural_gate(child):
				entries.append(_entry(entries.size(), child, child, true))
		elif child is Checkpoint:
			entries.append(_entry(entries.size(), child, null, false))
	return entries


static func _entry(index: int, node: Node, gate: Node, virtual: bool) -> Dictionary:
	var node_3d := node as Node3D
	return {
		"index": index,
		"node": node_3d,
		"gate": gate as Node3D,
		"xform": node_3d.global_transform if node_3d != null else Transform3D.IDENTITY,
		"virtual": virtual,
	}


static func is_procedural_gate(node: Node) -> bool:
	return node is ProceduralGate


## Direction a checkpoint is crossed forwards: its -Z, matching Checkpoint.get_velocity_check().
static func entry_forward(entry: Dictionary) -> Vector3:
	var basis: Basis = (entry["xform"] as Transform3D).basis
	return -basis.z.normalized()


static func entry_origin(entry: Dictionary) -> Vector3:
	return (entry["xform"] as Transform3D).origin


## Splits a token of the course string. Keys: marker, index, backward, valid.
static func parse_token(token: String, count: int) -> Dictionary:
	var result := {"marker": "", "index": -1, "backward": false, "valid": false}
	var text := token.strip_edges()
	if text == MARKER_START or text == MARKER_END:
		result["marker"] = text
		result["valid"] = true
		return result
	var backward := text.ends_with("b")
	if backward:
		text = text.substr(0, text.length() - 1)
	if text.is_empty() or not text.is_valid_int():
		return result
	var index := text.to_int()
	result["index"] = index
	result["backward"] = backward
	result["valid"] = index >= 0 and index < count
	return result


## The tokens Track will actually run, including the markers it inserts when they are missing.
static func course_tokens(course: String, count: int) -> PackedStringArray:
	var text := course.replace("\n", ",").replace(" ", "")
	var tokens := PackedStringArray()
	if text.is_empty():
		for i in count:
			tokens.append(str(i))
	else:
		for part in text.split(","):
			if not part.is_empty():
				tokens.append(part)
	if not tokens.has(MARKER_START):
		tokens.insert(0, MARKER_START)
	if not tokens.has(MARKER_END):
		tokens.append(MARKER_END)
	return tokens


## Keeps the first checkpoint of each gate: a triple gate offers three ways through the same
## obstacle, and the course must name only one of them.
static func one_per_gate(entries: Array[Dictionary]) -> Array[Dictionary]:
	var kept: Array[Dictionary] = []
	var seen: Array[Node] = []
	for entry in entries:
		var gate: Node = entry["gate"]
		if gate != null:
			if seen.has(gate):
				continue
			seen.append(gate)
		kept.append(entry)
	return kept


static func course_from_order(entries: Array[Dictionary]) -> String:
	var parts := PackedStringArray([MARKER_START])
	for entry in entries:
		parts.append(str(entry["index"]))
	parts.append(MARKER_END)
	return ",".join(parts)


## Greedy nearest neighbour from the launchpad, adding the "b" suffix when the checkpoint is
## reached against its front. It is a starting point, not an answer: a course that crosses
## itself (a figure eight) will need hand editing afterwards.
static func course_from_proximity(track: Node3D, entries: Array[Dictionary]) -> String:
	var pending := entries.duplicate()
	var parts := PackedStringArray([MARKER_START])
	var from := Vector3.ZERO
	var launchpad := find_launchpad(track)
	if launchpad != null:
		from = launchpad.global_transform.origin
	while not pending.is_empty():
		var best := 0
		var best_distance := INF
		for i in pending.size():
			var distance := entry_origin(pending[i]).distance_to(from)
			if distance < best_distance:
				best_distance = distance
				best = i
		var entry: Dictionary = pending[best]
		pending.remove_at(best)
		var token := str(entry["index"])
		var approach := entry_origin(entry) - from
		if approach.length_squared() > 0.0 and approach.normalized().dot(entry_forward(entry)) < 0.0:
			token += "b"
		parts.append(token)
		from = entry_origin(entry)
	parts.append(MARKER_END)
	return ",".join(parts)


static func find_launchpad(track: Node3D) -> Node3D:
	if track == null:
		return null
	for child in track.get_children():
		if child is Launchpad:
			return child as Node3D
	return null


## Launchpad.launch_areas is only filled in _ready(), so the areas are counted by hand here.
static func count_launch_areas(launchpad: Node3D) -> int:
	if launchpad == null:
		return 0
	var count := 0
	for child in launchpad.get_children():
		if child is LaunchArea:
			count += 1
	return count


## Distance of every leg of the course, in course order.
## Keys: from, to, distance, backward.
static func leg_distances(entries: Array[Dictionary], tokens: PackedStringArray) -> Array[Dictionary]:
	var legs: Array[Dictionary] = []
	var previous := -1
	for token in tokens:
		var parsed := parse_token(token, entries.size())
		if not parsed["valid"] or not str(parsed["marker"]).is_empty():
			continue
		var index: int = parsed["index"]
		if previous >= 0:
			legs.append({
				"from": previous,
				"to": index,
				"distance": entry_origin(entries[previous]).distance_to(entry_origin(entries[index])),
				"backward": parsed["backward"],
			})
		previous = index
	return legs
