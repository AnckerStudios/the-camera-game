class_name DamageableEnvironment
extends StaticBody3D
## Основа разрушаемого окружения: мишеней, бочек, дверей.
signal damaged(amount: float, source: Node)
signal destroyed(source: Node)

## Необязательная точка прицеливания; без неё используется центр коллизии/модели.
@export var aim_point: Node3D
var damage_receiver := DamageReceiver.new()
@export var hp: float = 100.0:
	get:
		return damage_receiver.health
	set(value):
		damage_receiver.health = maxf(value, 0.0)
var _destroyed: bool = false

func _ready() -> void:
	damage_receiver.aim_point = aim_point
	damage_receiver.register_owner(self)
	add_to_group(&"damageable_environment")
	damage_receiver.damaged.connect(_on_damage_received)
	damage_receiver.depleted.connect(_on_health_depleted)

## Единый внешний интерфейс для пуль, взрывов и других источников.
func take_damage(amount: float, source: Node) -> void:
	if not _destroyed:
		damage_receiver.take_damage(amount * _get_damage_multiplier(source), source)

## Наследники могут определять устойчивость к разным источникам.
func _get_damage_multiplier(_source: Node) -> float:
	return 1.0

func _on_damage_received(amount: float, source: Node) -> void:
	damaged.emit(amount, source)

func _on_health_depleted(source: Node) -> void:
	if _destroyed:
		return
	_destroyed = true
	destroyed.emit(source)
	_on_destroyed(source)

## Бочка может запустить взрыв, дверь — анимацию разрушения вместо удаления.
func _on_destroyed(_source: Node) -> void:
	queue_free()
