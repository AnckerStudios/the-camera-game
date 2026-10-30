extends Node3D

## Тестовая сцена огнестрела: держатель оружия поворачивается за курсором по полу,
## перед ним рисуется конус зрения камеры.

## Полный угол конуса зрения в градусах.
@export_range(10.0, 180.0) var cone_angle := 60.0
@export var cone_range := 12.0
@export var cone_color := Color(1.0, 1.0, 0.85, 0.2)
@export var cone_edge_color := Color(1.0, 1.0, 0.85, 0.5)

const MouseTracker = preload("res://gamelogic/mouse_tracker.gd")

const CONE_SEGMENTS := 32
const CONE_FLOOR_OFFSET := 0.02

@onready var _holder: Node3D = $WeaponHolder


func _ready() -> void:
	var tracker := MouseTracker.new()
	tracker.name = &"MouseTracker"
	tracker.target = _holder
	tracker.target_changed.connect(_on_mouse_target_changed)
	add_child(tracker)
	_holder.add_child(_create_cone_mesh())
	_holder.add_child(_create_cone_light())


## Получает мировую точку от общего адаптера курсора.
func _on_mouse_target_changed(world_position: Vector3) -> void:
	var direction := world_position - _holder.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		_holder.look_at(_holder.global_position + direction, Vector3.UP)

## Плоский сектор на полу: полупрозрачная заливка и контур. Смотрит вдоль -Z держателя.
func _create_cone_mesh() -> MeshInstance3D:
	var y := -_holder.global_position.y + CONE_FLOOR_OFFSET
	var origin := Vector3(0.0, y, 0.0)
	var half := deg_to_rad(cone_angle) / 2.0
	var arc: Array[Vector3] = []
	for i in CONE_SEGMENTS + 1:
		var a := lerpf(-half, half, float(i) / CONE_SEGMENTS)
		arc.append(Vector3(sin(a) * cone_range, y, -cos(a) * cone_range))

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.surface_set_color(cone_color)
	for i in CONE_SEGMENTS:
		mesh.surface_add_vertex(origin)
		mesh.surface_add_vertex(arc[i + 1])
		mesh.surface_add_vertex(arc[i])
	mesh.surface_end()

	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	mesh.surface_set_color(cone_edge_color)
	mesh.surface_add_vertex(origin)
	for point in arc:
		mesh.surface_add_vertex(point)
	mesh.surface_add_vertex(origin)
	mesh.surface_end()

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var cone := MeshInstance3D.new()
	cone.name = "ViewCone"
	cone.mesh = mesh
	cone.material_override = material
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return cone


## Свет камеры в пределах конуса: видно, что попадает в кадр, и препятствия отбрасывают тени.
func _create_cone_light() -> SpotLight3D:
	var light := SpotLight3D.new()
	light.name = "ViewConeLight"
	light.spot_angle = cone_angle / 2.0
	light.spot_range = cone_range
	light.spot_attenuation = 0.5
	light.light_energy = 3.0
	light.shadow_enabled = true
	return light
