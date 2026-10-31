extends MultiMeshInstance3D

@onready var ground_mesh : MeshInstance3D = $"../NavigationRegion3D/Ground/Mesh"

var grass_count := 100000

func _ready() -> void:
	multimesh.instance_count = grass_count
	var rng = RandomNumberGenerator.new()
	rng.seed = 42

	for i in range(grass_count):
		# Генерируем случайные координаты X и Z в пределах платформы 30x30
		var aabb = ground_mesh.mesh.get_aabb()
		var x = rng.randf_range(-aabb.size.x / 2, aabb.size.x / 2)
		var z = rng.randf_range(-aabb.size.z / 2, aabb.size.z / 2)
		
		# Если у вас плоская платформа, Y всегда 0. 
		# Если ландшафт неровный, здесь нужно будет определять высоту (например, через RayCast)
		var y = 0.0
		
		# Создаем позицию куста
		var pos = Vector3(x, y, z)
		
		# Создаем случайный поворот вокруг вертикальной оси Y (в радианах)
		var rotation_y = rng.randf_range(0, PI * 2)
		
		# Случайный масштаб, чтобы трава выглядела естественнее (от 80% до 120% от базового размера)
		var scale_factor = rng.randf_range(0.8, 1.2)
		var scale = Vector3(scale_factor, scale_factor, scale_factor)
		
		# Собираем матрицу трансформации куста
		var basis = Basis().rotated(Vector3.UP, rotation_y).scaled(scale)
		var xform = Transform3D(basis, pos)
		
		# Записываем матрицу напрямую в буфер MultiMesh под индексом i
		multimesh.set_instance_transform(i, xform)
