class_name Firearm
extends Weapon

## Огнестрельное оружие с мгновенным попаданием (хитскан): патроны, перезарядка, разброс дроби.
## Цель получает урон, если take_damage(amount: float, source: Node).
## Материальность цели (призраки) решает сама цель.

## Выстрел произведён; rounds - сколько патронов ушло. Можно использовать как шум для врагов.
signal fired(rounds: int)
## Спуск нажат, а патронов нет.
signal dry_fired
signal ammo_changed(loaded: int, capacity: int, reserve: int)
signal reload_started
signal reload_finished

const FLASH_DURATION := 0.05

@export_group("Стрельба")
## Урон одной пули или дробины.
@export var damage := 25.0
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

@export_group("Патроны")
@export var capacity := 6
@export var reserve_ammo := 24
## Время полной перезарядки или одного патрона, если reload_per_round.
@export var reload_time := 1.5
## Заряжать по одному патрону; выстрел прерывает перезарядку.
@export var reload_per_round := false

var loaded := 0
var is_reloading := false

var _cooldown := 0.0
var _reload_timer := 0.0

@onready var _muzzle: Node3D = $Muzzle
@onready var _flash_light: Light3D = get_node_or_null("Muzzle/Flash")


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
	reload_started.emit()


func unequip() -> void:
	is_reloading = false
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

	rounds = clampi(rounds, 1, loaded)
	loaded -= rounds
	_cooldown = fire_interval
	for i in rounds * pellets:
		_fire_ray(_spread_direction())
	_flash()
	fired.emit(rounds)
	ammo_changed.emit(loaded, capacity, reserve_ammo)
	return true


func add_ammo(amount: int) -> void:
	reserve_ammo += amount
	ammo_changed.emit(loaded, capacity, reserve_ammo)


func _load_rounds(count: int) -> void:
	count = mini(count, reserve_ammo)
	loaded += count
	reserve_ammo -= count
	ammo_changed.emit(loaded, capacity, reserve_ammo)


func _spread_direction() -> Vector3:
	var half := deg_to_rad(spread_degrees) / 2.0
	return (-_muzzle.global_basis.z).rotated(Vector3.UP, randf_range(-half, half))


func _fire_ray(direction: Vector3) -> void:
	var from := _muzzle.global_position
	var to := from + direction * max_range
	var query := PhysicsRayQueryParameters3D.create(from, to, hit_mask, _exclude())
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		to = hit.position
		var target: Object = hit.collider
		if target.has_method("take_damage"):
			target.take_damage(damage, self)
	Tracer.spawn(self, from, to)


## Не попадать в того, кто держит оружие.
func _exclude() -> Array[RID]:
	var node := get_parent()
	while node:
		if node is CollisionObject3D:
			return [node.get_rid()]
		node = node.get_parent()
	return []


func _flash() -> void:
	if not _flash_light:
		return
	_flash_light.visible = true
	get_tree().create_timer(FLASH_DURATION).timeout.connect(_flash_light.hide)
