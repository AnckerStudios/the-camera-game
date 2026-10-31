class_name FilterSubject
extends Node
## Общая заливка для обоих фильтров; размерность и цвета хранятся в профиле.
@export var vision_profile: VisionProfile = VisionProfile.new()
var _target: Node3D
var _meshes: Array[MeshInstance3D] = []
var _original_overlays: Array[Material] = []
var _fill: ShaderMaterial

func _ready() -> void:
	_target = get_parent() as Node3D
	if not _target:
		return
	var owner_profile := VisionProfile.from_target(_target)
	if owner_profile:
		vision_profile = owner_profile
	else:
		vision_profile.attach(_target)
	_fill = ShaderMaterial.new()
	_fill.shader = preload("res://gamelogic/filters/infrared_fill.gdshader")
	if _target is MeshInstance3D:
		_register_mesh(_target)
	for mesh in _target.find_children("*", "MeshInstance3D", true, false):
		_register_mesh(mesh)
	VisionFilters.filter_changed.connect(_on_filter_changed)
	_on_filter_changed(VisionFilters.mode)

func _register_mesh(mesh: MeshInstance3D) -> void:
	if mesh.name == &"Outline":
		return
	_meshes.append(mesh)
	_original_overlays.append(mesh.material_overlay)

func _on_filter_changed(mode: VisionProfile.Filter) -> void:
	var apply_fill := vision_profile.should_highlight(mode)
	_fill.set_shader_parameter("thermal_color", vision_profile.highlight_color(mode))
	for index in _meshes.size():
		if is_instance_valid(_meshes[index]):
			_meshes[index].material_overlay = _fill if apply_fill else _original_overlays[index]
	if not _target.has_meta(&"cone_visibility_managed"):
		_target.visible = vision_profile.is_visible(mode)
	elif not vision_profile.is_visible(mode):
		_target.hide()
