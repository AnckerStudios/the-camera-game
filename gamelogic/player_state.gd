extends Node

## Глобальное состояние игрока. Типо основной контроллер состояний, батарейки, hp.

##PlayerState.battery -= 25.0 - Как использовать

signal battery_changed(value: float, max_value: float)
signal hp_changed(value: float, max_value: float)
signal weapon_changed(weapon_name: String)
## capacity == 0 - у текущего оружия нет патронов.
signal ammo_changed(loaded: int, capacity: int, reserve: int)

const BATTERY_MAX := 100.0
const HP_MAX := 100.0

var battery := BATTERY_MAX:
	set(value):
		value = clampf(value, 0.0, BATTERY_MAX)
		if is_equal_approx(value, battery):
			return
		battery = value
		battery_changed.emit(battery, BATTERY_MAX)

var hp := HP_MAX:
	set(value):
		value = clampf(value, 0.0, HP_MAX)
		if is_equal_approx(value, hp):
			return
		hp = value
		hp_changed.emit(hp, HP_MAX)

var weapon_name := "":
	set(value):
		weapon_name = value
		weapon_changed.emit(weapon_name)


var ammo_loaded := 0
var ammo_capacity := 0
var ammo_reserve := 0


func set_ammo(loaded: int, capacity: int, reserve: int) -> void:
	ammo_loaded = loaded
	ammo_capacity = capacity
	ammo_reserve = reserve
	ammo_changed.emit(loaded, capacity, reserve)
