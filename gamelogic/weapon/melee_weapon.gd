class_name MeleeWeapon
extends Weapon

## Оружие ближнего боя: удар задевает всех в секторе перед персонажем.

signal swung
signal struck(hits: int)

@export_group("Удар")
@export var damage := 40.0
## Дальность удара от оружия, м.
@export var reach := 1.6
## Полный угол сектора удара в градусах (в плоскости пола).
@export_range(0.0, 360.0) var arc_degrees := 100.0
## Минимальная пауза между ударами, сек.
@export var swing_interval := 0.6
## Время от начала замаха до попадания, сек.
@export var hit_delay := 0.2
@export_flags_3d_physics var hit_mask := 1
## Вид сверху: удар задевает всё в вертикальной полосе вокруг оружия, как и пули.
@export var hit_band_below := 1.0
@export var hit_band_above := 0.5

@export_group("Анимация")
## Плеер анимаций модели; если анимации нет, замах делается поворотом swing_pivot.
@export var animator: AnimationPlayer
## Анимация удара под swing_interval.
@export var swing_animation: StringName
## Узел в точке хвата, который поворачивается при замахе.
@export var swing_pivot: Node3D
## Дуга горизонтального удара справа налево, градусы; середина дуги - момент попадания.
@export var swing_degrees := 140.0

## При анимации персонажа не вращаем оружие второй раз отдельным tween.
var character_animation := false

var _cooldown := 0.0
var _hit_timer := 0.0
var _tween: Tween
var _hit_shape := CylinderShape3D.new()

@onready var _swing_sound: AudioStreamPlayer3D = get_node_or_null("SwingSound")


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _hit_timer <= 0.0:
		return
	_hit_timer -= delta
	if _hit_timer <= 0.0:
		_strike()


func primary_attack() -> void:
	swing()


## Начать удар. проверка на замах 
func swing() -> bool:
	if _cooldown > 0.0:
		return false
	_cooldown = swing_interval
	_hit_timer = maxf(hit_delay, 0.001)
	if not character_animation:
		_play_swing_animation()
	if _swing_sound:
		_swing_sound.play()
	swung.emit()
	return true


func unequip() -> void:
	_hit_timer = 0.0
	_reset_animation()
	super()


## Бьёт всех в секторе перед персонажем, каждого не больше одного раза.
func _strike() -> void:
	var forward := _aim_direction()
	var origin := global_position
	_hit_shape.radius = reach
	_hit_shape.height = hit_band_below + hit_band_above

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _hit_shape
	query.transform = Transform3D(Basis.IDENTITY,
		origin + Vector3.UP * (hit_band_above - hit_band_below) / 2.0)
	query.collision_mask = hit_mask
	query.collide_with_areas = true
	query.exclude = _exclude()

	var half := deg_to_rad(arc_degrees) / 2.0
	var hit_targets := {}
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var target: Object = hit.collider
		if hit_targets.has(target) or not target.has_method("take_damage"):
			continue
		var to_target: Vector3 = (target as Node3D).global_position - origin
		to_target.y = 0.0
		if to_target.length_squared() > 0.0001 and forward.angle_to(to_target) > half:
			continue
		hit_targets[target] = true
		target.take_damage(damage, self)
	if not hit_targets.is_empty():
		struck.emit(hit_targets.size())


## Направление удара в плоскости пола. В держателе - по его прицелу, а не по модели в руке.
func _aim_direction() -> Vector3:
	var forward := -global_basis.z
	var holder := get_parent() as WeaponHolder
	if holder:
		forward = holder.get_aim_direction()
	forward.y = 0.0
	return forward.normalized()


## Не попадать в того, кто держит оружие.
func _exclude() -> Array[RID]:
	var node := get_parent()
	while node:
		if node is CollisionObject3D:
			return [node.get_rid()]
		node = node.get_parent()
	return []


## Анимация из модели, если есть; иначе горизонтальный удар поворотом узла хвата:
## Вперёд оно смотрит в середине дуги, ровно через hit_delay.
func _play_swing_animation() -> void:
	if animator and animator.has_animation(swing_animation):
		var length := animator.get_animation(swing_animation).length
		animator.play(swing_animation, -1.0, length / maxf(swing_interval, 0.01))
		return
	if not swing_pivot:
		return
	_reset_animation()
	var half := swing_degrees / 2.0
	var from := Vector3(0.0, deg_to_rad(90.0 - half), deg_to_rad(-90.0))
	var to := Vector3(0.0, deg_to_rad(90.0 + half), deg_to_rad(-90.0))
	_tween = create_tween()
	_tween.tween_property(swing_pivot, "rotation", from, hit_delay * 0.5)
	_tween.tween_property(swing_pivot, "rotation", to, hit_delay)
	_tween.tween_property(swing_pivot, "rotation", Vector3.ZERO, maxf(swing_interval - hit_delay * 1.5, 0.05))


## Прерванный удар не должен оставлять модель в середине замаха.
func _reset_animation() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	if swing_pivot:
		swing_pivot.rotation = Vector3.ZERO
	if animator and animator.is_playing():
		animator.seek(0.0, true)
		animator.stop()
