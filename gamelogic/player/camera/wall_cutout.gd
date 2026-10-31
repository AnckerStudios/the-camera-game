extends Node
## Открывает круг вокруг персонажа в непрозрачной статической геометрии уровня.
## Узлы группы camera_cutout_ignore и их потомки не изменяются.

@export var enabled: bool = true
## Степень дизеринга: больше 1 — прозрачная область шире, меньше 1 — стена плотнее.
@export_range(0.01, 8.0, 0.01) var interior_visibility: float = 4.0
@export_range(10.0, 300.0, 1.0) var radius_pixels: float = 0.0
## Максимальный радиус и расстояние за стеной для его достижения.
@export_range(10.0, 600.0, 1.0) var max_radius_pixels: float = 200.0
@export_range(0.01, 20.0, 0.1) var radius_max_distance: float = 3.0

## Скорость плавного изменения радиуса: меньше — медленнее.
@export_range(0.1, 30.0, 0.1) var radius_smoothing: float = 8.0

@export var focus_height: float = 1.0
@export_range(0.0, 1.0, 0.01) var depth_margin: float = 0.15

const CUTOUT_SHADER = preload("res://gamelogic/player/camera/wall_cutout.gdshader")
@export_range(0.0, 0.2, 0.01) var ray_update_interval: float = 0.05
var _ray_remaining := 0.0
var _mesh_bodies: Dictionary = {}
var _shader_values: Dictionary = {}
var _body_materials: Dictionary = {}
var _material_meshes: Dictionary = {}
var _material_bindings: Dictionary = {}
var _attached_materials: Dictionary = {}
var _enemy_active_materials: Dictionary = {}
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
	var bodies: Array[RID] = []
	ancestor = node
	while ancestor:
		if ancestor is CollisionObject3D:
			bodies.append(ancestor.get_rid())
		ancestor = ancestor.get_parent()
	_mesh_bodies[node] = bodies
	node.tree_exiting.connect(_forget_mesh.bind(node), CONNECT_ONE_SHOT)
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
		_set_material_parameter(material, "interior_visibility", interior_visibility)
		if original is StandardMaterial3D:
			_set_material_parameter(material, "base_color", original.albedo_color)
			_set_material_parameter(material, "base_roughness", original.roughness)
			_set_material_parameter(material, "base_metallic", original.metallic)
			_set_material_parameter(material, "texture_scale", original.uv1_scale)
			_set_material_parameter(material, "texture_offset", original.uv1_offset)
			if original.albedo_texture:
				_set_material_parameter(material, "has_texture", true)
				_set_material_parameter(material, "base_texture", original.albedo_texture)
		if override_material:
			_register_material(node, material, -1, override_material)
			break
		_register_material(node, material, surface, node.get_surface_override_material(surface))

func _register_material(mesh: MeshInstance3D, material: ShaderMaterial, surface: int, original: Material) -> void:
	_materials.append(material)
	_meshes.append(mesh)
	_material_meshes[material] = mesh
	_material_bindings[material] = {"surface": surface, "original": original}
	for body in _mesh_bodies[mesh]:
		var materials: Array = _body_materials.get_or_add(body, [])
		materials.append(material)

## Обрабатываем только пересечённые стены и те, где круг ещё плавно закрывается.
func _process(delta: float) -> void:
	_update_enemy_materials(delta)
	var camera := get_viewport().get_camera_3d()
	if not camera:
		for material in _current_radii:
			_set_material_parameter(material, &"cutout_enabled", false)
		_current_radii.clear()
		return
	var candidates: Dictionary = {}
	for material in _current_radii:
		candidates[material] = true
	if enabled:
		for body in _blocking_distances:
			for material in _body_materials.get(body, []):
				candidates[material] = true
	if candidates.is_empty():
		return
	var focus := _player.global_position + Vector3.UP * focus_height
	var size := get_viewport().get_visible_rect().size
	var uv := camera.unproject_position(focus) / size
	var depth := -(camera.global_transform.affine_inverse() * focus).z
	var in_front := not camera.is_position_behind(focus)
	var weight := 1.0 - exp(-radius_smoothing * delta)
	for material in candidates:
		var mesh: MeshInstance3D = _material_meshes[material]
		var desired := 0.0
		if enabled and in_front and _has_blocking_body(mesh) and _is_occluding(mesh, camera, depth):
			desired = _get_radius(mesh)
		var previous: float = _current_radii.get(material, 0.0)
		var radius := lerpf(previous, desired, weight)
		if desired == 0.0 and radius < 0.1:
			radius = 0.0
		_set_material_parameter(material, &"cutout_enabled", enabled and radius > 0.0)
		if radius == 0.0:
			_current_radii.erase(material)
			continue
		_current_radii[material] = radius
		_set_material_parameter(material, &"interior_visibility", interior_visibility)
		_set_material_parameter(material, &"target_uv", uv)
		_set_material_parameter(material, &"viewport_size", size)
		_set_material_parameter(material, &"radius_pixels", radius)


func _get_radius(mesh: MeshInstance3D) -> float:
	var distance_behind := maxf(_blocking_distance(mesh, _blocking_distances), 0.0)
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
func _physics_process(delta: float) -> void:
	_ray_remaining -= delta
	if _ray_remaining > 0.0:
		return
	_ray_remaining = maxf(_ray_remaining + ray_update_interval, 0.0)
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
	return _blocking_distance(mesh, _blocking_distances) >= 0.0

func _blocking_distance(mesh: MeshInstance3D, distances: Dictionary) -> float:
	for body in _mesh_bodies.get(mesh, []):
		if distances.has(body):
			return distances[body]
	return -1.0

## Большинство стен не меняются: не отправляем одинаковые uniforms каждый кадр.
func _set_material_parameter(material: ShaderMaterial, parameter: StringName, value: Variant) -> void:
	var values: Dictionary = _shader_values.get_or_add(material, {})
	if values.has(parameter) and values[parameter] == value:
		return
	values[parameter] = value
	material.set_shader_parameter(parameter, value)
	if parameter == &"cutout_enabled" or parameter == &"enemy_cutout_count":
		_sync_material_attachment(material)

## Шейдер с discard нужен только на стенах, где действительно открывается отверстие.
## Остальное окружение сохраняет исходные общие материалы и обычную отрисовку.
func _sync_material_attachment(material: ShaderMaterial) -> void:
	if not _material_bindings.has(material):
		return
	var values: Dictionary = _shader_values[material]
	var needed: bool = values.get(&"cutout_enabled", false) or values.get(&"enemy_cutout_count", 0) > 0
	if needed == _attached_materials.has(material):
		return
	var mesh: MeshInstance3D = _material_meshes[material]
	if not is_instance_valid(mesh) or mesh.is_queued_for_deletion():
		return
	var binding: Dictionary = _material_bindings[material]
	var replacement: Material = material if needed else binding.original
	if binding.surface < 0:
		mesh.material_override = replacement
	else:
		mesh.set_surface_override_material(binding.surface, replacement)
	if needed:
		_attached_materials[material] = true
	else:
		_attached_materials.erase(material)

func _forget_mesh(mesh: MeshInstance3D) -> void:
	for body in _mesh_bodies.get(mesh, []):
		var materials: Array = _body_materials.get(body, [])
		for index in range(materials.size() - 1, -1, -1):
			if _material_meshes.get(materials[index]) == mesh:
				materials.remove_at(index)
		if materials.is_empty():
			_body_materials.erase(body)
	_mesh_bodies.erase(mesh)
	for index in range(_meshes.size() - 1, -1, -1):
		if _meshes[index] == mesh:
			_material_bindings.erase(_materials[index])
			_attached_materials.erase(_materials[index])
			_material_meshes.erase(_materials[index])
			_enemy_active_materials.erase(_materials[index])
			_shader_values.erase(_materials[index])
			_current_radii.erase(_materials[index])
			for state in _enemy_states.values():
				state.radii.erase(_materials[index])
			_materials.remove_at(index)
			_meshes.remove_at(index)

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
	if not camera or _enemy_states.is_empty():
		for material in _enemy_active_materials:
			_set_material_parameter(material, &"enemy_cutout_count", 0)
		_enemy_active_materials.clear()
		if not camera:
			for state in _enemy_states.values():
				state.radii.clear()
		return
	var size := get_viewport().get_visible_rect().size
	var keys := _enemy_states.keys()
	# Проекция врага одинакова для всех стен — считаем один раз, а не на каждый материал.
	for id in keys:
		var state: Dictionary = _enemy_states[id]
		state.uv = camera.unproject_position(state.focus) / size
		state.in_front = not camera.is_position_behind(state.focus)
	var weight := 1.0 - exp(-radius_smoothing * delta)
	var candidates: Dictionary = {}
	for material in _enemy_active_materials:
		candidates[material] = true
	if enabled:
		for id in keys:
			for body in _enemy_states[id].bodies:
				for material in _body_materials.get(body, []):
					candidates[material] = true
	for material in candidates:
		var mesh: MeshInstance3D = _material_meshes[material]
		var circles := PackedVector4Array()
		circles.resize(MAX_ENEMY_CUTOUTS)
		var count := 0
		for id in keys:
			var state: Dictionary = _enemy_states[id]
			var desired := 0.0
			if enabled and state.in_front:
				var distance_behind := _blocking_distance(mesh, state.bodies)
				if distance_behind >= 0.0:
					var progress := smoothstep(0.0, maxf(radius_max_distance, 0.01), distance_behind)
					desired = lerpf(radius_pixels, maxf(radius_pixels, max_radius_pixels), progress)
			var previous: float = state.radii.get(material, 0.0)
			var radius := lerpf(previous, desired, weight)
			if desired == 0.0 and radius < 0.1:
				radius = 0.0
			if radius > 0.0:
				state.radii[material] = radius
				var uv: Vector2 = state.uv
				circles[count] = Vector4(uv.x, uv.y, radius, 0.0)
				count += 1
			else:
				state.radii.erase(material)
		if count > 0:
			_enemy_active_materials[material] = true
			_set_material_parameter(material, &"enemy_cutouts", circles)
			_set_material_parameter(material, &"viewport_size", size)
			_set_material_parameter(material, &"interior_visibility", interior_visibility)
		else:
			_enemy_active_materials.erase(material)
		_set_material_parameter(material, &"enemy_cutout_count", count)
	for id in keys:
		var state: Dictionary = _enemy_states[id]
		if state.bodies.is_empty() and state.radii.is_empty():
			_enemy_states.erase(id)
