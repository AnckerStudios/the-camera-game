extends Node

@onready var player : CharacterBody3D = $Player

func _ready() -> void:
	MenuState.state = false

func _physics_process(delta: float) -> void:
	get_tree().call_group(Monster.MONSTER_GROUP, "update_target_location", player.global_transform.origin)
