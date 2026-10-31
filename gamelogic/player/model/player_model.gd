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
## Скорость смены позы рук при смене оружия.
@export var pose_blend_speed := 10.0

const ROLL_ANIMATION := &"move/roll"
const AXE_ATTACK_ANIMATION := &"move/axe_attack"
const RELOAD_ANIMATION := &"move/reload"

var _blend := Vector2.ZERO
var _roll_remaining := 0.0
var _roll_yaw := 0.0
## Поза рук: одноручный огнестрел - пистолетная, ближний бой - с топором;
## двуручное оружие и пустые руки остаются в позе ходьбы с оружием.
var _pistol_pose := 0.0
var _axe_pose := 0.0
var _weapon: Weapon

@onready var _tree: AnimationTree = $AnimationTree
@onready var _holder: WeaponHolder = find_child("WeaponHolder", true, false) as WeaponHolder


func _ready() -> void:
	if body and body.has_signal(&"dashed"):
		body.dashed.connect(_on_body_dashed)
	if _holder:
		_holder.weapon_changed.connect(_on_weapon_changed)
		_on_weapon_changed(_holder.current)


func _physics_process(delta: float) -> void:
	if not body:
		return
	_update_facing(delta)

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
	_update_weapon_pose(delta)


## Поза рук плавно следует за оружием в руке, чтобы оно не прыгало при переключении.
func _update_weapon_pose(delta: float) -> void:
	var weapon: Weapon = _weapon if is_instance_valid(_weapon) else null
	var weight := 1.0 - exp(-pose_blend_speed * delta)
	_pistol_pose = lerpf(_pistol_pose, 1.0 if weapon is Firearm and weapon.one_handed else 0.0, weight)
	_axe_pose = lerpf(_axe_pose, 1.0 if weapon is MeleeWeapon else 0.0, weight)
	_tree.set(&"parameters/PistolFactor/blend_amount", _pistol_pose)
	_tree.set(&"parameters/AxeFactor/blend_amount", _axe_pose)


## Подписка на атаки текущего оружия; прежнее отключается, его разовые анимации гасятся.
func _on_weapon_changed(weapon: Weapon) -> void:
	if is_instance_valid(_weapon):
		if _weapon is Firearm:
			var previous_firearm := _weapon as Firearm
			previous_firearm.reload_started.disconnect(_on_reload_started)
			previous_firearm.fired.disconnect(_on_fired)
		elif _weapon is MeleeWeapon:
			(_weapon as MeleeWeapon).swung.disconnect(_on_swung)
	_fade_out(&"ReloadFactor")
	_fade_out(&"AxeAttack")
	_weapon = weapon if is_instance_valid(weapon) else null
	if _weapon is Firearm:
		var firearm := _weapon as Firearm
		firearm.reload_started.connect(_on_reload_started)
		firearm.fired.connect(_on_fired)
	elif _weapon is MeleeWeapon:
		(_weapon as MeleeWeapon).swung.connect(_on_swung)


## Замах тела растягивается на паузу между ударами, как и анимация самого оружия.
func _on_swung() -> void:
	var swing := _tree.get_animation(AXE_ATTACK_ANIMATION)
	var melee := _weapon as MeleeWeapon
	_tree.set(&"parameters/AxeAttackSpeed/scale", swing.length / maxf(melee.swing_interval, 0.01))
	_tree.set(&"parameters/AxeAttack/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Перезарядка по одному патрону длится, пока не заполнится магазин или не кончится запас.
func _on_reload_started() -> void:
	var firearm := _weapon as Firearm
	var duration := firearm.reload_time
	if firearm.reload_per_round:
		duration *= maxi(mini(firearm.capacity - firearm.loaded, firearm.reserve_ammo), 1)
	var reload := _tree.get_animation(RELOAD_ANIMATION)
	_tree.set(&"parameters/ReloadSpeed/scale", reload.length / maxf(duration, 0.01))
	_tree.set(&"parameters/ReloadFactor/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Выстрел прерывает поштучную перезарядку - руки возвращаются в позу прицеливания.
func _on_fired(_rounds: int) -> void:
	_fade_out(&"ReloadFactor")


func _fade_out(one_shot: StringName) -> void:
	if _tree.get(&"parameters/%s/active" % one_shot):
		_tree.set(&"parameters/%s/request" % one_shot, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


## Кувырок растягивается на длительность рывка.
func _on_body_dashed(direction: Vector3, duration: float) -> void:
	var roll := _tree.get_animation(ROLL_ANIMATION)
	_tree.set(&"parameters/RollSpeed/scale", roll.length / maxf(duration, 0.01))
	_tree.set(&"parameters/Roll/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_roll_remaining = duration
	_roll_yaw = atan2(-direction.x, -direction.z)


## Во время кувырка модель смотрит туда, куда катится, а не на курсор;
## родитель (взгляд) продолжает поворачиваться, поэтому направление держится в мировых осях.
func _update_facing(delta: float) -> void:
	if _roll_remaining > 0.5:
		_roll_remaining -= delta
		global_rotation.y = _roll_yaw
	else:
		rotation.y = lerp_angle(rotation.y, 0.0, 1.0 - exp(-face_back_speed * delta))
