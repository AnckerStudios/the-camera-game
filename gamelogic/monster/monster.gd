class_name Monster extends CharacterBody3D

enum Dimension {REAL, INFRARED}

const MONSTER_GROUP = "monster"
const PHYSICAL_WEAPONS := ["WeaponDoubleShotgun", "WeaponRevolver", "WeaponAxe"]

@onready var nav_agent : NavigationAgent3D = $NavigationAgent3D
@onready var collision : CollisionShape3D = $CollisionShape3D
@onready var animation_tree : AnimationTree = $Rig/AnimationTree
@onready var playback : AnimationNodeStateMachinePlayback = $Rig/AnimationTree.get("parameters/StateMachine/playback")
@onready var monster_state : MonsterState = $MonsterState

var rotation_speed := 10.0

var dimension: Dimension
var hp: float
var move_speed: float
var attack_damage: float
var resistance_physical: float
var resistance_energetic: float

func _ready() -> void:
	add_child(ConeVisibility.new())
	add_to_group(MONSTER_GROUP)

func _physics_process(delta: float) -> void:
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

func take_damage(amount: float, source: Node) -> void:
	var resistance: float
	
	if PHYSICAL_WEAPONS.has(source.name):
		resistance = resistance_physical
	else:
		resistance = resistance_energetic
	
	hp -= amount * resistance
	print("%s: -%.0f от %s, осталось %.0f" % [name, amount, source.name, hp])
	if hp <= 0.0:
		die()

# Действия при смерти монстра
func die() -> void:
		monster_state.is_dead = true
		velocity = Vector3.ZERO
		collision_mask = 2
		collision_layer = 2
		playback.state_finished.connect(_on_state_finished_for_death, CONNECT_ONE_SHOT)
		playback.travel("die")

func _on_state_finished_for_death(state_name: StringName):
	if state_name == "die":
		queue_free()
	else:
		playback.state_finished.connect(_on_state_finished_for_death, CONNECT_ONE_SHOT)

# Пересчёт движения для навигации в дочерних объектах
func recalculate_velocity(safe_velocity: Vector3) -> void:
	if monster_state.is_already_attack():
		velocity = Vector3.ZERO
		return
	safe_velocity.y = 0
	velocity = velocity.move_toward(safe_velocity, 0.5)
	if not is_on_floor():
		velocity.y += get_gravity().y * 0.2
	move_and_slide()

func attack() -> void:
	if monster_state.is_already_attack():
		return
	monster_state.is_attacked = true
	playback.state_finished.connect(_on_state_finished_for_attack, CONNECT_ONE_SHOT)
	playback.travel("attack")

func _on_state_finished_for_attack(state_name: StringName) -> void:
	if state_name == "attack":
		monster_state.is_attacked = false
	else:
		playback.state_finished.connect(_on_state_finished_for_attack, CONNECT_ONE_SHOT)

func do_damage() -> void:
	PlayerState.hp -= attack_damage
