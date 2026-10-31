class_name ExplosiveBarrel
extends StaticBody3D
## Бочка использует DamageReceiver через поле; уничтожение запускает один взрыв.
signal damaged(amount: float, source: Node)
signal destroyed(source: Node)
signal exploded(position: Vector3)

@export var aim_point: Node3D
var damage_receiver := DamageReceiver.new()
@export var hp: float = 100.0:
	get:
		return damage_receiver.health
	set(value):
		damage_receiver.health = maxf(value, 0.0)

@export_group("Взрыв")
@export_range(0.1, 30.0, 0.1) var explosion_radius: float = 5.0
@export_range(0.0, 500.0, 1.0) var explosion_damage: float = 300.0
@export var damage_falloff: bool = true
@export var walls_block_damage: bool = true
@export_flags_3d_physics var explosion_obstacle_mask: int = 1
@export_group("Звук")
@export var explosion_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var explosion_volume_db: float = -3.0
@export_group("Тряска")
@export_range(0.1, 50.0, 0.5) var shake_radius: float = 15.0
@export_range(0.0, 5.0, 0.1) var shake_strength: float = 2.0
@export_range(0.0, 1.0, 0.01) var shake_amplitude: float = 0.25
@export_range(0.01, 2.0, 0.01) var shake_duration: float = 0.4

@export_group("Обводка")
@export var outline_color: Color = Color(1.0, 0.08, 0.04, 1.0)
@export_range(0.001, 0.2, 0.001) var outline_width: float = 0.025

var _exploded: bool = false
static var _fallback_sound: AudioStreamWAV

@export var vision_profile: VisionProfile = preload("res://gamelogic/filters/active_profile.tres")

func _ready() -> void:
	vision_profile = vision_profile.duplicate()
	vision_profile.attach(self)
	damage_receiver.aim_point = aim_point
	damage_receiver.register_owner(self)
	add_to_group(&"damageable_environment")
	add_to_group(&"cutout_targets")
	damage_receiver.damaged.connect(_on_damage_received)
	damage_receiver.depleted.connect(_on_health_depleted)
	var outline := ObjectOutline.new()
	outline.name = &"ObjectOutline"
	outline.mesh_root = self
	outline.color = outline_color
	outline.width = outline_width
	add_child(outline)
	var subject := FilterSubject.new()
	subject.name = &"FilterSubject"
	add_child(subject)

func take_damage(amount: float, source: Node) -> void:
	if not _exploded:
		damage_receiver.take_damage(amount, source)

func _on_damage_received(amount: float, source: Node) -> void:
	damaged.emit(amount, source)

func _on_health_depleted(source: Node) -> void:
	destroyed.emit(source)
	# Цепные взрывы выполняются последовательно, не создавая рекурсию урона.
	explode.call_deferred()

## Можно вызвать извне. Повторные вызовы не создают второй взрыв.
func explode() -> void:
	if _exploded:
		return
	_exploded = true
	damage_receiver.enabled = false
	var center := damage_receiver.get_target_point()
	hide()
	_play_explosion_sound(center)
	_damage_in_radius(center)
	_shake_camera(center)
	exploded.emit(center)
	queue_free()

func _damage_in_radius(center: Vector3) -> void:
	for target in get_tree().get_nodes_in_group(DamageReceiver.TARGET_GROUP):
		if target == self or not is_instance_valid(target):
			continue
		var receiver := DamageReceiver.get_receiver(target)
		if not receiver or not receiver.can_receive_damage():
			continue
		var point := receiver.get_target_point()
		var amount := _damage_at_distance(center.distance_to(point))
		if amount > 0.0 and _has_clear_path(center, point, target):
			receiver.receive_hit(amount, self)
	# Пока здоровье игрока хранится в PlayerState, он имеет отдельный интерфейс урона.
	var player := _get_camera_target()
	if is_instance_valid(player) and not DamageReceiver.get_receiver(player) and player.has_method("take_damage"):
		var point := player.global_position + Vector3.UP * 1.0
		var amount := _damage_at_distance(center.distance_to(point))
		if amount > 0.0 and _has_clear_path(center, point, player):
			player.take_damage(amount, self)

func _damage_at_distance(distance: float) -> float:
	if distance > explosion_radius:
		return 0.0
	return explosion_damage * (1.0 - distance / explosion_radius) if damage_falloff else explosion_damage

func _has_clear_path(center: Vector3, point: Vector3, target: Node3D) -> bool:
	if not walls_block_damage:
		return true
	var query := PhysicsRayQueryParameters3D.create(center, point, explosion_obstacle_mask, [get_rid()])
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var body: Node = hit.collider
	return body == target or target.is_ancestor_of(body)

func _get_camera_target() -> Node3D:
	var camera := get_viewport().get_camera_3d()
	if camera and camera.get_parent().has_method("shake"):
		return camera.get_parent().get("target") as Node3D
	return null

func _shake_camera(center: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	var player := _get_camera_target()
	if not camera or not player:
		return
	var weight := clampf(1.0 - player.global_position.distance_to(center) / shake_radius, 0.0, 1.0)
	if weight > 0.0:
		camera.get_parent().shake(shake_strength * weight, shake_amplitude, shake_duration)

## Источник принадлежит уровню, поэтому звук продолжается после удаления бочки.
func _play_explosion_sound(center: Vector3) -> void:
	var sound := AudioStreamPlayer3D.new()
	if (explosion_sound != null):
		sound.stream = explosion_sound
		sound.bus = &"SFX"
		sound.volume_db = explosion_volume_db
		sound.unit_size = 8.0
		sound.max_distance = 60.0
		sound.top_level = true
		get_tree().current_scene.add_child(sound)
		sound.global_position = center
		sound.finished.connect(sound.queue_free)
		sound.play()
