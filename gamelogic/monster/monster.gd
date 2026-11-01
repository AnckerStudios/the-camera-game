class_name Monster extends CharacterBody3D


const MONSTER_GROUP = "monster"
const PHYSICAL_WEAPONS := ["WeaponDoubleShotgun", "WeaponRevolver", "WeaponAxe"]

@onready var nav_agent : NavigationAgent3D = $NavigationAgent3D
@onready var collision : CollisionShape3D = $CollisionShape3D
var playback : AnimationNodeStateMachinePlayback
var animation_tree : AnimationTree
var monster_state : MonsterState

var rotation_speed := 10.0

## За пределами радиуса враг не обнаруживает и не преследует игрока.
@export_range(0.0, 100.0, 0.5) var detection_radius: float = 8.0
var _detected_player: Node3D
var _has_target_in_range := false
var _next_path_update_ms: int = 0
var _path_target_initialized := false

## Дистанция начала удара; хит проверяется один раз в активной фазе анимации.
@export_range(0.5, 3.0, 0.05) var attack_distance: float = 1.05
@export_range(0.5, 3.0, 0.05) var attack_reach: float = 1.35
@export_range(0.1, 3.0, 0.1) var attack_width: float = 1.2
@export_range(0.1, 3.0, 0.1) var attack_height: float = 1.6
@export var attack_center_height: float = 1.0
@export_range(0.0, 1.0, 0.01) var attack_hit_progress: float = 0.45
@export_range(0.1, 3.0, 0.05) var attack_duration: float = 0.8
@export_range(0.0, 3.0, 0.05) var attack_cooldown: float = 0.35
@export_flags_3d_physics var attack_target_mask: int = 8
@export_flags_3d_physics var attack_obstacle_mask: int = 1
var _attack_active := false
var _attack_checked := false
var _attack_elapsed := 0.0
var _attack_cooldown_left := 0.0
var _attack_shape := BoxShape3D.new()

@export var vision_profile: VisionProfile = VisionProfile.new()
## Необязательная точка прицеливания; без неё используется центр коллизии/модели.
@export var aim_point: Node3D
var damage_receiver := DamageReceiver.new()
var hp: float:
	get:
		return damage_receiver.health
	set(value):
		damage_receiver.health = maxf(value, 0.0)
var move_speed: float
var attack_damage: float
var resistance_physical: float
var resistance_energetic: float

func _ready() -> void:
	nav_agent.target_desired_distance = minf(nav_agent.target_desired_distance, attack_distance * 0.4)
	vision_profile = vision_profile.duplicate()
	vision_profile.attach(self)
	damage_receiver.aim_point = aim_point
	damage_receiver.register_owner(self)
	damage_receiver.depleted.connect(_on_health_depleted)
	if has_node("Rig/AnimationTree"):
		animation_tree = $Rig/AnimationTree
		playback = animation_tree.get("parameters/StateMachine/playback")
		if playback:
			playback.state_finished.connect(_on_state_finished_for_attack)
	if has_node("MonsterState"):
		monster_state = $MonsterState

	add_child(ConeVisibility.new())
	add_to_group(MONSTER_GROUP)

func _physics_process(delta: float) -> void:
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_update_player_detection()
	if monster_state and monster_state.is_dead:
		_finish_attack()
		velocity = Vector3.ZERO
		return
	if _attack_active:
		_update_attack(delta)
		_idle_movement(delta)
		return
	if not _has_target_in_range:
		_idle_movement(delta)
		return
	if _can_start_attack():
		attack()
		_idle_movement(delta)
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	# Вычисление движения в сторону персонажа
	var current_location = global_transform.origin
	var next_location = nav_agent.get_next_path_position()
	var new_velocity = (next_location - current_location).normalized() * move_speed

	nav_agent.velocity = new_velocity

	# Поворот модели в сторону движения
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	if horizontal_velocity.length() > 0.1:
		var target_angle = atan2(-horizontal_velocity.x, -horizontal_velocity.z)
		rotation.y = lerp_angle(rotation.y, target_angle, delta * rotation_speed)

## Сцены со старым контроллером уровня также проходят проверку радиуса.
func update_target_location(target_location: Vector3) -> void:
	_has_target_in_range = detection_radius > 0.0 and global_position.distance_squared_to(target_location) <= detection_radius * detection_radius
	if monster_state and monster_state.is_dead:
		_has_target_in_range = false
	if not _has_target_in_range:
		return
	var now := Time.get_ticks_msec()
	if now < _next_path_update_ms:
		return
	_next_path_update_ms = now + 200
	if not _path_target_initialized or not nav_agent.target_position.is_equal_approx(target_location):
		_path_target_initialized = true
		nav_agent.target_position = target_location

## Работает и в сценах без test_level_dima_script.gd, например forest_base.
func _update_player_detection() -> void:
	if not is_instance_valid(_detected_player):
		_detected_player = get_tree().get_first_node_in_group(&"players") as Node3D
	if not is_instance_valid(_detected_player) or _detected_player.is_queued_for_deletion() or PlayerState.hp <= 0.0:
		_has_target_in_range = false
		return
	update_target_location(_detected_player.global_position)

## Ожидание сохраняет гравитацию, но не позволяет avoidance толкать врага по старому пути.
func _idle_movement(delta: float) -> void:
	nav_agent.velocity = Vector3.ZERO
	velocity.x = 0.0
	velocity.z = 0.0
	if monster_state and monster_state.is_dead:
		velocity = Vector3.ZERO
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

## Монстры переопределяют множитель или сам метод, сохраняя общий расчёт здоровья.
func take_damage(amount: float, source: Node) -> void:
	if(monster_state != null):
		if monster_state.is_dead:
			return
	damage_receiver.take_damage(amount * _get_damage_multiplier(source), source)

func _get_damage_multiplier(source: Node) -> float:
	if is_instance_valid(source) and PHYSICAL_WEAPONS.has(source.name):
		return resistance_physical
	return resistance_energetic

func _on_health_depleted(_source: Node) -> void:
	die()

# Действия при смерти монстра
func die() -> void:
	_finish_attack()
	if(monster_state != null):
		monster_state.is_dead = true
		velocity = Vector3.ZERO
		collision_mask = 2
		collision_layer = 2
		if(playback != null):
			playback.state_finished.connect(_on_state_finished_for_death, CONNECT_ONE_SHOT)
			playback.travel("die")

func _on_state_finished_for_death(state_name: StringName):
	if state_name == "die":
		queue_free()
	else:
		if(playback != null):
			playback.state_finished.connect(_on_state_finished_for_death, CONNECT_ONE_SHOT)

# Пересчёт движения для навигации в дочерних объектах
func recalculate_velocity(safe_velocity: Vector3) -> void:
	if not _has_target_in_range:
		return
	if(monster_state != null):
		if monster_state.is_already_attack():
			velocity = Vector3.ZERO
			return
	safe_velocity.y = 0
	velocity = velocity.move_toward(safe_velocity, 0.5)
	if not is_on_floor():
		velocity.y += get_gravity().y * 0.2
	move_and_slide()

func _can_start_attack() -> bool:
	if _attack_active or _attack_cooldown_left > 0.0 or not _has_target_in_range or not is_instance_valid(_detected_player):
		return false
	var offset := _detected_player.global_position - global_position
	return Vector2(offset.x, offset.z).length_squared() <= attack_distance * attack_distance and absf(offset.y) <= attack_height

func attack() -> void:
	if not _can_start_attack() or (monster_state and monster_state.is_dead):
		return
	_attack_active = true
	_attack_checked = false
	_attack_elapsed = 0.0
	if monster_state:
		monster_state.is_attacked = true
	var direction := _detected_player.global_position - global_position
	if Vector2(direction.x, direction.z).length_squared() > 0.001:
		global_rotation.y = atan2(-direction.x, -direction.z)
	velocity = Vector3.ZERO
	nav_agent.velocity = Vector3.ZERO
	if playback:
		playback.travel(&"attack")

## Используем позицию AnimationTree, учитывающую скорость воспроизведения.
func _update_attack(delta: float) -> void:
	_attack_elapsed += delta
	var progress := _attack_elapsed / maxf(attack_duration, 0.01)
	var duration := attack_duration
	if playback:
		if playback.get_current_node() == &"attack":
			duration = maxf(playback.get_current_length(), 0.01)
			progress = playback.get_current_play_position() / duration
		else:
			if _attack_checked or _attack_elapsed > maxf(attack_duration * 2.0, 1.0):
				_finish_attack()
			return
	if not _attack_checked and progress >= attack_hit_progress:
		_attack_checked = true
		_attempt_attack_hit()
	if progress >= 0.99 or _attack_elapsed > maxf(duration * 3.0, 2.0):
		_finish_attack()

## Единственная проверка на взмах, не зависит от нулевой формы старого AttackHitBox.
func _attempt_attack_hit() -> void:
	if not _has_target_in_range or not is_instance_valid(_detected_player) or PlayerState.hp <= 0.0:
		return
	_attack_shape.size = Vector3(attack_width, attack_height, attack_reach)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _attack_shape
	var origin := global_position + Vector3.UP * attack_center_height
	query.transform = Transform3D(global_basis.orthonormalized(), origin) * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -attack_reach * 0.5))
	query.collision_mask = attack_target_mask
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var space := get_world_3d().direct_space_state
	for hit in space.intersect_shape(query, 16):
		if hit.collider != _detected_player:
			continue
		var excluded: Array[RID] = [get_rid()]
		if _detected_player is CollisionObject3D:
			excluded.append(_detected_player.get_rid())
		var destination := _detected_player.global_position + Vector3.UP * 0.9
		var ray := PhysicsRayQueryParameters3D.create(origin, destination, attack_obstacle_mask, excluded)
		ray.collide_with_areas = false
		ray.hit_from_inside = true
		if not space.intersect_ray(ray).is_empty():
			return
		if _detected_player.has_method(&"take_damage"):
			_detected_player.take_damage(attack_damage, self)
		return

func _finish_attack() -> void:
	if not _attack_active:
		return
	_attack_active = false
	_attack_cooldown_left = attack_cooldown
	if monster_state:
		monster_state.is_attacked = false

func _on_state_finished_for_attack(state_name: StringName) -> void:
	if state_name == &"attack" and _attack_active:
		_finish_attack()

## Сохраняем совместимость треков анимации, не допуская повторного урона от Area3D.
func do_damage() -> void:
	pass
