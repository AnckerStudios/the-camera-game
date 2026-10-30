class_name WeaponHolder
extends Node3D

## Держатель оружия игрока: дочерние Weapon, переключение, ввод и проброс состояния в PlayerState.

var current: Weapon

var _index := -1


func _ready() -> void:
	for weapon in get_weapons():
		weapon.unequip()
	select(0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("weapon_next"):
		select(_index + 1)
	elif event.is_action_pressed("weapon_prev"):
		select(_index - 1)
	elif not current:
		return
	elif event.is_action_pressed("fire"):
		current.primary_attack()
	elif event.is_action_pressed("alt_fire"):
		current.secondary_attack()
	elif event.is_action_pressed("reload"):
		current.reload()


func get_weapons() -> Array[Weapon]:
	var result: Array[Weapon] = []
	for child in get_children():
		if child is Weapon:
			result.append(child)
	return result


func select(index: int) -> void:
	var weapons := get_weapons()
	if weapons.is_empty():
		return
	index = wrapi(index, 0, weapons.size())
	if weapons[index] == current:
		return

	if current:
		if current is Firearm:
			current.ammo_changed.disconnect(PlayerState.set_ammo)
		current.unequip()

	_index = index
	current = weapons[index]
	current.equip()
	PlayerState.weapon_name = current.display_name
	if current is Firearm:
		current.ammo_changed.connect(PlayerState.set_ammo)
		PlayerState.set_ammo(current.loaded, current.capacity, current.reserve_ammo)
	else:
		PlayerState.set_ammo(0, 0, 0)
