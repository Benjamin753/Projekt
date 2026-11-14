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

func world_normal(node: Node2D, normal: Vector2) -> Vector2:
	var inverse := node.global_transform.affine_inverse()
	return Vector2(inverse.x.dot(normal), inverse.y.dot(normal)).normalized()

func make_ball(at: Vector2, velocity: Vector2) -> RigidBody2D:
	var ball: RigidBody2D = load("res://ball.tscn").instantiate()
	ball.position = at
	ball.linear_velocity = velocity
	ball.gravity_scale = 0.0
	root.add_child(ball)
	return ball

func pad_test(path: String, point: Vector2, normal: Vector2, powered := true) -> void:
	var pad = extract(path)
	activations = 0
	pad.activated.connect(func(): activations += 1)
	var outward_normal := world_normal(pad, normal)
	var origin: Vector2 = pad.to_global(point) + outward_normal * 42.0
	var ball := make_ball(origin, -outward_normal * 300.0)
	ball.angular_velocity = 8.0
	for frame in 30:
		await physics_frame
	var outgoing := ball.linear_velocity.dot(outward_normal)
	check(activations == (1 if powered else 0), "%s %s activates %s times, got %s." % [path, normal, 1 if powered else 0, activations])
	if powered:
		check(outgoing > 300.0 and outgoing < 1000.0, "%s gives its front a bounded outward kick, got %s." % [path, outgoing])
		PhysicsServer2D.body_set_state(ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, origin))
		PhysicsServer2D.body_set_state(ball.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, -outward_normal * 300.0)
		for frame in 30:
			await physics_frame
		check(activations == 2, "%s kicks again on a separate return contact." % path)
	else:
		check(outgoing > 0.0 and outgoing < 300.0, "%s back or end remains a passive energy-losing wall, got %s." % [path, outgoing])
	var fast_outgoing := outward_normal * 1100.0
	check(pad.bounce_velocity(fast_outgoing, outward_normal).is_equal_approx(fast_outgoing), "An already fast outward ball gets no further acceleration.")
	ball.queue_free()
	pad.queue_free()
	await process_frame

func orientation_test(path: String) -> void:
	var pad = extract(path)
	pad.rotation += 0.43
	pad.scale = Vector2(1.5, 0.7)
	pad.skew = 0.3
	var normal := world_normal(pad, pad.active_normal)
	activations = 0
	pad.activated.connect(func(): activations += 1)
	var velocity := normal * 100.0
	check(pad.bounce_velocity(velocity, normal).dot(normal) > 100.0, "A rotated/scaled active face still supplies an outward kick.")
	check(activations == 1, "The transformed front activates once.")
	var back := -normal * 100.0
	check(pad.bounce_velocity(back, -normal).is_equal_approx(back), "A rotated/scaled back is passive.")
	check(activations == 1, "The back does not fire the active-face signal.")
	var tangent := Vector2(-normal.y, normal.x)
	check(pad.bounce_velocity(tangent * 100.0, tangent).is_equal_approx(tangent * 100.0), "The pad end is passive.")
	var rail: PhysicsMaterial = load("res://assets/pinball/rail_material.tres")
	check(is_equal_approx(pad.physics_material_override.bounce, rail.bounce), "Passive pad restitution matches the rail.")
	pad.queue_free()
	await process_frame

func flipper_test(side: String, charge: float, fraction: float) -> Vector2:
	var flipper = extract(side)
	await physics_frame
	await physics_frame
	var ball := make_ball(flipper.to_global(Vector2(flipper.length * fraction * flipper.side, -24)), Vector2(0, 100))
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
	for path in ["UpperLeft", "UpperRight"]:
		await pad_test("BouncePads/" + path, Vector2.ZERO, Vector2.UP)
		await pad_test("BouncePads/" + path, Vector2.ZERO, Vector2.DOWN, false)
		await orientation_test("BouncePads/" + path)
	var corners := [Vector2(0, -16), Vector2(50, 0), Vector2(0, 16), Vector2(-50, 0)]
	for index in 4:
		var a: Vector2 = corners[index]
		var b: Vector2 = corners[(index + 1) % 4]
		var edge := b - a
		await pad_test("BouncePads/Diamond", (a + b) / 2, Vector2(edge.y, -edge.x).normalized())
	for side in ["Left", "Right"]:
		await orientation_test("Slingshots/" + side + "/ActiveFace")
		await pad_test("Slingshots/" + side + "/ActiveFace", Vector2.ZERO, Vector2.UP)
		await pad_test("Slingshots/" + side + "/ActiveFace", Vector2.ZERO, Vector2.DOWN, false)
		var sling = extract("Slingshots/" + side)
		check(sling.get_child_count() >= 3, "Each slingshot has an active inner face and passive outer/bottom walls.")
		for child in sling.get_children():
			if child is StaticBody2D and child.name != "ActiveFace":
				check(not child.has_method("bounce_velocity"), "Slingshot outer and bottom walls have no active kick.")
		sling.queue_free()
		await process_frame
	var normal := await flipper_test("LeftFlipper", 0.0, 0.58)
	var charged := await flipper_test("LeftFlipper", 2.0, 0.58)
	check(charged.length() > normal.length() * 1.4, "A charged strike is substantially stronger than a normal strike.")
	var right := await flipper_test("RightFlipper", 0.0, 0.58)
	check(absf(right.y - normal.y) < 20 and absf(right.x + normal.x) < 20, "Mirrored flippers have mirrored strike trajectories.")
	var tip := await flipper_test("LeftFlipper", 0.0, 0.85)
	check(tip.length() > normal.length(), "The faster moving tip delivers a stronger strike.")
	var flipper = extract("LeftFlipper")
	flipper.set_pressed(true, 3.0)
	for frame in 30:
		await physics_frame
	var ball := make_ball(flipper.to_global(Vector2(flipper.length * 0.58, -35)), Vector2(0, 180))
	for frame in 20:
		await physics_frame
	check(ball.linear_velocity.length() < 220, "A stationary held flipper does not create repeated powered strikes.")
	check(not flipper.struck, "Landing on a stationary flipper does not consume its charge.")
	if failures == 0:
		print("Directional pad, diamond, slingshot and flipper checks passed")
	quit(1 if failures else 0)

