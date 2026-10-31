class_name PlayerInventory
extends Node
signal changed
@export_range(6, 96, 6) var capacity: int = 24
var entries: Array[InventoryEntry] = []
var weapons: Array[InventoryEntry] = [null, null]
var filter_slot: InventoryEntry
var filters: Array[InventoryEntry] = []
var _holder: WeaponHolder

## Оружие, уже выданное сценой игрока, также появляется в инвентаре.
func initialize(holder: WeaponHolder) -> void:
	_holder = holder
	if holder:
		for weapon in holder.get_weapons():
			var data := InventoryItem.new()
			data.id = StringName("weapon_" + String(weapon.name))
			data.display_name = weapon.display_name
			data.kind = InventoryItem.Kind.WEAPON
			data.weapon_id = weapon.name
			if not weapon.scene_file_path.is_empty():
				data.weapon_scene = load(weapon.scene_file_path) as PackedScene
			var entry := InventoryEntry.new()
			entry.item = data
			entry.weapon = weapon
			entries.append(entry)
			if weapons[0] == null:
				weapons[0] = entry
			elif weapons[1] == null:
				weapons[1] = entry
	# Сохраняем доступ к двум фильтрам, ранее доступным игроку по Tab.
	for mode in [VisionProfile.Filter.INFRARED, VisionProfile.Filter.ULTRAVIOLET]:
		var data := InventoryItem.new()
		data.id = StringName("filter_" + str(mode))
		data.display_name = "Инфракрасный фильтр" if mode == VisionProfile.Filter.INFRARED else "Ультрафиолетовый фильтр"
		data.kind = InventoryItem.Kind.FILTER
		data.filter_mode = mode
		add_item(data, 1)
	for entry in entries:
		if entry.item.kind == InventoryItem.Kind.FILTER:
			filter_slot = entry
			filters.append(entry)
			break
	_sync_weapons()
	_sync_filters()
	changed.emit()

func add_item(item: InventoryItem, quantity: int = 1) -> bool:
	if not item or quantity <= 0:
		return false
	var room := maxi(capacity - entries.size(), 0) * item.stack_limit()
	for entry in entries:
		if entry.item.key() == item.key():
			room += maxi(entry.item.stack_limit() - entry.quantity, 0)
	if room < quantity:
		return false
	var remaining := quantity
	for entry in entries:
		if entry.item.key() != item.key():
			continue
		var count := mini(remaining, maxi(entry.item.stack_limit() - entry.quantity, 0))
		entry.quantity += count
		remaining -= count
	while remaining > 0:
		var entry := InventoryEntry.new()
		entry.item = item
		entry.quantity = mini(remaining, item.stack_limit())
		entries.append(entry)
		remaining -= entry.quantity
	changed.emit()
	return true

func equip_weapon(entry: InventoryEntry, slot: int) -> bool:
	if not entries.has(entry) or slot < 0 or slot > 1 or entry.item.kind != InventoryItem.Kind.WEAPON:
		return false
	if not is_instance_valid(entry.weapon):
		if not _holder or not entry.item.weapon_scene:
			return false
		entry.weapon = _holder.create_inventory_weapon(entry.item.weapon_scene)
		if not entry.weapon:
			return false
	for index in weapons.size():
		if weapons[index] == entry:
			weapons[index] = null
	weapons[slot] = entry
	_sync_weapons()
	_sync_filters()
	changed.emit()
	return true

func equip_filter(entry: InventoryEntry) -> bool:
	if not entries.has(entry) or entry.item.kind != InventoryItem.Kind.FILTER:
		return false
	filter_slot = entry
	if not filters.has(entry):
		filters.append(entry)
	_sync_filters()
	changed.emit()
	return true

## Лечение расходует одну единицу, патроны передают весь выбранный запас оружию.
func use_item(entry: InventoryEntry) -> bool:
	if not entries.has(entry):
		return false
	if entry.item.kind == InventoryItem.Kind.MEDICINE:
		if PlayerState.hp >= PlayerState.HP_MAX or entry.item.healing <= 0.0:
			return false
		PlayerState.hp += entry.item.healing
		_consume(entry, 1)
		return true
	if entry.item.kind == InventoryItem.Kind.AMMO:
		for candidate in entries:
			if candidate.weapon is Firearm and candidate.item.weapon_id == entry.item.weapon_id:
				candidate.weapon.add_ammo(entry.quantity)
				_consume(entry, entry.quantity)
				return true
	return false

func _consume(entry: InventoryEntry, quantity: int) -> void:
	entry.quantity -= quantity
	if entry.quantity <= 0:
		entries.erase(entry)
	changed.emit()

func _sync_weapons() -> void:
	if not _holder:
		return
	var equipped: Array[Weapon] = []
	for entry in weapons:
		if entry and is_instance_valid(entry.weapon):
			equipped.append(entry.weapon)
	_holder.set_inventory_weapons(equipped)


func unequip(entry: InventoryEntry) -> void:
	for index in weapons.size():
		if weapons[index] == entry:
			weapons[index] = null
	if filters.has(entry):
		filters.erase(entry)
		filter_slot = filters.back() if not filters.is_empty() else null
		_sync_filters()
	_sync_weapons()
	_sync_filters()
	changed.emit()

## Выбрасывает весь выбранный стек. Экземпляр оружия сохраняется вместе с патронами.
func drop_item(entry: InventoryEntry, player: Node3D) -> bool:
	if not entries.has(entry) or not is_instance_valid(player):
		return false
	var pickup_scene := load("res://gamelogic/environment/items/pickup_item.tscn") as PackedScene
	if not pickup_scene:
		return false
	var pickup = pickup_scene.instantiate()
	pickup.inventory_item = entry.item
	pickup.quantity = entry.quantity
	pickup.stored_entry = entry
	pickup.model_snapshot = InventoryPreview.build(entry)
	pickup.model_snapshot.position.y = pickup.model_snapshot.get_meta(&"floor_offset", 0.3)
	var position := _drop_position(player)
	# Сначала исключаем из экипировки, затем переносим скрытую логику оружия в предмет.
	entries.erase(entry)
	for slot in weapons.size():
		if weapons[slot] == entry:
			weapons[slot] = null
	if filters.has(entry):
		filters.erase(entry)
		filter_slot = filters.back() if not filters.is_empty() else null
		_sync_filters()
	_sync_weapons()
	if is_instance_valid(entry.weapon):
		entry.weapon.unequip()
		entry.weapon.get_parent().remove_child(entry.weapon)
		pickup.add_child(entry.weapon)
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = position
	changed.emit()
	return true

func restore_entry(entry: InventoryEntry) -> bool:
	if entries.size() >= capacity or entries.has(entry):
		return false
	if is_instance_valid(entry.weapon):
		if not is_instance_valid(_holder):
			return false
		entry.weapon.reparent(_holder, false)
		entry.weapon.unequip()
		if entry.weapon is Firearm and not entry.weapon.fired.is_connected(_holder._on_weapon_fired):
			entry.weapon.fired.connect(_holder._on_weapon_fired)
	entries.append(entry)
	changed.emit()
	return true

func _drop_position(player: Node3D) -> Vector3:
	var forward := -player.global_basis.z
	var visual := player.get_node_or_null("Visual") as Node3D
	if visual:
		forward = -visual.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var origin := player.global_position + Vector3.UP * 0.8
	var desired := origin + forward * 1.3
	var excluded: Array[RID] = []
	if player is CollisionObject3D:
		excluded.append(player.get_rid())
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, desired, 0xFFFFFFFF, excluded)
	var obstacle := space.intersect_ray(query)
	if not obstacle.is_empty():
		desired = obstacle.position - forward * 0.25
	query.from = desired
	query.to = desired + Vector3.DOWN * 4.0
	var floor_hit := space.intersect_ray(query)
	return floor_hit.position + Vector3.UP * 0.02 if not floor_hit.is_empty() else player.global_position


func is_equipped(entry: InventoryEntry) -> bool:
	return weapons.has(entry) or filters.has(entry)

func _sync_filters() -> void:
	var modes: Array[int] = []
	for entry in filters:
		modes.append(int(entry.item.filter_mode))
	VisionFilters.set_available_filters(modes)
