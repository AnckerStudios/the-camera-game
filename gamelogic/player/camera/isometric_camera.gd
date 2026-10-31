extends Node3D
## Следует за персонажем и немного смещает кадр в сторону курсора.

@export var target: Node3D
## Жёсткость пружины: меньше значение — заметнее отставание.
@export_range(0.1, 30.0, 0.1) var follow_speed: float = 7.0
## Затухание: 1 — без раскачки, меньше 1 — мягкое пружинное колебание.
@export_range(0.1, 2.0, 0.05) var follow_damping: float = 1.2
## При телепортации дальше этого расстояния камера сразу догоняет цель.
@export_range(1.0, 100.0, 0.5) var teleport_snap_distance: float = 15.0
## Максимальное горизонтальное смещение от персонажа в метрах.
@export_range(0.0, 5.0, 0.1) var look_ahead_distance: float = 1.5
## Скорость сглаживания смещения к курсору.
@export_range(0.1, 20.0, 0.1) var look_ahead_speed: float = 5.0

@export_group("Инвентарь")
@export_range(2.0, 8.0, 0.1) var inventory_size: float = 4.8
@export_range(0.05, 1.0, 0.01) var inventory_transition: float = 0.35
var _inventory_snapshot_valid: bool = false
var _inventory_open: bool = false
var _inventory_tween: Tween
var _game_camera_transform: Transform3D
var _game_camera_size: float
var _game_process_mode: int

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
var _audio_listener: AudioListener3D
var _camera: Camera3D
var _base_h_offset: float = 0.0
var _base_v_offset: float = 0.0
var _rng := RandomNumberGenerator.new()

var _look_offset: Vector3 = Vector3.ZERO
var _follow_velocity: Vector3 = Vector3.ZERO
var _last_target_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Камера обновляется после физического движения персонажа.
	process_physics_priority = 100
	_camera = get_node_or_null("Camera3D")
	_audio_listener = AudioListener3D.new()
	_audio_listener.name = &"PlayerAudioListener"
	_audio_listener.top_level = true
	add_child(_audio_listener)
	_update_audio_listener()
	_audio_listener.make_current()
	if _camera:
		_base_h_offset = _camera.h_offset
		_base_v_offset = _camera.v_offset
	if is_instance_valid(target):
		snap_to_target()

func _physics_process(delta: float) -> void:
	if _inventory_open or (_inventory_tween and _inventory_tween.is_running()):
		return
	_update_audio_listener()
	if not is_instance_valid(target):
		return
	_look_offset = _look_offset.lerp(_get_cursor_offset(),
		1.0 - exp(-look_ahead_speed * delta))
	var desired_position := target.global_position + _look_offset
	if target.global_position.distance_to(_last_target_position) > teleport_snap_distance:
		snap_to_target()
	else:
		_update_spring(desired_position, delta)
	_last_target_position = target.global_position


## Пружина хранит скорость: камера набирает ход и мягко тормозит у цели.
## Неявное интегрирование сохраняет устойчивость при изменении частоты кадров.
func _update_spring(desired_position: Vector3, delta: float) -> void:
	var frequency := maxf(follow_speed, 0.1)
	var stiffness := frequency * frequency
	var damping := 2.0 * maxf(follow_damping, 0.0) * frequency
	var displacement := global_position - desired_position
	_follow_velocity = (_follow_velocity - displacement * stiffness * delta) / (1.0 + damping * delta + stiffness * delta * delta)
	global_position += _follow_velocity * delta


## Внешний вызов для телепортаций или смены цели; сбрасывает инерцию.
func snap_to_target() -> void:
	_follow_velocity = Vector3.ZERO
	if is_instance_valid(target):
		global_position = target.global_position + _look_offset
		_last_target_position = target.global_position

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

func set_sway_amount(amount: float = 1.0, amplitude: float = 0.02, frequency: float = 0.7, smoothing: float = 1.0) -> void:
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
	if _inventory_open or (_inventory_tween and _inventory_tween.is_running()):
		return
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


## Громкость зависит от расстояния до игрока; лево/право совпадает с видом камеры.
## Пружина, покачивание и смещение камеры не перемещают звуковые «уши».
func _update_audio_listener() -> void:
	if not is_instance_valid(_audio_listener) or not is_instance_valid(target):
		return
	_audio_listener.global_position = target.global_position + Vector3.UP * 1.2
	if is_instance_valid(_camera):
		_audio_listener.global_basis = _camera.global_basis.orthonormalized()


## Приближает реальную камеру и помещает игрока в центр правой трети экрана.
func set_inventory_view(opened: bool) -> void:
	if not is_instance_valid(_camera) or not is_instance_valid(target):
		return
	if _inventory_tween and _inventory_tween.is_valid():
		_inventory_tween.kill()
	if opened and not _inventory_snapshot_valid:
		_inventory_snapshot_valid = true
		_game_camera_transform = _camera.transform
		_game_camera_size = _camera.size
		_game_process_mode = process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	_inventory_open = opened
	_follow_velocity = Vector3.ZERO
	_inventory_tween = create_tween().set_parallel(true)
	_inventory_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_inventory_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if opened:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
		var rect := get_viewport().get_visible_rect()
		var aspect := rect.size.x / maxf(rect.size.y, 1.0)
		var height := inventory_size if _camera.keep_aspect == Camera3D.KEEP_HEIGHT else inventory_size / aspect
		var width := height * aspect
		var focus := target.global_position + Vector3.UP * 0.9
		var forward := -_camera.global_basis.z
		var distance := 4.0 if _camera.projection == Camera3D.PROJECTION_PERSPECTIVE else 10.0
		var destination := focus - forward * distance - _camera.global_basis.x * width / 3.0
		_inventory_tween.tween_property(_camera, "global_position", destination, inventory_transition)
		_inventory_tween.tween_property(_camera, "size", inventory_size, inventory_transition)
	else:
		_inventory_tween.tween_property(_camera, "transform", _game_camera_transform, inventory_transition)
		_inventory_tween.tween_property(_camera, "size", _game_camera_size, inventory_transition)
		_inventory_tween.chain().tween_callback(_finish_inventory_view)

func _finish_inventory_view() -> void:
	_inventory_snapshot_valid = false
	process_mode = _game_process_mode
	_follow_velocity = Vector3.ZERO
