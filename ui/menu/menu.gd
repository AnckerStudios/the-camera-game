extends Control
var scene_setting = preload("res://ui/options/options.tscn")

func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://mainscene.tscn")

func _on_options_button_pressed() -> void:
	var scene =  scene_setting.instantiate()
	add_child(scene)

func _on_quit_button_pressed() -> void:
	get_tree().quit()
	
