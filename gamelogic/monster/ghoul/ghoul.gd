class_name Ghoul extends Monster

func _ready() -> void:
	super()
	dimension = Dimension.REAL
	hp = 100.0
	move_speed = 2.0
	attack_damage = 10.0
	resistance_physical = 1.0
	resistance_energetic = 0.3

func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	recalculate_velocity(safe_velocity)
