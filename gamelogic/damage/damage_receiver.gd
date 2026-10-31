class_name DamageReceiver
extends RefCounted
## Общая обработка здоровья. Может быть заменена наследником для особых правил урона.
signal damaged(amount: float, source: Node)
signal depleted(source: Node)

const TARGET_GROUP: StringName = &"damage_receivers"
const RECEIVER_META: StringName = &"damage_receiver_component"
var _owner_ref: WeakRef
## Необязательный Marker3D/Node3D для точного задания точки прицеливания.
var aim_point: Node3D
var _local_aim_center: Vector3 = Vector3.ZERO
var enabled: bool = true
var health: float = 100.0

## Возвращает фактически снятое здоровье; повторная смерть не вызывается.
func take_damage(amount: float, source: Node) -> float:
	if not enabled or health <= 0.0 or not is_finite(amount) or amount <= 0.0:
		return 0.0
	var calculated := _calculate_damage(amount, source)
	if not is_finite(calculated) or calculated <= 0.0:
		return 0.0
	var applied := minf(health, calculated)
	health = maxf(health - applied, 0.0)
	damaged.emit(applied, source)
	if health <= 0.0:
		depleted.emit(source)
	return applied

## Точка расширения для специальных правил обработки урона.
func _calculate_damage(amount: float, _source: Node) -> float:
	return amount


## Регистрирует владельца как общую цель для оружия независимо от его типа.
func register_owner(owner: Node3D) -> void:
	_owner_ref = weakref(owner)
	_local_aim_center = _calculate_aim_center(owner)
	owner.set_meta(RECEIVER_META, self)
	owner.add_to_group(TARGET_GROUP)

func can_receive_damage() -> bool:
	if not enabled or health <= 0.0 or not _owner_ref:
		return false
	var owner = _owner_ref.get_ref()
	return is_instance_valid(owner) and not owner.is_queued_for_deletion()

## Оружие обращается к компоненту; переопределение take_damage у владельца сохраняется.
func receive_hit(amount: float, source: Node) -> float:
	if not can_receive_damage():
		return 0.0
	var owner = _owner_ref.get_ref()
	var previous_health := health
	owner.take_damage(amount, source)
	print("-%.0f от %s" % [amount, source.name])
	return maxf(previous_health - health, 0.0)

## Одинаковая проверка для lock и попаданий, включая дочерние коллизии.
static func find_target(collider: Node) -> Node3D:
	var node := collider
	while is_instance_valid(node):
		var receiver = node.get_meta(RECEIVER_META) if node.has_meta(RECEIVER_META) else null
		if receiver is DamageReceiver:
			return node as Node3D if receiver.can_receive_damage() else null
		node = node.get_parent()
	return null

static func get_receiver(target: Node) -> DamageReceiver:
	if not is_instance_valid(target) or not target.has_meta(RECEIVER_META):
		return null
	var receiver = target.get_meta(RECEIVER_META)
	return receiver as DamageReceiver


## Точка захвата общая для проверки видимости, полёта пули и поворота оружия.
func get_target_point() -> Vector3:
	if is_instance_valid(aim_point):
		return aim_point.global_position
	var owner = _owner_ref.get_ref() if _owner_ref else null
	if not is_instance_valid(owner):
		return Vector3.ZERO
	return owner.to_global(_local_aim_center)


## Центр основных коллизий владельца; триггеры атаки/обнаружения не учитываются.
func _calculate_aim_center(owner: Node3D) -> Vector3:
	var bounds := AABB()
	var found := false
	var inverse := owner.global_transform.affine_inverse()
	for node in owner.find_children("*", "CollisionShape3D", true, false):
		if node.disabled or not node.shape or node.get_parent() != owner:
			continue
		var shape_bounds: AABB = (inverse * node.global_transform) * node.shape.get_debug_mesh().get_aabb()
		bounds = bounds.merge(shape_bounds) if found else shape_bounds
		found = true
	if not found:
		for node in owner.find_children("*", "MeshInstance3D", true, false):
			if not node.mesh or not node.is_visible_in_tree():
				continue
			var mesh_bounds: AABB = (inverse * node.global_transform) * node.get_aabb()
			bounds = bounds.merge(mesh_bounds) if found else mesh_bounds
			found = true
	return bounds.get_center() if found else Vector3.ZERO
