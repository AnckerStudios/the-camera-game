class_name InventoryCarousel
extends Node3D
@export_range(0.05, 0.6, 0.01) var transition_seconds: float = 0.2
@export_range(0.0, 90.0, 1.0) var rotation_speed_degrees: float = 18.0
var _rotation_phase: float = 0.0
var _tween: Tween

## Одновременно в кадре не более трёх моделей, центральная крупнее соседей.
func display(entries: Array[InventoryEntry], selected: int, direction: int = 0) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if entries.is_empty():
		return
	_tween = create_tween().set_parallel(true)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for slot in range(-1, 2):
		if entries.size() == 1 and slot != 0:
			continue
		if entries.size() == 2 and slot == -1:
			continue
		var index := posmod(selected + slot, entries.size())
		var pivot := Node3D.new()
		add_child(pivot)
		var model := InventoryPreview.build(entries[index])
		pivot.add_child(model)
		model.rotation = Vector3(deg_to_rad(-12.0), deg_to_rad(-25.0) + _rotation_phase, 0.0)
		var target_scale := 1.0 if slot == 0 else 0.55
		pivot.position = Vector3(float(slot + direction) * 2.25, 0, -absf(slot) * 0.7)
		pivot.scale = Vector3.ONE * (0.55 if direction != 0 else target_scale)
		_tween.tween_property(pivot, "position", Vector3(slot * 2.25, 0, -absf(slot) * 0.7), transition_seconds)
		_tween.tween_property(pivot, "scale", Vector3.ONE * target_scale, transition_seconds)


## Вращаются модели внутри опорных узлов: анимация прокрутки не затрагивается.
func _process(delta: float) -> void:
	var increment := deg_to_rad(rotation_speed_degrees) * delta
	_rotation_phase = fmod(_rotation_phase + increment, TAU)
	for pivot in get_children():
		if pivot.get_child_count() > 0:
			var model := pivot.get_child(0) as Node3D
			if model:
				model.rotation.y = deg_to_rad(-25.0) + _rotation_phase
