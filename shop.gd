extends Control

const CATEGORIES := [["turbo", "save"], ["precision", "length"]]
const BASE_EFFECTS := {
	"turbo": "Kein Bonus bei schnellen Treffern.",
	"precision": "Volle Ladung klingt über 3 s ab.",
	"length": "Normale Flipperlänge.",
	"save": "Keine Ballrettung.",
}

var game: Node2D
var category := 0
var selected_pin := 0
var selected_upgrade := "turbo"
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
	return "%s Punkte pro Treffer" % game.pin_points(index, level)

func refresh() -> void:
	var over: bool = game.phase == game.Phase.OVER
	%Title.text = "Run beendet" if over else "Mach mehr aus deinem Run."
	%Eyebrow.text = "STEEL BALLZ RUN / ERGEBNIS" if over else "STEEL BALLZ RUN / WERKSTATT"
	%Wallet.text = "Guthaben  %s" % game.credit
	%RunScore.text = "Aktueller Run  %s" % game.score
	%HighScore.text = "Highscore  %s" % game.high_score
	%Subtitle.text = "Jeder Treffer zählt. Auf zum nächsten Versuch." if over else "%s Kugeln übrig · %s Ausrüstungsangebote" % [game.balls_left, game.offers.size()]
	%Tabs.visible = not over
	shop_content.visible = not over
	buy_button.visible = not over
	%LifeCard.visible = not over
	%RunSummary.visible = over
	%RunSummary.text = "%s\nPUNKTE IN DIESEM RUN\n\nHighscore  %s\n\nInvestiert  %s · Übrig  %s" % [game.score, game.high_score, game.score - game.credit, game.credit]
	continue_button.text = "Neuen Run starten  →" if over else "Weiter zur nächsten Kugel  →"
	%Footnote.text = "Neuer Run: Pins auf Level 1, Upgrades zurückgesetzt.\nDein Highscore bleibt erhalten." if over else "Upgrades gelten für diesen Run."
	if over:
		%Feedback.text = ""
		return
	%LifeStatus.text = "%s / %s gekauft · pro Run" % [game.extra_lives_bought, game.MAX_EXTRA_LIVES]
	extra_life_button.disabled = game.extra_lives_bought >= game.MAX_EXTRA_LIVES or game.credit < game.EXTRA_LIFE_COST
	extra_life_button.text = "Limit erreicht" if game.extra_lives_bought >= game.MAX_EXTRA_LIVES else "+1 Kugel · %s" % game.EXTRA_LIFE_COST
	extra_life_button.tooltip_text = "Noch %s Guthaben nötig" % maxi(0, game.EXTRA_LIFE_COST - game.credit) if game.credit < game.EXTRA_LIFE_COST else "Eine zusätzliche Kugel für diesen Run"
	for index in category_buttons.size():
		category_buttons[index].set_pressed_no_signal(category == index)
	%PinPicker.visible = category == 0
	%ItemPicker.visible = category != 0
	for index in pin_buttons.size():
		var pin_level: int = game.pin_levels[index]
		pin_buttons[index].text = "L%s" % pin_level
		pin_buttons[index].get_node("Skin").set_skin(game.pin_texture(index, pin_level), game.pin_points(index, pin_level))
		pin_buttons[index].tooltip_text = "%s · %s Punkte" % [game.PIN_NAMES[index], game.pin_points(index, pin_level)]
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
		%CurrentSkin.set_skin(game.pin_texture(selected_pin, level + 1), game.pin_points(selected_pin, level + 1))
		%NextSkin.visible = level < max_level
		if level < max_level:
			%NextSkin.set_skin(game.pin_texture(selected_pin, level + 2), game.pin_points(selected_pin, level + 2))
		detail_title.text = "%s · %s" % [game.PIN_NAMES[selected_pin], "Gold-Pin" if game.is_golden(selected_pin) else "Pin"]
		%Level.text = "LEVEL %s / %s   ·   EINZELNES UPGRADE" % [level + 1, game.PIN_MAX_LEVEL]
		%CurrentEffect.text = "JETZT\n" + pin_effect(selected_pin, level + 1)
		next_effect.text = "NÄCHSTES LEVEL\n" + pin_effect(selected_pin, level + 2) if level < max_level else "VOLL AUSGEBAUT\nAlle neun Level freigeschaltet."
	else:
		for index in item_buttons.size():
			var id: String = CATEGORIES[category - 1][index]
			var item_level: int = game.upgrade_levels[id]
			var offer_text := "Verfügbar" if id in game.offers else "Heute nicht verfügbar"
			if item_level == game.COSTS.size():
				offer_text = "Voll ausgebaut"
			item_buttons[index].text = "%s\nStufe %s / 3\n%s" % [game.UPGRADES[id][0], item_level, offer_text]
			item_buttons[index].set_pressed_no_signal(selected_upgrade == id)
		level = game.upgrade_levels[selected_upgrade]
		max_level = game.COSTS.size()
		available = selected_upgrade in game.offers
		detail_title.text = game.UPGRADES[selected_upgrade][0]
		%Level.text = "STUFE %s / 3   ·   AUSRÜSTUNG" % level
		%CurrentEffect.text = "JETZT\n" + (BASE_EFFECTS[selected_upgrade] if level == 0 else game.UPGRADES[selected_upgrade][level])
		next_effect.text = "NÄCHSTE STUFE\n" + game.UPGRADES[selected_upgrade][level + 1] if level < max_level else "VOLL AUSGEBAUT\nAlle Stufen freigeschaltet."
		if selected_upgrade == "save":
			next_effect.text += "\nZiele: oben rechts + unten Mitte. Einmal pro Kugel."
	buy_button.disabled = true
	if level == max_level:
		buy_button.text = "Maximum erreicht"
	elif not available:
		buy_button.text = "Bei diesem Besuch nicht verfügbar"
	elif game.credit < prices[level]:
		buy_button.text = "%s Guthaben · noch %s nötig" % [prices[level], prices[level] - game.credit]
	else:
		buy_button.text = "Upgrade kaufen  ·  %s" % prices[level]
		buy_button.disabled = false

func buy_selected() -> void:
	var purchased: bool = game.buy_pin(selected_pin) if category == 0 else game.buy_upgrade(selected_upgrade)
	if purchased:
		refresh()
		%Feedback.text = "✓ %s verbessert." % (game.PIN_NAMES[selected_pin] if category == 0 else game.UPGRADES[selected_upgrade][0])

func buy_extra_life() -> void:
	if game.buy_extra_life():
		refresh()
		%Feedback.text = "✓ Zusatzkugel gekauft. %s Kugeln übrig." % game.balls_left

func continue_run() -> void:
	%Feedback.text = ""
	if game.phase == game.Phase.OVER:
		category = 0
		selected_pin = 0
		game.new_run()
	elif game.phase == game.Phase.SHOP:
		game.start_round()

