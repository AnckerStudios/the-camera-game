extends StaticBody3D

## Тестовая мишень: принимает урон от оружия и пишет его в лог.

@export var hp := 100.0


func take_damage(amount: float, source: Node) -> void:
	hp -= amount
	print("%s: -%.0f от %s, осталось %.0f" % [name, amount, source.name, hp])
	if hp <= 0.0:
		queue_free()


## Видимость не отключает коллизию и возможность получать урон.
func _ready() -> void:
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
