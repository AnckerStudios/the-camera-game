class_name DamageDoor
extends DamageableEnvironment
## Разрушаемая дверь — обычное окружение, видимое независимо от конуса игрока.
@export var victory_on_destroy: bool = false
@export_range(0.0, 400.0, 5.0) var target_lock_radius_pixels: float = 160.0
const VICTORY_SCENE = preload("res://ui/alive/alive.tscn")

func _ready() -> void:
	damage_receiver.target_lock_radius_pixels = target_lock_radius_pixels
	_prepare_model_and_collision()
	# FilterSubject подключается после подготовки материалов; ConeVisibility двери не нужен.
	super()

## Коллизия должна соответствовать текущей модели, а не прежней дверной раме.
func _prepare_model_and_collision() -> void:
	var model := get_node_or_null("Model") as Node3D
	if not model:
		return
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.push_front(model)
	var faces := PackedVector3Array()
	var inverse := global_transform.affine_inverse()
	for mesh in meshes:
		if not mesh.mesh:
			continue
		var local: Transform3D = inverse * mesh.global_transform
		for vertex in mesh.mesh.get_faces():
			faces.append(local * vertex)
		# Односторонние поверхности двери не должны пропадать при взгляде сзади.
		if mesh.material_override is StandardMaterial3D:
			var material := mesh.material_override.duplicate() as StandardMaterial3D
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.material_override = material
		else:
			for surface in mesh.mesh.get_surface_count():
				var original: Material = mesh.get_active_material(surface)
				if original is StandardMaterial3D:
					var material := original.duplicate() as StandardMaterial3D
					material.cull_mode = BaseMaterial3D.CULL_DISABLED
					mesh.set_surface_override_material(surface, material)
	if faces.is_empty():
		push_warning("Дверь не содержит геометрии для коллизии.")
		return
	var collider := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not collider:
		collider = CollisionShape3D.new()
		collider.name = &"CollisionShape3D"
		add_child(collider)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	collider.transform = Transform3D.IDENTITY
	collider.shape = shape

func _on_destroyed(_source: Node) -> void:
	if victory_on_destroy:
		_show_victory()
	queue_free()

func _show_victory() -> void:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene) or scene.has_node("VictoryScreen"):
		return
	var layer := CanvasLayer.new()
	layer.name = &"VictoryScreen"
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	scene.add_child(layer)
	layer.add_child(VICTORY_SCENE.instantiate())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
