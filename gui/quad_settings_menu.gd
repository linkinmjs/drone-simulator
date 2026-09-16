extends Control


signal back


## Help texts shown as tooltips. The rate ones depend on the selected curve,
## because the three sliders change meaning with it.
const HELP_CAMERA_ANGLE := """Inclinación de la cámara FPV respecto al dron, en grados.
A mayor ángulo, más inclinado hacia adelante tenés que volar para ver el horizonte,
es decir, más rápido. Orientativo: 15-25 para freestyle tranquilo, 30-45 para carreras."""
const HELP_DRY_WEIGHT := """Peso del dron sin batería, en gramos.
Más peso significa más inercia, respuestas más lentas y menos empuje sobrante.
Orientativo: 550 g es un 5 pulgadas de freestyle con cámara de acción; 300 g, uno de carreras."""
const HELP_BATTERY_WEIGHT := """Peso de la batería, en gramos. Se suma al peso en seco.
Orientativo: una LiPo 4S de 1300 mAh pesa unos 180 g; una 6S de 1100 mAh, unos 200 g."""
const HELP_RATES_CURVE := """Fórmula que convierte la posición del stick en velocidad de giro.
Todas describen lo mismo con parámetros distintos. ACTUAL es la más fácil de razonar
porque sus valores están directamente en grados por segundo.
Al cambiar de curva los números se conservan pero cambian de significado:
pulsá Reset Rates para cargar valores razonables de la curva elegida."""
const HELP_PITCH := """Pitch: inclinar el morro arriba o abajo (stick derecho adelante y atrás).
Es lo que hace avanzar o frenar al dron."""
const HELP_ROLL := """Roll: inclinarse a izquierda o derecha (stick derecho lateral).
Desplaza el dron de costado. Conviene mantenerlo igual que Pitch:
el dron es simétrico en estos dos ejes."""
const HELP_YAW := """Yaw: girar sobre el eje vertical, cambiar hacia dónde mira el morro
(stick izquierdo lateral). Es el eje más débil del dron, porque solo dispone
del par de reacción de las hélices, así que suele llevar un máximo algo menor."""
const HELP_GRAPH := """Eje horizontal: posición del stick, de todo a la izquierda a todo a la derecha.
Eje vertical: velocidad de giro que pide esa posición.
P, R e Y: máximo de cada eje en grados por segundo."""
const HELP_RESET_QUAD := "Restaura el ángulo de cámara y los pesos por defecto."
const HELP_RESET_RATES := "Carga los valores por defecto de la curva de rates seleccionada."

## Per curve: help texts for the [rate, rc, expo] columns.
const HELP_RATES := {
	ControlProfile.RateCurve.ACTUAL: [
		"""Max Rate: velocidad de giro con el stick a fondo, en grados por segundo.
Define lo rápido que podés hacer un flip: a 360 un giro completo tarda 1 segundo.
Debe ser mayor que Center Rate; si son iguales, la curva es una recta y Expo no hace nada.
Orientativo: 400 para aprender, 670 es el valor por defecto de Betaflight.""",
		"""Center Rate: sensibilidad cerca del centro, en grados por segundo.
Al 10 % de stick obtenés el 10 % de este valor. Es el número que más define
la sensación en vuelo normal, porque casi siempre volás cerca del centro.
Orientativo: 70-100 para empezar, hasta 200 para pilotos ágiles.""",
		"""Expo: reparte la diferencia entre Center Rate y Max Rate a lo largo del recorrido.
Con 0 la curva sube de forma progresiva desde el centro. Con valores altos se mantiene
cerca de Center Rate en gran parte del recorrido y la subida se concentra en los extremos:
precisión en el centro sin renunciar a un máximo alto. Orientativo: 0.3.""",
	],
	ControlProfile.RateCurve.RACEFLIGHT: [
		"""Rate: velocidad de giro base con el stick a fondo, en grados por segundo, con Acro+ en 0.""",
		"""Acro+: añade velocidad extra hacia los extremos del stick.
El máximo real pasa a ser Rate x (1 + Acro+ / 100).""",
		"""Expo: suaviza la zona central. 0 es lineal; cuanto más alto, más plano cerca del centro.""",
	],
	ControlProfile.RateCurve.KISS: [
		"""Rate: curva "super rate" de 0 a 99. Cuanto mayor, más se concentra
la velocidad en los extremos del stick y mayor es el máximo.""",
		"""RC Rate: sensibilidad general del stick. Multiplica toda la curva.""",
		"""RC Curve: expo de la zona central. 0 es lineal; cuanto más alto, más suave cerca del centro.""",
	],
	ControlProfile.RateCurve.QUICKRATES: [
		"""Max Rate: velocidad de giro con el stick a fondo, en grados por segundo.""",
		"""RC Rate: sensibilidad cerca del centro.""",
		"""Expo: suaviza la zona central. 0 es lineal; cuanto más alto, más plano cerca del centro.""",
	],
}


@onready var camera_angle_label := %CameraAngleLabel as Label
@onready var camera_angle_slider := %CameraAngleSlider as HSlider
@onready var camera_angle_spin := %CameraAngleCurrent as SpinBox
@onready var dry_weight_label := %DryWeightLabel as Label
@onready var dry_weight_slider := %DryWeightSlider as HSlider
@onready var dry_weight_spin := %DryWeightCurrent as SpinBox
@onready var battery_weight_label := %BatteryWeightLabel as Label
@onready var battery_weight_slider := %BatteryWeightSlider as HSlider
@onready var battery_weight_spin := %BatteryWeightCurrent as SpinBox

@onready var rates_curve_label := %RatesCurveLabel as Label
@onready var rates_curve_list := %RatesCurveOptionButton as OptionButton
@onready var rate_label := %RateLabel as Label
@onready var rc_label := %RcLabel as Label
@onready var expo_label := %ExpoLabel as Label
@onready var pitch_label := %PitchLabel as Label
@onready var roll_label := %RollLabel as Label
@onready var yaw_label := %YawLabel as Label

@onready var pitch_rate_slider := %PitchRateSlider as HSlider
@onready var roll_rate_slider := %RollRateSlider as HSlider
@onready var yaw_rate_slider := %YawRateSlider as HSlider
@onready var pitch_rate_spin := %PitchRate as SpinBox
@onready var roll_rate_spin := %RollRate as SpinBox
@onready var yaw_rate_spin := %YawRate as SpinBox
@onready var pitch_rc_slider := %PitchRcSlider as HSlider
@onready var roll_rc_slider := %RollRcSlider as HSlider
@onready var yaw_rc_slider := %YawRcSlider as HSlider
@onready var pitch_rc_spin := %PitchRc as SpinBox
@onready var roll_rc_spin := %RollRc as SpinBox
@onready var yaw_rc_spin := %YawRc as SpinBox
@onready var pitch_expo_slider := %PitchExpoSlider as HSlider
@onready var roll_expo_slider := %RollExpoSlider as HSlider
@onready var yaw_expo_slider := %YawExpoSlider as HSlider
@onready var pitch_expo_spin := %PitchExpo as SpinBox
@onready var roll_expo_spin := %RollExpo as SpinBox
@onready var yaw_expo_spin := %YawExpo as SpinBox

@onready var rate_graph := %RateGraph as Control

@onready var button_reset_quad := %ButtonResetQuad as Button
@onready var button_reset_rates := %ButtonResetRates as Button
@onready var button_back := %ButtonBack as Button


func _ready() -> void:
	QuadSettings.load_quad_settings()

	# Each spin box shares its range with the slider next to it: typing a value moves
	# the slider and dragging the slider updates the text, through a single signal.
	camera_angle_slider.share(camera_angle_spin)
	dry_weight_slider.share(dry_weight_spin)
	battery_weight_slider.share(battery_weight_spin)
	pitch_rate_slider.share(pitch_rate_spin)
	roll_rate_slider.share(roll_rate_spin)
	yaw_rate_slider.share(yaw_rate_spin)
	pitch_rc_slider.share(pitch_rc_spin)
	roll_rc_slider.share(roll_rc_spin)
	yaw_rc_slider.share(yaw_rc_spin)
	pitch_expo_slider.share(pitch_expo_spin)
	roll_expo_slider.share(roll_expo_spin)
	yaw_expo_slider.share(yaw_expo_spin)

	var _discard := camera_angle_slider.value_changed.connect(_on_angle_changed)
	camera_angle_slider.value = QuadSettings.angle

	_discard = dry_weight_slider.value_changed.connect(_on_dry_weight_changed)
	_discard = battery_weight_slider.value_changed.connect(_on_battery_weight_changed)
	dry_weight_slider.value = QuadSettings.dry_weight * 1000
	battery_weight_slider.value = QuadSettings.battery_weight * 1000

	rates_curve_list.clear()
	for item: String in ControlProfile.RateCurve.keys():
		rates_curve_list.add_item(item)
	rates_curve_list.select(QuadSettings.control_profile.rate_curve)
	_discard = rates_curve_list.item_selected.connect(_on_rate_curve_selected)

	_discard = pitch_rate_slider.value_changed.connect(_on_rate_changed.bind(pitch_rate_slider))
	_discard = roll_rate_slider.value_changed.connect(_on_rate_changed.bind(roll_rate_slider))
	_discard = yaw_rate_slider.value_changed.connect(_on_rate_changed.bind(yaw_rate_slider))
	_discard = pitch_rc_slider.value_changed.connect(_on_rc_changed.bind(pitch_rc_slider))
	_discard = roll_rc_slider.value_changed.connect(_on_rc_changed.bind(roll_rc_slider))
	_discard = yaw_rc_slider.value_changed.connect(_on_rc_changed.bind(yaw_rc_slider))
	_discard = pitch_expo_slider.value_changed.connect(_on_expo_changed.bind(pitch_expo_slider))
	_discard = roll_expo_slider.value_changed.connect(_on_expo_changed.bind(roll_expo_slider))
	_discard = yaw_expo_slider.value_changed.connect(_on_expo_changed.bind(yaw_expo_slider))

	_discard = button_reset_quad.pressed.connect(_on_reset_quad_pressed)
	_discard = button_reset_rates.pressed.connect(_on_reset_rates_pressed)
	_discard = button_back.pressed.connect(_on_back_pressed)

	setup_help()
	update_rates_ui()


func _input(event: InputEvent) -> void:
	if event.is_action("ui_cancel") and event.is_pressed() and not event.is_echo():
		accept_event()
		QuadSettings.save_quad_settings()
		back.emit()


func setup_help() -> void:
	for control: Control in [camera_angle_label, camera_angle_slider, camera_angle_spin]:
		set_help(control, HELP_CAMERA_ANGLE)
	for control: Control in [dry_weight_label, dry_weight_slider, dry_weight_spin]:
		set_help(control, HELP_DRY_WEIGHT)
	for control: Control in [battery_weight_label, battery_weight_slider, battery_weight_spin]:
		set_help(control, HELP_BATTERY_WEIGHT)
	for control: Control in [rates_curve_label, rates_curve_list]:
		set_help(control, HELP_RATES_CURVE)
	set_help(pitch_label, HELP_PITCH)
	set_help(roll_label, HELP_ROLL)
	set_help(yaw_label, HELP_YAW)
	set_help(rate_graph, HELP_GRAPH)
	set_help(button_reset_quad, HELP_RESET_QUAD)
	set_help(button_reset_rates, HELP_RESET_RATES)


func set_help(control: Control, text: String) -> void:
	control.tooltip_text = text
	if control is Label:
		# Labels ignore the mouse by default, so they would never show a tooltip
		control.mouse_filter = Control.MOUSE_FILTER_PASS


func _on_angle_changed(value: float) -> void:
	QuadSettings.angle = value as int


func _on_dry_weight_changed(value: float) -> void:
	QuadSettings.dry_weight = value / 1000


func _on_battery_weight_changed(value: float) -> void:
	QuadSettings.battery_weight = value / 1000


func _on_rate_curve_selected(idx: int) -> void:
	var new_curve := ControlProfile.RateCurve[rates_curve_list.get_item_text(idx)] as ControlProfile.RateCurve
	if new_curve != QuadSettings.control_profile.rate_curve:
		QuadSettings.control_profile.rate_curve = new_curve
		update_rates_ui()


func _on_rate_changed(value: float, slider: HSlider) -> void:
	if slider == pitch_rate_slider:
		QuadSettings.control_profile.pitch_rate = value as int
	elif slider == roll_rate_slider:
		QuadSettings.control_profile.roll_rate = value as int
	elif slider == yaw_rate_slider:
		QuadSettings.control_profile.yaw_rate = value as int
	update_graph()


func _on_rc_changed(value: float, slider: HSlider) -> void:
	if slider == pitch_rc_slider:
		QuadSettings.control_profile.pitch_rc = value as int
	elif slider == roll_rc_slider:
		QuadSettings.control_profile.roll_rc = value as int
	elif slider == yaw_rc_slider:
		QuadSettings.control_profile.yaw_rc = value as int
	update_graph()


func _on_expo_changed(value: float, slider: HSlider) -> void:
	if slider == pitch_expo_slider:
		QuadSettings.control_profile.pitch_expo = value
	elif slider == roll_expo_slider:
		QuadSettings.control_profile.roll_expo = value
	elif slider == yaw_expo_slider:
		QuadSettings.control_profile.yaw_expo = value
	update_graph()


func update_graph() -> void:
	var pitch: Array[Vector2] = []
	var roll: Array[Vector2] = []
	var yaw: Array[Vector2] = []

	var num_points := 101
	for i in num_points:
		var input := (i / 50.0 - 1) as float
		var pitch_y := QuadSettings.control_profile.get_axis_command(ControlProfile.Axis.PITCH, input)
		var roll_y := QuadSettings.control_profile.get_axis_command(ControlProfile.Axis.ROLL, input)
		var yaw_y := QuadSettings.control_profile.get_axis_command(ControlProfile.Axis.YAW, input)
		pitch.append(Vector2(input, pitch_y))
		roll.append(Vector2(input, roll_y))
		yaw.append(Vector2(input, yaw_y))

	rate_graph.update_rates(pitch, roll, yaw)


func update_rates_labels() -> void:
	match QuadSettings.control_profile.rate_curve:
		ControlProfile.RateCurve.ACTUAL:
			rate_label.text = "Max Rate"
			rc_label.text = "Center Rate"
			expo_label.text = "Expo"
		ControlProfile.RateCurve.RACEFLIGHT:
			rate_label.text = "Rate"
			rc_label.text = "Acro+"
			expo_label.text = "Expo"
		ControlProfile.RateCurve.KISS:
			rate_label.text = "Rate"
			rc_label.text = "RC Rate"
			expo_label.text = "RC Curve"
		ControlProfile.RateCurve.QUICKRATES:
			rate_label.text = "Max Rate"
			rc_label.text = "RC Rate"
			expo_label.text = "Expo"

	# The help follows the curve, since the columns change meaning with it
	var help: Array = HELP_RATES[QuadSettings.control_profile.rate_curve]
	for control: Control in [rate_label, pitch_rate_slider, roll_rate_slider, yaw_rate_slider,
			pitch_rate_spin, roll_rate_spin, yaw_rate_spin]:
		set_help(control, help[0] as String)
	for control: Control in [rc_label, pitch_rc_slider, roll_rc_slider, yaw_rc_slider,
			pitch_rc_spin, roll_rc_spin, yaw_rc_spin]:
		set_help(control, help[1] as String)
	for control: Control in [expo_label, pitch_expo_slider, roll_expo_slider, yaw_expo_slider,
			pitch_expo_spin, roll_expo_spin, yaw_expo_spin]:
		set_help(control, help[2] as String)


func update_rates_ui() -> void:
	update_rates_labels()
	update_slider_limits()
	update_sliders()
	update_graph()


func update_slider_limits() -> void:
	match QuadSettings.control_profile.rate_curve:
		ControlProfile.RateCurve.ACTUAL:
			pitch_rate_slider.min_value = 0
			pitch_rate_slider.max_value = 1800
			roll_rate_slider.min_value = 0
			roll_rate_slider.max_value = 1800
			yaw_rate_slider.min_value = 0
			yaw_rate_slider.max_value = 1800
			pitch_rc_slider.min_value = 10
			pitch_rc_slider.max_value = 1800
			roll_rc_slider.min_value = 10
			roll_rc_slider.max_value = 1800
			yaw_rc_slider.min_value = 10
			yaw_rc_slider.max_value = 1800
		ControlProfile.RateCurve.RACEFLIGHT:
			pitch_rate_slider.min_value = 10
			pitch_rate_slider.max_value = 1800
			roll_rate_slider.min_value = 10
			roll_rate_slider.max_value = 1800
			yaw_rate_slider.min_value = 10
			yaw_rate_slider.max_value = 1800
			pitch_rc_slider.min_value = 0
			pitch_rc_slider.max_value = 255
			roll_rc_slider.min_value = 0
			roll_rc_slider.max_value = 255
			yaw_rc_slider.min_value = 0
			yaw_rc_slider.max_value = 255
		ControlProfile.RateCurve.KISS:
			pitch_rate_slider.min_value = 0
			pitch_rate_slider.max_value = 99
			roll_rate_slider.min_value = 0
			roll_rate_slider.max_value = 99
			yaw_rate_slider.min_value = 0
			yaw_rate_slider.max_value = 99
			pitch_rc_slider.min_value = 1
			pitch_rc_slider.max_value = 255
			roll_rc_slider.min_value = 1
			roll_rc_slider.max_value = 255
			yaw_rc_slider.min_value = 1
			yaw_rc_slider.max_value = 255
		ControlProfile.RateCurve.QUICKRATES:
			pitch_rate_slider.min_value = 0
			pitch_rate_slider.max_value = 1800
			roll_rate_slider.min_value = 0
			roll_rate_slider.max_value = 1800
			yaw_rate_slider.min_value = 0
			yaw_rate_slider.max_value = 1800
			pitch_rc_slider.min_value = 1
			pitch_rc_slider.max_value = 255
			roll_rc_slider.min_value = 1
			roll_rc_slider.max_value = 255
			yaw_rc_slider.min_value = 1
			yaw_rc_slider.max_value = 255


func update_sliders() -> void:
	pitch_rate_slider.value = QuadSettings.control_profile.pitch_rate
	roll_rate_slider.value = QuadSettings.control_profile.roll_rate
	yaw_rate_slider.value = QuadSettings.control_profile.yaw_rate
	pitch_rc_slider.value = QuadSettings.control_profile.pitch_rc
	roll_rc_slider.value = QuadSettings.control_profile.roll_rc
	yaw_rc_slider.value = QuadSettings.control_profile.yaw_rc
	pitch_expo_slider.value = QuadSettings.control_profile.pitch_expo
	roll_expo_slider.value = QuadSettings.control_profile.roll_expo
	yaw_expo_slider.value = QuadSettings.control_profile.yaw_expo


func _on_reset_quad_pressed() -> void:
	QuadSettings.reset_quad()
	camera_angle_slider.value = QuadSettings.angle
	dry_weight_slider.value = QuadSettings.dry_weight * 1000
	battery_weight_slider.value = QuadSettings.battery_weight * 1000


func _on_reset_rates_pressed() -> void:
	QuadSettings.reset_rates()
	update_sliders()


func _on_back_pressed() -> void:
	QuadSettings.save_quad_settings()
	back.emit()
