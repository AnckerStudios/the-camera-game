class_name ObjectOutline
extends Node
## Переиспользуемая обводка предметов и окружения, не меняющая материалы модели.
@export var mesh_root: Node3D
@export var color: Color = Color(0.797, 0.796, 0.993, 1.0)
@export var selected_color: Color = Color(1.0, 0.8, 0.15, 1.0)
@export_range(0.001, 0.2, 0.001) var width: float = 0.025
const OUTLINE_SHADER = preload("res://gamelogic/environment/outline/object_outline.gdshader")
var _material: ShaderMaterial
var _selected: bool = false
var _shells: Array[MeshInstance3D] = []

func _ready() -> void:
	if not mesh_root:
		mesh_root = get_parent() as Node3D
	if not mesh_root:
		return
	_material = ShaderMaterial.new()
	_material.shader = OUTLINE_SHADER
	_update_material()
	# Список собирается до добавления оболочек, чтобы не обводить саму обводку.
	var meshes := mesh_root.find_children("*", "MeshInstance3D", true, false)
	if mesh_root is MeshInstance3D:
		meshes.push_front(mesh_root)
	for source in meshes:
		if not source.mesh or source.name == &"Outline":
			continue
		var shell := MeshInstance3D.new()
		shell.name = &"Outline"
		shell.mesh = source.mesh
		shell.material_override = _material
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		source.add_child(shell)
		_shells.append(shell)

func set_selected(value: bool) -> void:
	_selected = value
	_update_material()

func _update_material() -> void:
	if _material:
		_material.set_shader_parameter("outline_color", selected_color if _selected else color)
		_material.set_shader_parameter("outline_width", width)

func _exit_tree() -> void:
	for shell in _shells:
		if is_instance_valid(shell) and not shell.is_queued_for_deletion():
			shell.queue_free()
