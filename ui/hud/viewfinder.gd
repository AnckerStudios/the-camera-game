extends Control

## Рамка видоискателя: уголки по краям экрана и перекрестие в центре.

@export var color := Color(1, 1, 1, 0.75)
@export var margin := 24.0
@export var corner_length := 48.0
@export var line_width := 3.0
@export var cross_size := 12.0


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var r := Rect2(Vector2(margin, margin), size - Vector2(margin, margin) * 2.0)
	var corners := [
		[r.position, Vector2.RIGHT, Vector2.DOWN],
		[Vector2(r.end.x, r.position.y), Vector2.LEFT, Vector2.DOWN],
		[Vector2(r.position.x, r.end.y), Vector2.RIGHT, Vector2.UP],
		[r.end, Vector2.LEFT, Vector2.UP],
	]
	for c in corners:
		draw_line(c[0], c[0] + c[1] * corner_length, color, line_width)
		draw_line(c[0], c[0] + c[2] * corner_length, color, line_width)
