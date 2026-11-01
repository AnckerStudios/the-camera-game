extends Node
## Переключает режим; правила конкретного объекта находятся в VisionProfile.
signal filter_changed(mode: VisionProfile.Filter)
signal available_filters_changed
const Mode = VisionProfile.Filter
var mode: VisionProfile.Filter = VisionProfile.Filter.NORMAL
## Звук интерфейса не зависит от положения персонажа или камеры.
@export var switch_sound: AudioStream = preload("res://resources/music/caseta3.wav")
@export_range(-40.0, 6.0, 0.5) var switch_volume_db: float = -8.0
## Расход заряда батарейки камеры, пока включён фильтр, единиц в секунду (полный заряд - 100).
@export_range(0.0, 50.0, 0.1) var battery_drain_per_second: float = 2.0
## При таком заряде (в процентах, как в HUD) фильтр выключается и не включается снова.
@export_range(0, 100, 1) var min_battery_percent: int = 1
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

## Фильтр питается от батарейки камеры; на паузе (инвентарь, меню) заряд не тратится.
func _process(delta: float) -> void:
	if mode == Mode.NORMAL:
		return
	PlayerState.battery -= battery_drain_per_second * delta
	if _is_battery_low():
		set_mode(Mode.NORMAL)

## Округление то же, что в HUD: фильтр гаснет, когда на экране появляется порог.
func _is_battery_low() -> bool:
	return roundi(PlayerState.battery / PlayerState.BATTERY_MAX * 100.0) <= min_battery_percent

## Tab включает только фильтры из экипированного набора.
func cycle_filter() -> void:
	var index := _available_modes.find(int(mode))
	set_mode(_available_modes[(index + 1) % _available_modes.size()])

## Добавление фильтра не меняет текущий режим зрения.
func set_available_filters(filters: Array[int]) -> void:
	var previous := _available_modes.duplicate()
	_available_modes.assign([VisionProfile.Filter.NORMAL])
	for value in filters:
		if value != VisionProfile.Filter.NORMAL and not _available_modes.has(value):
			_available_modes.append(value)
	if not _available_modes.has(int(mode)):
		set_mode(VisionProfile.Filter.NORMAL)
	if previous != _available_modes:
		available_filters_changed.emit()

## Экипированный фильтр доступен по Tab, но может оставаться выключенным.
func get_equipped_filter_mode() -> int:
	return _available_modes[1] if _available_modes.size() > 1 else int(Mode.NORMAL)

func set_mode(value: VisionProfile.Filter, play_sound: bool = true) -> void:
	if mode == value:
		return
	# Разряженная камера не включает фильтр; выключить его можно всегда.
	if value != Mode.NORMAL and _is_battery_low():
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
