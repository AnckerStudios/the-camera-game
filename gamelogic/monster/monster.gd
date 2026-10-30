class_name Monster extends CharacterBody3D

enum Dimension {REAL, INFRARED}

const MONSTER_GROUP = "monster"

@onready var nav_agent : NavigationAgent3D = $NavigationAgent3D

var dimension
var hp
var move_speed
var attack_damage

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
	hp -= amount
	print("%s: -%.0f от %s, осталось %.0f" % [name, amount, source.name, hp])
	if hp <= 0.0:
		queue_free()
