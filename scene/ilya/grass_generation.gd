extends MultiMeshInstance3D
## Трава из чанков: камера отсекает каждый чанк отдельно, поэтому рисуется только видимая часть поля.
## Узел служит шаблоном: берёт меш из своего MultiMesh и материал из material_override.

@export var ground_mesh_path: NodePath = ^"../NavigationRegion3D/Ground/Mesh"
@export var grass_count := 100000
## Доля травы в браузере: WebGL заметно медленнее на большом числе вершин.
@export_range(0.05, 1.0, 0.05) var web_density := 0.5
## Сторона чанка в метрах. Меньше - точнее отсечение, но больше вызовов отрисовки.
@export_range(1.0, 30.0, 0.5) var chunk_size := 5.0
@export var random_seed := 42

## Число float на экземпляр в буфере MultiMesh для TRANSFORM_3D.
const FLOATS_PER_INSTANCE := 12


func _ready() -> void:
	var ground := get_node(ground_mesh_path) as MeshInstance3D
	var area := ground.mesh.get_aabb().size
	var count := grass_count
	if OS.has_feature("web"):
		count = int(count * web_density)
	var columns := maxi(1, ceili(area.x / chunk_size))
	var rows := maxi(1, ceili(area.z / chunk_size))
	var chunk_extent := Vector2(area.x / columns, area.z / rows)
	var per_chunk := count / (columns * rows)
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	for column in columns:
		for row in rows:
			var center := Vector3(
				-area.x / 2.0 + (column + 0.5) * chunk_extent.x,
				0.0,
				-area.z / 2.0 + (row + 0.5) * chunk_extent.y)
			add_child(_create_chunk(center, chunk_extent, per_chunk, rng))
	# Сам шаблон ничего не рисует.
	multimesh.instance_count = 0


func _create_chunk(center: Vector3, extent: Vector2, count: int, rng: RandomNumberGenerator) -> MultiMeshInstance3D:
	# Буфер заполняется целиком: это намного быстрее, чем set_instance_transform на каждый куст.
	var buffer := PackedFloat32Array()
	buffer.resize(count * FLOATS_PER_INSTANCE)
	for i in count:
		var x := rng.randf_range(-extent.x / 2.0, extent.x / 2.0)
		var z := rng.randf_range(-extent.y / 2.0, extent.y / 2.0)
		var angle := rng.randf_range(0.0, TAU)
		var scale_factor := rng.randf_range(0.8, 1.2)
		var c := cos(angle) * scale_factor
		var s := sin(angle) * scale_factor
		var offset := i * FLOATS_PER_INSTANCE
		# Строки матрицы поворота вокруг Y с масштабом и смещением.
		buffer[offset] = c
		buffer[offset + 1] = 0.0
		buffer[offset + 2] = s
		buffer[offset + 3] = x
		buffer[offset + 4] = 0.0
		buffer[offset + 5] = scale_factor
		buffer[offset + 6] = 0.0
		buffer[offset + 7] = 0.0
		buffer[offset + 8] = -s
		buffer[offset + 9] = 0.0
		buffer[offset + 10] = c
		buffer[offset + 11] = z

	var chunk_multimesh := MultiMesh.new()
	chunk_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	chunk_multimesh.mesh = multimesh.mesh
	chunk_multimesh.instance_count = count
	chunk_multimesh.buffer = buffer

	var chunk := MultiMeshInstance3D.new()
	chunk.name = &"GrassChunk"
	chunk.multimesh = chunk_multimesh
	chunk.material_override = material_override
	# Трава не попадает в карты теней солнца и фонаря.
	chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk.position = center
	return chunk
