extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)

func run() -> void:
	var scene := load("res://ball.tscn") as PackedScene
	var ball := scene.instantiate() as RigidBody2D
	ball.gravity_scale = 0.0
	ball.linear_velocity = Vector2(200, 0)
	root.add_child(ball)
	for step in 120:
		await physics_frame
	check(ball.linear_velocity.x > 170 and ball.linear_velocity.x < 195, "Rolling resistance slows the ball gradually.")
	ball.queue_free()
	await process_frame

	var wall := StaticBody2D.new()
	wall.position = Vector2(100, 0)
	wall.physics_material_override = load("res://assets/pinball/rail_material.tres")
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8, 1000)
	collision.shape = shape
	wall.add_child(collision)
	root.add_child(wall)
	ball = scene.instantiate()
	ball.gravity_scale = 0.0
	ball.linear_velocity = Vector2(2200, 300)
	root.add_child(ball)
	for step in 12:
		await physics_frame
	check(ball.position.x < 86 and ball.linear_velocity.x < 0, "A fast ball bounces without passing through a thin wall.")
	check(ball.linear_velocity.length() < 2000, "A passive wall loses energy on impact.")
	check(absf(ball.angular_velocity) > 0.1, "An oblique impact transfers tangential motion into spin.")
	ball.queue_free()
	wall.queue_free()
	await process_frame

	ball = scene.instantiate()
	root.add_child(ball)
	for step in 60:
		await physics_frame
	check(ball.linear_velocity.y > 240 and ball.linear_velocity.y < 290, "Table gravity accelerates a free ball downhill.")
	check(absf(ball.linear_velocity.x) < 0.01, "Gravity does not invent sideways drift.")
	if failures == 0:
		print("Ball physics checks passed")
	quit(1 if failures else 0)
