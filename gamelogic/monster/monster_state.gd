class_name MonsterState extends Node

var is_dead := false:
	set(value):
		is_dead = value

var is_attacked := false:
	set(value):
		is_attacked = value
	get():
		return is_attacked and !is_dead

var is_can_attack := false:
	set(value):
		is_can_attack = value
	get():
		return is_can_attack and !is_attacked

func is_already_attack() -> bool:
	return is_dead or is_attacked
