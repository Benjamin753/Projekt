extends SceneTree

var failures := 0
var activations := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)

func extract(path: String) -> Node2D:
	var table: Node2D = load("res://table.tscn").instantiate()
	var part: Node2D = table.get_node(path)
	part.get_parent().remove_child(part)
	table.free()
	part.position = Vector2.ZERO
	root.add_child(part)
	return part

func make_ball(at: Vector2, velocity: Vector2) -> RigidBody2D:
	var ball: RigidBody2D = load("res://ball.tscn").instantiate()
	ball.position = at
	ball.linear_velocity = velocity
	ball.gravity_scale = 0.0
	root.add_child(ball)
	return ball

func pad_test(path: String, point: Vector2, normal: Vector2) -> void:
	var pad = extract(path)
	activations = 0
	pad.activated.connect(func(): activations += 1)
	var ball := make_ball(pad.to_global(point + normal * 42.0), -normal.rotated(pad.rotation) * 300.0)
	ball.angular_velocity = 8.0
	for frame in 24:
		await physics_frame
	var outgoing := ball.linear_velocity.dot(normal.rotated(pad.rotation))
	check(activations == 1, "%s kicks once per contact, got %s." % [path, activations])
	check(outgoing > 300.0 and outgoing < 1000.0, "%s provides a bounded outward kick, got %s." % [path, outgoing])
	var origin: Vector2 = pad.to_global(point + normal * 42.0)
	PhysicsServer2D.body_set_state(ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, origin))
	PhysicsServer2D.body_set_state(ball.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, -normal.rotated(pad.rotation) * 300.0)
	for frame in 24:
		await physics_frame
	check(activations == 2, "%s kicks again after a separate return contact." % path)
	var fast_outgoing := normal.rotated(pad.rotation) * 1100.0
	check(pad.bounce_velocity(fast_outgoing, normal.rotated(pad.rotation)).is_equal_approx(fast_outgoing), "An already fast outward ball gets no further acceleration.")
	ball.queue_free()
	pad.queue_free()
	await process_frame

func flipper_test(side: String, charge: float, offset: float) -> Vector2:
	var flipper = extract(side)
	await physics_frame
	await physics_frame
	var ball := make_ball(flipper.to_global(Vector2(offset * flipper.side, -24)), Vector2(0, 100))
	await physics_frame
	flipper.held = charge
	flipper.set_pressed(true, 3.0)
	for frame in 10:
		await physics_frame
	var velocity := ball.linear_velocity
	check(flipper.struck, "%s registers the rising surface contact." % side)
	check(velocity.y < -100, "%s sends the ball upward, got %s." % [side, velocity])
	ball.queue_free()
	flipper.queue_free()
	await process_frame
	return velocity

func run() -> void:
	for path in ["UpperLeft", "UpperRight", "LowerLeft", "LowerRight"]:
		await pad_test("BouncePads/" + path, Vector2.ZERO, Vector2.UP)
	var corners := [Vector2(0, -30), Vector2(46, 0), Vector2(0, 30), Vector2(-46, 0)]
	for index in 4:
		var a: Vector2 = corners[index]
		var b: Vector2 = corners[(index + 1) % 4]
		var edge := b - a
		await pad_test("BouncePads/Diamond", (a + b) / 2, Vector2(edge.y, -edge.x).normalized())

	var normal := await flipper_test("LeftFlipper", 0.0, 65.0)
	var charged := await flipper_test("LeftFlipper", 2.0, 65.0)
	check(charged.length() > normal.length() * 1.4, "A charged strike is substantially stronger than a normal strike.")
	var right := await flipper_test("RightFlipper", 0.0, 65.0)
	check(absf(right.y - normal.y) < 20 and absf(right.x + normal.x) < 20, "Mirrored flippers have mirrored strike trajectories.")
	var tip := await flipper_test("LeftFlipper", 0.0, 95.0)
	check(tip.length() > normal.length(), "The faster moving tip delivers a stronger strike.")

	var flipper = extract("LeftFlipper")
	flipper.set_pressed(true, 3.0)
	for frame in 30:
		await physics_frame
	var ball := make_ball(flipper.to_global(Vector2(65, -35)), Vector2(0, 180))
	for frame in 20:
		await physics_frame
	check(ball.linear_velocity.length() < 220, "A stationary held flipper does not create repeated powered strikes.")
	check(not flipper.struck, "Landing on a stationary flipper does not consume its charge.")
	if failures == 0:
		print("Bounce pad and flipper checks passed")
	quit(1 if failures else 0)
