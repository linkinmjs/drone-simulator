class_name ChallengeCatalog
extends RefCounted
## The challenges of the progression mode, in the order they are unlocked.
##
## A challenge is a Track scene plus the times that earn each medal: ChallengeLevel loads the
## track into the shared challenge level, so adding one is writing the track scene and adding
## an entry here. The order of this list is the order of the menu, and a challenge opens up
## once the previous one has been finished (see GameSettings.is_challenge_unlocked).
##
## The progression follows how FPV is actually trained: first holding a line and a steady
## throttle, then coordinated turns, then height control, and only at the end dives and acro.
##
## `name` and `goal` are translation keys; `gold`, `silver` and `bronze` are total seconds for
## the whole run, laps included. THE TIMES ARE PROVISIONAL: they have to be flown and tuned.


enum Medal {NONE, BRONZE, SILVER, GOLD}

const CHALLENGES: Array[Dictionary] = [
	{
		"id": "gate-and-back",
		"name": "CHAL_GATE_AND_BACK_NAME",
		"goal": "CHAL_GATE_AND_BACK_GOAL",
		"track": "res://tracks/tracks/Track_Challenge_1_GateAndBack.tscn",
		"laps": 2,
		"gold": 24.0,
		"silver": 32.0,
		"bronze": 45.0,
	},
	{
		"id": "slalom",
		"name": "CHAL_SLALOM_NAME",
		"goal": "CHAL_SLALOM_GOAL",
		"track": "res://tracks/tracks/Track_Challenge_2_Slalom.tscn",
		"laps": 1,
		"gold": 22.0,
		"silver": 30.0,
		"bronze": 42.0,
	},
	{
		"id": "five-rings",
		"name": "CHAL_FIVE_RINGS_NAME",
		"goal": "CHAL_FIVE_RINGS_GOAL",
		"track": "res://tracks/tracks/Track_Challenge_3_FiveRings.tscn",
		"laps": 2,
		"gold": 40.0,
		"silver": 52.0,
		"bronze": 70.0,
	},
	{
		"id": "ladder",
		"name": "CHAL_LADDER_NAME",
		"goal": "CHAL_LADDER_GOAL",
		"track": "res://tracks/tracks/Track_Challenge_4_Ladder.tscn",
		"laps": 1,
		"gold": 26.0,
		"silver": 35.0,
		"bronze": 48.0,
	},
	{
		"id": "figure-eight",
		"name": "CHAL_FIGURE_EIGHT_NAME",
		"goal": "CHAL_FIGURE_EIGHT_GOAL",
		"track": "res://tracks/tracks/Track_Challenge_5_FigureEight.tscn",
		"laps": 3,
		"gold": 54.0,
		"silver": 70.0,
		"bronze": 95.0,
	},
	{
		"id": "dive",
		"name": "CHAL_DIVE_NAME",
		"goal": "CHAL_DIVE_GOAL",
		"track": "res://tracks/tracks/Track_Challenge_6_Dive.tscn",
		"laps": 2,
		"gold": 38.0,
		"silver": 50.0,
		"bronze": 68.0,
	},
]

const MEDAL_KEYS := {
	Medal.NONE: "CHAL_MEDAL_NONE",
	Medal.BRONZE: "CHAL_MEDAL_BRONZE",
	Medal.SILVER: "CHAL_MEDAL_SILVER",
	Medal.GOLD: "CHAL_MEDAL_GOLD",
}


static func count() -> int:
	return CHALLENGES.size()


static func get_challenge(index: int) -> Dictionary:
	if index < 0 or index >= CHALLENGES.size():
		return {}
	return CHALLENGES[index]


static func get_by_id(id: String) -> Dictionary:
	for challenge in CHALLENGES:
		if challenge["id"] == id:
			return challenge
	return {}


static func get_index(id: String) -> int:
	for i in CHALLENGES.size():
		if CHALLENGES[i]["id"] == id:
			return i
	return -1


## A time of 0 or less means the challenge was never finished.
static func medal_for(index: int, time: float) -> Medal:
	var challenge := get_challenge(index)
	if challenge.is_empty() or time <= 0.0:
		return Medal.NONE
	if time <= float(challenge["gold"]):
		return Medal.GOLD
	if time <= float(challenge["silver"]):
		return Medal.SILVER
	if time <= float(challenge["bronze"]):
		return Medal.BRONZE
	return Medal.NONE


static func medal_key(medal: Medal) -> String:
	return MEDAL_KEYS.get(medal, "CHAL_MEDAL_NONE")


## Time in the "00:00.00" form used by the lap timers.
static func format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "--:--.--"
	var minute := int(seconds / 60.0)
	var second := int(seconds - minute * 60)
	var decimal := floori((seconds - minute * 60 - second) * 100)
	return "%02d:%02d.%02d" % [minute, second, decimal]


## Entries for a ChoiceMenu, shared by the challenge menu and the picker inside the level.
## Each one: {"id", "text", "primary", "locked"}. A locked challenge is listed, greyed by its
## label, so the progression is visible instead of hidden.
static func menu_entries(current_id := "") -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var focus := GameSettings.get_first_unfinished_challenge()
	if not current_id.is_empty():
		focus = get_index(current_id)
	for i in CHALLENGES.size():
		var challenge := CHALLENGES[i]
		var id := str(challenge["id"])
		var unlocked: bool = GameSettings.is_challenge_unlocked(i)
		var best: float = GameSettings.get_best_time(id)
		var text := "%d. %s" % [i + 1, _translate(str(challenge["name"]))]
		if not unlocked:
			text += "   %s" % [_translate("CHAL_LOCKED")]
		elif best > 0.0:
			text += "   %s %s" % [_translate(medal_key(medal_for(i, best))), format_time(best)]
		entries.append({
			"id": id,
			"text": text,
			"primary": i == focus and unlocked,
			"locked": not unlocked,
		})
	return entries


static func _translate(key: String) -> String:
	return TranslationServer.translate(key)
