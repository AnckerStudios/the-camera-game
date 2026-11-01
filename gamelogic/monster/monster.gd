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
	vision_profile = vision_profile.duplicate()
	vision_profile.attach(self)
	damage_receiver.aim_point = aim_point
	damage_receiver.register_owner(self)
	damage_receiver.depleted.connect(_on_health_depleted)
	if has_node("Rig/AnimationTree"):
		animation_tree = $Rig/AnimationTree
		playback = animation_tree.get("parameters/StateMachine/playback")
	if has_node("MonsterState"):
		monster_state = $MonsterState

	add_child(ConeVisibility.new())
	add_to_group(MONSTER_GROUP)

func _physics_process(delta: float) -> void:
	_update_player_detection()
	if not _has_target_in_range:
		_idle_movement(delta)
		return
	if(monster_state != null):
		if monster_state.is_dead:
			velocity = Vector3.ZERO
			return
		if monster_state.is_can_attack:
			attack()
			return
		if monster_state.is_attacked:
			var target_position := (nav_agent.target_position - position).normalized()
			var target_angle = atan2(-target_position.x, -target_position.z)
			rotation.y = lerp_angle(rotation.y, target_angle, delta * rotation_speed)
			velocity = Vector3.ZERO
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

func attack() -> void:
	if(monster_state != null):
		if monster_state.is_already_attack():
			return
		monster_state.is_attacked = true
		if (playback != null):
			playback.state_finished.connect(_on_state_finished_for_attack, CONNECT_ONE_SHOT)
			playback.travel("attack")

func _on_state_finished_for_attack(state_name: StringName) -> void:
	if state_name == "attack":
		monster_state.is_attacked = false
	else:
		if (playback != null):
			playback.state_finished.connect(_on_state_finished_for_attack, CONNECT_ONE_SHOT)

func do_damage() -> void:
	if _has_target_in_range:
		PlayerState.hp -= attack_damage
