extends AudioStreamPlayer3D
## Запись шагов играет только при реальном движении по земле.
func _ready() -> void:
	if not stream:
		stream = preload("res://resources/music/фаст_шаг.mp3")
	# Зацикливаем только локальную копию, не изменяя импортированный ресурс.
	stream = stream.duplicate()
	if stream is AudioStreamMP3:
		stream.loop = true

func update_movement(moving: bool, speed_ratio: float) -> void:
	if not moving:
		if playing:
			stop()
		return
	pitch_scale = clampf(speed_ratio, 0.85, 1.2)
	if not playing:
		play()
