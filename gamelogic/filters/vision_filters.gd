extends Node
## Переключает режим; правила конкретного объекта находятся в VisionProfile.
signal filter_changed(mode: VisionProfile.Filter)
const Mode = VisionProfile.Filter
var mode: VisionProfile.Filter = VisionProfile.Filter.NORMAL
## Звук интерфейса не зависит от положения персонажа или камеры.
@export var switch_sound: AudioStream = preload("res://resources/music/caseta3.wav")
@export_range(-40.0, 6.0, 0.5) var switch_volume_db: float = -8.0
const TURN_ON_SOUND: AudioStream = preload("res://resources/music/turn_on.wav")
const TURN_OFF_SOUND: AudioStream = preload("res://resources/music/turn_off.wav")
var _switch_audio: AudioStreamPlayer
var _power_audio: AudioStreamPlayer
var _available_modes: Array[int] = [VisionProfile.Filter.NORMAL]
var _infrared: CanvasLayer
var _ultraviolet: CanvasLayer

func _ready() -> void:
	_switch_audio = AudioStreamPlayer.new()
	_switch_audio.name = &"FilterSwitchSound"
	_switch_audio.bus = &"SFX"
	_switch_audio.max_polyphony = 3
	add_child(_switch_audio)
	_power_audio = AudioStreamPlayer.new()
	_power_audio.name = &"FilterPowerSound"
	_power_audio.bus = &"SFX"
	add_child(_power_audio)
	_infrared = preload("res://gamelogic/filters/infrared_overlay.tscn").instantiate()
	_ultraviolet = preload("res://gamelogic/filters/ultraviolet_overlay.tscn").instantiate()
	add_child(_infrared)
	add_child(_ultraviolet)
	_update_overlays()

## Tab включает только фильтры из экипированного набора.
func cycle_filter() -> void:
	var index := _available_modes.find(int(mode))
	set_mode(_available_modes[(index + 1) % _available_modes.size()])

## Добавление фильтра не меняет текущий режим зрения.
func set_available_filters(filters: Array[int]) -> void:
	_available_modes.assign([VisionProfile.Filter.NORMAL])
	for value in filters:
		if value != VisionProfile.Filter.NORMAL and not _available_modes.has(value):
			_available_modes.append(value)
	if not _available_modes.has(int(mode)):
		set_mode(VisionProfile.Filter.NORMAL)

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
	# Кассета звучит одновременно с включением или отключением фильтра.
	if is_instance_valid(_switch_audio) and switch_sound:
		_switch_audio.stream = switch_sound
		_switch_audio.volume_db = switch_volume_db
		_switch_audio.play()
	if is_instance_valid(_power_audio):
		_power_audio.stream = TURN_OFF_SOUND if mode == Mode.NORMAL else TURN_ON_SOUND
		_power_audio.volume_db = switch_volume_db
		_power_audio.play()
