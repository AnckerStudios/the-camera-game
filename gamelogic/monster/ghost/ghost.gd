class_name Ghost extends Monster

@export_range(0.05, 1.0, 0.05) var infrared_opacity: float = 0.1

func _ready() -> void:
	vision_profile = vision_profile.duplicate()
	vision_profile.dimension = VisionProfile.Dimension.INFRARED
	vision_profile.infrared_opacity = infrared_opacity
	super()
	# Исключаем только физическое столкновение с игроком, сохраняя попадания пуль.
	get_tree().node_added.connect(_on_collision_candidate_added)
	for player in get_tree().get_nodes_in_group(&"players"):
		_ignore_player_collision(player)
	hp = 75.0
	move_speed = 3.0
	attack_damage = 15.0
	resistance_physical = 1.0
	resistance_energetic = 1.0

## Также поддерживает появление игрока после призрака.
func _on_collision_candidate_added(node: Node) -> void:
	if node is PhysicsBody3D and node.is_in_group(&"players"):
		_ignore_player_collision.call_deferred(node)

func _ignore_player_collision(player: Node) -> void:
	if not is_instance_valid(player) or not player is PhysicsBody3D or not player.is_inside_tree():
		return
	add_collision_exception_with(player)
	player.add_collision_exception_with(self)

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
