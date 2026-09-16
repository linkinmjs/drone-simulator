class_name MenuHero
extends SubViewportContainer
## Slowly orbiting 3D drone shown next to the main and pause menus.
## It reuses the preview scene of the controls menu, so it also tilts with the sticks.


const PREVIEW_SCENE := "res://gui/options_menu/controls_menu/controls_menu_drone.tscn"
const ORBIT_SPEED := 0.25
const ORBIT_RADIUS := 1.414
const ORBIT_HEIGHT := 0.45

@export var enabled_on_web := true

var _camera: Camera3D = null
var _angle := -PI * 0.75


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if OS.has_feature("web") and not enabled_on_web:
		visible = false
		return
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	var preview := (load(PREVIEW_SCENE) as PackedScene).instantiate()
	viewport.add_child(preview)
	_camera = preview.get_node_or_null("Camera3D") as Camera3D
	if _camera:
		_camera.fov = 11.0
	_update_camera()


func _process(delta: float) -> void:
	if _camera == null or not is_visible_in_tree():
		return
	_angle += delta * ORBIT_SPEED
	_update_camera()


func _update_camera() -> void:
	if _camera == null:
		return
	_camera.position = Vector3(sin(_angle) * ORBIT_RADIUS, ORBIT_HEIGHT, cos(_angle) * ORBIT_RADIUS)
	_camera.look_at(Vector3(0, 0.02, 0), Vector3.UP)
