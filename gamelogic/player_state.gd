extends Node

## Глобальное состояние игрока. Типо основной контроллер состояний, батарейки, hp.

##PlayerState.battery -= 25.0 - Как использовать

signal battery_changed(value: float, max_value: float)
signal hp_changed(value: float, max_value: float)

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
