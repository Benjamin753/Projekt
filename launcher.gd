@tool
extends Node2D

var compression := 0.0:
	set(value):
		compression = clampf(value, 0.0, 1.0)
		queue_redraw()

func _draw() -> void:
	if not has_node("Spawn"):
		return
	var top: Vector2 = $Spawn.position.lerp($PullEnd.position, compression) + Vector2(0, 12)
	var bottom: Vector2 = $SpringBottom.position
	var points := PackedVector2Array([top])
	for index in 13:
		var point: Vector2 = top.lerp(bottom, (index + 1) / 14.0)
		point.x += 10.0 if index % 2 == 0 else -10.0
		points.append(point)
	points.append(bottom)
	draw_polyline(points, Color("#142b3c"), 6.0, true)
	draw_polyline(points, Color("#8babc0"), 2.5, true)
	draw_line(top + Vector2(-13, -2), top + Vector2(13, -2), Color("#e9ddca"), 4, true)
