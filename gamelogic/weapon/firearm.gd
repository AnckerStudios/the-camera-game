class_name Firearm
extends Weapon

## Огнестрельное оружие с мгновенным попаданием (хитскан): патроны, перезарядка, разброс дроби.
## Доступность цели и получение урона определяет общий компонент DamageReceiver.
## Материальность цели (призраки) решает сама цель.

## Выстрел произведён; rounds - сколько патронов ушло. Можно использовать как шум для врагов.
signal fired(rounds: int)
## Результат отдельной пули/дробины, включая промахи.
signal pellet_fired(origin: Vector3, endpoint: Vector3, target: Object, applied_damage: float)
## Спуск нажат, а патронов нет.
signal dry_fired
signal ammo_changed(loaded: int, capacity: int, reserve: int)
signal reload_started
signal reload_finished

const FLASH_DURATION := 0.05
const ShotAudio = preload("res://gamelogic/weapon/spatial_shot_audio.gd")

@export_group("Стрельба")
## Урон одной пули или дробины.
@export var damage := 25.0
## Необязательная точка игрового старта. Без неё — центр владельца на shooting_height.
@export var shot_origin: Node3D
@export var shooting_height: float = 1.2
## Количество дробин в одном патроне.
@export var pellets := 1
## Полный угол разброса в градусах (в плоскости пола).
@export_range(0.0, 90.0) var spread_degrees := 0.0
@export var max_range := 30.0
## Минимальная пауза между выстрелами, сек.
@export var fire_interval := 0.3
## Альтернативная атака выпускает все заряженные патроны разом (дуплет).
@export var secondary_fires_all := false
@export_flags_3d_physics var hit_mask := 1
## Области-триггеры по умолчанию не останавливают пули.
@export var hit_areas: bool = false

@export_group("Патроны")
@export var capacity := 6
## Запас хранится в инвентаре; само оружие содержит только магазин.
var reserve_ammo: int:
	get:
		var inventory := _get_ammo_inventory()
		return inventory.get_ammo_count(_ammo_id) if inventory else 0
var _ammo_inventory: WeakRef
var _ammo_id: StringName
## Время полной перезарядки или одного патрона, если reload_per_round.
@export var reload_time := 1.5
## Заряжать по одному патрону; выстрел прерывает перезарядку.
@export var reload_per_round := false

@export_group("Анимация")
## Плеер анимаций
@export var animator: AnimationPlayer
## Анимация под reload_time. потом в методе растягиваем анимацию
@export var reload_animation: StringName

var loaded := 0
var is_reloading := false

var _cached_exclusions: Array[RID] = []
var _exclusions_parent: Node
var _exclusions_refresh_ms: int = 0
var _cooldown := 0.0
var _reload_timer := 0.0


@onready var _muzzle: Node3D = $Muzzle
@onready var _flash_light: Light3D = get_node_or_null("Muzzle/Flash")
@onready var shoot_sound: AudioStreamPlayer3D = $ShootSound


func _ready() -> void:
	loaded = capacity
	if _flash_light:
		_flash_light.visible = false


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not is_reloading:
		return
	_reload_timer -= delta
	if _reload_timer > 0.0:
		return
	if reload_per_round:
		_load_rounds(1)
		if loaded < capacity and reserve_ammo > 0:
			_reload_timer += reload_time
			return
	else:
		_load_rounds(capacity - loaded)
	is_reloading = false
	reload_finished.emit()


func primary_attack() -> void:
	shoot(1)


func secondary_attack() -> void:
	if secondary_fires_all:
		shoot(loaded)


func reload() -> void:
	if is_reloading or loaded >= capacity or reserve_ammo <= 0:
		return
	is_reloading = true
	_reload_timer = reload_time
	_play_reload_animation()
	reload_started.emit()


func unequip() -> void:
	is_reloading = false
	_reset_animation()
	super()


## Выстрелить rounds патронами. Возвращает true, если выстрел произошёл.
func shoot(rounds := 1) -> bool:
	if _cooldown > 0.0:
		return false
	if loaded <= 0:
		dry_fired.emit()
		reload()
		return false
	if is_reloading:
		if not reload_per_round:
			return false
		is_reloading = false
		_reset_animation()

	rounds = clampi(rounds, 1, loaded)
	loaded -= rounds
	_cooldown = fire_interval
	for i in rounds * pellets:
		_fire_ray(_spread_direction(), damage)
	_flash()
	fired.emit(rounds)
	ammo_changed.emit(loaded, capacity, reserve_ammo)
	ShotAudio.play(shoot_sound, _muzzle.global_position)
	return true


## Подключает общий запас патронов. WeakRef не удерживает удалённый инвентарь.
func bind_ammo_inventory(inventory: Node, weapon_id: StringName = &"") -> void:
	var previous := _get_ammo_inventory()
	if previous and previous.changed.is_connected(_on_inventory_ammo_changed):
		previous.changed.disconnect(_on_inventory_ammo_changed)
	_ammo_inventory = weakref(inventory) if is_instance_valid(inventory) else null
	_ammo_id = weapon_id
	if is_instance_valid(inventory):
		inventory.changed.connect(_on_inventory_ammo_changed)
	_on_inventory_ammo_changed()


func get_ammo_id() -> StringName:
	return _ammo_id


func _get_ammo_inventory() -> Node:
	return _ammo_inventory.get_ref() as Node if _ammo_inventory else null


func _on_inventory_ammo_changed() -> void:
	ammo_changed.emit(loaded, capacity, reserve_ammo)


## Патроны списываются при завершении перезарядки, для дробовика/револьвера — по одному.
func _load_rounds(count: int) -> void:
	var inventory := _get_ammo_inventory()
	if not inventory:
		return
	count = clampi(count, 0, capacity - loaded)
	loaded += inventory.consume_ammo(_ammo_id, count)
	ammo_changed.emit(loaded, capacity, reserve_ammo)


func _spread_direction() -> Vector3:
	var half := deg_to_rad(spread_degrees) / 2.0
	var forward := -_muzzle.global_basis.z
	var holder := get_parent() as WeaponHolder
	if holder:
		forward = holder.get_aim_direction()
	# Захват сохраняет высоту цели; без захвата остаётся стрельба по горизонтали.
	if not holder or not holder.has_target_lock():
		forward.y = 0.0
	return forward.normalized().rotated(Vector3.UP, randf_range(-half, half))


## Каждая пуля проверяется отдельно из центра персонажа; трассер начинается у дула.
## Первое пересечённое препятствие останавливает пулю.
func _fire_ray(direction: Vector3, pellet_damage: float = -1.0) -> void:
	if direction.is_zero_approx() or max_range <= 0.0:
		return
	direction = direction.normalized()
	var origin := get_shot_origin()
	var result := _trace_pellet(origin, direction)
	var endpoint: Vector3 = result.endpoint
	var target: Object = result.target
	var applied_damage := 0.0
	var receiver := DamageReceiver.get_receiver(target)
	if receiver and receiver.can_receive_damage():
		var requested_damage := maxf(damage if pellet_damage < 0.0 else pellet_damage, 0.0)
		applied_damage = receiver.receive_hit(requested_damage, self)
	Tracer.spawn(self, _muzzle.global_position, endpoint)
	pellet_fired.emit(origin, endpoint, target, applied_damage)


## Игровой старт не зависит от анимации руки и положения ствола.
func get_shot_origin() -> Vector3:
	if is_instance_valid(shot_origin):
		return shot_origin.global_position
	var node := get_parent()
	while node:
		if node is CollisionObject3D:
			return node.global_position + Vector3.UP * shooting_height
		node = node.get_parent()
	var holder := get_parent() as Node3D
	return holder.global_position if holder else global_position


## Точный луч: пол и декорации останавливают пулю только при реальном пересечении
## её траектории. Точка и объект попадания получаются одним физическим запросом.
func _trace_pellet(origin: Vector3, direction: Vector3) -> Dictionary:
	var endpoint := origin + direction * max_range
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint, hit_mask, get_shot_exclusions())
	query.collide_with_areas = hit_areas
	query.collide_with_bodies = true
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"endpoint": endpoint, "target": null}
	var collider: Node = hit.collider
	return {"endpoint": hit.position, "target": _get_damage_receiver(collider)}


## Коллизия может находиться в дочернем узле, а здоровье — в скрипте самого врага.
func _get_damage_receiver(collider: Node) -> Node:
	return DamageReceiver.find_target(collider)


## Исключает владельца и все его дочерние коллизии, включая экипировку.
func get_shot_exclusions() -> Array[RID]:
	var now := Time.get_ticks_msec()
	if _exclusions_parent == get_parent() and now < _exclusions_refresh_ms:
		return _cached_exclusions
	_exclusions_parent = get_parent()
	_exclusions_refresh_ms = now + 250
	var excluded: Array[RID] = []
	var node := get_parent()
	while node:
		if node is CollisionObject3D:
			excluded.append(node.get_rid())
			for child in node.find_children("*", "CollisionObject3D", true, false):
				excluded.append(child.get_rid())
			break
		node = node.get_parent()
	_cached_exclusions = excluded
	return excluded

## метод для растягивания анимации оружия под reload 
func _play_reload_animation() -> void:
	if not animator or not animator.has_animation(reload_animation):
		return
	var length := animator.get_animation(reload_animation).length
	animator.play(reload_animation, -1.0, length / maxf(reload_time, 0.01))


func _reset_animation() -> void:
	if animator and animator.is_playing():
		animator.seek(0.0, true)
		animator.stop()


func _flash() -> void:
	if not _flash_light:
		return
	_flash_light.visible = true
	get_tree().create_timer(FLASH_DURATION).timeout.connect(_flash_light.hide)
