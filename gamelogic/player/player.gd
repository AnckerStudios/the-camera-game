extends CharacterBody3D
## Управляет движением персонажа относительно камеры, прыжком и поворотом модели.

signal dashed(direction: Vector3, duration: float)

## Максимальная скорость движения по земле.
@export var speed: float = 2.5
## Скорость разгона и торможения.
@export var acceleration: float = 25.0
## Начальная вертикальная скорость прыжка.
@export var jump_speed: float = 4.0
## Скорость плавного поворота модели к направлению движения.
@export var turn_speed: float = 5.0

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

## Дистанция, длительность и пауза после рывка.
@export_range(0.1, 10.0, 0.1) var dash_distance: float = 2.9
@export_range(0.01, 2.0, 0.01) var dash_seconds: float = 0.9
@export_range(0.0, 5.0, 0.05) var dash_cooldown_seconds: float = 0.4
## Профиль рывка: x - доля времени, y - доля пройденной дистанции.
## Повторяет смещение бёдер в анимации кувырка, чтобы ноги не скользили. Без кривой - равномерно.
@export var dash_curve: Curve = preload("res://resources/animation/player/roll_motion.tres")

var _dash_remaining: float = 0.0
var _dash_cooldown_remaining: float = 0.0
var _dash_direction: Vector3 = Vector3.FORWARD

var _jump_hold_remaining: float = 0.0
var _coyote_remaining: float = 0.0
var _fall_seconds: float = 0.0

const INSPECTION_SCENE = preload("res://ui/item_inspection/item_inspection.tscn")
const INVENTORY_WINDOW = preload("res://ui/inventory/inventory_window.tscn")
var _inventory := PlayerInventory.new()
var _inventory_window
var _inspection

var _selected_pickup: PickupItem
var _weapon_after_inspection: InventoryEntry

var _dying := false
var _aim_lock_target: Node3D


var _mouse_target: Vector3
var _has_mouse_target: bool = false

@onready var controls = $PlayerInput
@onready var visual: Node3D = $Visual
@onready var _look_target: Node3D = get_node_or_null("Visual/PlayerModel/LookTarget")


func _ready() -> void:
	PlayerState.reset()
	VisionFilters.set_mode(VisionProfile.Filter.NORMAL, false)
	_inventory.name = &"Inventory"
	add_child(_inventory)
	var holder := find_child("WeaponHolder", true, false) as WeaponHolder
	_inventory.initialize(holder)
	_inventory_window = INVENTORY_WINDOW.instantiate()
	add_child(_inventory_window)
	_inspection = INSPECTION_SCENE.instantiate()
	add_child(_inspection)
	_inspection.closed.connect(_on_inspection_closed)
	controls.dash.connect(_on_dash_requested)
	controls.interaction.connect(_on_interaction_requested)
	controls.filter_toggle.connect(VisionFilters.cycle_filter)
	controls.inventory_toggle.connect(_on_inventory_toggle)
	$MouseTracker.target_changed.connect(_on_mouse_target_changed)
	PlayerState.hp_changed.connect(_on_hp_changed)


func _physics_process(delta: float) -> void:
	if get_tree().paused or _dying:
		return
	var direction := _get_movement_direction()
	_update_dash_and_movement(direction, delta)
	_apply_gravity_and_jump(delta)

	move_and_slide()
	_update_shader_parametrs()
	_update_mouse_facing(delta)
	_reset_if_fallen()
	_update_camera_walking()
	_update_pickup_selection()


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
	if _look_target and _look_target.has_method(&"update_look"):
		_look_target.update_look(global_position + direction, visual, delta, turn_speed)
		return
	if direction.length_squared() > 0.001:
		var target_angle := atan2(-direction.x, -direction.z)
		var weight := 1.0 - exp(-turn_speed * delta)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_angle, weight)


## Возвращает персонажа на площадку, если он упал за её пределы.
func _reset_if_fallen() -> void:
	if global_position.y < -15.0:
		global_position = Vector3(0, 2, 0)
		velocity = Vector3.ZERO
		_dash_remaining = 0.0
		_dash_cooldown_remaining = 0.0
		_jump_hold_remaining = 0.0
		_coyote_remaining = 0.0
		_fall_seconds = 0.0
		controls.clear_jump_buffer()


## Фиксирует направление рывка; повторное нажатие во время перезарядки игнорируется.
func _on_dash_requested() -> void:
	if _dash_remaining > 0.0 or _dash_cooldown_remaining > 0.0:
		return

	_dash_direction = _get_movement_direction()
	if _dash_direction.is_zero_approx():
		_dash_direction = -visual.global_basis.z
	_dash_direction.y = 0.0
	_dash_direction = _dash_direction.normalized()
	_dash_remaining = dash_seconds
	dashed.emit(_dash_direction, dash_seconds)


## Рывок заменяет горизонтальное движение, сохраняя прыжок и гравитацию.
## Скорость берётся из профиля: путь за этот кадр, делённый на его длительность.
func _update_dash_and_movement(direction: Vector3, delta: float) -> void:
	_dash_cooldown_remaining = maxf(_dash_cooldown_remaining - delta, 0.0)
	if _dash_remaining > 0.0:
		var from := _dash_progress(1.0 - _dash_remaining / dash_seconds)
		_dash_remaining = maxf(_dash_remaining - delta, 0.0)
		var to := _dash_progress(1.0 - _dash_remaining / dash_seconds)
		var dash_speed := (to - from) * dash_distance / delta
		velocity.x = _dash_direction.x * dash_speed
		velocity.z = _dash_direction.z * dash_speed

		if _dash_remaining <= 0.0:
			_dash_cooldown_remaining = dash_cooldown_seconds
			_dash_remaining = 0.0
	else:
		_update_horizontal_velocity(direction, delta)


## Доля пройденной дистанции рывка к доле прошедшего времени.
func _dash_progress(time_fraction: float) -> float:
	if dash_curve:
		return dash_curve.sample(clampf(time_fraction, 0.0, 1.0))
	return time_fraction


## Получает цель от отдельного узла слежения за курсором.
func _on_mouse_target_changed(world_position: Vector3) -> void:
	_mouse_target = world_position
	_has_mouse_target = true


## Направление взгляда не зависит от клавиш движения и рывка.
func _update_mouse_facing(delta: float) -> void:
	if is_instance_valid(_aim_lock_target) and not _aim_lock_target.is_queued_for_deletion():

		var locked_direction := _aim_lock_target.global_position - global_position
		locked_direction.y = 0.0
		_rotate_visual(locked_direction.normalized(), delta)
		return

	if not _has_mouse_target:
		return
	var direction := _mouse_target - global_position
	direction.y = 0.0
	_rotate_visual(direction.normalized(), delta)

## Передаёт камере фактическую скорость ходьбы; в воздухе и при рывке покачивание затухает.
func _update_camera_walking() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var rig := camera.get_parent()
	if not rig.has_method("set_sway_amount"):
		return
	var amount := 0.0
	if is_on_floor() and _dash_remaining <= 0.0:
		var motion := get_real_velocity()
		amount = Vector2(motion.x, motion.z).length() / maxf(speed, 0.01)
	rig.set_sway_amount(amount)


## Одно нажатие E подбирает ближайший доступный предмет, совпадающий с подсветкой.
func _on_interaction_requested() -> void:
	if _inventory_window.is_open:
		_inventory_window.handle_interaction()
		return
	if _inspection.is_open:
		_inspection.close()
		return
	_update_pickup_selection()
	if not is_instance_valid(_selected_pickup):
		return
	# Снимок модели создаётся до удаления предмета из мира.
	_inspection.prepare(_selected_pickup)
	var previous_entries := _inventory.entries.duplicate()
	if _selected_pickup.try_pick_up(self):
		_weapon_after_inspection = null
		for entry in _inventory.entries:
			if entry.item.kind == InventoryItem.Kind.WEAPON and not previous_entries.has(entry):
				_weapon_after_inspection = entry
				break
		_set_selected_pickup(null)
		velocity = Vector3.ZERO
		_dash_remaining = 0.0
		_inspection.open(controls)

## Выбор обновляется при движении даже без нажатия кнопки взаимодействия.
func _update_pickup_selection() -> void:
	var nearest: PickupItem = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group(&"pickup_items"):
		if not node is PickupItem or node.is_queued_for_deletion() or not node.can_pick_up(self):
			continue
		var distance_squared := global_position.distance_squared_to(node.global_position)
		if distance_squared < nearest_distance:
			nearest_distance = distance_squared
			nearest = node
	_set_selected_pickup(nearest)


## При смене цели возвращает прежнему предмету его обычный цвет.
func _set_selected_pickup(item: PickupItem) -> void:
	if is_instance_valid(_selected_pickup) and _selected_pickup == item:
		return
	if is_instance_valid(_selected_pickup):
		_selected_pickup.set_pickup_selected(false)
	_selected_pickup = item
	if is_instance_valid(_selected_pickup):
		_selected_pickup.set_pickup_selected(true)


func _exit_tree() -> void:
	if is_instance_valid(_selected_pickup):
		_selected_pickup.set_pickup_selected(false)

func _update_shader_parametrs() -> void:
	if (get_tree().current_scene.has_node("MultiMeshInstance3D")):
		var grass_node = get_tree().current_scene.get_node("MultiMeshInstance3D")
		grass_node.set_deferred("instance_shader_parameters/player_position", position + Vector3(0, -0.1, 0))

func _on_hp_changed(value: float, _max_value: float) -> void:
	if value > 0.0 or _dying:
		return
	_dying = true
	velocity = Vector3.ZERO
	controls.hardware_enabled = false
	var holder := find_child("WeaponHolder", true, false) as WeaponHolder
	if holder:
		holder.set_process_unhandled_input(false)
		if holder.current:
			holder.current.unequip()
	var actions := get_node_or_null("Visual/PlayerModel/WeaponAnimation")
	if actions:
		var duration: float = actions.play_death()
		await get_tree().create_timer(maxf(duration - 0.03, 0.01), false).timeout
		if not is_inside_tree():
			return
		$Visual/PlayerModel/AnimationTree.active = false
	var scene = preload("res://ui/dead/dead.tscn").instantiate()
	add_child(scene)
	get_tree().paused = true


func set_aim_lock(target: Node3D) -> void:
	_aim_lock_target = target if is_instance_valid(target) else null


## Получение внешнего урона (например, от взрыва); интерфейс смерти использует PlayerState.
func take_damage(amount: float, _source: Node) -> void:
	if is_finite(amount) and amount > 0.0:
		PlayerState.hp -= amount


func get_inventory() -> PlayerInventory:
	return _inventory

func _on_inventory_toggle() -> void:
	if _inspection.is_open:
		return
	if _inventory_window.is_open:
		_inventory_window.close()
		return
	if get_tree().paused or _dying:
		return
	velocity = Vector3.ZERO
	_dash_remaining = 0.0
	_set_selected_pickup(null)
	_inventory_window.open(self, _inventory, controls)


## После осмотра оружия переходим к выбору экипировки в инвентаре.
func _on_inspection_closed() -> void:
	var entry := _weapon_after_inspection
	_weapon_after_inspection = null
	if entry:
		_open_inventory_after_weapon.call_deferred(entry)

func _open_inventory_after_weapon(entry: InventoryEntry) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not _inventory.entries.has(entry):
		return
	if _inspection.is_open or _inventory_window.is_open or get_tree().paused:
		return
	_inventory_window.open(self, _inventory, controls)
	_inventory_window.select_entry(entry)
