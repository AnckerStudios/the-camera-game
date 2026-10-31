extends StaticBody3D
## Мишень использует компонент урона через поле, как монстры.
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

func _ready() -> void:
	damage_receiver.aim_point = aim_point
	damage_receiver.register_owner(self)
	add_to_group(&"damageable_environment")
	damage_receiver.damaged.connect(_on_damage_received)
	damage_receiver.depleted.connect(_on_health_depleted)
	add_child(ConeVisibility.new())
	add_to_group(&"cutout_targets")
	_update_cone_visibility()

func _process(_delta: float) -> void:
	_update_cone_visibility()

func _update_cone_visibility() -> void:
	var cones := get_tree().get_nodes_in_group(&"visibility_cones")
	# Сцены без конуса сохраняют обычное отображение мишени.
	var inside := cones.is_empty()
	for cone in cones:
		if cone.contains_world_point(global_position):
			inside = true
			break
	visible = inside


## Общий компонент снимает здоровье и гарантирует однократную обработку разрушения.
func take_damage(amount: float, source: Node) -> void:
	damage_receiver.take_damage(amount, source)

func _on_damage_received(amount: float, source: Node) -> void:
	damaged.emit(amount, source)

func _on_health_depleted(source: Node) -> void:
	destroyed.emit(source)
	queue_free()
