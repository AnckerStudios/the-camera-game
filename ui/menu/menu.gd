extends Control
var scene_setting = preload("res://ui/options/options.tscn")

func _ready():
	MenuState.state = true

func _on_play_button_pressed() -> void:
	TrToPlay.start_loading("res://scene/ilya/ilya_v1_doma.tscn")
	#TransitionTort.change_scene("res://scene/ilya/ilya_v1_doma.tscn")

func _on_options_button_pressed() -> void:
	var scene =  scene_setting.instantiate()
	add_child(scene)

func _on_quit_button_pressed() -> void:
	get_tree().quit()
