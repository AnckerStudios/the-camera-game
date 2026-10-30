extends Node3D

@export var target: Node3D
@export var follow_speed: float = 8.0

func _ready() -> void:
	if target:
		global_position = target.global_position

func _physics_process(delta: float) -> void:
	if is_instance_valid(target):
		global_position = global_position.lerp(target.global_position, 1.0 - exp(-follow_speed * delta))
