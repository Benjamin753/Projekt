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
	var effect := "%s Punkte pro Treffer" % game.pin_points(index, level)
	if not game.is_golden(index) and level > 1:
		effect += " · stärkerer Rückstoß"
	return effect

func refresh() -> void:
	var over: bool = game.phase == game.Phase.OVER
	%Title.text = "RUN BEENDET" if over else "UPGRADE-SHOP"
	%Wallet.text = "Score  %s" % game.score if over else "Guthaben  %s" % game.credit
	%Subtitle.text = "Drei Kugeln gespielt. Bereit für den nächsten Run?" if over else "%s Kugeln übrig · %s Ausrüstungsangebote bei diesem Besuch" % [game.balls_left, game.offers.size()]
	%Tabs.visible = not over
	shop_content.visible = not over
	%RunSummary.visible = over
	%RunSummary.text = "Dein Run\n\n%s Punkte\n\nInvestiert: %s\nRestguthaben: %s" % [game.score, game.score - game.credit, game.credit]
	continue_button.text = "Neuer Run" if over else "Zur Feder · nächste Kugel"
	%Footnote.text = "Ein neuer Run beginnt mit Level 1 und ohne Upgrades." if over else "Upgrades gelten für diesen Run.\nAbschuss: Leertaste oder Feder halten und loslassen."
	if over:
		%Feedback.text = ""
		return
	for index in category_buttons.size():
		category_buttons[index].set_pressed_no_signal(category == index)
	%PinPicker.visible = category == 0
	%ItemPicker.visible = category != 0
	for index in pin_buttons.size():
		pin_buttons[index].text = "L%s" % game.pin_levels[index]
		pin_buttons[index].get_node("Skin").set_skin(game.pin_texture(index, game.pin_levels[index]))
		pin_buttons[index].tooltip_text = game.PIN_NAMES[index]
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
		%CurrentSkin.set_skin(game.pin_texture(selected_pin, level + 1))
		%NextSkin.visible = level < max_level
		if level < max_level:
			%NextSkin.set_skin(game.pin_texture(selected_pin, level + 2))
		detail_title.text = "%s · %s" % [game.PIN_NAMES[selected_pin], "Golden Pin" if game.is_golden(selected_pin) else "Pin"]
		%Level.text = "Level %s / 3 · nur dieser Pin" % (level + 1)
		%CurrentEffect.text = "Jetzt: " + pin_effect(selected_pin, level + 1)
		next_effect.text = "Danach: " + pin_effect(selected_pin, level + 2) if level < max_level else "Alle Stufen dieses Pins freigeschaltet."
	else:
		for index in item_buttons.size():
			var id: String = CATEGORIES[category - 1][index]
			var item_level: int = game.upgrade_levels[id]
			var offer_text := "Im Angebot" if id in game.offers else "Nicht im Angebot"
			if item_level == game.COSTS.size():
				offer_text = "Maximum erreicht"
			item_buttons[index].text = "%s\nStufe %s / 3\n%s" % [game.UPGRADES[id][0], item_level, offer_text]
			item_buttons[index].set_pressed_no_signal(selected_upgrade == id)
		level = game.upgrade_levels[selected_upgrade]
		max_level = game.COSTS.size()
		available = selected_upgrade in game.offers
		detail_title.text = game.UPGRADES[selected_upgrade][0]
		%Level.text = "Stufe %s / 3" % level
		%CurrentEffect.text = "Jetzt: " + (BASE_EFFECTS[selected_upgrade] if level == 0 else game.UPGRADES[selected_upgrade][level])
		next_effect.text = "Danach: " + game.UPGRADES[selected_upgrade][level + 1] if level < max_level else "Alle Stufen dieses Upgrades freigeschaltet."
		if selected_upgrade == "save":
			next_effect.text += "\nZiele: oben rechts + unten Mitte. Einmal pro Kugel."
	buy_button.disabled = true
	if level == max_level:
		buy_button.text = "Maximum erreicht"
	elif not available:
		buy_button.text = "Bei diesem Besuch nicht im Angebot"
	elif game.credit < prices[level]:
		buy_button.text = "Preis %s · noch %s Guthaben nötig" % [prices[level], prices[level] - game.credit]
	else:
		buy_button.text = "Upgrade kaufen · %s" % prices[level]
		buy_button.disabled = false

func buy_selected() -> void:
	var purchased: bool = game.buy_pin(selected_pin) if category == 0 else game.buy_upgrade(selected_upgrade)
	if purchased:
		%Feedback.text = "Gekauft! %s verbessert." % (game.PIN_NAMES[selected_pin] if category == 0 else game.UPGRADES[selected_upgrade][0])

func continue_run() -> void:
	%Feedback.text = ""
	if game.phase == game.Phase.OVER:
		category = 0
		selected_pin = 0
		game.new_run()
	elif game.phase == game.Phase.SHOP:
		game.start_round()
