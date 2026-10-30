extends Node3D
## Следует за персонажем и немного смещает кадр в сторону курсора.

@export var target: Node3D
@export var follow_speed: float = 8.0
## Максимальное горизонтальное смещение от персонажа в метрах.
@export_range(0.0, 5.0, 0.1) var look_ahead_distance: float = 1.5
## Скорость сглаживания смещения к курсору.
@export_range(0.1, 20.0, 0.1) var look_ahead_speed: float = 5.0

@export_group("Покачивание")
@export var sway_enabled: bool = true
@export_group("Тряска")
@export var shake_enabled: bool = true

# Текущие параметры эффектов сохраняются между кадрами.
var _active_sway_amplitude: float = 0.0
var _active_sway_frequency: float = 0.0
var _active_sway_smoothing: float = 0.0
var _active_shake_amplitude: float = 0.0

var _sway_amount: float = 0.0
var _sway_weight: float = 0.0
var _sway_phase: float = 0.0
var _shake_remaining: float = 0.0
var _shake_duration: float = 0.0
var _shake_strength: float = 0.0
var _camera: Camera3D
var _base_h_offset: float = 0.0
var _base_v_offset: float = 0.0
var _rng := RandomNumberGenerator.new()

var _look_offset: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Камера обновляется после физического движения персонажа.
	process_physics_priority = 100
	_camera = get_node_or_null("Camera3D")
	if _camera:
		_base_h_offset = _camera.h_offset
		_base_v_offset = _camera.v_offset
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


## Задаёт интенсивность покачивания: 0 — выключено, 1 — полная амплитуда.
## Параметры действуют до следующего вызова; пропущенные используют значения аргументов по умолчанию.

func set_sway_amount(amount: float = 1.0, amplitude: float = 0.0, frequency: float = 0.6, smoothing: float = 10.0) -> void:
	_active_sway_amplitude = maxf(amplitude, 0.0)
	_active_sway_frequency = maxf(frequency, 0.0)
	_active_sway_smoothing = maxf(smoothing, 0.0)
	_sway_amount = clampf(amount, 0.0, 1.0)


## Запускает тряску от любого внешнего источника с заданной силой.
## Амплитуда и длительность задаются для этого импульса и имеют значения по умолчанию.
func shake(strength: float = 1.0, amplitude: float = 0.18, duration: float = 0.2) -> void:
	if not shake_enabled or strength <= 0.0:
		return
	_shake_strength = strength
	_active_shake_amplitude = maxf(amplitude, 0.0)
	_shake_duration = maxf(duration, 0.01)
	_shake_remaining = _shake_duration


## Смещения применяются к камере отдельно от слежения, поэтому не накапливаются.
func _process(delta: float) -> void:
	if not is_instance_valid(_camera):
		return
	var active_amplitude := _active_sway_amplitude
	var active_frequency := _active_sway_frequency
	var active_smoothing := _active_sway_smoothing
	var desired_weight := _sway_amount if sway_enabled else 0.0
	_sway_weight = lerpf(_sway_weight, desired_weight, 1.0 - exp(-active_smoothing * delta))
	_sway_phase = fmod(_sway_phase + delta * TAU * active_frequency, TAU)
	var offset := Vector2(sin(_sway_phase) * 0.5, cos(_sway_phase * 2.0)) * active_amplitude * _sway_weight
	_shake_remaining = maxf(_shake_remaining - delta, 0.0)
	if shake_enabled and _shake_remaining > 0.0:
		var envelope := _shake_remaining / _shake_duration
		offset += Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * _active_shake_amplitude * _shake_strength * envelope
	else:
		_shake_strength = 0.0
	_camera.h_offset = _base_h_offset + offset.x
	_camera.v_offset = _base_v_offset + offset.y
