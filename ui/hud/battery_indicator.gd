@tool
extends Control

## Иконка батарейки с делениями заряда.

@export_range(0.0, 1.0) var level := 1.0:
	set(value):
		level = clampf(value, 0.0, 1.0)
		queue_redraw()
@export var segments := 4
@export var outline_color := Color(1, 1, 1, 0.85)
@export var full_charge_color := Color(0.2, 0.8, 0.2, 1)
@export var charge_color := Color(0.95, 0.8, 0.2, 1)
@export var low_charge_color := Color(0.9, 0.15, 0.1, 1)
@export_range(0.0, 1.0) var low_threshold := 0.25
@export_range(0.0, 1.0) var full_threshold := 0.9

const OUTLINE_WIDTH := 2.0
const PADDING := 3.0
const SEGMENT_GAP := 2.0
const NUB_WIDTH := 4.0

##Код бога машины + я ебло
func _draw() -> void:
	var body := Rect2(Vector2.ZERO, size - Vector2(NUB_WIDTH, 0))
	draw_rect(body.grow(-OUTLINE_WIDTH / 2.0), outline_color, false, OUTLINE_WIDTH)
	var nub_height := size.y * 0.4
	draw_rect(Rect2(body.end.x, (size.y - nub_height) / 2.0, NUB_WIDTH, nub_height), outline_color)

	var inner := body.grow(-(OUTLINE_WIDTH + PADDING))
	var segment_width := (inner.size.x - SEGMENT_GAP * (segments - 1)) / segments
	var color := full_charge_color
	if level <= low_threshold:
		color = low_charge_color
	elif level > low_threshold && level < full_threshold:
		color = charge_color
	elif level >= full_threshold:
		color = full_charge_color
	var filled := ceili(level * segments)
	for i in filled:
		var x := inner.position.x + i * (segment_width + SEGMENT_GAP)
		draw_rect(Rect2(x, inner.position.y, segment_width, inner.size.y), color)
