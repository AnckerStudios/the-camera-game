class_name Ghoul extends Monster

func _ready() -> void:
	vision_profile = vision_profile.duplicate()
	super()
	vision_profile.dimension = VisionProfile.Dimension.REAL
	hp = 100.0
	move_speed = 1.5
	attack_damage = 10.0
	resistance_physical = 1.0
	resistance_energetic = 0.3

func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	recalculate_velocity(safe_velocity)

func _on_attack_zone_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		monster_state.is_can_attack = true

func _on_attack_zone_body_exited(body: Node3D) -> void:
	if body.name == "Player":
		monster_state.is_can_attack = false

func _on_attack_hit_box_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		do_damage()
