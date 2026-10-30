class_name Ghost extends Monster

func _ready() -> void:
	super()
	dimension = Dimension.INFRARED
	hp = 200.0
	move_speed = 3.0
	attack_damage = 15.0
	resistance_physical = 0.3
	resistance_energetic = 1.0

func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	recalculate_velocity(safe_velocity)
