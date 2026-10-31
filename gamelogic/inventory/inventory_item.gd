class_name InventoryItem
extends Resource
## Описание предмета, общее для мирового объекта и ячейки инвентаря.
enum Kind {WEAPON, AMMO, MEDICINE, FILTER}
@export var id: StringName
@export var display_name: String = "Предмет"
@export_multiline var description: String
@export var kind: Kind = Kind.MEDICINE
@export var icon: Texture2D
@export var model_scene: PackedScene
@export_range(1, 999, 1) var max_stack: int = 10
@export var weapon_scene: PackedScene
## Имя узла оружия для совместимых патронов, например WeaponRevolver.
@export var weapon_id: StringName
@export_range(0.0, 100.0, 1.0) var healing: float = 25.0
@export var filter_mode: VisionProfile.Filter = VisionProfile.Filter.INFRARED

func stack_limit() -> int:
	return 1 if kind == Kind.WEAPON or kind == Kind.FILTER else maxi(max_stack, 1)

func key() -> String:
	return String(id) if not id.is_empty() else (resource_path if not resource_path.is_empty() else display_name + ":" + str(kind))

func kind_name() -> String:
	return ["Оружие", "Патроны", "Медикаменты", "Фильтр"][kind]
