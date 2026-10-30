extends Node
## Открывает круг вокруг персонажа в непрозрачной статической геометрии уровня.
## Узлы группы camera_cutout_ignore и их потомки не изменяются.

@export var enabled: bool = true
## Ширина плавного перехода от отверстия к непрозрачной стене.
@export_range(0.0, 100.0, 1.0) var edge_softness_pixels: float = 16.0
@export_range(10.0, 300.0, 1.0) var radius_pixels: float = 0.0
## Максимальный радиус и расстояние за стеной для его достижения.
@export_range(10.0, 600.0, 1.0) var max_radius_pixels: float = 80.0
@export_range(0.01, 20.0, 0.1) var radius_max_distance: float = 3.0

## Скорость плавного изменения радиуса: меньше — медленнее.
@export_range(0.1, 30.0, 0.1) var radius_smoothing: float = 8.0

@export var focus_height: float = 1.0
@export_range(0.0, 1.0, 0.01) var depth_margin: float = 0.15

const CUTOUT_SHADER = preload("res://gamelogic/player/camera/wall_cutout.gdshader")
var _materials: Array[ShaderMaterial] = []
var _meshes: Array[MeshInstance3D] = []
const MAX_ENEMY_CUTOUTS := 8
var _enemy_states: Dictionary = {}

var _current_radii: Dictionary = {}
var _blocking_distances: Dictionary = {}
var _blocking_bodies: Array[RID] = []
@onready var _player: Node3D = get_parent()

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_scan_level")

func _scan_level() -> void:
	for node in get_tree().current_scene.find_children("*", "MeshInstance3D", true, false):
		_prepare_mesh(node)

func _on_node_added(node: Node) -> void:
	if node is MeshInstance3D:
		_prepare_mesh.call_deferred(node)

## Сохраняет основные настройки стандартных материалов; пользовательские шейдеры не заменяет.
func _prepare_mesh(node: MeshInstance3D) -> void:
	if not is_instance_valid(node) or not node.mesh or node.has_meta(&"wall_cutout_ready"):
		return
	var ancestor: Node = node
	var is_static := false
	while ancestor:
		if ancestor == _player or ancestor.is_in_group(&"camera_cutout_ignore") or ancestor.has_method("take_damage"):
			return
		if ancestor is StaticBody3D:
			is_static = true
		ancestor = ancestor.get_parent()
	if not is_static:
		return
	node.set_meta(&"wall_cutout_ready", true)
	var override_material := node.material_override
	for surface in node.mesh.get_surface_count():
		var original := node.get_active_material(surface)
		if original != null and not original is StandardMaterial3D:
			continue
		if original is StandardMaterial3D and original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var material := ShaderMaterial.new()
		material.shader = CUTOUT_SHADER
		material.set_shader_parameter("edge_softness_pixels", edge_softness_pixels)
		if original is StandardMaterial3D:
			material.set_shader_parameter("base_color", original.albedo_color)
			material.set_shader_parameter("base_roughness", original.roughness)
			material.set_shader_parameter("base_metallic", original.metallic)
			material.set_shader_parameter("texture_scale", original.uv1_scale)
			material.set_shader_parameter("texture_offset", original.uv1_offset)
			if original.albedo_texture:
				material.set_shader_parameter("has_texture", true)
				material.set_shader_parameter("base_texture", original.albedo_texture)
		if override_material:
			node.material_override = material
			_materials.append(material)
			_meshes.append(node)
			break
		node.set_surface_override_material(surface, material)
		_materials.append(material)
		_meshes.append(node)

func _process(delta: float) -> void:
	_update_enemy_materials(delta)
	var camera := get_viewport().get_camera_3d()
	if not camera:
		for material in _materials:
			material.set_shader_parameter("cutout_enabled", false)
		return
	var focus := _player.global_position + Vector3.UP * focus_height
	var size := get_viewport().get_visible_rect().size
	var screen_position := camera.unproject_position(focus)
	var depth := -(camera.global_transform.affine_inverse() * focus).z
	var visibility_flags: Array[bool] = []
	for mesh in _meshes:
		var occluding := false
		if enabled and not camera.is_position_behind(focus) and is_instance_valid(mesh):
			occluding = _is_occluding(mesh, camera, depth) and _has_blocking_body(mesh)
		visibility_flags.append(occluding)

	for index in _materials.size():
		var material := _materials[index]
		var desired_radius := _get_radius(_meshes[index]) if visibility_flags[index] else 0.0
		var previous_radius: float = _current_radii.get(material, 0.0)
		var current_radius := lerpf(previous_radius, desired_radius,
			1.0 - exp(-radius_smoothing * delta))
		if desired_radius == 0.0 and current_radius < 0.1:
			current_radius = 0.0
		_current_radii[material] = current_radius
		material.set_shader_parameter("cutout_enabled", enabled and current_radius > 0.0)
		material.set_shader_parameter("edge_softness_pixels", edge_softness_pixels)
		material.set_shader_parameter("target_uv", screen_position / size)
		material.set_shader_parameter("viewport_size", size)
		material.set_shader_parameter("radius_pixels", current_radius)


## Нелинейный рост по расстоянию: плавный старт и замедление у максимума.
func _get_radius(mesh: MeshInstance3D) -> float:
	var distance_behind := 0.0
	var node: Node = mesh
	while is_instance_valid(node):
		if node is CollisionObject3D and _blocking_distances.has(node.get_rid()):
			distance_behind = _blocking_distances[node.get_rid()]
			break
		node = node.get_parent()
	var progress := smoothstep(0.0, maxf(radius_max_distance, 0.01), distance_behind)
	return lerpf(radius_pixels, maxf(radius_pixels, max_radius_pixels), progress)

## Решение принимается для всего меша, чтобы задние поверхности не закрывали отверстие.
func _is_occluding(mesh: MeshInstance3D, camera: Camera3D, focus_depth: float) -> bool:
	var bounds := mesh.get_aabb()
	var nearest_depth := INF
	var highest_y := -INF
	var view := camera.global_transform.affine_inverse()
	for corner in 8:
		var world_corner := mesh.global_transform * bounds.get_endpoint(corner)
		nearest_depth = minf(nearest_depth, -(view * world_corner).z)
		highest_y = maxf(highest_y, world_corner.y)
	# Основной пол не является препятствием, закрывающим тело персонажа.
	return nearest_depth < focus_depth - depth_margin and highest_y > _player.global_position.y + 0.2


## Луч строится через экранную точку персонажа — это важно для ортографической камеры.
func _physics_process(_delta: float) -> void:
	_update_enemy_rays()
	_blocking_bodies.clear()
	_blocking_distances.clear()
	var camera := get_viewport().get_camera_3d()
	if not enabled or not camera:
		return
	var focus := _player.global_position + Vector3.UP * focus_height
	if camera.is_position_behind(focus):
		return
	var screen_position := camera.unproject_position(focus)
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var endpoint := focus - direction * depth_margin
	if (endpoint - origin).dot(direction) <= 0.0:
		return
	var excluded: Array[RID] = []
	if _player is CollisionObject3D:
		excluded.append(_player.get_rid())
	var space := _player.get_world_3d().direct_space_state
	# Проверяем все перекрывающие стены, включая стоящие друг за другом.
	for iteration in 32:
		var query := PhysicsRayQueryParameters3D.create(origin, endpoint, 0xFFFFFFFF, excluded)
		query.hit_from_inside = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		var body: RID = hit.rid
		excluded.append(body)
		_blocking_bodies.append(body)
		# Глубина персонажа за точкой пересечения стены вдоль луча камеры.
		var hit_position: Vector3 = hit.position
		_blocking_distances[body] = maxf((focus - hit_position).dot(direction), 0.0)


## Вырезаем только меши тел, реально пересекающих линию взгляда к персонажу.
func _has_blocking_body(mesh: MeshInstance3D) -> bool:
	var node: Node = mesh
	while node:
		if node is CollisionObject3D and _blocking_bodies.has(node.get_rid()):
			return true
		node = node.get_parent()
	return false


## Собирает только врагов, доступных взгляду; цели вне конуса плавно закрываются.
func _update_enemy_rays() -> void:
	for state in _enemy_states.values():
		state.bodies = {}
	var camera := get_viewport().get_camera_3d()
	if not enabled or not camera:
		return
	var cones := get_tree().get_nodes_in_group(&"visibility_cones")
	var enemies := get_tree().get_nodes_in_group(&"monster")
	for enemy in enemies:
		if not enemy is Node3D or not enemy.is_visible_in_tree():
			continue
		var in_cone := false
		for cone in cones:
			if cone.contains_world_point(enemy.global_position):
				in_cone = true
				break
		if not in_cone:
			continue
		var id: int = enemy.get_instance_id()
		if not _enemy_states.has(id):
			if _enemy_states.size() >= MAX_ENEMY_CUTOUTS:
				continue
			_enemy_states[id] = {"focus": Vector3.ZERO, "bodies": {}, "radii": {}}
		var state: Dictionary = _enemy_states[id]
		state.focus = enemy.global_position + Vector3.UP * focus_height
		if camera.is_position_behind(state.focus):
			continue
		var origin := camera.project_ray_origin(camera.unproject_position(state.focus))
		var direction := camera.project_ray_normal(camera.unproject_position(state.focus))
		var endpoint: Vector3 = state.focus - direction * depth_margin
		if (endpoint - origin).dot(direction) <= 0.0:
			continue
		var excluded: Array[RID] = []
		if _player is CollisionObject3D:
			excluded.append(_player.get_rid())
		if enemy is CollisionObject3D:
			excluded.append(enemy.get_rid())
		var space := _player.get_world_3d().direct_space_state
		for attempt in 32:
			var query := PhysicsRayQueryParameters3D.create(origin, endpoint, 0xFFFFFFFF, excluded)
			query.hit_from_inside = true
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				break
			excluded.append(hit.rid)
			var body: Node = hit.collider
			if not body is StaticBody3D or body.has_method("take_damage"):
				continue
			var hit_position: Vector3 = hit.position
			state.bodies[hit.rid] = maxf((state.focus - hit_position).dot(direction), 0.0)


## На каждом материале хранится до восьми отверстий; их края объединяются в шейдере.
func _update_enemy_materials(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		for material in _materials:
			material.set_shader_parameter("enemy_cutout_count", 0)
		return
	var size := get_viewport().get_visible_rect().size
	var keys := _enemy_states.keys()
	for index in _materials.size():
		var material := _materials[index]
		var mesh := _meshes[index]
		var circles := PackedVector4Array()
		circles.resize(MAX_ENEMY_CUTOUTS)
		for slot in keys.size():
			var state: Dictionary = _enemy_states[keys[slot]]
			var focus: Vector3 = state.focus
			var desired := 0.0
			if enabled and is_instance_valid(mesh) and not camera.is_position_behind(focus):
				var ancestor: Node = mesh
				while ancestor:
					if ancestor is CollisionObject3D and state.bodies.has(ancestor.get_rid()):
						var distance_behind: float = state.bodies[ancestor.get_rid()]
						var progress := smoothstep(0.0, maxf(radius_max_distance, 0.01), distance_behind)
						desired = lerpf(radius_pixels, maxf(radius_pixels, max_radius_pixels), progress)
						break
					ancestor = ancestor.get_parent()
			var previous: float = state.radii.get(material, 0.0)
			var radius := lerpf(previous, desired, 1.0 - exp(-radius_smoothing * delta))
			if desired == 0.0 and radius < 0.1:
				radius = 0.0
			state.radii[material] = radius
			var uv := camera.unproject_position(focus) / size
			circles[slot] = Vector4(uv.x, uv.y, radius, 0.0)
		material.set_shader_parameter("enemy_cutouts", circles)
		material.set_shader_parameter("enemy_cutout_count", keys.size())
	# Освобождаем слоты исчезнувших из взгляда и уничтоженных врагов после затухания.
	for id in keys:
		var state: Dictionary = _enemy_states[id]
		if not state.bodies.is_empty():
			continue
		var fading := false
		for radius in state.radii.values():
			if radius > 0.0:
				fading = true
				break
		if not fading:
			_enemy_states.erase(id)
