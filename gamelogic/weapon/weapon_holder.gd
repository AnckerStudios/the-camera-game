class_name WeaponHolder
extends Node3D

## Держатель оружия игрока: дочерние Weapon, переключение, ввод и проброс состояния в PlayerState.

## Оружие в руке сменилось; null - руки пустые.
signal weapon_changed(weapon: Weapon)

## Узел, вдоль -Z которого целится оружие. Держатель может сидеть на кисти и качаться
## вместе с анимацией, а стрелять нужно туда, куда смотрит персонаж. Без узла - сам держатель.
@export var aim: Node3D
## Предмет во второй руке; виден только с одноручным оружием.
@export var off_hand: Node3D
## Держатель сидит на кости и удар делает анимация персонажа, а не само оружие.
@export var owner_animates_attacks := false

const TargetLockScript = preload("res://gamelogic/weapon/target_lock.gd")
var _target_lock: Node
var _aim_direction: Vector3 = Vector3.ZERO
var _aim_target: Node3D

var _inventory_managed: bool = false
var _inventory_weapons: Array[Weapon] = []
var current: Weapon

var _index := -1


func _ready() -> void:
	# После адаптера ввода, перед физическим обновлением игрока.
	process_physics_priority = -50
	_target_lock = get_node_or_null("TargetLock")
	if not _target_lock:
		_target_lock = TargetLockScript.new()
		_target_lock.name = &"TargetLock"
		add_child(_target_lock)
	for weapon in get_weapons():
		weapon.unequip()
		if weapon is Firearm:
			weapon.fired.connect(_on_weapon_fired)
	select(0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("weapon_next"):
		select(_index + 1)
	elif event.is_action_pressed("weapon_prev"):
		select(_index - 1)
	elif not current:
		return
	elif event.is_action_pressed("fire"):
		current.primary_attack()
	elif event.is_action_pressed("alt_fire"):
		current.secondary_attack()
	elif event.is_action_pressed("reload"):
		current.reload()


func get_weapons() -> Array[Weapon]:
	if _inventory_managed:
		return _inventory_weapons
	var result: Array[Weapon] = []
	for child in get_children():
		if child is Weapon:
			result.append(child)
	return result


func get_aim_direction() -> Vector3:
	if has_target_lock():
		return _aim_direction
	return -(aim if aim else self).global_basis.z


func select(index: int) -> void:
	_aim_target = null
	_aim_direction = Vector3.ZERO
	var weapons := get_weapons()
	if weapons.is_empty():
		return
	index = wrapi(index, 0, weapons.size())
	if weapons[index] == current:
		return

	if current:
		if current is Firearm:
			current.ammo_changed.disconnect(PlayerState.set_ammo)
		current.unequip()

	_index = index
	current = weapons[index]
	current.equip()
	if off_hand:
		off_hand.visible = current.one_handed
	PlayerState.weapon_name = current.display_name
	if current is Firearm:
		current.ammo_changed.connect(PlayerState.set_ammo)
		PlayerState.set_ammo(current.loaded, current.capacity, current.reserve_ammo)
	else:
		PlayerState.set_ammo(0, 0, 0)
	weapon_changed.emit(current)


## Только успешный выстрел собственного оружия запускает тряску активной камеры.
func _on_weapon_fired(rounds: int) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var rig := camera.get_parent()
	if not rig.has_method("shake"):
		return
	var followed: Node = rig.get("target")
	if is_instance_valid(followed) and followed.is_ancestor_of(self):
		rig.shake(sqrt(float(rounds)))


## Постоянный поиск цели выполняется в физическом тике, а не при выстреле.
func _physics_process(_delta: float) -> void:
	_aim_direction = Vector3.ZERO
	_aim_target = null
	var shooter: Node3D = null
	var node := get_parent()
	while node:
		if node is CollisionObject3D:
			shooter = node
			break
		node = node.get_parent()
	if current is Firearm:
		var origin: Vector3 = current.get_shot_origin()
		var acquired = _target_lock.acquire(origin, current.max_range, current.get_shot_exclusions(), shooter)
		if is_instance_valid(acquired) and not acquired.is_queued_for_deletion():
			_aim_target = acquired
			_aim_direction = (_target_lock.get_target_point(_aim_target) - origin).normalized()
	if shooter and shooter.has_method("set_aim_lock"):
		shooter.set_aim_lock(_aim_target)

func has_target_lock() -> bool:
	return is_instance_valid(_aim_target) and not _aim_target.is_queued_for_deletion() and not _aim_direction.is_zero_approx()


func create_inventory_weapon(scene: PackedScene) -> Weapon:
	var instance := scene.instantiate()
	if not instance is Weapon:
		instance.free()
		return null
	add_child(instance)
	instance.unequip()
	if instance is Firearm:
		instance.fired.connect(_on_weapon_fired)
	return instance

func set_inventory_weapons(equipped: Array[Weapon]) -> void:
	if is_instance_valid(current):
		if current is Firearm and current.ammo_changed.is_connected(PlayerState.set_ammo):
			current.ammo_changed.disconnect(PlayerState.set_ammo)
		current.unequip()
	current = null
	_inventory_managed = true
	_inventory_weapons = equipped.duplicate()
	if not _inventory_weapons.is_empty():
		select(0)
	else:
		PlayerState.weapon_name = ""
		PlayerState.set_ammo(0, 0, 0)
		weapon_changed.emit(null)


## Выбранное в инвентаре оружие становится видимым в руке, а не только занимает слот.
func activate_inventory_weapon(weapon: Weapon) -> void:
	var equipped := get_weapons()
	var index := equipped.find(weapon)
	if index >= 0:
		select(index)
