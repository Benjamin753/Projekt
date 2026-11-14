extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)

func place_ball(game, at: Vector2, velocity: Vector2) -> void:
	var body: RigidBody2D = game.ball
	var rid := body.get_rid()
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0, at))
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, velocity)

func launch(game, seconds: float = 1.7) -> void:
	game.set_spring_pressed(true)
	game._physics_process(seconds)
	game.set_spring_pressed(false)

func run() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	var scene := load(main_scene) as PackedScene if not main_scene.is_empty() else null
	if scene == null:
		check(false, "The project needs a playable main scene.")
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	check(game.has_method("charge_multiplier"), "The starting scene must implement charged shots.")
	if failures > 0:
		quit(1)
		return
	check(is_equal_approx(game.charge_multiplier(0.5), 1.25), "Half a second gives 1.25x strength.")
	check(is_equal_approx(game.charge_multiplier(2.0), 2.0), "Two seconds gives 2x strength.")
	check(is_equal_approx(game.charge_multiplier(5.0), 2.0), "Charge cannot exceed 2x strength.")
	check(game.phase == game.Phase.START and game.ball.freeze and not game.menu.visible, "The table starts with a waiting ball and no start menu.")
	game._physics_process(1.0)
	check(game.ball.linear_velocity == Vector2.ZERO, "A waiting ball does not launch itself.")
	game.start_round()
	launch(game, 0.5)
	var weak_speed: float = game.ball.linear_velocity.length()
	check(weak_speed > 0 and weak_speed < 500, "A short pull gives a weak shot.")
	game.lose_ball()
	game.new_run()
	launch(game, 1.7)
	check(game.ball.linear_velocity.length() > weak_speed * 2, "A longer pull changes launch speed.")
	check(game.pin_levels.size() == 4 and game.pin_levels.all(func(level): return level == 1), "All four pins start at level 1.")
	game.credit = 1000
	check(not game.buy_pin(0), "Pin purchases must be blocked during play.")
	game.lose_ball()
	game.lose_ball()
	check(game.balls_left == 2, "A round loss removes a single ball.")
	check(game.buy_pin(0) and game.buy_pin(0), "Two affordable upgrades can be purchased in one shop.")
	check(game.pin_levels[0] == 3 and game.pin_levels[1] == 1, "An upgrade affects only the chosen pin.")
	check(game.credit == 0 and game.score == 0, "Purchases spend credit and preserve score.")
	check(not game.buy_pin(0), "Level 3 is the pin upgrade limit.")
	game.start_round()
	launch(game)
	check(game.pin_levels[0] == 3, "Pin upgrades carry over into the next round.")
	game.lose_ball()
	game.start_round()
	launch(game)
	game.lose_ball()
	check(game.balls_left == 0 and not game.buy_pin(0), "Three losses end the run and close purchases.")
	game.new_run()
	launch(game)
	check(game.pin_levels[0] == 1 and game.balls_left == 3, "A new run resets upgrades and lives.")
	var charge_flipper = game.flippers[0]
	charge_flipper.set_pressed(true, 3.0)
	charge_flipper._physics_process(2.0)
	charge_flipper.set_pressed(false, 3.0)
	check(is_equal_approx(charge_flipper.held, 2.0), "Release preserves the full charge.")
	charge_flipper._physics_process(1.5)
	check(is_equal_approx(charge_flipper.held, 1.0), "Half the charge remains after 1.5 seconds.")
	charge_flipper.set_pressed(true, 3.0)
	check(is_equal_approx(charge_flipper.strike_power, 1.5), "The next strike uses the remaining charge.")
	charge_flipper.set_pressed(false, 3.0)
	charge_flipper._physics_process(2.0)
	check(is_zero_approx(charge_flipper.held), "Charge decays to zero without going negative.")
	charge_flipper.reset()
	var left := InputEventScreenTouch.new()
	left.index = 0
	left.pressed = true
	left.position = Vector2(105, 675)
	var right := InputEventScreenTouch.new()
	right.index = 1
	right.pressed = true
	right.position = Vector2(375, 675)
	root.push_input(left, true)
	root.push_input(right, true)
	check(game.flippers[0].pressed and game.flippers[1].pressed, "Two fingers can hold both flippers.")
	for step in 63:
		await physics_frame
	var release := left.duplicate() as InputEventScreenTouch
	release.pressed = false
	root.push_input(release, true)
	check(not game.flippers[0].pressed and game.flippers[1].pressed, "Releasing one finger preserves the other.")
	root.push_input(left.duplicate(), true)
	check(game.flippers[0].strike_power > 1.2 and game.flippers[0].strike_power < 1.3, "A release and re-press uses the partial charge.")

	var key := InputEventKey.new()
	key.physical_keycode = KEY_A
	key.pressed = true
	root.push_input(key, true)
	root.push_input(release.duplicate(), true)
	check(game.flippers[0].pressed, "Holding A keeps the left flipper up after touch release.")
	key = key.duplicate()
	key.pressed = false
	root.push_input(key, true)
	check(not game.flippers[0].pressed, "Releasing A lowers the left flipper.")

	# A real physics contact must award points once and reverse the ball's direction.
	var score_before: int = game.score
	place_ball(game, Vector2(175, 305), Vector2(0, -500))
	for step in 14:
		await physics_frame
	check(game.score == score_before + 100, "One golden pin contact adds 100 points. Got %s." % (game.score - score_before))
	check(is_instance_valid(game.ball) and game.ball.linear_velocity.y > 0.0, "The ball rebounds from the pin.")
	if not is_instance_valid(game.ball):
		quit(1)
		return
	place_ball(game, Vector2(94, 412), Vector2(0, 700))
	for step in 8:
		await physics_frame
	check(game.balls_left == 3, "The former side hole is now solid table.")
	game.lose_ball()
	game.new_run()
	launch(game)
	for step in 150:
		await physics_frame
	check(game.balls_left == 3 and game.ball.position.x < 390, "The launcher sends the ball into play.")
	if is_instance_valid(game.ball):
		place_ball(game, Vector2(240, 720), Vector2(0, 1000))
		for step in 10:
			await physics_frame
		check(game.balls_left == 2, "Passing below the flippers ends a round.")
	check(game.get_node("Table/BouncePads").get_child_count() == 5, "The scene contains four pads and a solid diamond.")
	check(game.get_node("Table/MultiplierZones").get_child_count() == 2, "Two sensor zones are placed beside the diamond.")
	# Sample guide ends, side passages and the shooter lane for resting traps.
	for origin in [Vector2(65, 350), Vector2(98, 350), Vector2(355, 350), Vector2(390, 350), Vector2(427, 735), Vector2(50, 560), Vector2(390, 560), Vector2(155, 437)]:
		if is_instance_valid(game.ball):
			game.lose_ball()
		game.new_run()
		launch(game)
		await physics_frame
		place_ball(game, origin, Vector2(9, 35))
		var resting_frames := 0
		for frame in 720:
			await physics_frame
			if not is_instance_valid(game.ball) or game.phase == game.Phase.START:
				break
			if game.ball.linear_velocity.length() < 12.0:
				resting_frames += 1
			else:
				resting_frames = 0
			if resting_frames >= 120:
				break
		check(resting_frames < 120, "The ball must leave the guide passage at %s." % origin)
	if is_instance_valid(game.ball):
		game.ball.queue_free()
		game.ball = null
	await process_frame
	game.phase = game.Phase.OVER
	game.new_run()
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	root.push_input(space, true)
	for frame in 30:
		await physics_frame
	check(game.ball.freeze and game.spring_charge > 0.2, "Space pulls the spring while the ball waits.")
	space = space.duplicate()
	space.pressed = false
	root.push_input(space, true)
	check(game.phase == game.Phase.PLAY and not game.ball.freeze, "Space release launches the ball.")
	for frame in 200:
		await physics_frame
	check(game.phase == game.Phase.START and game.balls_left == 3, "A weak shot returns to the spring without losing a ball.")
	for frame in 120:
		await physics_frame
	check(game.phase == game.Phase.START and game.ball.freeze, "The returned ball waits for another manual pull.")
	if failures == 0:
		print("Steel Ballz Run checks passed")
	quit(1 if failures else 0)
