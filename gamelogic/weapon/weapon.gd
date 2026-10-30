class_name Weapon
extends Node3D

## Базовый класс оружия игрока. Конкретные виды (огнестрел, ближний бой, энергетика) переопределяют атаки.

@export var display_name := "ОРУЖИЕ"
## Держится одной рукой: вторая свободна (под фонарик, потом добавлю модельку).
@export var one_handed := false


## (ЛКМ).
func primary_attack() -> void:
	pass


## (ПКМ).
func secondary_attack() -> void:
	pass


func reload() -> void:
	pass


## Достать оружие.
func equip() -> void:
	show()
	process_mode = Node.PROCESS_MODE_INHERIT


## Убрать оружие.
func unequip() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED
