class_name Monster extends CharacterBody3D

enum Dimension {REAL, INFRARED}

const MONSTER_GROUP = "monster"
const PHYSICAL_WEAPONS := ["WeaponDoubleShotgun", "WeaponRevolver"]

@onready var nav_agent : NavigationAgent3D = $NavigationAgent3D
@onready var animation_tree : AnimationTree = $Rig/AnimationTree
@onready var playback : AnimationNodeStateMachinePlayback = $Rig/AnimationTree.get("parameters/StateMachine/playback")

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
	if not is_on_floor():
		velocity += get_gravity() * delta

	var current_location = global_transform.origin
	var next_location = nav_agent.get_next_path_position()
	var new_velocity = (next_location - current_location).normalized() * move_speed

	nav_agent.velocity = new_velocity

func update_target_location(target_location: Vector3) -> void:
	nav_agent.target_position = target_location
	pass

func recalculate_velocity(safe_velocity: Vector3) -> void:
	velocity = velocity.move_toward(safe_velocity, 0.5)
	move_and_slide()


func take_damage(amount: float, source: Node) -> void:
	var resistance: float
	
	if PHYSICAL_WEAPONS.has(source.name):
		resistance = resistance_physical
	else:
		resistance = resistance_energetic
	
	hp -= amount * resistance
	print("%s: -%.0f от %s, осталось %.0f" % [name, amount, source.name, hp])
	if hp <= 0.0:
		playback.state_finished.connect(_on_state_finished_for_death, CONNECT_ONE_SHOT)
		playback.travel("die")


func _on_state_finished_for_death(state_name: StringName):
	if state_name == "die":
		queue_free()
	else:
		playback.state_finished.connect(_on_state_finished_for_death, CONNECT_ONE_SHOT)

func recalculate_velocity(safe_velocity: Vector3) -> void:
	velocity = velocity.move_toward(safe_velocity, 0.5)
	move_and_slide()
