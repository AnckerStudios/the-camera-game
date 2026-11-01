extends MultiMeshInstance3D
## Трава из чанков: камера отсекает каждый чанк отдельно, поэтому рисуется только видимая часть поля.
## Узел служит шаблоном: берёт меш из своего MultiMesh и материал из material_override.

@export var ground_mesh_path: NodePath = ^"../NavigationRegion3D/Ground/Mesh"
@export var grass_count := 100000
## Доля травы в браузере: WebGL заметно медленнее на большом числе вершин.
@export_range(0.05, 1.0, 0.05) var web_density := 0.5
## Сторона чанка в метрах. Меньше - точнее отсечение, но больше вызовов отрисовки.
@export_range(1.0, 30.0, 0.5) var chunk_size := 3.0
@export var random_seed := 42


func _ready() -> void:
	var ground := get_node_or_null(ground_mesh_path) as MeshInstance3D
	if not ground or not ground.mesh or not multimesh or not multimesh.mesh:
		push_warning("Grass needs a ground mesh and a MultiMesh template mesh.")
		return
	var bounds := ground.mesh.get_aabb()
	var area := bounds.size
	var ground_to_grass := global_transform.affine_inverse() * ground.global_transform
	var count := maxi(grass_count, 0)
	if OS.has_feature("web"):
		count = int(count * web_density)
	var columns := maxi(1, ceili(area.x / chunk_size))
	var rows := maxi(1, ceili(area.z / chunk_size))
	var chunk_extent := Vector2(area.x / columns, area.z / rows)
	var per_chunk := count / (columns * rows)
	var remainder := count % (columns * rows)
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	for column in columns:
		for row in rows:
			var center := Vector3(
				bounds.position.x + (column + 0.5) * chunk_extent.x,
				bounds.end.y + 0.01,
				bounds.position.z + (row + 0.5) * chunk_extent.y)
			var index := column * rows + row
			var amount := per_chunk + (1 if index < remainder else 0)
			if amount == 0:
				continue
			var chunk := _create_chunk(center, chunk_extent, amount, rng)
			chunk.transform = ground_to_grass * chunk.transform
			add_child(chunk)
	# Сам шаблон ничего не рисует.
	multimesh = multimesh.duplicate() as MultiMesh
	multimesh.instance_count = 0


func _create_chunk(center: Vector3, extent: Vector2, count: int, rng: RandomNumberGenerator) -> MultiMeshInstance3D:
	var chunk_multimesh := MultiMesh.new()
	chunk_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	chunk_multimesh.mesh = multimesh.mesh
	chunk_multimesh.instance_count = count
	# Один вызов движка на куст быстрее, чем 12 записей в PackedFloat32Array из GDScript.
	for i in count:
		var x := rng.randf_range(-extent.x / 2.0, extent.x / 2.0)
		var z := rng.randf_range(-extent.y / 2.0, extent.y / 2.0)
		var angle := rng.randf_range(0.0, TAU)
		var scale_factor := rng.randf_range(0.8, 1.2)
		var basis := Basis(Vector3.UP, angle).scaled(Vector3.ONE * scale_factor)
		chunk_multimesh.set_instance_transform(i, Transform3D(basis, Vector3(x, 0.0, z)))

	var chunk := MultiMeshInstance3D.new()
	chunk.name = &"GrassChunk"
	chunk.multimesh = chunk_multimesh
	chunk.material_override = material_override
	# Трава не попадает в карты теней солнца и фонаря.
	chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk.position = center
	return chunk
