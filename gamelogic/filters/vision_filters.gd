extends Node
## Переключает режим; правила конкретного объекта находятся в VisionProfile.
signal filter_changed(mode: VisionProfile.Filter)
const Mode = VisionProfile.Filter
var mode: VisionProfile.Filter = VisionProfile.Filter.NORMAL
var _infrared: CanvasLayer
var _ultraviolet: CanvasLayer

func _ready() -> void:
	_infrared = preload("res://gamelogic/filters/infrared_overlay.tscn").instantiate()
	_ultraviolet = preload("res://gamelogic/filters/ultraviolet_overlay.tscn").instantiate()
	add_child(_infrared)
	add_child(_ultraviolet)
	_update_overlays()

func cycle_filter() -> void:
	match mode:
		Mode.NORMAL:
			set_mode(Mode.INFRARED)
		Mode.INFRARED:
			set_mode(Mode.ULTRAVIOLET)
		Mode.ULTRAVIOLET:
			set_mode(Mode.NORMAL)

func set_mode(value: VisionProfile.Filter) -> void:
	if mode == value:
		return
	mode = value
	_update_overlays()
	filter_changed.emit(mode)

func _update_overlays() -> void:
	_infrared.visible = mode == Mode.INFRARED
	_ultraviolet.visible = mode == Mode.ULTRAVIOLET

## Обычная геометрия без профиля остаётся окружением, а не целью фильтра.
func is_target_visible(target: Node3D) -> bool:
	var profile := VisionProfile.from_target(target)
	return profile.is_visible(mode) if profile else true
