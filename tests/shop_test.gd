extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)

func settle() -> void:
	await process_frame
	await process_frame

func click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await settle()

func touch(button: Button) -> void:
	var event := InputEventScreenTouch.new()
	event.position = root.get_final_transform() * button.get_global_rect().get_center()
	event.index = 0
	event.pressed = true
	Input.parse_input_event(event)
	await settle()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await settle()

func run() -> void:
	var game = load("res://pinball.tscn").instantiate()
	game.high_score_path = "res://.godot/test_shop.cfg"
	root.add_child(game)
	check(game.menu.has_method("select_pin"), "The shop must provide individual pin selection and a purchase preview.")
	if failures:
		quit(1)
		return
	game.set_spring_pressed(true)
	game._physics_process(1.7)
	game.set_spring_pressed(false)
	game.credit = 1000
	game.score = 1234
	game.lose_ball()
	await settle()
	var shop = game.menu
	check(shop.visible and game.ball == null, "The shop opens safely between balls.")
	check(game.offers.size() == 3, "Three equipment offers are chosen per visit.")
	var original_offers: Array = game.offers.duplicate()
	await touch(shop.pin_buttons[3])
	check(shop.selected_pin == 3, "Touch input selects an individual pin.")
	await click(shop.pin_buttons[1])
	check(shop.selected_pin == 1 and game.credit == 1000, "Selecting a pin does not purchase it.")
	check(shop.detail_title.text.contains("Oben rechts"), "The preview names the selected pin.")
	check(shop.next_effect.text.contains("75"), "The next normal pin level previews its 75 base points.")
	await click(shop.buy_button)
	check(game.pin_levels[1] == 2 and game.pin_levels[0] == 1, "Only the selected pin upgrades.")
	check(game.credit == 700 and game.score == 1234, "Purchase spends credit while preserving score.")
	check(shop.buy_button.text.contains("500"), "The next price refreshes immediately.")
	await click(shop.buy_button)
	await click(shop.buy_button)
	check(game.pin_levels[1] == 3 and game.credit == 200 and shop.buy_button.disabled, "The next pin upgrade is disabled when credit is insufficient.")
	await click(shop.pin_buttons[0])
	check(shop.buy_button.disabled and shop.buy_button.text.contains("100"), "Insufficient credit shows the missing amount and disables buying.")
	check(not game.buy_pin(-1) and not game.buy_pin(20), "Invalid pin selections are rejected.")
	check(game.offers == original_offers, "Buying and selecting do not reroll the offers.")
	game.credit = 20000
	await click(shop.pin_buttons[2])
	for upgrade in 8:
		await click(shop.buy_button)
	check(game.pin_levels[2] == 9 and shop.buy_button.disabled, "The golden pin reaches level nine and stops there.")
	game.credit = 5000
	game.offers = ["turbo", "precision", "length"]
	game.update_menu()
	await click(shop.category_buttons[1])
	check(shop.selected_upgrade == "turbo" and shop.buy_button.text.contains("250"), "The ball tab previews the available turbo upgrade.")
	await click(shop.buy_button)
	check(game.upgrade_levels["turbo"] == 1, "The equipment purchase button buys the selected upgrade.")
	await click(shop.buy_button)
	await click(shop.buy_button)
	check(game.upgrade_levels["turbo"] == 3 and shop.buy_button.disabled, "Equipment also stops at its maximum tier.")
	await click(shop.item_buttons[1])
	check(shop.selected_upgrade == "save" and shop.buy_button.disabled, "Unavailable equipment is visible but cannot be bought.")
	var before: int = game.credit
	game.buy_upgrade("save")
	game.buy_upgrade("unknown")
	check(game.credit == before, "Invalid or unavailable upgrades do not spend credit.")
	await click(shop.category_buttons[2])
	await click(shop.buy_button)
	check(game.upgrade_levels["precision"] == 1, "The flipper tab purchases charge retention.")
	await click(shop.item_buttons[1])
	await click(shop.buy_button)
	check(game.upgrade_levels["length"] == 1, "Flipper length is separately purchasable.")
	await click(shop.extra_life_button)
	check(game.balls_left == 3 and game.extra_lives_bought == 1, "The shop extra-life button buys one life.")
	await click(shop.continue_button)
	check(game.phase == game.Phase.START and game.ball.freeze and not shop.visible, "Continue waits at the spring without auto-launching.")
	check(is_equal_approx(game.flippers[0].length, 57.0 * 1.05), "Purchased flipper length applies to the next ball.")
	check(not game.buy_pin(0) and not game.buy_upgrade("turbo"), "Purchases outside the shop are blocked.")
	for loss in 3:
		game.set_spring_pressed(true)
		game._physics_process(1.7)
		game.set_spring_pressed(false)
		game.lose_ball()
		if loss < 2:
			game.start_round()
	await settle()
	check(game.phase == game.Phase.OVER and not shop.shop_content.visible, "Game over shows the run summary instead of purchases.")
	check(not game.buy_extra_life(), "Extra lives cannot be bought after game over.")
	await click(shop.continue_button)
	check(game.phase == game.Phase.START and game.credit == 0 and game.pin_levels.all(func(level): return level == 1), "A new run resets credit and every pin.")
	check(game.upgrade_levels.values().all(func(level): return level == 0), "A new run resets equipment.")
	for id in game.upgrade_levels:
		game.upgrade_levels[id] = 3
	game.set_spring_pressed(true)
	game._physics_process(1.7)
	game.set_spring_pressed(false)
	game.lose_ball()
	check(game.offers.is_empty() and shop.get_node("%Subtitle").text.contains("0 Ausrüstungsangebote"), "When equipment is maxed, the shop accurately reports zero remaining offers.")
	if failures == 0:
		print("Shop selection, purchases, and round flow checks passed")
	quit(1 if failures else 0)



