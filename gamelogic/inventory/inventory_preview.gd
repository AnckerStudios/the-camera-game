class_name InventoryPreview
extends RefCounted
## Копирует только геометрию, не запуская оружие, коллизии и скрипты моделей.
static func build(entry: InventoryEntry) -> Node3D:
	var root := Node3D.new()
	var source: Node3D
	var temporary: Node
	if is_instance_valid(entry.weapon):
		source = entry.weapon.get_node_or_null("Model") as Node3D
		if not source:
			source = entry.weapon
	elif entry.item.model_scene:
		temporary = entry.item.model_scene.instantiate()
		source = temporary as Node3D
	elif entry.item.weapon_scene:
		temporary = entry.item.weapon_scene.instantiate()
		source = temporary as Node3D
	if source:
		_copy(source, Transform3D.IDENTITY, root)
	if temporary:
		temporary.free()
	if root.get_child_count() == 0:
		_placeholder(entry.item.kind, root)
	var bounds := AABB()
	var found := false
	for mesh in root.get_children():
		var box: AABB = mesh.transform * mesh.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var factor := 1.7 / maxf(longest, 0.01)
	for mesh in root.get_children():
		mesh.position -= bounds.get_center()
	root.scale = Vector3.ONE * factor
	root.set_meta(&"floor_offset", bounds.size.y * factor * 0.5 + 0.03)
	return root

static func _copy(node: Node3D, parent_transform: Transform3D, root: Node3D) -> void:
	if node.name == &"Outline":
		return
	var local := parent_transform * node.transform
	if node is MeshInstance3D and node.mesh:
		var mesh := MeshInstance3D.new()
		mesh.mesh = node.mesh
		mesh.transform = local
		mesh.material_override = node.material_override
		for surface in node.mesh.get_surface_count():
			mesh.set_surface_override_material(surface, node.get_surface_override_material(surface))
		root.add_child(mesh)
	for child in node.get_children():
		if child is Node3D:
			_copy(child, local, root)

static func _part(root: Node3D, shape: Mesh, position: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.position = position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.45
	mesh.material_override = material
	root.add_child(mesh)

static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

static func _placeholder(kind: InventoryItem.Kind, root: Node3D) -> void:
	match kind:
		InventoryItem.Kind.WEAPON:
			_part(root, _box(Vector3(1.4, 0.2, 0.2)), Vector3.ZERO, Color(0.3, 0.34, 0.4))
			_part(root, _box(Vector3(0.2, 0.5, 0.2)), Vector3(0.35, -0.25, 0), Color(0.25, 0.12, 0.06))
		InventoryItem.Kind.AMMO:
			for index in 3:
				var bullet := CylinderMesh.new()
				bullet.top_radius = 0.08
				bullet.bottom_radius = 0.13
				bullet.height = 0.7
				_part(root, bullet, Vector3((index - 1) * 0.34, 0, 0), Color(0.85, 0.62, 0.2))
		InventoryItem.Kind.MEDICINE:
			_part(root, _box(Vector3(0.8, 0.7, 0.3)), Vector3.ZERO, Color(0.7, 0.06, 0.08))
			_part(root, _box(Vector3(0.12, 0.4, 0.04)), Vector3(0, 0, 0.17), Color.WHITE)
			_part(root, _box(Vector3(0.4, 0.12, 0.04)), Vector3(0, 0, 0.17), Color.WHITE)
		InventoryItem.Kind.FILTER:
			var filter := CylinderMesh.new()
			filter.top_radius = 0.5
			filter.bottom_radius = 0.5
			filter.height = 0.25
			_part(root, filter, Vector3.ZERO, Color(0.1, 0.65, 0.8))
