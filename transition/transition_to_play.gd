extends CanvasLayer
@export var target_scene_path: String = "res://scene/ilya/ilya_v1_doma.tscn"
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var progress: Array = []

func start_loading(scene_path: String) -> void:
	target_scene_path = scene_path
	ResourceLoader.load_threaded_request(target_scene_path)
	$AnimationPlayer.play("dissolve")
	await  $AnimationPlayer.animation_finished
	
func _process(_delta: float) -> void:
	await  $AnimationPlayer.animation_finished
	var status = ResourceLoader.load_threaded_get_status(target_scene_path, progress)
	
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		progress_bar.value = progress[0] * 100
		
	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		progress_bar.value = 100
		var packed_scene = ResourceLoader.load_threaded_get(target_scene_path)
		get_tree().change_scene_to_packed(packed_scene)
		$AnimationPlayer.play_backwards("dissolve")
		await  $AnimationPlayer.animation_finished
		
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		printerr("Ошибка при загрузке сцены!")
