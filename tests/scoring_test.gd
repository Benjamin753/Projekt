extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)

func place(game, at: Vector2, velocity := Vector2.ZERO) -> void:
	game.ball.freeze = true
	game.ball.position = at
	PhysicsServer2D.body_set_state(game.ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0, at))
	await frames(2)
	game.ball.freeze = false
	game.ball.linear_velocity = velocity

func frames(count: int) -> void:
	for frame in count:
		await physics_frame
	await process_frame

func hit_pin(game, expected: int) -> void:
	var before: int = game.score
	var credit_before: int = game.credit
	await place(game, Vector2(175, 305), Vector2(0, -500))
	await frames(14)
	check(game.score - before == expected, "Pin contact should award %s, got %s." % [expected, game.score - before])
	check(game.credit - credit_before == expected, "Contact awards the same spendable credit.")

func run() -> void:
	var game = load("res://pinball.tscn").instantiate()
	root.add_child(game)
	game.set_spring_pressed(true)
	game._physics_process(1.7)
	game.set_spring_pressed(false)
	game.ball.gravity_scale = 0.0
	await frames(2)
	await hit_pin(game, 100)
	await place(game, Vector2(145, 422))
	await frames(8)
	check(game.multiplier_remaining > 9.8 and game.multiplier_remaining <= 10.0, "Left zone starts ten seconds of double points.")
	game._process(0.0)
	check(game.get_node("HUD/Multiplier").visible, "The bonus countdown is visible.")
	game._physics_process(3.0)
	await frames(8)
	check(game.multiplier_remaining < 7.0 and game.multiplier_remaining > 6.7, "Remaining inside a zone does not refresh the timer.")
	await hit_pin(game, 200)
	check(game.get_node("Table/Pins/UpperLeft/Points").text == "+200", "The hit shows its actual doubled award.")
	check(game.get_node("Table/Pins/UpperLeft/Level").text == "L1", "The level remains on the pin.")
	await place(game, Vector2(307, 422))
	await frames(8)
	check(game.multiplier_remaining > 9.8 and game.multiplier_remaining <= 10.0, "Right zone refreshes to ten seconds without stacking.")
	game._physics_process(11.0)
	game._process(0.0)
	check(game.multiplier_remaining == 0.0 and not game.get_node("HUD/Multiplier").visible, "Expired bonus clamps at zero and hides countdown.")
	await hit_pin(game, 100)
	# Cross the full sensor at the maximum permitted ball speed.
	await place(game, Vector2(145, 370), Vector2(0, 2400))
	await frames(6)
	check(game.multiplier_remaining > 9.9, "A fast crossing still activates the zone.")
	# Keep the ball safe while checking upgrade arithmetic through the scoring callback.
	await place(game, Vector2(145, 422))
	game.ball.linear_velocity = Vector2(700, 0)
	game.pin_levels[0] = 3
	game.pin_hits[0] = 2
	game.upgrade_levels["turbo"] = 3
	var before: int = game.score
	game.on_ball_contact(game.get_node("Table/Pins/UpperLeft"), game.ball)
	check(game.score - before == 800, "Double points applies after level and turbo; no extra third-hit jackpot remains.")
	game.multiplier_remaining = 3.0
	game.on_multiplier_entered(game.get_node("Table/Pins/UpperLeft"))
	check(game.multiplier_remaining == 3.0, "Other bodies cannot refresh the bonus.")
	game.lose_ball()
	game._process(0.0)
	check(game.multiplier_remaining == 0.0 and not game.get_node("HUD/Multiplier").visible, "Losing the ball clears the bonus.")
	game.start_round()
	game.on_multiplier_entered(game.ball)
	check(game.multiplier_remaining == 0.0, "A waiting ball cannot activate double points.")
	if failures == 0:
		print("Scoring and multiplier checks passed")
	quit(1 if failures else 0)
