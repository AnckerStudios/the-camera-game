extends Node
## Переключает режим; правила конкретного объекта находятся в VisionProfile.
signal filter_changed(mode: VisionProfile.Filter)
const Mode = VisionProfile.Filter
var mode: VisionProfile.Filter = VisionProfile.Filter.NORMAL
## Звук интерфейса не зависит от положения персонажа или камеры.
@export var switch_sound: AudioStream = preload("res://resources/music/gun_ghost.mp3")
@export_range(-40.0, 6.0, 0.5) var switch_volume_db: float = -8.0
var _switch_audio: AudioStreamPlayer
var _infrared: CanvasLayer
var _ultraviolet: CanvasLayer

func _ready() -> void:
	_switch_audio = AudioStreamPlayer.new()
	_switch_audio.name = &"FilterSwitchSound"
	_switch_audio.bus = &"SFX"
	_switch_audio.max_polyphony = 3
	add_child(_switch_audio)
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

func set_mode(value: VisionProfile.Filter, play_sound: bool = true) -> void:
	if mode == value:
		return
	mode = value
	_update_overlays()
	if play_sound:
		_play_switch_sound()
	filter_changed.emit(mode)

func _update_overlays() -> void:
	_infrared.visible = mode == Mode.INFRARED
	_ultraviolet.visible = mode == Mode.ULTRAVIOLET

## Обычная геометрия без профиля остаётся окружением, а не целью фильтра.
func is_target_visible(target: Node3D) -> bool:
	var profile := VisionProfile.from_target(target)
	return profile.is_visible(mode) if profile else true


func _play_switch_sound() -> void:
	if not is_instance_valid(_switch_audio) or not switch_sound:
		return
	_switch_audio.stream = switch_sound
	_switch_audio.volume_db = switch_volume_db
	_switch_audio.play()
