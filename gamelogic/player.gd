extends CharacterBody3D
## Управляет движением персонажа относительно камеры, прыжком и поворотом модели.

## Максимальная скорость движения по земле.
@export var speed: float = 3.0
## Скорость разгона и торможения.
@export var acceleration: float = 32.0
## Начальная вертикальная скорость прыжка.
@export var jump_speed: float = 4.0
## Скорость плавного поворота модели к направлению движения.
@export var turn_speed: float = 8.0

## Допустимое время прыжка после схода с края.
@export_range(0.0, 0.5, 0.01) var coyote_seconds: float = 0.12
## Усиление гравитации в начале падения и его прирост за секунду.
@export_range(1.0, 10.0, 0.1) var fall_gravity_multiplier: float = 1.8
@export_range(0.0, 20.0, 0.1) var fall_gravity_growth: float = 3.0
## Предел усиления гравитации при длительном падении.
@export_range(1.0, 20.0, 0.1) var max_fall_multiplier: float = 4.0
## Усиление гравитации при отпускании кнопки во время подъёма.
@export_range(1.0, 10.0, 0.1) var released_jump_multiplier: float = 3.0

## Максимальное время влияния удержания на подъём после начала прыжка.
@export_range(0.0, 1.0, 0.01) var max_jump_hold_seconds: float = 0.15

var _jump_hold_remaining: float = 0.0
var _coyote_remaining: float = 0.0
var _fall_seconds: float = 0.0

@onready var controls = $PlayerInput
@onready var visual: Node3D = $Visual


func _physics_process(delta: float) -> void:
	var direction := _get_movement_direction()
	_update_horizontal_velocity(direction, delta)
	_apply_gravity_and_jump(delta)
	_rotate_visual(direction, delta)
	move_and_slide()
	_reset_if_fallen()


## Переводит ввод в направление на плоскости земли относительно активной камеры.
## Если камеры нет, использует мировые оси.
func _get_movement_direction() -> Vector3:
	var input: Vector2 = controls.get_movement()
	var camera := get_viewport().get_camera_3d()
	var right := Vector3.RIGHT
	var forward := Vector3.FORWARD
	if camera:
		right = camera.global_basis.x
		forward = -camera.global_basis.z
		right.y = 0.0
		forward.y = 0.0
	return right.normalized() * input.x - forward.normalized() * input.y


## Плавно приближает горизонтальную скорость к заданной вводом.
func _update_horizontal_velocity(direction: Vector3, delta: float) -> void:
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)


## Обновляет окно Coyote Time и выполняет сохранённый запрос прыжка.
func _apply_gravity_and_jump(delta: float) -> void:
	if is_on_floor():
		_coyote_remaining = coyote_seconds
		_jump_hold_remaining = 0.0
		_fall_seconds = 0.0
	else:
		_coyote_remaining = maxf(_coyote_remaining - delta, 0.0)

	if (is_on_floor() or _coyote_remaining > 0.0) and controls.consume_jump():
		velocity.y = jump_speed
		_jump_hold_remaining = max_jump_hold_seconds
		_coyote_remaining = 0.0
		_fall_seconds = 0.0

	if not is_on_floor() or velocity.y > 0.0:
		_apply_air_gravity(delta)


## Падение ускоряется со временем; раннее отпускание сокращает высоту прыжка.
func _apply_air_gravity(delta: float) -> void:
	var multiplier: float = 1.0
	if velocity.y <= 0.0:
		_fall_seconds += delta
		multiplier = minf(fall_gravity_multiplier + fall_gravity_growth * _fall_seconds,
			max_fall_multiplier)
	else:
		_fall_seconds = 0.0
		if not controls.is_jump_held() or _jump_hold_remaining <= 0.0:
			multiplier = released_jump_multiplier
	velocity += get_gravity() * multiplier * delta
	_jump_hold_remaining = maxf(_jump_hold_remaining - delta, 0.0)

## Поворачивает только модель; при отсутствии ввода сохраняет её направление.
func _rotate_visual(direction: Vector3, delta: float) -> void:
	if direction.length_squared() > 0.001:
		var target_angle := atan2(-direction.x, -direction.z)
		var weight := 1.0 - exp(-turn_speed * delta)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_angle, weight)


## Возвращает персонажа на площадку, если он упал за её пределы.
func _reset_if_fallen() -> void:
	if global_position.y < -15.0:
		global_position = Vector3(0, 2, 0)
		velocity = Vector3.ZERO
		_jump_hold_remaining = 0.0
		_coyote_remaining = 0.0
		_fall_seconds = 0.0
		controls.clear_jump_buffer()
