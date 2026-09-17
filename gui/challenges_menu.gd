extends MenuScreen
## List of the challenges with their medal and best time. Built from ChallengeCatalog, so a
## new challenge shows up here on its own. One line each, with the skill it trains and the
## target times shown below for whichever one has the focus: with ten entries a two-line
## button per challenge no longer fits on a 720p screen.


const CHALLENGE_SCENE := "res://sceneries/challenge_level.tscn"

@onready var subtitle := %Subtitle as Label
@onready var list := %List as VBoxContainer
@onready var detail := %Detail as Label
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
		# The menu buttons are 30 px by default: ten of those do not fit on a 720p screen.
		button.add_theme_font_size_override(&"font_size", 22)
		button.text = str(entry["text"])
		button.disabled = bool(entry["locked"])
		list.add_child(button)
		if button.disabled:
			continue
		var _discard := button.pressed.connect(_on_challenge_pressed.bind(str(entry["id"])))
		_discard = button.focus_entered.connect(_show_detail.bind(index))
		_discard = button.mouse_entered.connect(_show_detail.bind(index))
		if focus == null or bool(entry["primary"]):
			focus = button

	# MenuScreen grabs the initial focus deferred, after this runs: setting it here instead of
	# grabbing the focus by hand keeps it from moving the scroll afterwards.
	initial_focus = focus if focus != null else button_back
	grab_initial_focus.call_deferred(true)
	if focus != null:
		# The buttons are added in catalogue order, locked ones included.
		_show_detail(focus.get_index())
	else:
		detail.text = ""


## The skill the challenge trains and the times that earn each medal.
func _show_detail(index: int) -> void:
	var challenge := ChallengeCatalog.get_challenge(index)
	if challenge.is_empty():
		detail.text = ""
		return
	detail.text = "%s\n%s" % [tr(str(challenge["goal"])), tr("CHAL_TARGETS") % [
			ChallengeCatalog.format_time(float(challenge["gold"])),
			ChallengeCatalog.format_time(float(challenge["silver"])),
			ChallengeCatalog.format_time(float(challenge["bronze"]))]]


func _on_challenge_pressed(id: String) -> void:
	Global.selected_challenge = id
	SceneTransition.change_scene(CHALLENGE_SCENE, true)
