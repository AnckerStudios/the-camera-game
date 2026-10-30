extends CanvasLayer


func change_scene(target: String):
	#$AudioStreamPlayer.play()
	$AnimationPlayer.play("dissolve")
	await  $AnimationPlayer.animation_finished
	get_tree().change_scene_to_file(target)
	$AnimationPlayer.play_backwards("dissolve")
	
func start_scene():
	$AnimationPlayer.play('start_animation')
	await $AnimationPlayer.animation_finished
	$AnimationPlayer.play_backwards('dissolve')
