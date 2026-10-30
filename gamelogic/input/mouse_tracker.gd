extends Node
## Проецирует курсор на горизонтальную плоскость на высоте персонажа.
signal target_changed(world_position: Vector3)

@export var target: Node3D
var _last_position: Vector3
var _has_position: bool = false

func _ready() -> void:
	process_physics_priority = -90

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var mouse_position := get_viewport().get_mouse_position()
	if not get_viewport().get_visible_rect().has_point(mouse_position):
		return
	var plane := Plane(Vector3.UP, target.global_position.y)
	var hit: Variant = plane.intersects_ray(camera.project_ray_origin(mouse_position),
		camera.project_ray_normal(mouse_position))
	if hit == null:
		return
	var position: Vector3 = hit
	if not _has_position or not position.is_equal_approx(_last_position):
		_last_position = position
		_has_position = true
		target_changed.emit(position)
