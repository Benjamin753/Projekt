extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)

func run() -> void:
	var game = load("res://pinball.tscn").instantiate()
	root.add_child(game)
	game.set_spring_pressed(true)
	game._physics_process(1.7)
	game.set_spring_pressed(false)
	game.ball.freeze = true
	game.ball.linear_velocity = Vector2.ZERO
	for index in 4:
		for level in range(1, 4):
			game.pin_levels[index] = level
			game.update_pin_skin(index)
			var pin: Node = game.get_node("Table/Pins").get_child(index)
			var color: String = ["blue", "yellow", "green", "blue"][index]
			check(pin.get_node("Sprite").texture.resource_path.ends_with("%s_%s.tres" % [color, level]), "Each pin uses the reference skin for its color and level.")
			check(pin.get_node("Level").text == "L%s" % level, "The level label follows the skin.")
			var before: int = game.score
			var expected: int = [100, 150, 200][level - 1] if index in [0, 3] else [50, 75, 100][level - 1]
			game.on_ball_contact(game.get_node("Table/Pins").get_child(index), game.ball)
			check(game.score - before == expected, "Pin %s level %s should give %s points, got %s." % [index, level, expected, game.score - before])
	check(game.get_node("Table/Pins/LowerCenter").position.y == 550.0, "The lower golden pin moves 40 pixels upward.")
	game.pin_levels.fill(1)
	game.lose_ball()
	for index in 4:
		game.credit = 2000
		var prices := [400, 600] if index in [0, 3] else [300, 500]
		for price in prices:
			var before: int = game.credit
			check(game.buy_pin(index), "The next pin level is purchasable.")
			check(before - game.credit == price, "The pin charges its type-specific price.")
		check(game.pin_levels[index] == 3 and not game.buy_pin(index), "Pin levels end at three.")
	check(game.COSTS == [250, 450, 700], "Equipment has moderately increased prices.")
	game.new_run()
	for index in 4:
		check(game.get_node("Table/Pins").get_child(index).get_node("Sprite").texture.resource_path.ends_with("_1.tres"), "A new run restores every level-one skin.")
	if failures == 0:
		print("Three-level pin balance checks passed")
	quit(1 if failures else 0)
