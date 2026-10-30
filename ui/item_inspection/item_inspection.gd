extends CanvasLayer
## Отдельный 3D-просмотр предмета. Ввод взаимодействия остаётся активным при паузе.
signal closed
const MouseInput = preload("res://gamelogic/input/mouse_tracker.gd")

## Начальный наклон модели и длительности появления в секундах.
@export var initial_tilt_degrees: Vector3 = Vector3(12.0, 10.0, -8.0)
@export_range(0.05, 1.0, 0.01) var entrance_seconds: float = 0.2
@export_range(0.05, 1.0, 0.01) var text_fade_seconds: float = 0.15

var _entrance_tween: Tween
var _entering: bool = false
var _text_panel: Control
var is_open: bool = false
var _adapter: Node
var _was_paused: bool
var _hardware_enabled: bool
var _adapter_mode: int
var _mouse_mode: int
var _pivot: Node3D
var _title: Label
var _description: Label
var _viewport: SubViewport
var _preview_camera: Camera3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	_bind_interface()
	hide()
	var mouse_input := MouseInput.new()
	mouse_input.drag_delta.connect(_rotate_model)
	add_child(mouse_input)

## Интерфейс собран в сцене из Control-нод и редактируется в Godot.
func _bind_interface() -> void:
	_text_panel = $Window/Layout/TextPanel
	_title = $Window/Layout/TextPanel/Margin/Text/Title
	_description = $Window/Layout/TextPanel/Margin/Text/Description
	_viewport = $Window/Layout/Preview/Viewport
	_pivot = $Window/Layout/Preview/Viewport/Pivot
	_preview_camera = $Window/Layout/Preview/Viewport/Camera3D

## Копирует только геометрию: логика предмета и область подбора в просмотр не попадают.
func prepare(item: PickupItem) -> void:
	for child in _pivot.get_children():
		_pivot.remove_child(child)
		child.queue_free()
	_stop_entrance()
	_pivot.position = Vector3.ZERO
	_pivot.rotation_degrees = initial_tilt_degrees
	_text_panel.modulate.a = 0.0
	_title.text = item.display_name
	_description.text = item.description
	_copy_meshes(item.get_node("Model"), Transform3D.IDENTITY)
	var bounds := AABB()
	var initialized := false
	for mesh in _pivot.get_children():
		var mesh_bounds: AABB = mesh.transform * mesh.get_aabb()
		bounds = bounds.merge(mesh_bounds) if initialized else mesh_bounds
		initialized = true
	var radius := maxf(bounds.size.length() * 0.5, 0.1)
	for mesh in _pivot.get_children():
		mesh.position -= bounds.get_center()
	_preview_camera.position.z = radius / tan(deg_to_rad(_preview_camera.fov * 0.5)) * 1.5
	_preview_camera.near = 0.01
	_preview_camera.far = maxf(_preview_camera.position.z + radius * 4.0, 20.0)

func _copy_meshes(node: Node3D, parent_transform: Transform3D) -> void:
	if node.name == &"Outline":
		return
	var local_transform := parent_transform * node.transform
	if node is MeshInstance3D and node.mesh:
		var copy := MeshInstance3D.new()
		copy.mesh = node.mesh
		copy.transform = local_transform
		copy.material_override = node.material_override
		for surface in node.mesh.get_surface_count():
			copy.set_surface_override_material(surface, node.get_surface_override_material(surface))
		_pivot.add_child(copy)
	for child in node.get_children():
		if child is Node3D:
			_copy_meshes(child, local_transform)

func open(adapter: Node) -> void:
	_adapter = adapter
	_was_paused = get_tree().paused
	_hardware_enabled = adapter.hardware_enabled
	_adapter_mode = adapter.process_mode
	_mouse_mode = Input.mouse_mode
	adapter.hardware_enabled = false
	adapter.process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_open = true
	show()
	get_tree().paused = true
	_play_entrance()

func close() -> void:
	if not is_open:
		return
	is_open = false
	_stop_entrance()
	hide()
	get_tree().paused = _was_paused
	if is_instance_valid(_adapter):
		_adapter.hardware_enabled = _hardware_enabled
		_adapter.process_mode = _adapter_mode
	Input.mouse_mode = _mouse_mode
	closed.emit()

func _rotate_model(relative: Vector2) -> void:
	if not is_open or _entering:
		return
	_pivot.rotation.y += relative.x * 0.01
	_pivot.rotation.x = clampf(_pivot.rotation.x + relative.y * 0.01, -1.3, 1.3)

func _exit_tree() -> void:
	if is_open:
		close()


## Сначала предмет поднимается снизу в центр; затем проявляются подложка и текст.
func _play_entrance() -> void:
	_stop_entrance()
	_entering = true
	_text_panel.modulate.a = 0.0
	var half_view_height := _preview_camera.position.z * tan(deg_to_rad(_preview_camera.fov * 0.5))
	_pivot.position = Vector3(0.0, -half_view_height * 1.8, 0.0)
	_entrance_tween = create_tween()
	_entrance_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_entrance_tween.tween_property(_pivot, "position", Vector3.ZERO, entrance_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_callback(_finish_model_entrance)
	_entrance_tween.tween_property(_text_panel, "modulate:a", 1.0, text_fade_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _finish_model_entrance() -> void:
	_entering = false

## Закрытие по E прерывает анимацию; следующий предмет начинает её заново.
func _stop_entrance() -> void:
	if _entrance_tween and _entrance_tween.is_valid():
		_entrance_tween.kill()
	_entering = false
