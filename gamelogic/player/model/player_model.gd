extends Node3D
## Модель персонажа: смешивает анимации ходьбы по движению тела относительно направления взгляда.
## Взгляд (поворот модели к курсору) и движение независимы, поэтому при движении вбок
## или спиной вперёд играют стрейф и ходьба назад.

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

var _blend := Vector2.ZERO

@onready var _tree: AnimationTree = $AnimationTree


func _physics_process(delta: float) -> void:
	if not body:
		return
	var velocity := body.velocity
	velocity.y = 0.0
	# Скорость в осях модели: вперёд по взгляду (-Z) и вправо (+X).
	var local := global_basis.inverse() * velocity
	var target := Vector2(local.x, -local.z) / full_blend_speed
	target = target.limit_length(1.0)
	_blend = _blend.lerp(target, 1.0 - exp(-blend_smoothing * delta))
	_tree.set(&"parameters/Move/blend_position", _blend)

	var speed := velocity.length()
	_tree.set(&"parameters/Speed/scale", maxf(1.0, minf(speed / anim_ground_speed, max_time_scale)))
