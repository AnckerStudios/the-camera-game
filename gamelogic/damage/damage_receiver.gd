class_name DamageReceiver
extends RefCounted
## Общая обработка здоровья. Может быть заменена наследником для особых правил урона.
signal damaged(amount: float, source: Node)
signal depleted(source: Node)

const TARGET_GROUP: StringName = &"damage_receivers"
const RECEIVER_META: StringName = &"damage_receiver_component"
var _owner_ref: WeakRef
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
