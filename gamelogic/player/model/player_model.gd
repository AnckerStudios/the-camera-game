extends Node3D
## Модель персонажа: смешивает анимации ходьбы по движению тела относительно направления взгляда.
## Взгляд (поворот модели к курсору) и движение независимы, поэтому при движении вбок
## или спиной вперёд играют стрейф и ходьба назад. На рывок тела играет кувырок.

## Тело, чью скорость показывает анимация.
@export var body: CharacterBody3D
## Скорость, при которой смешивание доходит до полной ходьбы, м/с.
@export var full_blend_speed := 3.0
## Скорость шага в анимациях ходьбы (после масштаба модели), м/с.
@export var anim_ground_speed := 1.0
## Предел ускорения анимации, чтобы на бегу она не превращалась в перемотку.
@export var max_time_scale := 2.0
## Плавность смены направления в смешивании.
@export var blend_smoothing := 10.0
## Скорость возврата модели к направлению взгляда после кувырка.
@export var face_back_speed := 6.0



var _blend := Vector2.ZERO
var _roll_remaining := 0.0
var _roll_yaw := 0.0

@onready var _tree: AnimationTree = $AnimationTree


func _ready() -> void:
	var actions := get_node_or_null("WeaponAnimation")
	if actions:
		actions.initialize(body, find_child("WeaponHolder", true, false) as WeaponHolder)
	if body and body.has_signal(&"dashed"):
		body.dashed.connect(_on_body_dashed)


func _physics_process(delta: float) -> void:
	if not body:
		return
	_update_facing(delta)

	var velocity := body.velocity
	velocity.y = 0.0
	# Скорость в осях модели: вперёд по взгляду (-Z) и вправо (+X).
	var local := global_basis.inverse() * velocity
	var target := Vector2(local.x, -local.z) / maxf(full_blend_speed, 0.01)
	target = target.limit_length(1.0)
	_blend = _blend.lerp(target, 1.0 - exp(-blend_smoothing * delta))
	_tree.set(&"parameters/Move/blend_position", _blend)

	var speed := velocity.length()
	_tree.set(&"parameters/Speed/scale", maxf(1.0, minf(speed / maxf(anim_ground_speed, 0.01), max_time_scale)))


## Кувырок растягивается на длительность рывка.
func _on_body_dashed(direction: Vector3, duration: float) -> void:
	_roll_remaining = duration
	_roll_yaw = atan2(-direction.x, -direction.z)


## Во время кувырка модель смотрит туда, куда катится, а не на курсор;
## родитель (взгляд) продолжает поворачиваться, поэтому направление держится в мировых осях.
func _update_facing(delta: float) -> void:
	if _roll_remaining > 0.0:
		_roll_remaining -= delta
		global_rotation.y = _roll_yaw
	else:
		rotation.y = lerp_angle(rotation.y, 0.0, 1.0 - exp(-face_back_speed * delta))
