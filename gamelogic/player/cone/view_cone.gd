extends Node3D
## Конус видимости, направленный вдоль локальной оси -Z.

@export_range(10.0, 180.0) var cone_angle := 60.0
@export var cone_range := 12.0
@export var cone_color := Color(1.0, 1.0, 0.85, 0.2)
@export var cone_edge_color := Color(1.0, 1.0, 0.85, 0.5)
## Периферийное зрение
@export var peripheral_radius := 1.8

const CONE_SEGMENTS := 32
const CONE_FLOOR_OFFSET := 0.02


const FLASHLIGHT_ANGLE_MARGIN := 3.0
const FLASHLIGHT_RANGE_MARGIN := 1.5

const PERIPHERAL_LIGHT_RANGE_MARGIN := 1.0

@onready var _flashlight: SpotLight3D = $Flashlight
@onready var _peripheral_light: OmniLight3D = $PeripheralLight

func _ready() -> void:
	add_to_group(&"visibility_cones")
	add_child(_create_cone_mesh())
	_fit_flashlight()

func _create_cone_mesh() -> MeshInstance3D:
	var y := CONE_FLOOR_OFFSET
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


func _fit_flashlight() -> void:
	_flashlight.spot_angle = cone_angle / 2.0 + FLASHLIGHT_ANGLE_MARGIN
	_flashlight.spot_range = cone_range + FLASHLIGHT_RANGE_MARGIN
	_peripheral_light.omni_range = peripheral_radius + PERIPHERAL_LIGHT_RANGE_MARGIN


## Проверяет дальность и угол относительно направления взгляда на плоскости земли.
## Вблизи персонажа (peripheral_radius) точка видна в любом направлении.
func contains_world_point(world_position: Vector3) -> bool:
	var direction := world_position - global_position
	direction.y = 0.0
	if direction.length_squared() <= peripheral_radius * peripheral_radius:
		return true
	if direction.length_squared() > cone_range * cone_range:
		return false
	if direction.is_zero_approx():
		return true
	var forward := -global_basis.z
	forward.y = 0.0
	return forward.normalized().dot(direction.normalized()) >= cos(deg_to_rad(cone_angle * 0.5))
