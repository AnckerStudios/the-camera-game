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
	add_child(ConeVisibility.new())
