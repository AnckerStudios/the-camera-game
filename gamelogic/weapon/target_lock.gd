class_name WeaponTargetLock
extends Node
## Выбирает ближайшую к курсору доступную цель с DamageReceiver: монстра или окружение.
signal target_changed(target: Node3D)

@export var enabled: bool = true
@export_range(0.0, 300.0, 1.0) var capture_radius_pixels: float = 80.0
@export var require_view_cone: bool = true
@export_flags_3d_physics var obstruction_mask: int = 1

# Слабая ссылка не удерживает удалённого врага и возвращает null после его удаления.
var _target_ref: WeakRef
var current_target: Node3D:
	get:
		if not _target_ref:
			return null
		var candidate = _target_ref.get_ref()
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			return null
		return candidate as Node3D
	set(value):
		_target_ref = weakref(value) if is_instance_valid(value) else null

## Вызывается держателем каждый физический тик; выстрел использует готовый результат.
func acquire(origin: Vector3, max_distance: float, excluded: Array[RID], shooter: Node3D) -> Node3D:
	var selected: Node3D = null
	var camera := get_viewport().get_camera_3d()
	if enabled and camera:
		var mouse := get_viewport().get_mouse_position()
		var closest := capture_radius_pixels * capture_radius_pixels
		for enemy in get_tree().get_nodes_in_group(DamageReceiver.TARGET_GROUP):
			if not enemy is Node3D or enemy.is_queued_for_deletion() or not enemy.is_visible_in_tree():
				continue
			if DamageReceiver.find_target(enemy) != enemy or enemy == shooter or not VisionFilters.is_target_visible(enemy):
				continue
			var point := get_target_point(enemy)
			if camera.is_position_behind(point) or origin.distance_to(point) > max_distance:
				continue
			var screen := camera.unproject_position(point)
			if not get_viewport().get_visible_rect().has_point(screen):
				continue
			var distance_squared := mouse.distance_squared_to(screen)
			if distance_squared > closest or not _in_view(enemy, shooter):
				continue
			if not _has_clear_path(origin, point, enemy, excluded):
				continue
			closest = distance_squared
			selected = enemy
	var previous := current_target
	# Назначение обязательно и при selected == null: старую цель нельзя возвращать.
	current_target = selected
	if previous != selected:
		target_changed.emit(selected)
	# Обработчик сигнала также может удалить цель — повторно проверяем слабую ссылку.
	return current_target

func get_target_point(enemy: Node3D) -> Vector3:
	var receiver := DamageReceiver.get_receiver(enemy)
	return receiver.get_target_point() if receiver else enemy.global_position

func _in_view(enemy: Node3D, shooter: Node3D) -> bool:
	if not require_view_cone:
		return true
	for cone in get_tree().get_nodes_in_group(&"visibility_cones"):
		if shooter and not shooter.is_ancestor_of(cone):
			continue
		if cone.contains_world_point(enemy.global_position):
			return true
	return false

func _has_clear_path(origin: Vector3, point: Vector3, enemy: Node3D, excluded: Array[RID]) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin, point, obstruction_mask, excluded)
	query.collide_with_areas = false
	query.hit_from_inside = true
	var hit := enemy.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Node = hit.collider
	return DamageReceiver.find_target(collider) == enemy
