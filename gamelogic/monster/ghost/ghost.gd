class_name Ghost extends Monster

func _ready() -> void:
	vision_profile = vision_profile.duplicate()
	vision_profile.dimension = VisionProfile.Dimension.INFRARED
	super()
	hp = 200.0
	move_speed = 3.0
	attack_damage = 15.0
	resistance_physical = 0.3
	resistance_energetic = 1.0

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
