@tool
extends Node2D

func _draw() -> void:
	draw_circle(Vector2(1.5, 2.5), 7.0, Color("#17141391"), true, -1.0, true)
	draw_circle(Vector2.ZERO, 5.7, Color("#313033"), true, -1.0, true)
	draw_arc(Vector2.ZERO, 5.1, -2.95, 0.10, 18, Color("#ece7d9"), 1.1, true)
	draw_circle(Vector2.ZERO, 3.9, Color("#a4a3a0"), true, -1.0, true)
	draw_circle(Vector2(-0.45, -0.6), 2.9, Color("#c6c5bf"), true, -1.0, true)
	draw_line(Vector2(-1.65, -0.85), Vector2(1.65, 0.85), Color("#514e4b"), 0.9, true)
