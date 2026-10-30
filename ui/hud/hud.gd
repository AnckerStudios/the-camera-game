class_name Hud
extends CanvasLayer

## Интерфейс "камеры" игрока: здоровье, батарея, оружие, узлы.

const FLASH_DURATION := 0.4

var _rec_time := 0.0
var _flash_tween: Tween


func _ready() -> void:
	PlayerState.battery_changed.connect(set_battery)
	set_battery(PlayerState.battery, PlayerState.BATTERY_MAX)
	PlayerState.battery -= 75.0

	PlayerState.hp_changed.connect(set_health)
	set_health(PlayerState.hp, PlayerState.HP_MAX)
	PlayerState.hp -= 50.0

	PlayerState.weapon_changed.connect(set_weapon)
	if PlayerState.weapon_name:
		set_weapon(PlayerState.weapon_name)
	PlayerState.ammo_changed.connect(set_ammo)
	set_ammo(PlayerState.ammo_loaded, PlayerState.ammo_capacity, PlayerState.ammo_reserve)



func _process(delta: float) -> void:
	_rec_time += delta
	var seconds := int(_rec_time)
	%RecTime.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	%RecDot.modulate.a = 1.0 if fmod(_rec_time, 1.0) < 0.5 else 0.0


func set_health(value: float, max_value: float) -> void:
	%HealthBar.max_value = max_value
	%HealthBar.value = value


func set_battery(value: float, max_value: float) -> void:
	var level := value / max_value if max_value > 0.0 else 0.0
	%BatteryIndicator.level = level
	%BatteryPercent.text = "%d%%" % roundi(level * 100.0)


func set_nodes(activated: int, total: int) -> void:
	%NodesLabel.text = "УЗЛЫ: %d / %d" % [activated, total]


func set_weapon(weapon_name: String) -> void:
	%WeaponLabel.text = weapon_name.to_upper()


func set_ammo(loaded: int, capacity: int, reserve: int) -> void:
	%AmmoLabel.visible = capacity > 0
	%AmmoLabel.text = "%d / %d" % [loaded, reserve]


func play_flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	%FlashOverlay.modulate.a = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(%FlashOverlay, "modulate:a", 0.0, FLASH_DURATION)
