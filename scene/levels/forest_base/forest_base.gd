extends Node3D

@export_range(-40.0, 0.0, 1.0) var music_volume_db: float = -20.0
@export_range(0.1, 5.0, 0.1) var music_transition_seconds: float = 1.0
var _beat_started := false
var _music_tween: Tween
@onready var _forest_music: AudioStreamPlayer = $ForestMusic
@onready var _beat_music: AudioStreamPlayer = $ForestBeatMusic

func _ready() -> void:
	MenuState.state = false
	_enable_loop(_forest_music)
	_enable_loop(_beat_music)
	_forest_music.volume_db = music_volume_db
	_forest_music.play()
	for item in get_tree().get_nodes_in_group(&"pickup_items" ):
		_connect_pickup(item)
	get_tree().node_added.connect(_on_music_node_added)

func _enable_loop(player: AudioStreamPlayer) -> void:
	if player.stream:
		player.stream = player.stream.duplicate()
		if player.stream is AudioStreamMP3:
			player.stream.loop = true

func _on_music_node_added(node: Node) -> void:
	if node is PickupItem:
		_connect_pickup.call_deferred(node)

func _connect_pickup(item: Node) -> void:
	if not is_instance_valid(item) or not item is PickupItem or not is_ancestor_of(item):
		return
	if not item.picked_up.is_connected(_on_music_item_picked_up):
		item.picked_up.connect(_on_music_item_picked_up)

## Сигнал приходит только после успешного добавления предмета в инвентарь.
func _on_music_item_picked_up(item: PickupItem, _receiver: Node3D) -> void:
	if _beat_started or not item.inventory_item:
		return
	var data := item.inventory_item
	if data.kind != InventoryItem.Kind.WEAPON or data.weapon_id != &"WeaponDoubleShotgun":
		return
	_beat_started = true
	_beat_music.volume_db = -80.0
	_beat_music.play()
	_music_tween = create_tween().set_parallel(true)
	# Музыка и переход продолжаются во время осмотра предмета и паузы.
	_music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.tween_property(_forest_music, "volume_db", -80.0, music_transition_seconds)
	_music_tween.tween_property(_beat_music, "volume_db", music_volume_db, music_transition_seconds)
	_music_tween.chain().tween_callback(_forest_music.stop)
