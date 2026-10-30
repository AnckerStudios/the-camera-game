extends Control
@onready var h_slider: HSlider = $Options/VBoxContainer/HSlider
	
func _on_back_pressed() -> void:
	get_tree().paused = false
	queue_free()


	
