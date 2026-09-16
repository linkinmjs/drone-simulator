extends MenuScreen


## Paragraphs of the help page, in order. Each one is a translation key with BBCode.
const SECTIONS: Array[String] = ["HELP_INTRO", "HELP_DEVICE", "HELP_MENU_NAVIGATION",
		"HELP_KEYBOARD", "HELP_FLIGHT_MODES", "HELP_ARMING", "HELP_AXIS_RANGES", "HELP_HUD"]

@onready var label := %HelpLabel as RichTextLabel
@onready var button_back := %ButtonBack as Button


func _ready() -> void:
	initial_focus = label
	super()
	label.set_meta(&"no_focus_ring", true)
	var _discard := label.meta_clicked.connect(_on_url_clicked)
	bind_back_button(button_back)
	_build_text()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_build_text()


func _build_text() -> void:
	label.clear()
	var accent := UIPalette.ACCENT.to_html(false)
	for i in SECTIONS.size():
		var text := tr(SECTIONS[i]).replace("{accent}", accent)
		label.append_text(text)
		if i < SECTIONS.size() - 1:
			label.append_text("\n\n")


func _on_url_clicked(meta: Variant) -> void:
	var _discard := OS.shell_open(str(meta))
