class_name VisionProfile
extends Resource
## Общие данные и правила зрения для монстров, предметов и окружения.
enum Dimension {REAL, INFRARED}
enum Filter {NORMAL, INFRARED, ULTRAVIOLET}
const META: StringName = &"vision_profile"

@export var dimension: Dimension = Dimension.REAL
@export var active_object: bool = false
@export var infrared_color: Color = Color(1.0, 0.28, 0.035, 1.0)
@export var ultraviolet_color: Color = Color(0.15, 0.8, 1.0, 1.0)

func attach(target: Node3D) -> void:
	target.set_meta(META, self)

func is_visible(mode: Filter) -> bool:
	match mode:
		Filter.NORMAL:
			return dimension == Dimension.REAL
		Filter.INFRARED:
			return true
		Filter.ULTRAVIOLET:
			return active_object
	return false

func should_highlight(mode: Filter) -> bool:
	return (mode == Filter.INFRARED and dimension == Dimension.INFRARED) or (mode == Filter.ULTRAVIOLET and active_object)

func highlight_color(mode: Filter) -> Color:
	return ultraviolet_color if mode == Filter.ULTRAVIOLET else infrared_color

static func from_target(target: Node3D) -> VisionProfile:
	if not is_instance_valid(target):
		return null
	if target.has_meta(META):
		return target.get_meta(META) as VisionProfile
	return null
