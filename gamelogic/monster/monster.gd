class_name Monster extends CharacterBody3D


const MONSTER_GROUP = "monster"
const PHYSICAL_WEAPONS := ["WeaponDoubleShotgun", "WeaponRevolver", "WeaponAxe"]

@onready var nav_agent : NavigationAgent3D = $NavigationAgent3D
@onready var collision : CollisionShape3D = $CollisionShape3D
var playback : AnimationNodeStateMachinePlayback
var animation_tree : AnimationTree
var monster_state : MonsterState

var rotation_speed := 10.0

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

func update_target_location(target_location: Vector3) -> void:
	nav_agent.target_position = target_location

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
	PlayerState.hp -= attack_damage
