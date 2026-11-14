extends StaticBody2D

signal activated

@export var kick_speed := 260.0
@export var maximum_outward_speed := 1000.0
var flash := 0.0

func bounce_velocity(velocity: Vector2, normal: Vector2) -> Vector2:
	var outward := velocity.dot(normal)
	var boost := minf(kick_speed, maxf(0.0, maximum_outward_speed - outward))
	flash = 1.0
	activated.emit()
	return velocity + normal * boost

func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta * 6.0)
	modulate = Color.WHITE.lerp(Color(1.7, 1.7, 1.7), flash)
