class_name ConeVisibility
extends Node

## Плавно проявляет и скрывает родителя в зависимости от того, видит ли его конус игрока.
## Скрытие только визуальное: коллизия и получение урона не отключаются.

## Время проявления и исчезновения, сек.
@export var fade_in_time := 0.10
@export var fade_out_time := 1.0

var _target: Node3D
var _meshes: Array[GeometryInstance3D] = []
var _alpha := 1.0


func _ready() -> void:
	_target = get_parent()
	_target.set_meta(&"cone_visibility_managed", true)
	if not _target.has_node("FilterSubject"):
		var subject := FilterSubject.new()
		subject.name = &"FilterSubject"
		_target.add_child.call_deferred(subject)
	for node in _target.find_children("*", "GeometryInstance3D", true, false):
		_meshes.append(node)
	_alpha = 1.0 if _is_seen() else 0.0
	_apply()


func _process(delta: float) -> void:
	if not VisionFilters.is_target_visible(_target):
		_alpha = 0.0
		_apply()
		return
	var goal := 1.0 if _is_seen() else 0.0
	var time := fade_in_time if goal > _alpha else fade_out_time
	_alpha = move_toward(_alpha, goal, delta / time) if time > 0.0 else goal
	_apply()


func _is_seen() -> bool:
	if not VisionFilters.is_target_visible(_target):
		return false
	var cones := get_tree().get_nodes_in_group(&"visibility_cones")
	# Сцены без конуса сохраняют обычное отображение.
	if cones.is_empty():
		return true
	for cone in cones:
		if cone.contains_world_point(_target.global_position):
			return true
	return false


func _apply() -> void:
	_target.visible = _alpha > 0.0
	for mesh in _meshes:
		mesh.transparency = 1.0 - _alpha
