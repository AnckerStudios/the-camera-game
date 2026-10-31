class_name WeaponHolder
extends Node3D

## Держатель оружия игрока: дочерние Weapon, переключение, ввод и проброс состояния в PlayerState.

## Узел, вдоль -Z которого целится оружие. Держатель может сидеть на кисти и качаться
## вместе с анимацией, а стрелять нужно туда, куда смотрит персонаж. Без узла - сам держатель.
@export var aim: Node3D
## Предмет во второй руке; виден только с одноручным оружием.
@export var off_hand: Node3D
## Время визуального удержания оружия на цели после выстрела.
@export_range(0.0, 1.0, 0.01) var lock_pose_seconds: float = 0.2
@export_range(0.1, 30.0, 0.1) var aim_return_speed: float = 12.0

const TargetLockScript = preload("res://gamelogic/weapon/target_lock.gd")
var _target_lock: Node
var _shot_direction: Vector3 = Vector3.ZERO
var _shot_target: Node3D
var _visual_lock_remaining: float = 0.0
var _rest_basis: Basis
var _visual_aim_active: bool = false

var current: Weapon

var _index := -1


func _ready() -> void:
	_rest_basis = basis
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
	var result: Array[Weapon] = []
	for child in get_children():
		if child is Weapon:
			result.append(child)
	return result


func get_aim_direction() -> Vector3:
	if not _shot_direction.is_zero_approx():
		return _shot_direction
	return -(aim if aim else self).global_basis.z


func select(index: int) -> void:
	_visual_lock_remaining = 0.0
	if _visual_aim_active:
		basis = _rest_basis
		_visual_aim_active = false
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


## Захват вызывается один раз на успешную попытку выстрела из Firearm.
func prepare_shot(origin: Vector3, max_distance: float, excluded: Array[RID]) -> void:
	_shot_direction = Vector3.ZERO
	var shooter: Node3D = null
	var node := get_parent()
	while node:
		if node is CollisionObject3D:
			shooter = node
			break
		node = node.get_parent()
	_shot_target = null
	var acquired = _target_lock.acquire(origin, max_distance, excluded, shooter)
	if is_instance_valid(acquired) and not acquired.is_queued_for_deletion():
		_shot_target = acquired
	if is_instance_valid(_shot_target):
		_shot_direction = _target_lock.get_target_point(_shot_target) - origin

		_shot_direction = _shot_direction.normalized()
		_visual_lock_remaining = lock_pose_seconds
		_visual_aim_active = true
		_apply_visual_aim()
		if shooter and shooter.has_method("set_shooting_lock"):
			shooter.set_shooting_lock(_shot_target, lock_pose_seconds)

func finish_shot() -> void:
	_shot_direction = Vector3.ZERO


func has_shot_lock() -> bool:
	return not _shot_direction.is_zero_approx()


## Обновляется после анимации руки, сохраняя наведение на движущуюся цель.
func _process(delta: float) -> void:
	if not is_instance_valid(_shot_target):
		_shot_target = null
	elif _shot_target.is_queued_for_deletion():
		_shot_target = null
	if _visual_lock_remaining > 0.0 and is_instance_valid(_shot_target) and not _shot_target.is_queued_for_deletion():
		_visual_lock_remaining = maxf(_visual_lock_remaining - delta, 0.0)
		_apply_visual_aim()
	elif _visual_aim_active:
		_visual_lock_remaining = 0.0
		var weight := 1.0 - exp(-aim_return_speed * delta)
		var rotation_from := basis.orthonormalized().get_rotation_quaternion()
		var rotation_to := _rest_basis.orthonormalized().get_rotation_quaternion()
		basis = Basis(rotation_from.slerp(rotation_to, weight)).scaled(_rest_basis.get_scale())
		if rotation_from.angle_to(rotation_to) < 0.001:
			basis = _rest_basis
			_visual_aim_active = false


## Ориентирует оружие по всем трём осям, не наклоняя тело персонажа.
func _apply_visual_aim() -> void:
	if not is_instance_valid(current) or not is_instance_valid(_shot_target):
		return
	var muzzle := current.get_node_or_null("Muzzle") as Node3D
	if not muzzle:
		return
	var point: Vector3 = _target_lock.get_target_point(_shot_target)
	# Два уточнения компенсируют смещение самого дула при повороте держателя.
	for iteration in 2:
		var direction := point - muzzle.global_position
		if direction.is_zero_approx():
			return
		direction = direction.normalized()
		var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.999 else Vector3.UP
		var scale_before := global_basis.get_scale()
		global_basis = Basis.looking_at(direction, up).scaled(scale_before)
