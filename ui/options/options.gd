extends Control
@onready var h_slider: HSlider = $Options/VBoxContainer/HSlider
@onready var back: Button = $Options/VBoxContainer/Back
@onready var label: Label = $Label

func _ready() -> void:
	if MenuState.state :
		back.text = "назад"
		label.visible = true
	else :
		back.text = "в меню"
		label.visible = false
	
func _on_back_pressed() -> void:
	if MenuState.state :
		back_to_tree()
	else :
		get_tree().paused = false
		TransitionTort.change_scene("res://ui/menu/menu.tscn")

func back_to_tree() -> void:
		get_tree().paused = false
		queue_free()
		
func pause():
	_ready()
