extends CanvasLayer
## 3D-карусель: выбранный предмет в центре, соседи меньше по бокам.
var is_open: bool = false
var _inventory: PlayerInventory
var _player: Node3D
var _adapter: Node
var _rig: Node
var _selected: InventoryEntry
var _index: int = 0
var _context_open: bool = false
var _choosing_weapon_slot: bool = false
var _context_index: int = 0
var _preferred_weapon_slot: int = 0
var _previous_pause: bool
var _hardware: bool
var _adapter_mode: int
var _menu_enabled: bool
var _mouse_mode: int
var _hud_layer: CanvasLayer
var _hud_visible: bool
var _cutout: Node
var _cutout_mode: int
@onready var _carousel: InventoryCarousel = $Root/Left/Margin/Column/Preview/Viewport/Carousel
@onready var _details: Label = $Root/Left/Margin/Column/Details
@onready var _status: Label = $Root/Left/Margin/Column/Status
@onready var _context: HBoxContainer = $Root/Context
@onready var _primary: Button = $Root/Context/Primary
@onready var _drop: Button = $Root/Context/Drop
@onready var _cancel: Button = $Root/Context/Cancel
@onready var _weapon_one: Button = $Root/Equipment/Margin/Column/Slots/WeaponOne
@onready var _weapon_two: Button = $Root/Equipment/Margin/Column/Slots/WeaponTwo
@onready var _filter: Button = $Root/Equipment/Margin/Column/Slots/Filter
var _actions: Array[Button] = []

func _ready() -> void:
	hide()
	_actions = [_primary, _drop, _cancel]
	_primary.pressed.connect(_apply_selected)
	_drop.pressed.connect(_drop_selected)
	_cancel.pressed.connect(_close_context)
	_weapon_one.pressed.connect(_choose_weapon_slot.bind(0))
	_weapon_two.pressed.connect(_choose_weapon_slot.bind(1))
	_filter.pressed.connect(_select_equipped_filter)
	_context.hide()

func open(player: Node3D, inventory: PlayerInventory, adapter: Node) -> void:
	_player = player
	_adapter = adapter
	_menu_enabled = adapter.menu_navigation_enabled
	adapter.menu_navigation_enabled = true
	if not adapter.menu_horizontal.is_connected(_on_horizontal):
		adapter.menu_horizontal.connect(_on_horizontal)
	_inventory = inventory
	_adapter = adapter
	_previous_pause = get_tree().paused
	_hardware = adapter.hardware_enabled
	_adapter_mode = adapter.process_mode
	_mouse_mode = Input.mouse_mode
	if not inventory.changed.is_connected(_refresh):
		inventory.changed.connect(_refresh)
	var camera := get_viewport().get_camera_3d()
	_rig = camera.get_parent() if camera else null
	if _rig and _rig.has_method("set_inventory_view"):
		_rig.set_inventory_view(true)
	_cutout = player.get_node_or_null("WallCutout")
	if _cutout:
		_cutout_mode = _cutout.process_mode
		_cutout.process_mode = Node.PROCESS_MODE_ALWAYS
	var hud := player.get_parent().get_node_or_null("HUD")
	if hud is CanvasLayer:
		_hud_layer = hud
		_hud_visible = hud.visible
		hud.hide()
	adapter.hardware_enabled = false
	adapter.process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_open = true
	get_tree().paused = true
	_close_context()
	_refresh()
	show()

func close() -> void:
	if not is_open:
		return
	is_open = false
	_close_context()
	hide()
	get_tree().paused = _previous_pause
	if is_instance_valid(_adapter):
		_adapter.menu_navigation_enabled = _menu_enabled
		_adapter.hardware_enabled = _hardware
		_adapter.process_mode = _adapter_mode
	if is_instance_valid(_rig) and _rig.has_method("set_inventory_view"):
		_rig.set_inventory_view(false)
	if is_instance_valid(_cutout):
		_cutout.process_mode = _cutout_mode
	if is_instance_valid(_hud_layer):
		_hud_layer.visible = _hud_visible
	Input.mouse_mode = _mouse_mode

func _refresh(direction: int = 0) -> void:
	if not _inventory:
		return
	if _selected and _inventory.entries.has(_selected):
		_index = _inventory.entries.find(_selected)
	else:
		_index = clampi(_index, 0, maxi(_inventory.entries.size() - 1, 0))
		_selected = _inventory.entries[_index] if not _inventory.entries.is_empty() else null
	_carousel.display(_inventory.entries, _index, direction)
	_weapon_one.text = _slot_text("Оружие 1", _inventory.weapons[0])
	_weapon_two.text = _slot_text("Оружие 2", _inventory.weapons[1])
	var names := PackedStringArray()
	for entry in _inventory.filters:
		names.append(entry.item.display_name)
	_filter.text = "Фильтры\n" + (", ".join(names) if not names.is_empty() else "Пусто")
	_weapon_one.tooltip_text = _weapon_one.text + "\nВыбрать ячейку для экипировки"
	_weapon_two.tooltip_text = _weapon_two.text + "\nВыбрать ячейку для экипировки"
	_filter.tooltip_text = _filter.text
	_status.text = "A / D — выбрать    E — действия    Q — закрыть\n%d / %d предметов" % [_inventory.entries.size(), _inventory.capacity]
	if _selected:
		_details.text = _selected.item.display_name + ("  ×" + str(_selected.quantity) if _selected.quantity > 1 else "") + "\n" + _selected.item.kind_name() + "\n" + _selected.item.description
	else:
		_details.text = "Инвентарь пуст"
		_close_context()
	_update_primary_text()

func _slot_text(title: String, entry: InventoryEntry) -> String:
	return title + "\n" + (entry.item.display_name if entry else "Пусто")

## Направление приходит из адаптера ввода даже при остановленном персонаже.
func _on_horizontal(direction: int) -> void:
	if not is_open:
		return
	if _context_open:
		_context_index = posmod(_context_index + direction, _actions.size())
		_focus_action()
		return
	if _inventory.entries.size() <= 1:
		return
	_index = posmod(_index + direction, _inventory.entries.size())
	_selected = _inventory.entries[_index]
	_refresh(direction)

func handle_interaction() -> void:
	if not is_open or not _selected:
		return
	if _context_open:
		_actions[_context_index].pressed.emit()
	else:
		_open_context()

func _open_context() -> void:
	_choosing_weapon_slot = false
	_drop.text = "Выбросить"
	_context_open = true
	_context_index = 0
	if _selected.item.kind == InventoryItem.Kind.WEAPON:
		for slot in _inventory.weapons.size():
			if _inventory.weapons[slot] == null:
				_preferred_weapon_slot = slot
				break
	_update_primary_text()
	_context.show()
	_focus_action()

func _close_context() -> void:
	_choosing_weapon_slot = false
	if is_instance_valid(_drop):
		_drop.text = "Выбросить"
	_context_open = false
	if is_instance_valid(_context):
		_context.hide()

func _focus_action() -> void:
	for index in _actions.size():
		_actions[index].modulate = Color(1.0, 0.8, 0.3) if index == _context_index else Color.WHITE
	_actions[_context_index].grab_focus()

func _update_primary_text() -> void:
	if _choosing_weapon_slot:
		_primary.text = _weapon_choice_text(0)
		_drop.text = _weapon_choice_text(1)
		return
	if not _selected:
		return
	var equipped := _inventory.is_equipped(_selected)
	if equipped:
		_primary.text = "Снять"
	elif _selected.item.kind == InventoryItem.Kind.WEAPON:
		_primary.text = "Надеть"
	elif _selected.item.kind == InventoryItem.Kind.FILTER:
		_primary.text = "Надеть"
	else:
		_primary.text = "Применить"

func _apply_selected() -> void:
	if _choosing_weapon_slot:
		_equip_in_slot(0)
		return
	if _selected and _selected.item.kind == InventoryItem.Kind.WEAPON and not _inventory.is_equipped(_selected):
		_choosing_weapon_slot = true
		_context_index = 0
		_update_primary_text()
		_focus_action()
		return
	if not _selected:
		return
	var entry := _selected
	_close_context()
	if _inventory.is_equipped(entry):
		_inventory.unequip(entry)
		return
	var success := false
	match entry.item.kind:
		InventoryItem.Kind.WEAPON:
			success = _inventory.equip_weapon(entry, _preferred_weapon_slot)
		InventoryItem.Kind.FILTER:
			success = _inventory.equip_filter(entry)
		_:
			success = _inventory.use_item(entry)
	if not success:
		_details.text = "Предмет сейчас нельзя применить: проверьте здоровье, совместимость патронов или сцену оружия."

func _drop_selected() -> void:
	if _choosing_weapon_slot:
		_equip_in_slot(1)
		return
	if not _selected:
		return
	var entry := _selected
	_close_context()
	if not _inventory.drop_item(entry, _player):
		_details.text = "Не удалось выбросить предмет."

func _choose_weapon_slot(slot: int) -> void:
	if _choosing_weapon_slot:
		_equip_in_slot(slot)
		return
	_preferred_weapon_slot = slot
	if _context_open:
		_update_primary_text()
	elif _inventory.weapons[slot]:
		_selected = _inventory.weapons[slot]
		_refresh()

func _select_equipped_filter() -> void:
	if _inventory.filter_slot:
		_selected = _inventory.filter_slot
		_close_context()
		_refresh()

func _exit_tree() -> void:
	if is_open:
		close()


## Второй шаг действия «Надеть»: явный выбор оружейной ячейки.
func _weapon_choice_text(slot: int) -> String:
	var equipped := _inventory.weapons[slot]
	return "Слот %d: %s" % [slot + 1, equipped.item.display_name if equipped else "Пусто"]

func _equip_in_slot(slot: int) -> void:
	if not _selected or _selected.item.kind != InventoryItem.Kind.WEAPON:
		_close_context()
		return
	var entry := _selected
	_close_context()
	if not _inventory.equip_weapon(entry, slot):
		_details.text = "Не удалось надеть оружие."


## Внешний выбор, например только что подобранного оружия после осмотра.
func select_entry(entry: InventoryEntry) -> void:
	if not _inventory or not _inventory.entries.has(entry):
		return
	_selected = entry
	_close_context()
	_refresh()
