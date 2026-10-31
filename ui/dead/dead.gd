extends Control

func _on_back_pressed() -> void:
	TransitionTort.change_scene("res://ui/menu/menu.tscn")
	get_tree().paused = false
	
	
#код для вызова из метода умирания:
	#var scene_setting = preload("res://ui/dead/dead.tscn")
	#var scene =  scene_setting.instantiate()
	#add_child(scene)
	#get_tree().paused = true
#камеру я сама скрою потом
