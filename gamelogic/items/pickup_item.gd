class_name PickupItem
extends Area3D
## Базовый подбираемый предмет. Наследники переопределяют _apply_pickup().

signal pickup_available(item: PickupItem, receiver: Node3D)
signal pickup_unavailable(item: PickupItem, receiver: Node3D)
signal picked_up(item: PickupItem, receiver: Node3D)

## Сцена 3D-модели (например, .tscn или импортированный .glb).
## Если не задана, используется модель, уже находящаяся в узле Model.
@export var model_scene: PackedScene

@export_multiline var description: String = "Найденный предмет."
@export var display_name: String = "Предмет"
@export_range(0.1, 20.0, 0.1) var pickup_radius: float = 1.5:
	set(value):
		pickup_radius = maxf(value, 0.1)
		if is_node_ready():
			_update_radius()
## Пустая группа разрешает подбор любому CharacterBody3D; можно задать группу игрока.
@export var receiver_group: StringName = &""
@export var outline_color: Color = Color(0.797, 0.796, 0.993, 1.0)
## Цвет обводки предмета, выбранного для следующего подбора.
@export var selected_outline_color: Color = Color(1.0, 0.8, 0.15, 1.0)
## Толщина оболочки в локальных единицах модели.
@export_range(0.001, 0.2, 0.001) var outline_width: float = 0.025

const OUTLINE_SHADER = preload("res://gamelogic/items/item_outline.gdshader")
var _receivers: Array[Node3D] = []
var _taken: bool = false
var _outline_material: ShaderMaterial
@onready var _shape: CollisionShape3D = $PickupRadius
@onready var _model: Node3D = $Model

func _ready() -> void:
	add_to_group(&"pickup_items")
	# Обводка предмета не должна заменяться шейдером вырезания стен.
	add_to_group(&"camera_cutout_ignore")
	_load_model_scene()
	_update_radius()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = OUTLINE_SHADER
	_outline_material.set_shader_parameter("outline_color", outline_color)
	_outline_material.set_shader_parameter("outline_width", outline_width)
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		_add_outline(mesh)

func _update_radius() -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = pickup_radius
	_shape.shape = sphere

func _accepts(receiver: Node3D) -> bool:
	return receiver is CharacterBody3D and (receiver_group.is_empty() or receiver.is_in_group(receiver_group))

func _on_body_entered(body: Node3D) -> void:
	if _taken or not _accepts(body) or _receivers.has(body):
		return
	_receivers.append(body)
	pickup_available.emit(self, body)

func _on_body_exited(body: Node3D) -> void:
	if not _receivers.has(body):
		return
	_receivers.erase(body)
	pickup_unavailable.emit(self, body)

## Проверяет реальное пересечение области, а не только сохранённое событие входа.
func can_pick_up(receiver: Node3D) -> bool:
	return not _taken and is_instance_valid(receiver) and _accepts(receiver) and overlaps_body(receiver)

## Вызывается внешним контроллером взаимодействия. Удержание кнопок предмет не читает.
func try_pick_up(receiver: Node3D) -> bool:
	if not can_pick_up(receiver):
		return false
	_taken = true
	if not _apply_pickup(receiver):
		_taken = false
		return false
	for candidate in _receivers.duplicate():
		if is_instance_valid(candidate):
			pickup_unavailable.emit(self, candidate)
	_receivers.clear()
	picked_up.emit(self, receiver)
	queue_free()
	return true

## Наследник выдаёт ресурс/предмет в инвентарь; false отменяет подбор.
func _apply_pickup(_receiver: Node3D) -> bool:
	return true

## Отдельная оболочка сохраняет исходные материалы и текстуры модели.
func _add_outline(source: MeshInstance3D) -> void:
	if not source.mesh:
		return
	var outline := MeshInstance3D.new()
	outline.name = &"Outline"
	outline.mesh = source.mesh
	outline.material_override = _outline_material
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	source.add_child(outline)


## Меняет только обводку; обычная подсветка остальных предметов сохраняется.
func set_pickup_selected(selected: bool) -> void:
	if _outline_material:
		var color := selected_outline_color if selected else outline_color
		_outline_material.set_shader_parameter("outline_color", color)


## Сохраняет контейнер Model, используемый обводкой и окном осмотра.
func _load_model_scene() -> void:
	if not model_scene:
		return
	var instance := model_scene.instantiate()
	if not instance is Node3D:
		push_warning("Модель предмета должна иметь корневой узел Node3D: " + model_scene.resource_path)
		instance.free()
		return
	for child in _model.get_children():
		_model.remove_child(child)
		child.queue_free()
	_model.add_child(instance)
