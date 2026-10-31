class_name Firearm
extends Weapon

## Огнестрельное оружие с мгновенным попаданием (хитскан): патроны, перезарядка, разброс дроби.
## Цель получает урон, если take_damage(amount: float, source: Node).
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
## Вид сверху: игрок целится только по плоскости, поэтому пуля задевает всё
## в вертикальной полосе вокруг дула - и низких пауков, и высоких призраков.
@export var hit_band_below := 1.0
@export var hit_band_above := 0.5
## Толщина пули/дробины.
@export var hit_width := 0.1

@export_group("Патроны")
@export var capacity := 6
@export var reserve_ammo := 24
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
	var holder := get_parent() as WeaponHolder
	if holder:
		holder.prepare_shot(_get_shot_origin(), max_range, _exclude())
	for i in rounds * pellets:
		_fire_ray(_spread_direction(), damage)
	if holder:
		holder.finish_shot()
	_flash()
	fired.emit(rounds)
	ammo_changed.emit(loaded, capacity, reserve_ammo)
	shoot_sound.play()
	return true


func add_ammo(amount: int) -> void:
	reserve_ammo += amount
	ammo_changed.emit(loaded, capacity, reserve_ammo)


func _load_rounds(count: int) -> void:
	count = mini(count, reserve_ammo)
	loaded += count
	reserve_ammo -= count
	ammo_changed.emit(loaded, capacity, reserve_ammo)


## Направление выстрела в плоскости пола. В держателе - по его прицелу, а не по дулу,
## которое качается вместе с анимацией рук.
func _spread_direction() -> Vector3:
	var half := deg_to_rad(spread_degrees) / 2.0
	var forward := -_muzzle.global_basis.z
	var holder := get_parent() as WeaponHolder
	if holder:
		forward = holder.get_aim_direction()
	# Захват сохраняет высоту цели; без захвата остаётся стрельба по горизонтали.
	if not holder or not holder.has_shot_lock():
		forward.y = 0.0
	return forward.normalized().rotated(Vector3.UP, randf_range(-half, half))


## Протягивает вертикальную полосу высотой hit_band_below + hit_band_above от дула
## и бьёт первое, во что она упрётся.
func _fire_ray(direction: Vector3, pellet_damage: float = -1.0) -> void:
	if direction.is_zero_approx() or max_range <= 0.0:
		return
	direction = direction.normalized()
	var origin := _get_shot_origin()
	var result := _trace_pellet(origin, direction)
	var endpoint: Vector3 = result.endpoint
	var target: Object = result.target
	var applied_damage := 0.0
	if is_instance_valid(target) and target.has_method("take_damage"):
		applied_damage = maxf(damage if pellet_damage < 0.0 else pellet_damage, 0.0)
		target.take_damage(applied_damage, self)
	Tracer.spawn(self, _muzzle.global_position, endpoint)
	pellet_fired.emit(origin, endpoint, target, applied_damage)


## Игровой старт не зависит от анимации руки и положения ствола.
func _get_shot_origin() -> Vector3:
	if is_instance_valid(shot_origin):
		return shot_origin.global_position
	var node := get_parent()
	while node:
		if node is CollisionObject3D:
			return node.global_position + Vector3.UP * shooting_height
		node = node.get_parent()
	var holder := get_parent() as Node3D
	return holder.global_position if holder else global_position


## Независимое первое попадание каждой дробины с сохранением допуска по высоте.
func _trace_pellet(origin: Vector3, direction: Vector3) -> Dictionary:
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(hit_width, 0.001),
		maxf(hit_band_below + hit_band_above, 0.001), maxf(hit_width, 0.001))
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.looking_at(direction),
		origin + Vector3.UP * (hit_band_above - hit_band_below) * 0.5)
	query.collision_mask = hit_mask
	query.collide_with_areas = true
	query.exclude = _exclude()
	query.margin = 0.001
	var space := get_world_3d().direct_space_state
	var hit := space.get_rest_info(query)
	var travel := 0.0
	if hit.is_empty():
		query.motion = direction * max_range
		var fractions := space.cast_motion(query)
		if fractions[0] >= 1.0:
			return {"endpoint": origin + direction * max_range, "target": null}
		travel = clampf(fractions[1], 0.0, 1.0) * max_range
		# Запрос контакта выполняется неподвижной формой в точке столкновения.
		query.transform.origin += direction * (travel + 0.002)
		query.motion = Vector3.ZERO
		hit = space.get_rest_info(query)
	var target: Object = null
	if not hit.is_empty():
		target = instance_from_id(hit.collider_id)
	return {"endpoint": origin + direction * travel, "target": target}


## Исключает коллизию владельца из всех запросов отдельной дробины.
func _exclude() -> Array[RID]:
	var node := get_parent()
	while node:
		if node is CollisionObject3D:
			return [node.get_rid()]
		node = node.get_parent()
	return []


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
