extends HSlider
var index = AudioServer.get_bus_index("Music")

func _ready():
	print(AudioServer.get_bus_index("Music"))
	set_value_no_signal(AudioServer.get_bus_volume_linear(index))

func _on_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(index, value)
