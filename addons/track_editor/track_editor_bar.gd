@tool
extends HBoxContainer
## The toolbar shown above the 3D viewport while a Track is selected. It only emits what the
## user asked for; the plugin does the work.


signal piece_requested(id: StringName)
signal course_requested(by_proximity: bool)
signal floor_requested
signal snap_requested(degrees: float, yaw_only: bool)
signal validate_requested
signal numbers_toggled(pressed: bool)


const TrackPieces := preload("res://addons/track_editor/track_pieces.gd")

const SNAP_STEPS: Array[float] = [15.0, 45.0, 90.0]

var _numbers_button: CheckButton = null


func _ready() -> void:
	add_theme_constant_override(&"separation", 4)
	_build_pieces_menu()
	_build_course_menu()
	_build_floor_button()
	_build_snap_menu()
	_build_validate_button()
	_build_numbers_toggle()


func set_numbers_pressed(pressed: bool) -> void:
	if _numbers_button != null:
		_numbers_button.set_pressed_no_signal(pressed)


func _icon(name: StringName) -> Texture2D:
	var base := EditorInterface.get_base_control()
	if base != null and base.has_theme_icon(name, &"EditorIcons"):
		return base.get_theme_icon(name, &"EditorIcons")
	return null


func _build_pieces_menu() -> void:
	var button := MenuButton.new()
	button.text = "Agregar"
	button.tooltip_text = "Agrega la pieza encadenada delante de la seleccionada"
	button.icon = _icon(&"Add")
	button.flat = false
	add_child(button)
	var popup := button.get_popup()
	for i in TrackPieces.PIECES.size():
		var piece: Dictionary = TrackPieces.PIECES[i]
		popup.add_item(piece["label"] as String, i)
		if not ResourceLoader.exists(piece["path"] as String):
			popup.set_item_disabled(-1, true)
			popup.set_item_tooltip(-1, "Falta %s" % [piece["path"]])
	var _discard := popup.id_pressed.connect(_on_piece_id_pressed)


func _on_piece_id_pressed(id: int) -> void:
	var piece: Dictionary = TrackPieces.PIECES[id]
	piece_requested.emit(piece["id"] as StringName)


func _build_course_menu() -> void:
	var button := MenuButton.new()
	button.text = "Recorrido"
	button.tooltip_text = "Genera el campo Course de la pista"
	button.icon = _icon(&"CurveLinear")
	add_child(button)
	var popup := button.get_popup()
	popup.add_item("Por orden en el arbol", 0)
	popup.add_item("Por cercania desde la largada", 1)
	var _discard := popup.id_pressed.connect(func(id: int) -> void: course_requested.emit(id == 1))


func _build_floor_button() -> void:
	var button := Button.new()
	button.text = "Piso"
	button.tooltip_text = "Apoya la pieza seleccionada sobre el piso (y = 0)"
	button.icon = _icon(&"Anchor")
	add_child(button)
	var _discard := button.pressed.connect(func() -> void: floor_requested.emit())


func _build_snap_menu() -> void:
	var button := MenuButton.new()
	button.text = "Rotacion"
	button.tooltip_text = "Redondea la rotacion de la pieza seleccionada"
	button.icon = _icon(&"RotateLeft")
	add_child(button)
	var popup := button.get_popup()
	var id := 0
	for step in SNAP_STEPS:
		popup.add_item("Giro a %d grados" % [step], id)
		id += 1
	popup.add_separator()
	for step in SNAP_STEPS:
		popup.add_item("Los tres ejes a %d grados" % [step], id)
		id += 1
	var _discard := popup.id_pressed.connect(_on_snap_id_pressed)


func _on_snap_id_pressed(id: int) -> void:
	var count := SNAP_STEPS.size()
	var yaw_only := id < count
	var step: float = SNAP_STEPS[id % count]
	snap_requested.emit(step, yaw_only)


func _build_validate_button() -> void:
	var button := Button.new()
	button.text = "Verificar"
	button.tooltip_text = "Revisa la pista e informa los problemas en la salida"
	button.icon = _icon(&"Search")
	add_child(button)
	var _discard := button.pressed.connect(func() -> void: validate_requested.emit())


func _build_numbers_toggle() -> void:
	_numbers_button = CheckButton.new()
	_numbers_button.text = "Numeros"
	_numbers_button.tooltip_text = "Muestra el numero de cada checkpoint y el recorrido"
	_numbers_button.button_pressed = true
	add_child(_numbers_button)
	var _discard := _numbers_button.toggled.connect(func(on: bool) -> void: numbers_toggled.emit(on))
