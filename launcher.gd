@tool
extends Node2D

var compression := 0.0:
	set(value):
		var next := clampf(value, 0.0, 1.0)
		if not is_equal_approx(compression, next):
			compression = next
			queue_redraw()

func _draw() -> void:
	if not has_node("Spawn"):
		return
	var seat: Vector2 = $Spawn.position.lerp($PullEnd.position, compression)
	var bottom: Vector2 = $SpringBottom.position
	var top := seat + Vector2(0, 11.0)
	var points := PackedVector2Array()
	var shadows := PackedVector2Array()
	var highlights := PackedVector2Array()
	for index in 73:
		var turn := index / 72.0
		var angle := turn * TAU * 5.6
		var point := top.lerp(bottom, turn)
		point += Vector2(sin(angle) * 9.6, cos(angle) * minf(1.6, (bottom.y - top.y) * 0.095))
		points.append(point)
		shadows.append(point + Vector2(1.6, 2.2))
		highlights.append(point - Vector2(0.65, 0.75))
	draw_line(top, bottom, Color("#423932"), 7.0, true)
	draw_line(top - Vector2(1.4, 0), bottom - Vector2(1.4, 0), Color("#a89e8e"), 2.2, true)
	draw_polyline(shadows, Color("#1e1917"), 4.8, true)
	draw_polyline(points, Color("#76716b"), 3.6, true)
	draw_polyline(highlights, Color("#d8d2c5"), 1.15, true)
	draw_line(top - Vector2(12, 1.8), top + Vector2(12, -1.8), Color("#817e74"), 5, true)
	draw_line(top - Vector2(11, 3.2), top + Vector2(11, -3.2), Color("#e0d8c6"), 1.3, true)
