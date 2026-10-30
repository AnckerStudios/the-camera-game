extends Node
## Преобразует пользовательский ввод в сигналы и хранит буфер прыжка.

## Уведомляет о нажатии прыжка. Выполнение определяется игровой логикой.
signal jump

## Передаёт направление движения при его изменении.
signal movement_changed(direction: Vector2)

## Время хранения запроса прыжка в секундах игрового времени.
@export_range(0.01, 1.0, 0.01)
var jump_buffer_seconds: float = 0.12

## Включает обработку ввода. Отключение очищает движение и буфер.
var hardware_enabled: bool = true:
	set(value):
		hardware_enabled = value
		if not value:
			_jump_held = false
		if not value:
			clear_jump_buffer()
			_set_movement(Vector2.ZERO)

var _jump_held: bool = false

var _movement: Vector2 = Vector2.ZERO
var _jump_remaining: float = 0.0


## Задаёт обработку ввода раньше физических обновлений персонажа.
func _ready() -> void:
	process_physics_priority = -100


## Обновляет буфер и считывает ввод.
## [param delta] — длительность физического тика в секундах.
func _physics_process(delta: float) -> void:
	_jump_remaining = maxf(_jump_remaining - delta, 0.0)

	if not hardware_enabled:
		return

	_set_movement(Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_forward",
		&"move_backward"
	))

	_jump_held = Input.is_action_pressed(&"jump")

	if Input.is_action_just_pressed(&"jump"):
		_jump_remaining = jump_buffer_seconds
		jump.emit()


## Возвращает текущее направление ввода.
## X направлен вправо, отрицательная Y — вперёд.
func get_movement() -> Vector2:
	return _movement


## Возвращает true, если запрос прыжка ещё действует, не удаляя его.
func has_buffered_jump() -> bool:
	return _jump_remaining > 0.0


## Возвращает true и удаляет действующий запрос прыжка.
## Возвращает false, если запрос отсутствует или просрочен.
## Вызывается игровой логикой только тогда, когда прыжок разрешён.
func consume_jump() -> bool:
	if not has_buffered_jump():
		return false

	clear_jump_buffer()
	return true


## Отменяет сохранённый запрос прыжка.
func clear_jump_buffer() -> void:
	_jump_remaining = 0.0


## Сохраняет направление и отправляет сигнал при его изменении.
## [param direction] — направление ввода длиной не больше единицы.
func _set_movement(direction: Vector2) -> void:
	if _movement.is_equal_approx(direction):
		return

	_movement = direction
	movement_changed.emit(_movement)

## Возвращает состояние удержания кнопки независимо от буфера нажатия.
func is_jump_held() -> bool:
	return _jump_held
