class_name Ghost extends Monster

func _ready() -> void:
	super()
	dimension = Dimension.INFRARED
	hp = 200
	move_speed = 3.0
	attack_damage = 15
