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
	if not "high_score_path" in game:
		check(false, "Game must expose an isolated high-score save path before tests can run.")
		game.free()
		quit(1)
		return
	game.high_score_path = "res://.godot/test_pin_balance.cfg"
	root.add_child(game)
	game.set_spring_pressed(true)
	game._physics_process(1.7)
	game.set_spring_pressed(false)
	game.ball.freeze = true
	game.ball.linear_velocity = Vector2.ZERO
	var pins: Node = game.get_node("Table/Pins")
	check(pins.get_child_count() == 4, "Exactly four pins are playable.")
	for index in 4:
		check(game.is_golden(index) == (index == 2), "Only the upper middle pin is golden.")
		for level in range(1, 10):
			game.pin_levels[index] = level
			game.update_pin_skin(index)
			var pin: Node = pins.get_child(index)
			var color: String = ["green", "yellow", "blue", "green"][index]
			var tier := floori(float(level - 1) / 3.0) + 1
			var expected := 100 + 50 * (level - 1) if index == 2 else 50 + 25 * (level - 1)
			var skin = pin.get_node("Sprite")
			check(skin.texture.resource_path.ends_with("%s_%s.tres" % [color, tier]), "Pin %s level %s uses color %s and skin tier %s." % [index, level, color, tier])
			check(not pin.has_node("Level"), "Pins have no separate level label underneath.")
			check(skin.has_node("Value") and skin.get_node("Value").text == str(expected), "The center of pin %s displays its current %s base points." % [index, expected])
			check(game.pin_points(index, level) == expected, "The pin point formula covers all nine levels.")
			var before: int = game.score
			game.on_ball_contact(pin, game.ball)
			check(game.score - before == expected, "Pin %s level %s should award %s points, got %s." % [index, level, expected, game.score - before])
	game.pin_levels.fill(1)
	game.lose_ball()
	for index in 4:
		game.credit = 20000
		var prices := [300, 500, 750, 1050, 1400, 1800, 2250, 2750]
		for price in prices:
			var before: int = game.credit
			check(game.buy_pin(index), "Each of the eight pin upgrades is purchasable.")
			check(before - game.credit == price + (100 if index == 2 else 0), "The next level charges the correct pin-specific price.")
		check(game.pin_levels[index] == 9 and not game.buy_pin(index), "Pin levels stop at nine.")
	check(game.COSTS == [250, 450, 700], "Equipment retains its three prices.")
	check(game.upgrade_levels.size() == 4, "The four existing equipment types remain available.")
	game.new_run()
	for index in 4:
		check(pins.get_child(index).get_node("Sprite").texture.resource_path.ends_with("_1.tres"), "A new run restores every level-one skin.")
	if failures == 0:
		print("Nine-level pin balance checks passed")
	quit(1 if failures else 0)
