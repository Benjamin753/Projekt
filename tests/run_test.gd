extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)

func frames(count: int) -> void:
	for frame in count:
		await physics_frame
	await process_frame

func launch(game, seconds: float = 1.7) -> void:
	game.set_spring_pressed(true)
	game._physics_process(seconds)
	game.set_spring_pressed(false)

func place_ball(game, at: Vector2, velocity: Vector2) -> void:
	PhysicsServer2D.body_set_state(game.ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0, at))
	PhysicsServer2D.body_set_state(game.ball.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, velocity)

func run() -> void:
	var game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	if not "high_score_path" in game:
		check(false, "Game must provide an isolated high-score path.")
		game.free()
		quit(1)
		return
	game.high_score_path = "res://.godot/test_run_highscore.cfg"
	if FileAccess.file_exists(game.high_score_path):
		DirAccess.remove_absolute(game.high_score_path)
	root.add_child(game)
	check(game.high_score == 0, "A missing high-score file starts at zero.")
	check(is_equal_approx(game.charge_multiplier(0.5), 1.25), "Half a second gives 1.25x strength.")
	check(is_equal_approx(game.charge_multiplier(2.0), 2.0), "Two seconds gives 2x strength.")
	check(is_equal_approx(game.charge_multiplier(5.0), 2.0), "Charge cannot exceed 2x strength.")
	check(game.phase == game.Phase.START and game.ball.freeze and not game.menu.visible, "The table starts with a waiting ball and no start menu.")
	game._physics_process(1.0)
	check(game.ball.linear_velocity == Vector2.ZERO, "A waiting ball does not launch itself.")
	launch(game, 0.5)
	var weak_speed: float = game.ball.linear_velocity.length()
	check(weak_speed > 0 and weak_speed < 500, "A short pull gives a weak shot.")
	game.lose_ball()
	game.new_run()
	launch(game, 1.7)
	check(game.ball.linear_velocity.length() > weak_speed * 2, "A longer pull changes launch speed.")
	check(game.pin_levels.size() == 4 and game.pin_levels.all(func(level): return level == 1), "All four pins start at level 1.")
	game.credit = 1000
	check(not game.buy_pin(0) and not game.buy_extra_life(), "Purchases must be blocked during play.")
	game.lose_ball()
	game.lose_ball()
	check(game.balls_left == 2, "A round loss removes a single ball.")
	check(game.buy_pin(0) and game.buy_pin(0), "Two affordable upgrades can be purchased in one shop.")
	check(game.pin_levels[0] == 3 and game.pin_levels[1] == 1, "An upgrade affects only the chosen pin.")
	check(game.credit == 200 and game.score == 0, "Purchases spend credit and preserve score.")
	check(not game.buy_pin(0), "An unaffordable next level is rejected.")
	game.credit = 499
	check(not game.buy_extra_life(), "An extra life requires 500 credit.")
	game.credit = 2000
	for purchase in 3:
		check(game.buy_extra_life(), "Three extra lives can be purchased per run.")
	check(game.balls_left == 5 and game.credit == 500 and game.extra_lives_bought == 3, "Extra lives cost 500 each and increase the remaining balls.")
	check(not game.buy_extra_life(), "A fourth extra life is rejected even with enough credit.")
	game.start_round()
	launch(game)
	check(game.pin_levels[0] == 3, "Pin upgrades carry into the next round.")
	game.lose_ball()
	check(not game.buy_extra_life(), "The three-life cap survives later shop visits.")
	game.score = 1234
	game.update_high_score()
	check(game.high_score == 1234 and FileAccess.file_exists(game.high_score_path), "A new record is persisted.")
	game.score = 400
	game.update_high_score()
	check(game.high_score == 1234, "A lower score cannot overwrite the record.")
	game.high_score = 0
	game.load_high_score()
	check(game.high_score == 1234, "A saved record reloads correctly.")
	game.new_run()
	check(game.pin_levels[0] == 1 and game.balls_left == 3 and game.extra_lives_bought == 0, "A new run resets upgrades, lives and the extra-life limit.")
	check(game.high_score == 1234, "A new run preserves the best score.")
	check(not game.buy_extra_life(), "Extra lives are unavailable while waiting to launch.")
	launch(game)
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
	left.position = game.flippers[0].to_global(Vector2(game.flippers[0].length * 0.5, 0))
	var right := InputEventScreenTouch.new()
	right.index = 1
	right.pressed = true
	right.position = game.flippers[1].to_global(Vector2(-game.flippers[1].length * 0.5, 0))
	root.push_input(left, true)
	root.push_input(right, true)
	check(game.flippers[0].pressed and game.flippers[1].pressed, "Two fingers can hold both flippers.")
	await frames(63)
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
	game.lose_ball()
	game.new_run()
	launch(game)
	await frames(150)
	check(game.balls_left == 3 and is_instance_valid(game.ball) and game.ball.global_position.x < game.get_node("Table/Launcher/Spawn").global_position.x - 20, "The launcher sends the ball into play.")
	if is_instance_valid(game.ball):
		var drain: Area2D = game.get_node("Table/Drain")
		place_ball(game, drain.global_position, Vector2(0, 300))
		await frames(8)
		check(game.balls_left == 2, "Entering the configured drain ends a round.")
	check(game.get_node("Table/BouncePads").get_child_count() == 3, "The scene contains two upper pads and a diamond.")
	check(game.get_node("Table/Slingshots").get_child_count() == 2, "Both lower slingshots are present.")
	if game.phase == game.Phase.PLAY:
		game.lose_ball()
	game.new_run()
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	root.push_input(space, true)
	await frames(30)
	check(game.ball.freeze and game.spring_charge > 0.2, "Space pulls the spring while the ball waits.")
	space = space.duplicate()
	space.pressed = false
	root.push_input(space, true)
	check(game.phase == game.Phase.PLAY and not game.ball.freeze, "Space release launches the ball.")
	await frames(200)
	check(game.phase == game.Phase.START and game.balls_left == 3, "A weak shot returns to the spring without losing a ball.")
	await frames(120)
	check(game.phase == game.Phase.START and game.ball.freeze, "The returned ball waits for another manual pull.")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("res://.godot/test_run_highscore.cfg")
	if failures == 0:
		print("Steel Ballz Run lifecycle, persistence and input checks passed")
	quit(1 if failures else 0)

