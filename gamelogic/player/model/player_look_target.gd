class_name PlayerLookTarget
extends Node3D
## Управляет целью LookAtModifier3D и доворачивает корпус при большом угле взгляда.

@export_range(1.0, 170.0, 1.0) var body_turn_threshold_degrees: float = 55.0
@export_range(0.1, 30.0, 0.1) var body_turn_stop_degrees: float = 8.0
@export_range(1.0, 85.0, 1.0) var max_look_angle_degrees: float = 65.0
@export_range(0.1, 30.0, 0.1) var look_speed: float = 12.0
@export_range(0.1, 10.0, 0.1) var look_distance: float = 3.0
@export var look_height: float = 1.4

var _look_yaw: float
var _initialized := false
var _turning_body := false


## Вызывается игроком после перемещения, для курсора и захваченной цели одинаково.
func update_look(world_target: Vector3, body_pivot: Node3D, delta: float, body_turn_speed: float) -> void:
	var direction := world_target - body_pivot.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	var desired_yaw := atan2(-direction.x, -direction.z)
	if not _initialized:
		_look_yaw = body_pivot.global_rotation.y
		_initialized = true
	_update_body(desired_yaw, body_pivot, delta, body_turn_speed)
	_update_target(desired_yaw, body_pivot, delta)


## Разные пороги начала и конца исключают дрожание около границы поворота.
func _update_body(desired_yaw: float, body_pivot: Node3D, delta: float, speed: float) -> void:
	var error := absf(wrapf(desired_yaw - body_pivot.global_rotation.y, -PI, PI))
	var start_angle := deg_to_rad(body_turn_threshold_degrees)
	var stop_angle := minf(deg_to_rad(body_turn_stop_degrees), start_angle * 0.5)
	if error > start_angle:
		_turning_body = true
	elif error <= stop_angle:
		_turning_body = false
	if _turning_body:
		body_pivot.global_rotation.y = lerp_angle(body_pivot.global_rotation.y, desired_yaw,
			1.0 - exp(-speed * delta))


## Ограничиваем скручивание позвоночника, пока корпус догоняет взгляд.
func _update_target(desired_yaw: float, body_pivot: Node3D, delta: float) -> void:
	_look_yaw = lerp_angle(_look_yaw, desired_yaw, 1.0 - exp(-look_speed * delta))
	var body_yaw := body_pivot.global_rotation.y
	var limit := deg_to_rad(max_look_angle_degrees)
	_look_yaw = body_yaw + clampf(wrapf(_look_yaw - body_yaw, -PI, PI), -limit, limit)
	var direction := Vector3(-sin(_look_yaw), 0.0, -cos(_look_yaw))
	global_position = body_pivot.global_position + Vector3.UP * look_height + direction * look_distance
	global_rotation = Vector3(0.0, _look_yaw, 0.0)
