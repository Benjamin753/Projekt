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

func place(game, at: Vector2, velocity := Vector2.ZERO) -> void:
	game.ball.freeze = true
	game.ball.global_position = at
	PhysicsServer2D.body_set_state(game.ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0, at))
	await frames(2)
	game.ball.freeze = false
	game.ball.linear_velocity = velocity

func hit_pin(game, index: int, expected: int) -> void:
	var pin: Node2D = game.get_node("Table/Pins").get_child(index)
	var before: int = game.score
	var credit_before: int = game.credit
	await place(game, pin.global_position + Vector2(0, 47), Vector2(0, -500))
	await frames(14)
	check(game.score - before == expected, "Pin %s physical contact should award %s, got %s." % [index, expected, game.score - before])
	check(game.credit - credit_before == expected, "A contact awards the same spendable credit.")
	check(game.ball.linear_velocity.y > 0, "A pin reverses the incoming ball.")
	check(pin.get_node("Points").text == "+%s" % expected, "The hit label displays the actual award.")

func run() -> void:
	var game = load("res://pinball.tscn").instantiate()
	game.high_score_path = "res://.godot/test_scoring.cfg"
	root.add_child(game)
	game.set_spring_pressed(true)
	game._physics_process(1.7)
	game.set_spring_pressed(false)
	game.ball.gravity_scale = 0.0
	await frames(2)
	await hit_pin(game, 0, 50)
	await hit_pin(game, 2, 100)
	check(game.multiplier_remaining == 0.0, "Ordinary table play does not invent a multiplier bonus.")
	game.ball.freeze = true
	game.ball.linear_velocity = Vector2(700, 0)
	game.pin_levels[0] = 9
	game.pin_hits[0] = 2
	game.upgrade_levels["turbo"] = 3
	var before: int = game.score
	game.on_ball_contact(game.get_node("Table/Pins/UpperLeft"), game.ball)
	check(game.score - before == 500, "A level-nine normal pin and maximum turbo give 500; no third-hit jackpot remains.")
	check(game.high_score >= game.score, "Scoring immediately tracks the best score.")
	before = game.score
	var other_ball := RigidBody2D.new()
	game.on_ball_contact(game.get_node("Table/Pins/UpperCenter"), other_ball)
	other_ball.free()
	check(game.score == before, "Contacts from a different ball cannot award points.")
	# Optional custom zones retain their existing behavior without default map fixtures.
	if game.has_method("on_multiplier_entered"):
		game.on_multiplier_entered(game.ball)
		check(game.multiplier_remaining == 10.0, "An explicit bonus trigger starts ten seconds of double points.")
		game.ball.linear_velocity = Vector2.ZERO
		before = game.score
		game.on_ball_contact(game.get_node("Table/Pins/UpperCenter"), game.ball)
		check(game.score - before == 200, "An optional multiplier doubles the golden pin award.")
		game._physics_process(11.0)
		check(game.multiplier_remaining == 0.0, "An expired optional bonus clamps at zero.")
	game.lose_ball()
	check(game.multiplier_remaining == 0.0, "Losing the ball clears any bonus.")
	game.start_round()
	before = game.score
	game.on_ball_contact(game.get_node("Table/Pins/UpperCenter"), game.ball)
	check(game.score == before, "A waiting ball cannot award points.")
	if failures == 0:
		print("Physical pin contact and scoring ledger checks passed")
	quit(1 if failures else 0)
