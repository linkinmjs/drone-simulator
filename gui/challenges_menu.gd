extends MenuScreen
## List of the challenges with their medal, best time and target times. The list is built
## from ChallengeCatalog, so a new challenge shows up here on its own.


const CHALLENGE_SCENE := "res://sceneries/challenge_level.tscn"

@onready var subtitle := %Subtitle as Label
@onready var list := %List as VBoxContainer
@onready var button_back := %ButtonBack as Button


func _ready() -> void:
	super()
	bind_back_button(button_back)
	GameSettings.load_challenge_progress()
	_build_list()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_build_list()


func _build_list() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()

	subtitle.text = tr("CHAL_MENU_SUBTITLE") % [GameSettings.get_finished_challenge_count(),
			ChallengeCatalog.count()]

	var focus: Button = null
	for entry: Dictionary in ChallengeCatalog.menu_entries():
		var index := ChallengeCatalog.get_index(str(entry["id"]))
		var button := Button.new()
		button.theme_type_variation = &"MenuItemButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = false
		button.text = "%s\n%s" % [entry["text"], _details(index)]
		button.disabled = bool(entry["locked"])
		list.add_child(button)
		if not button.disabled:
			var _discard := button.pressed.connect(_on_challenge_pressed.bind(str(entry["id"])))
			if focus == null or bool(entry["primary"]):
				focus = button

	if focus != null:
		focus.grab_focus()
	else:
		button_back.grab_focus()


## Second line of a challenge: the skill it trains and the times that earn each medal.
func _details(index: int) -> String:
	var challenge := ChallengeCatalog.get_challenge(index)
	if challenge.is_empty():
		return ""
	return "%s   %s" % [tr(str(challenge["goal"])), tr("CHAL_TARGETS") % [
			ChallengeCatalog.format_time(float(challenge["gold"])),
			ChallengeCatalog.format_time(float(challenge["silver"])),
			ChallengeCatalog.format_time(float(challenge["bronze"]))]]


func _on_challenge_pressed(id: String) -> void:
	Global.selected_challenge = id
	SceneTransition.change_scene(CHALLENGE_SCENE, true)
