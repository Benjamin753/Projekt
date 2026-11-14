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
	game.previous_ball = at

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
	game.start_round()
	game.credit = 1000
	check(not game.buy_pin(0), "Pin purchases must be blocked during play.")
	game.lose_ball()
	game.lose_ball()
	check(game.balls_left == 2, "A round loss removes a single ball.")
	check(game.buy_pin(0) and game.buy_pin(0), "Two affordable upgrades can be purchased in one shop.")
	check(game.pin_levels[0] == 2 and game.pin_levels[1] == 0, "An upgrade affects only the chosen pin.")
	check(game.credit == 550 and game.score == 0, "Purchases spend credit and preserve score.")
	game.start_round()
	check(game.pin_levels[0] == 2, "Pin upgrades carry over into the next round.")
	game.lose_ball()
	game.start_round()
	game.lose_ball()
	check(game.balls_left == 0 and not game.buy_pin(0), "Three losses end the run and close purchases.")
	game.new_run()
	check(game.pin_levels[0] == 0 and game.balls_left == 3, "A new run resets upgrades and lives.")
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
	place_ball(game, Vector2(150, 282), Vector2(0, -500))
	for step in 14:
		await physics_frame
	check(game.score == score_before + 25, "One pin contact adds 25 points. Got %s." % (game.score - score_before))
	check(is_instance_valid(game.ball) and game.ball.linear_velocity.y > 0.0, "The ball rebounds from the pin.")
	if not is_instance_valid(game.ball):
		quit(1)
		return
	place_ball(game, Vector2(96, 320), Vector2(0, 1100))
	for step in 8:
		await physics_frame
	check(game.balls_left == 2 and not is_instance_valid(game.ball), "A fast ball entering a side hole ends the round.")
	game.new_run()
	for step in 105:
		await physics_frame
	check(game.score > 0 and game.balls_left == 3, "The launcher sends the ball into play and reaches a pin.")
	if is_instance_valid(game.ball):
		place_ball(game, Vector2(366, 240), Vector2(0, -1000))
		for step in 10:
			await physics_frame
		check(game.balls_left == 2, "The upper-right hole also ends a round.")
		game.start_round()
		await physics_frame
		place_ball(game, Vector2(240, 690), Vector2(0, 1000))
		for step in 10:
			await physics_frame
		check(game.balls_left == 1, "The center drain ends a round.")
	if failures == 0:
		print("Steel Ballz Run checks passed")
	quit(1 if failures else 0)
