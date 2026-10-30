extends Node3D
## Следует за персонажем и немного смещает кадр в сторону курсора.

@export var target: Node3D
@export var follow_speed: float = 8.0
## Максимальное горизонтальное смещение от персонажа в метрах.
@export_range(0.0, 5.0, 0.1) var look_ahead_distance: float = 1.5
## Скорость сглаживания смещения к курсору.
@export_range(0.1, 20.0, 0.1) var look_ahead_speed: float = 5.0

var _look_offset: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Камера обновляется после физического движения персонажа.
	process_physics_priority = 100
	if is_instance_valid(target):
		global_position = target.global_position

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	_look_offset = _look_offset.lerp(_get_cursor_offset(),
		1.0 - exp(-look_ahead_speed * delta))
	var desired_position := target.global_position + _look_offset
	global_position = global_position.lerp(desired_position,
		1.0 - exp(-follow_speed * delta))


## Экранное смещение не зависит от положения камеры, исключая самораскачивание.
## У центра кадра смещение небольшое, у края достигает заданного предела.
func _get_cursor_offset() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var rect := get_viewport().get_visible_rect()
	var mouse := get_viewport().get_mouse_position()
	if not camera or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Vector3.ZERO
	if not rect.has_point(mouse):
		return Vector3.ZERO
	var screen_offset := (mouse - rect.get_center()) / (rect.size * 0.5)
	screen_offset = screen_offset.limit_length(1.0)
	var right := camera.global_basis.x
	var forward := -camera.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	return (right.normalized() * screen_offset.x
		- forward.normalized() * screen_offset.y) * look_ahead_distance
