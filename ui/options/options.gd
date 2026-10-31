extends Control
@onready var h_slider: HSlider = $Options/VBoxContainer/HSlider
@onready var back: Button = $Options/VBoxContainer/Back
@onready var label: Label = $Label
@onready var h_box_container: HBoxContainer = $Options/VBoxContainer/HBoxContainer

func _ready() -> void:
	if MenuState.state :
		back.visible = true
		h_box_container.visible = false
		label.visible = true
	else :
		back.visible = false
		h_box_container.visible = true
		label.visible = false
	
func _on_back_pressed() -> void:
	get_tree().paused = false
	queue_free()

func pause():
	_ready()

func _on_back_pause_pressed() -> void:
	$"..".from_optional()

func _on_back_menu_pressed() -> void:
	TransitionTort.change_scene("res://ui/menu/menu.tscn")
	get_tree().paused = false
