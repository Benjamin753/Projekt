extends Control

const CATEGORIES := [["turbo", "save"], ["precision", "length"]]
const BASE_EFFECTS := {
	"turbo": "No Bonus for fast Ballz",
	"precision": "full charge will get lost after 3s.",
	"length": "normal length (2 cm)",
	"save": "No way saving the Ballz",
}

var game: Node2D
var category := 0
var selected_pin := 0
var selected_upgrade := "turbo"
var reveal_tween: Tween
@onready var category_buttons: Array = [%PinsTab, %BallTab, %FlippersTab]
@onready var pin_buttons: Array = [%UpperLeft, %UpperRight, %UpperCenter, %LowerCenter]
@onready var item_buttons: Array = [%Item0, %Item1]
@onready var shop_content: Control = %ShopContent
@onready var detail_title: Label = %DetailTitle
@onready var next_effect: Label = %NextEffect
@onready var buy_button: Button = %Buy
@onready var extra_life_button: Button = %ExtraLife
@onready var continue_button: Button = %Continue

func configure(owner_game: Node2D) -> void:
	game = owner_game
	for index in category_buttons.size():
		category_buttons[index].pressed.connect(select_category.bind(index))
	for index in pin_buttons.size():
		pin_buttons[index].pressed.connect(select_pin.bind(index))
	for index in item_buttons.size():
		item_buttons[index].pressed.connect(select_item.bind(index))
	buy_button.pressed.connect(buy_selected)
	extra_life_button.pressed.connect(buy_extra_life)
	continue_button.pressed.connect(continue_run)
	for button: Button in category_buttons + pin_buttons + item_buttons + [buy_button, extra_life_button, continue_button]:
		button.button_down.connect(press_feedback.bind(button, true))
		button.button_up.connect(press_feedback.bind(button, false))

func reveal() -> void:
	if reveal_tween:
		reveal_tween.kill()
	$Panel.modulate.a = 0.78
	reveal_tween = create_tween()
	reveal_tween.tween_property($Panel, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

func press_feedback(button: Button, down: bool) -> void:
	if down and Input.is_action_pressed("ui_accept"):
		return
	if button.has_meta("press_tween"):
		var previous: Tween = button.get_meta("press_tween")
		previous.kill()
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween()
	button.set_meta("press_tween", tween)
	var target := Vector2(0.98, 0.98) if down else Vector2.ONE
	tween.tween_property(button, "scale", target, 0.10 if down else 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): button.remove_meta("press_tween"))

func select_category(index: int) -> void:
	category = index
	if category > 0:
		selected_upgrade = CATEGORIES[category - 1][0]
	%Feedback.text = ""
	refresh()
	%Scroll.scroll_vertical = 0

func select_pin(index: int) -> void:
	selected_pin = index
	%Feedback.text = ""
	refresh()

func select_item(index: int) -> void:
	selected_upgrade = CATEGORIES[category - 1][index]
	%Feedback.text = ""
	refresh()

func pin_effect(index: int, level: int) -> String:
	return "%s Points per hit" % game.pin_points(index, level)

func refresh() -> void:
	var over: bool = game.phase == game.Phase.OVER
	%Title.text = "lost ur Ballz" if over else "skill issue... try again"
	%Eyebrow.text = "STEEL BALLZ RUN"
	%Wallet.text = "Moneyun  %s" % game.credit
	%Wallet.get_parent().visible = not over
	%RunScore.get_parent().visible = not over
	%RunScore.text = "Run  %s" % game.score
	%HighScore.text = "Highscore  %s" % game.high_score
	%Subtitle.text = "%s Ballz used" % (3 + game.extra_lives_bought) if over else "%s available Ballz · %s Offers" % [game.balls_left, game.offers.size()]
	%Tabs.visible = not over
	shop_content.visible = not over
	buy_button.visible = not over
	%LifeCard.visible = not over
	%RunSummary.visible = over
	continue_button.text = "Start new Run →" if over else "start with next Ballz →"
	%Footnote.text = "Your Highscore will be safed" if over else "Upgrades only usable for this run"
	if over:
		%ResultScore.text = str(game.score)
		%ResultHighScore.text = "All High  %s" % game.high_score
		%ResultCredits.text = "Invested  %s   ·   Wasted  %s" % [game.score - game.credit, game.credit]
		%Feedback.text = ""
		return
	var life_count := "%s / %s" % [game.extra_lives_bought, game.MAX_EXTRA_LIVES]
	var life_limit: bool = game.extra_lives_bought >= game.MAX_EXTRA_LIVES
	extra_life_button.disabled = life_limit or game.credit < game.EXTRA_LIFE_COST
	extra_life_button.text = "Maxed out · %s" % life_count if life_limit else "+1 Ballz · %s (%s)" % [game.EXTRA_LIFE_COST, life_count]
	extra_life_button.tooltip_text = "Max 3 Ballz per Run" if life_limit else "Price: %s Moneyun" % game.EXTRA_LIFE_COST
	for index in category_buttons.size():
		category_buttons[index].set_pressed_no_signal(category == index)
	%PinPicker.visible = category == 0
	%ItemPicker.visible = category != 0
	for index in pin_buttons.size():
		var pin_level: int = game.pin_levels[index]
		pin_buttons[index].text = "L%s" % pin_level
		pin_buttons[index].get_node("Skin").set_skin(game.pin_texture(index, pin_level), game.pin_points(index, pin_level), game.PIN_ACCENTS[index])
		pin_buttons[index].tooltip_text = "%s · %s Points" % [game.PIN_NAMES[index], game.pin_points(index, pin_level)]
		pin_buttons[index].set_pressed_no_signal(selected_pin == index)
	var level: int
	var max_level: int
	var available := true
	var prices: Array = game.COSTS
	%CurrentSkin.visible = category == 0
	%NextSkin.visible = category == 0
	if category == 0:
		level = game.pin_levels[selected_pin] - 1
		prices = game.pin_prices(selected_pin)
		max_level = prices.size()
		%CurrentSkin.set_skin(game.pin_texture(selected_pin, level + 1), game.pin_points(selected_pin, level + 1), game.PIN_ACCENTS[selected_pin])
		%NextSkin.visible = level < max_level
		if level < max_level:
			%NextSkin.set_skin(game.pin_texture(selected_pin, level + 2), game.pin_points(selected_pin, level + 2), game.PIN_ACCENTS[selected_pin])
		detail_title.text = "%s · %s" % [game.PIN_NAMES[selected_pin], "Gold-Pin" if game.is_golden(selected_pin) else "Pin"]
		%Level.text = "Level %s / %s" % [level + 1, game.PIN_MAX_LEVEL]
		%CurrentEffect.text = "Now\n" + pin_effect(selected_pin, level + 1)
		next_effect.text = "NEXT LEVEL\n" + pin_effect(selected_pin, level + 2) if level < max_level else "MAXED OUT\nAll 9 Levels got unlocked"
	else:
		for index in item_buttons.size():
			var id: String = CATEGORIES[category - 1][index]
			var item_level: int = game.upgrade_levels[id]
			var offer_text := "Available" if id in game.offers else "Not available rn"
			if item_level == game.COSTS.size():
				offer_text = "Maxed out"
			item_buttons[index].text = "%s\nStage %s / 3\n%s" % [game.UPGRADES[id][0], item_level, offer_text]
			item_buttons[index].set_pressed_no_signal(selected_upgrade == id)
		level = game.upgrade_levels[selected_upgrade]
		max_level = game.COSTS.size()
		available = selected_upgrade in game.offers
		detail_title.text = game.UPGRADES[selected_upgrade][0]
		%Level.text = "Stage %s / 3" % level
		%CurrentEffect.text = "NOW\n" + (BASE_EFFECTS[selected_upgrade] if level == 0 else game.UPGRADES[selected_upgrade][level])
		next_effect.text = "NEXT STAGE\n" + game.UPGRADES[selected_upgrade][level + 1] if level < max_level else "MAXED OUT\nAll Stages unlocked"
		if selected_upgrade == "save":
			next_effect.text += "\nZiel: upper right + lower middle. Once per Ballz"
	buy_button.disabled = true
	if level == max_level:
		buy_button.text = "Maxed out"
	elif not available:
		buy_button.text = "Not available rn"
	elif game.credit < prices[level]:
		buy_button.text = "%s Moneyun · need %s more" % [prices[level], prices[level] - game.credit]
	else:
		buy_button.text = "Buy upgrade  ·  %s" % prices[level]
		buy_button.disabled = false

func buy_selected() -> void:
	var purchased: bool = game.buy_pin(selected_pin) if category == 0 else game.buy_upgrade(selected_upgrade)
	if purchased:
		%Feedback.text = "✓ %s upgraded." % (game.PIN_NAMES[selected_pin] if category == 0 else game.UPGRADES[selected_upgrade][0])

func buy_extra_life() -> void:
	if game.buy_extra_life():
		%Feedback.text = "✓ bought more Ballz. %s Ballz left." % game.balls_left

func continue_run() -> void:
	%Feedback.text = ""
	if game.phase == game.Phase.OVER:
		category = 0
		selected_pin = 0
		game.new_run()
	elif game.phase == game.Phase.SHOP:
		game.start_round()
