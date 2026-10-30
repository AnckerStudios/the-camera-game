extends CheckBox
var index = AudioServer.get_bus_index("Master")

func _ready():
	button_pressed = AudioServer.is_bus_mute(index)

func _on_pressed() -> void:
	AudioServer.set_bus_mute(index, button_pressed)
