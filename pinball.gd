extends Node2D

const Flipper = preload("res://flipper.gd")
const COSTS := [150, 300, 500]
const PIN_POSITIONS := [
	Vector2(150, 218), Vector2(260, 188), Vector2(319, 321),
	Vector2(213, 369), Vector2(115, 450), Vector2(295, 487),
]
const HOLES := [Vector2(240, 752), Vector2(96, 342), Vector2(367, 205)]
const HOLE_RADII := [46.0, 19.0, 19.0]
const WALLS := [
	[Vector2(32, 659), Vector2(32, 178)], [Vector2(32, 178), Vector2(90, 116)],
	[Vector2(90, 116), Vector2(379, 116)], [Vector2(379, 116), Vector2(448, 181)],
	[Vector2(448, 181), Vector2(448, 659)], [Vector2(32, 659), Vector2(135, 797)],
	[Vector2(448, 659), Vector2(345, 797)],
	[Vector2(357, 164), Vector2(398, 183)], [Vector2(401, 355), Vector2(433, 415)],
	[Vector2(47, 540), Vector2(106, 580)], [Vector2(374, 580), Vector2(433, 540)],
]
const FLIPPER_POSITIONS := [Vector2(108, 682), Vector2(372, 682)]
const UPGRADES := {
	"turbo": ["Turbo-Kugel", "+25 % bei schnellen Treffern", "+50 % bei schnellen Treffern", "+100 % bei schnellen Treffern"],
	"precision": ["Präzisionsflipper", "0,8 s zum erneuten Drücken", "1,0 s zum erneuten Drücken", "1,2 s zum erneuten Drücken"],
	"length": ["Lange Flipper", "5 % längere Flipper", "10 % längere Flipper", "15 % längere Flipper"],
	"save": ["Ballrettung", "2 markierte Pins: Schutz für 6 s", "2 markierte Pins: Schutz für 12 s", "2 markierte Pins: Schutz bis zur Rettung"],
}
const INK := Color("#0a1624")
const CYAN := Color("#75e4e8")
const GOLD := Color("#ffbe66")
const TEXT := Color("#e5f4f8")

enum Phase { START, PLAY, SHOP, OVER }

var phase := Phase.START
var balls_left := 3
var credit := 0
var score := 0
var pin_levels: Array[int] = [0, 0, 0, 0, 0, 0]
var pin_hits: Array[int] = [0, 0, 0, 0, 0, 0]
var flashes: Array[float] = [0, 0, 0, 0, 0, 0]
var upgrade_levels := {"turbo": 0, "precision": 0, "length": 0, "save": 0}
var offers: Array = []
var flippers: Array[Flipper] = []
var touches := {}
var keyboard := {}
var ball: RigidBody2D
var previous_ball := Vector2.ZERO
var save_targets := 0
var save_time := 0.0
var save_used := false
var menu := PanelContainer.new()
var menu_items := VBoxContainer.new()
var font := ThemeDB.fallback_font

func _ready() -> void:
	for wall in WALLS:
		var shape := SegmentShape2D.new()
		shape.a = wall[0]
		shape.b = wall[1]
		add_static_shape(shape, Vector2.ZERO)
	for index in PIN_POSITIONS.size():
		var shape := CircleShape2D.new()
		shape.radius = 16.0
		add_static_shape(shape, PIN_POSITIONS[index]).set_meta("pin", index)
	for index in FLIPPER_POSITIONS.size():
		var flipper := Flipper.new()
		flipper.side = 1.0 if index == 0 else -1.0
		flipper.position = FLIPPER_POSITIONS[index]
		flipper.z_index = 1
		add_child(flipper)
		flippers.append(flipper)
	build_menu()
	update_menu()

func add_static_shape(shape: Shape2D, at: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	collider.shape = shape
	body.position = at
	body.add_child(collider)
	add_child(body)
	return body

func charge_multiplier(seconds: float) -> float:
	return Flipper.charge_multiplier(seconds)

func new_run() -> void:
	balls_left = 3
	credit = 0
	score = 0
	pin_levels.fill(0)
	pin_hits.fill(0)
	for id in UPGRADES:
		upgrade_levels[id] = 0
	start_round()

func start_round() -> void:
	if phase == Phase.PLAY and is_instance_valid(ball):
		return
	phase = Phase.PLAY
	menu.hide()
	touches.clear()
	keyboard.clear()
	flashes.fill(0.0)
	save_targets = 0
	save_time = 0.0
	save_used = false
	for flipper in flippers:
		flipper.reset()
		flipper.set_length_level(upgrade_levels["length"])

	ball = RigidBody2D.new()
	ball.position = Vector2(407, 497)
	ball.linear_velocity = Vector2(-270, -790)
	ball.linear_damp = 0.12
	ball.can_sleep = false
	ball.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	ball.contact_monitor = true
	ball.max_contacts_reported = 12
	ball.physics_material_override = PhysicsMaterial.new()
	ball.physics_material_override.bounce = 0.83
	ball.physics_material_override.friction = 0.12
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	collider.shape = shape
	ball.add_child(collider)
	ball.body_entered.connect(on_ball_contact)
	previous_ball = ball.position
	add_child(ball)

func lose_ball() -> void:
	if phase != Phase.PLAY:
		return
	balls_left -= 1
	phase = Phase.SHOP if balls_left > 0 else Phase.OVER
	ball.queue_free()
	ball = null
	for flipper in flippers:
		flipper.reset()
	offers = UPGRADES.keys().filter(func(id): return upgrade_levels[id] < COSTS.size())
	offers.shuffle()
	offers = offers.slice(0, 3)
	update_menu()

func buy_pin(index: int) -> bool:
	if phase != Phase.SHOP or index < 0 or index >= pin_levels.size():
		return false
	var level := pin_levels[index]
	if level >= COSTS.size() or credit < COSTS[level]:
		return false
	credit -= COSTS[level]
	pin_levels[index] += 1
	update_menu()
	return true

func buy_upgrade(id: String) -> void:
	if phase != Phase.SHOP or id not in offers:
		return
	var level: int = upgrade_levels[id]
	if level >= COSTS.size() or credit < COSTS[level]:
		return
	credit -= COSTS[level]
	upgrade_levels[id] += 1
	update_menu()

func on_ball_contact(body: Node) -> void:
	if phase != Phase.PLAY or not body.has_meta("pin"):
		return
	var number: int = body.get_meta("pin")
	var level := pin_levels[number]
	var points := 25
	pin_hits[number] += 1
	flashes[number] = 0.24
	if is_spring(number):
		points += 10 * level
		if level > 0:
			var pin_position: Vector2 = PIN_POSITIONS[number]
			var direction := (ball.position - pin_position).normalized()
			ball.call_deferred("apply_central_impulse", direction * 80.0 * level)
	else:
		points *= mini(level + 1, 3)
		if level == 3 and pin_hits[number] % 3 == 0:
			points += 100
	if ball.linear_velocity.length() >= 650.0:
		var turbo_bonus: Array[float] = [0.0, 0.25, 0.5, 1.0]
		points += roundi(points * turbo_bonus[upgrade_levels["turbo"]])
	score += points
	credit += points
	if upgrade_levels["save"] > 0 and not save_used:
		if number == 1:
			save_targets |= 1
		if number == 4:
			save_targets |= 2
		if save_targets == 3 and save_time <= 0.0:
			var durations := [0.0, 6.0, 12.0, INF]
			save_time = durations[upgrade_levels["save"]]

func is_spring(index: int) -> bool:
	return index == 1 or index == 4

func _input(event: InputEvent) -> void:
	if phase != Phase.PLAY:
		return
	if event is InputEventKey and not event.echo:
		var key: Key = event.physical_keycode
		if key in [KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT]:
			keyboard[key] = event.pressed
			update_input()
	elif event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			touches.erase(event.index)
		elif event.position.y >= 590.0 and event.position.y <= 820.0:
			touches[event.index] = 0 if event.position.x < 240.0 else 1
		update_input()

func update_input() -> void:
	var window: float = 0.6 + 0.2 * upgrade_levels["precision"]
	var sides := touches.values()
	flippers[0].set_pressed(keyboard.get(KEY_A, false) or keyboard.get(KEY_LEFT, false) or 0 in sides, window)
	flippers[1].set_pressed(keyboard.get(KEY_D, false) or keyboard.get(KEY_RIGHT, false) or 1 in sides, window)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and phase == Phase.PLAY:
		keyboard.clear()
		touches.clear()
		for flipper in flippers:
			flipper.reset()

func _physics_process(delta: float) -> void:
	if phase != Phase.PLAY:
		return
	for index in flashes.size():
		flashes[index] = maxf(0.0, flashes[index] - delta)
	save_time = maxf(0.0, save_time - delta)
	if save_time == 0.0 and save_targets == 3:
		save_targets = 0
	if ball.linear_velocity.length_squared() > 1800.0 * 1800.0:
		ball.linear_velocity = ball.linear_velocity.limit_length(1800.0)
	for body in ball.get_colliding_bodies():
		if body is Flipper:
			body.hit(ball)
	for index in HOLES.size():
		var center: Vector2 = HOLES[index]
		var closest := Geometry2D.get_closest_point_to_segment(center, previous_ball, ball.position)
		if closest.distance_squared_to(center) <= HOLE_RADII[index] * HOLE_RADII[index]:
			if index == 0 and save_time > 0.0:
				save_time = 0.0
				save_used = true
				ball.position = Vector2(240, 657)
				ball.linear_velocity = Vector2(60, -640)
				break
			lose_ball()
			return
	if ball.position.y > 830.0 or ball.position.x < -30.0 or ball.position.x > 510.0 or ball.position.y < 0.0:
		lose_ball()
		return
	previous_ball = ball.position
	queue_redraw()

func build_menu() -> void:
	var overlay := CanvasLayer.new()
	add_child(overlay)
	overlay.add_child(menu)
	menu.position = Vector2(39, 123)
	menu.custom_minimum_size = Vector2(402, 0)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#14263b")
	panel.border_color = Color("#36516a")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(14)
	panel.content_margin_left = 18
	panel.content_margin_right = 18
	panel.content_margin_top = 14
	panel.content_margin_bottom = 14
	menu.add_theme_stylebox_override("panel", panel)
	menu.add_child(menu_items)
	menu_items.add_theme_constant_override("separation", 7)

func update_menu() -> void:
	for old_item in menu_items.get_children():
		menu_items.remove_child(old_item)
		old_item.queue_free()
	menu.reset_size()
	menu.show()
	match phase:
		Phase.START:
			menu_label("Steel Ballz Run", 30)
			menu_label("A / ←   •   D / →   •   Touch am Flipper", 16)
			menu_label("Halten, loslassen, erneut drücken.", 16)
			menu_button(menu_items, "Run starten", new_run)
		Phase.SHOP:
			menu_label("Shop   ·   %s Punkte" % credit, 24)
			menu_label("Wähle einen Pin für sein eigenes Upgrade.", 15)
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 6)
			grid.add_theme_constant_override("v_separation", 6)
			menu_items.add_child(grid)
			for index in pin_levels.size():
				var level := pin_levels[index]
				var label := "Pin %s · %s" % [index + 1, "Feder" if is_spring(index) else "Gold"]
				if level < COSTS.size():
					label += "\nStufe %s → %s · %s" % [level, level + 1, COSTS[level]]
				else:
					label += "\nStufe 3 · Maximum"
				var button := menu_button(grid, label, buy_pin.bind(index))
				button.disabled = level == COSTS.size() or credit < COSTS[level]
			for id in offers:
				var level: int = upgrade_levels[id]
				var upgrade: Array = UPGRADES[id]
				if level < COSTS.size():
					var label := "%s · Stufe %s · %s\n%s" % [upgrade[0], level + 1, COSTS[level], upgrade[level + 1]]
					menu_button(menu_items, label, buy_upgrade.bind(id)).disabled = credit < COSTS[level]
			menu_button(menu_items, "Nächste Kugel", start_round)
		Phase.OVER:
			menu_label("Run beendet", 28)
			menu_label("Score   %s" % score, 20)
			menu_button(menu_items, "Neuer Run", new_run)
	queue_redraw()

func menu_label(value: String, size: int) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	menu_items.add_child(label)

func menu_button(parent: Container, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 46
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _draw() -> void:
	draw_rect(Rect2(0, 0, 480, 820), Color("#080e19"))
	draw_polygon(PackedVector2Array([
		Vector2(32, 178), Vector2(90, 116), Vector2(379, 116), Vector2(448, 181),
		Vector2(448, 659), Vector2(345, 797), Vector2(135, 797), Vector2(32, 659),
	]), PackedColorArray([INK]))
	for y in range(190, 632, 24):
		for x in range(56, 441, 24):
			draw_circle(Vector2(x, y), 1, Color("#20364a"))
	for wall in WALLS:
		draw_line(wall[0], wall[1], Color("#315573"), 8, true)
		draw_line(wall[0], wall[1], Color("#74a0bb"), 2, true)
	draw_string(font, Vector2(32, 40), "STEEL BALLZ RUN", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, TEXT)
	draw_string(font, Vector2(33, 82), "SCORE  %s" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, CYAN)
	draw_string(font, Vector2(160, 82), "GUTHABEN  %s" % credit, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, GOLD)
	draw_string(font, Vector2(345, 82), "KUGELN  %s" % balls_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, TEXT)
	for index in HOLES.size():
		var rim := CYAN if index == 0 and save_time > 0.0 else Color("#ce6b73")
		draw_circle(HOLES[index], HOLE_RADII[index] + 3.0, rim, true, -1.0, true)
		draw_circle(HOLES[index], HOLE_RADII[index], Color("#040810"), true, -1.0, true)
	for index in PIN_POSITIONS.size():
		var at: Vector2 = PIN_POSITIONS[index]
		var color := CYAN if is_spring(index) else GOLD
		if pin_levels[index] == 0:
			color = color.darkened(0.37)
		draw_circle(at, 19, Color("#283d52"), true, -1.0, true)
		if upgrade_levels["save"] > 0 and not save_used and is_spring(index):
			var target := 1 if index == 1 else 2
			var ring := CYAN if (save_targets & target) != 0 else Color("#577c91")
			draw_arc(at, 22.0, 0.0, TAU, 24, ring, 2.0, true)
		draw_circle(at, 15, color.lightened(flashes[index]), true, -1.0, true)
		draw_string(font, at + Vector2(-13, 5), str(index + 1), HORIZONTAL_ALIGNMENT_CENTER, 26, 15, INK)
		for level in pin_levels[index]:
			draw_circle(at + Vector2((level - 1) * 8, 26), 2.5, color, true, -1.0, true)
	if is_instance_valid(ball):
		var at := ball.position
		draw_circle(at, 11.0, Color("#314a60"), true, -1.0, true)
		draw_circle(at, 9.0, Color("#becedc"), true, -1.0, true)
		draw_circle(at - Vector2(2, 3), 4.0, Color("#f2f9ff"), true, -1.0, true)
	for index in flippers.size():
		var at := Vector2(59 if index == 0 else 318, 625)
		var flipper := flippers[index]
		var power := charge_multiplier(flipper.held) if flipper.pressed else (flipper.stored_power if flipper.ready_time > 0.0 else 1.0)
		var color := GOLD if flipper.ready_time > 0.0 or power >= 2.0 else CYAN
		draw_rect(Rect2(at, Vector2(103, 5)), Color("#253b4e"))
		draw_rect(Rect2(at, Vector2(103 * (power - 1.0), 5)), color)
		draw_string(font, at + Vector2(0, -8), "%s   %.2f×" % ["LINKS" if index == 0 else "RECHTS", power], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
