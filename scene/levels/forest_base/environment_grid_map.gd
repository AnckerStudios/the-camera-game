@tool
extends GridMap
## Создаёт палитру из исходных моделей один раз. Покадровой работы нет.
const SOURCES: Array[PackedScene] = [
	preload("res://resources/model/world/pines/pine_with_tex.glb"),
	preload("res://resources/model/world/pines/pine_with_tex_2.glb"),
	preload("res://resources/model/modules/fence/fence_1.glb"),
	preload("res://resources/model/modules/fence/fence_2.glb"),
	preload("res://resources/model/modules/fence/fence_3.glb"),
]
const ITEM_NAMES: Array[String] = ["Сосна 1", "Сосна 2", "Забор 1", "Забор 2", "Забор 3"]
@export_range(1.0, 15.0, 0.5) var tree_height: float = 5.0
@export var rebuild_library: bool = false:
	set(value):
		if value:
			_build_library.call_deferred()

func _enter_tree() -> void:
	if not mesh_library or mesh_library.get_item_list().is_empty():
		_build_library.call_deferred()

func _build_library() -> void:
	if not is_inside_tree():
		return
	var library := MeshLibrary.new()
	library.resource_name = "Лес: сосны и заборы"
	for index in SOURCES.size():
		var source := SOURCES[index].instantiate()
		var combined := ArrayMesh.new()
		_append_meshes(source, Transform3D.IDENTITY, combined)
		source.free()
		if combined.get_surface_count() == 0:
			push_warning("Модель для GridMap не содержит мешей: %s" % ITEM_NAMES[index])
			continue
		var bounds := combined.get_aabb()
		var is_tree := index < 2
		var span := bounds.size.y if is_tree else maxf(bounds.size.x, bounds.size.z)
		var factor := (tree_height if is_tree else cell_size.x) / maxf(span, 0.001)
		# Основание на уровне клетки, модель по центру X/Z независимо от исходного pivot.
		var offset := Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z) * factor
		var placement := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * factor), offset)
		library.create_item(index)
		library.set_item_name(index, ITEM_NAMES[index])
		library.set_item_mesh(index, combined)
		library.set_item_mesh_transform(index, placement)
		var height := bounds.size.y * factor
		var shape: Shape3D
		if is_tree:
			var trunk := CylinderShape3D.new()
			trunk.radius = 0.25
			trunk.height = minf(height, 2.5)
			height = trunk.height
			shape = trunk
		else:
			var fence := BoxShape3D.new()
			fence.size = Vector3(maxf(bounds.size.x * factor, 0.12), maxf(height, 0.1), maxf(bounds.size.z * factor, 0.12))
			shape = fence
		library.set_item_shapes(index, [shape, Transform3D(Basis.IDENTITY, Vector3(0.0, height * 0.5, 0.0))])
	mesh_library = library

## Объединяем поверхности, сохраняя материалы и локальные трансформации моделей.
func _append_meshes(node: Node, parent_transform: Transform3D, result: ArrayMesh) -> void:
	var local := parent_transform
	if node is Node3D:
		local = parent_transform * node.transform
	if node is MeshInstance3D and node.mesh:
		for surface in node.mesh.get_surface_count():
			var tool := SurfaceTool.new()
			tool.begin(node.mesh.surface_get_primitive_type(surface))
			tool.append_from(node.mesh, surface, local)
			tool.set_material(node.get_active_material(surface))
			tool.commit(result)
	for child in node.get_children():
		_append_meshes(child, local, result)
