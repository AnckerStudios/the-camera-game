extends Control

func _on_back_pressed() -> void:
	get_tree().paused = false
	TransitionTort.change_scene("res://ui/menu/menu.tscn")
