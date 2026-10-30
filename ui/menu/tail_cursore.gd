extends Line2D
@export var max_points: int = 20

func _ready():
	clear_points()

func _process(_delta):
	var mouse_pos = get_global_mouse_position()
	add_point(mouse_pos)
	while points.size() > max_points:
		remove_point(0)
