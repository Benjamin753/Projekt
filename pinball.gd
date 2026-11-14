extends Node2D

const BALL_SCENE = preload("res://ball.tscn")
const SPRING_PULL_TIME := 2.0
const SPRING_TRAVEL := 20.0
const SPRING_MAX_SPEED := 1450.0
const MULTIPLIER_DURATION := 10.0

const Flipper = preload("res://flipper.gd")
const COSTS := [250, 450, 700]
const PIN_MAX_LEVEL := 9
const EXTRA_LIFE_COST := 500
const MAX_EXTRA_LIVES := 3
const PIN_COSTS := [300, 500, 750, 1050, 1400, 1800, 2250, 2750]
const GOLDEN_PIN_COSTS := [400, 600, 850, 1150, 1500, 1900, 2350, 2850]
const PIN_COLORS := ["green", "yellow", "blue", "green"]
const PIN_NAMES := ["Oben links", "Oben rechts", "Oben Mitte", "Unten Mitte"]
const UPGRADES := {
	"turbo": ["Turbo-Kugel", "+25 % bei schnellen Treffern", "+50 % bei schnellen Treffern", "+100 % bei schnellen Treffern"],
	"precision": ["Ladungsspeicher", "Volle Ladung klingt über 4 s ab", "Volle Ladung klingt über 5 s ab", "Volle Ladung klingt über 6 s ab"],
	"length": ["Lange Flipper", "5 % längere Flipper", "10 % längere Flipper", "15 % längere Flipper"],
	"save": ["Ballrettung", "Beide Ziel-Pins: Schutz für 6 s", "Beide Ziel-Pins: Schutz für 12 s", "Beide Ziel-Pins: Schutz bis zur Rettung"],
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
var high_score := 0
var extra_lives_bought := 0
@export var high_score_path := "user://highscore.cfg"
var high_score_save_error := OK
var drain_pending := false
var pin_levels: Array[int] = [0, 0, 0, 0, 0, 0]
var pin_hits: Array[int] = [0, 0, 0, 0, 0, 0]
var flashes: Array[float] = [0, 0, 0, 0, 0, 0]
var upgrade_levels := {"turbo": 0, "precision": 0, "length": 0, "save": 0}
var offers: Array = []
var flippers: Array[Flipper] = []
var touches := {}
var keyboard := {}
var ball: RigidBody2D
var save_targets := 0
var save_time := 0.0
var save_used := false
@onready var menu: Control = $ShopLayer/Shop
var font := ThemeDB.fallback_font

var spring_held := false
var spring_charge := 0.0
var spring_touch := -1
var multiplier_remaining := 0.0
@onready var return_sensor: CollisionShape2D = $Table/Launcher/ReturnArea/Collision
@onready var multiplier_label: Label = $HUD/Multiplier

func _ready() -> void:
	load_high_score()
	pin_levels.resize($Table/Pins.get_child_count())
	pin_levels.fill(1)
	pin_hits.resize(pin_levels.size())
	flashes.resize(pin_levels.size())
	flippers.assign([$Table/LeftFlipper, $Table/RightFlipper])
	var zones := $Table.get_node_or_null("MultiplierZones")
	if zones:
		for zone in zones.get_children():
			zone.body_entered.connect(on_multiplier_entered)
	$Table/Drain.body_entered.connect(on_drain_entered)
	for index in pin_levels.size():
		update_pin_skin(index)
	menu.configure(self)
	start_round()

func charge_multiplier(seconds: float) -> float:
	return Flipper.charge_multiplier(seconds)

func new_run() -> void:
	update_high_score()
	extra_lives_bought = 0
	balls_left = 3
	credit = 0
	score = 0
	pin_levels.fill(1)
	for index in pin_levels.size():
		update_pin_skin(index)
	pin_hits.fill(0)
	for id in UPGRADES:
		upgrade_levels[id] = 0
	start_round()

func start_round() -> void:
	if is_instance_valid(ball):
		return
	phase = Phase.START
	spring_held = false
	spring_charge = 0.0
	spring_touch = -1
	menu.hide()
	touches.clear()
	keyboard.clear()
	flashes.fill(0.0)
	multiplier_remaining = 0.0
	save_targets = 0
	save_time = 0.0
	save_used = false
	drain_pending = false
	for flipper in flippers:
		flipper.reset()
		flipper.set_length_level(upgrade_levels["length"])

	ball = BALL_SCENE.instantiate()
	ball.position = to_local($Table/Launcher/Spawn.global_position)
	ball.freeze = true
	ball.collision_layer = 0
	ball.collision_mask = 0
	ball.body_entered.connect(on_ball_contact.bind(ball))
	add_child(ball)

func set_spring_pressed(value: bool) -> void:
	if phase != Phase.START or value == spring_held:
		return
	spring_held = value
	if not value and spring_charge > 0.0:
		# Spring energy grows with compression squared; launch speed grows linearly.
		var speed := spring_charge / SPRING_PULL_TIME * SPRING_MAX_SPEED
		PhysicsServer2D.body_set_state(ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, ball.global_position))
		ball.collision_layer = 1
		ball.collision_mask = 1
		ball.freeze = false
		ball.linear_velocity = -launcher_down() * speed
		spring_charge = 0.0
		phase = Phase.PLAY

func lose_ball() -> void:
	if phase != Phase.PLAY:
		return
	update_high_score()
	balls_left -= 1
	phase = Phase.SHOP if balls_left > 0 else Phase.OVER
	multiplier_remaining = 0.0
	flashes.fill(0.0)
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
	var level := pin_levels[index] - 1
	var prices := pin_prices(index)
	if level >= prices.size() or credit < prices[level]:
		return false
	credit -= prices[level]
	pin_levels[index] += 1
	update_pin_skin(index)
	update_menu()
	return true

func buy_upgrade(id: String) -> bool:
	if phase != Phase.SHOP or id not in offers or id not in UPGRADES:
		return false
	var level: int = upgrade_levels[id]
	if level >= COSTS.size() or credit < COSTS[level]:
		return false
	credit -= COSTS[level]
	upgrade_levels[id] += 1
	update_menu()
	return true

func on_multiplier_entered(body: Node2D) -> void:
	if phase == Phase.PLAY and body == ball:
		multiplier_remaining = MULTIPLIER_DURATION

func on_ball_contact(body: Node, source: RigidBody2D) -> void:
	if phase != Phase.PLAY or source != ball or not body.has_meta("pin"):
		return
	var number: int = body.get_meta("pin")
	var level := pin_levels[number] - 1
	var points := pin_points(number, pin_levels[number])
	pin_hits[number] += 1
	flashes[number] = 0.45
	if not is_golden(number) and level > 0:
		var pin_position: Vector2 = body.global_position
		var direction := (ball.global_position - pin_position).normalized()
		ball.call_deferred("apply_central_impulse", direction * 80.0 * level)
	if ball.linear_velocity.length() >= 650.0:
		var turbo_bonus: Array[float] = [0.0, 0.25, 0.5, 1.0]
		points += roundi(points * turbo_bonus[upgrade_levels["turbo"]])
	if multiplier_remaining > 0.0:
		points *= 2
	score += points
	credit += points
	update_high_score()
	$Table/Pins.get_child(number).get_node("Points").text = "+%s" % points
	if upgrade_levels["save"] > 0 and not save_used:
		if number == 1:
			save_targets |= 1
		if number == 3:
			save_targets |= 2
		if save_targets == 3 and save_time <= 0.0:
			var durations := [0.0, 6.0, 12.0, INF]
			save_time = durations[upgrade_levels["save"]]

func is_golden(index: int) -> bool:
	return index == 2

func pin_points(index: int, level: int) -> int:
	return 100 + 50 * (level - 1) if is_golden(index) else 50 + 25 * (level - 1)

func pin_prices(index: int) -> Array:
	return GOLDEN_PIN_COSTS if is_golden(index) else PIN_COSTS

func pin_texture(index: int, level: int) -> AtlasTexture:
	var design_level := (level - 1) / 3 + 1
	return load("res://assets/pins/%s_%s.tres" % [PIN_COLORS[index], design_level])

func update_pin_skin(index: int) -> void:
	var pin := $Table/Pins.get_child(index)
	pin.get_node("Sprite").set_skin(pin_texture(index, pin_levels[index]), pin_points(index, pin_levels[index]))

func _input(event: InputEvent) -> void:
	if phase == Phase.START:
		if event is InputEventKey and not event.echo and event.physical_keycode == KEY_SPACE:
			set_spring_pressed(event.pressed)
		elif event is InputEventScreenTouch:
			if event.pressed and launcher_touch_contains(event.position) and spring_touch == -1:
				spring_touch = event.index
				set_spring_pressed(true)
			elif event.index == spring_touch and not event.pressed:
				spring_touch = -1
				if event.canceled:
					spring_held = false
					spring_charge = 0.0
				else:
					set_spring_pressed(false)
		return
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
		else:
			var side := flipper_touch_side(event.position)
			if side >= 0:
				touches[event.index] = side
		update_input()

func update_input() -> void:
	var window: float = 3.0 + upgrade_levels["precision"]
	var sides := touches.values()
	flippers[0].set_pressed(keyboard.get(KEY_A, false) or keyboard.get(KEY_LEFT, false) or 0 in sides, window)
	flippers[1].set_pressed(keyboard.get(KEY_D, false) or keyboard.get(KEY_RIGHT, false) or 1 in sides, window)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and phase in [Phase.START, Phase.PLAY]:
		spring_held = false
		spring_charge = 0.0
		spring_touch = -1
		keyboard.clear()
		touches.clear()
		for flipper in flippers:
			flipper.reset()

func _physics_process(delta: float) -> void:
	multiplier_remaining = maxf(0.0, multiplier_remaining - delta)
	for index in flashes.size():
		flashes[index] = maxf(0.0, flashes[index] - delta)
	$Table/Launcher.compression = spring_charge / SPRING_PULL_TIME
	if phase == Phase.START:
		if spring_held:
			spring_charge = minf(spring_charge + delta, SPRING_PULL_TIME)
		ball.global_position = $Table/Launcher/Spawn.global_position.lerp($Table/Launcher/PullEnd.global_position, spring_charge / SPRING_PULL_TIME)
		return
	if phase != Phase.PLAY or drain_pending:
		return
	save_time = maxf(0.0, save_time - delta)
	if save_time == 0.0 and save_targets == 3:
		save_targets = 0
	# Area overlap lists can still contain the ball after it has moved elsewhere.
	var in_return_sensor := return_sensor.shape.get_rect().has_point(return_sensor.to_local(ball.global_position))
	if in_return_sensor and ball.linear_velocity.dot(launcher_down()) > 0.0:
		return_to_launcher()
		return
	var bounds := $Table.get_node_or_null("PlayBounds/Collision") as CollisionShape2D
	if bounds and not bounds.shape.get_rect().has_point(bounds.to_local(ball.global_position)):
		lose_ball()

func launcher_down() -> Vector2:
	return ($Table/Launcher/PullEnd.global_position - $Table/Launcher/Spawn.global_position).normalized()

func launcher_touch_contains(screen_point: Vector2) -> bool:
	var local_point: Vector2 = $Table/Launcher.to_local(get_canvas_transform().affine_inverse() * screen_point)
	return $Table/Launcher/TouchBounds.get_rect().has_point(local_point)

func flipper_touch_side(screen_point: Vector2) -> int:
	var world := get_canvas_transform().affine_inverse() * screen_point
	var nearest := -1
	var distance := INF
	for index in flippers.size():
		var local_point: Vector2 = flippers[index].to_local(world)
		var center := Vector2(flippers[index].side * flippers[index].length / 2.0, 0.0)
		var candidate := local_point.distance_to(center)
		if candidate < 65.0 and candidate < distance:
			distance = candidate
			nearest = index
	return nearest

func return_to_launcher() -> void:
	ball.freeze = true
	ball.collision_layer = 0
	ball.collision_mask = 0
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.global_position = $Table/Launcher/Spawn.global_position
	phase = Phase.START
	spring_held = false
	spring_charge = 0.0
	spring_touch = -1

func on_drain_entered(body: Node2D) -> void:
	if phase != Phase.PLAY or body != ball or drain_pending:
		return
	drain_pending = true
	resolve_drain.call_deferred(body)

func resolve_drain(body: Node2D) -> void:
	drain_pending = false
	if phase != Phase.PLAY or body != ball:
		return
	if save_time > 0.0:
		save_time = 0.0
		save_used = true
		var spawn: Node2D = $Table/BallSaveSpawn
		PhysicsServer2D.body_set_state(ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, spawn.global_position))
		ball.global_position = spawn.global_position
		ball.linear_velocity = Vector2.UP.rotated(spawn.global_rotation) * 640.0
		ball.angular_velocity = 0.0
	else:
		lose_ball()

func buy_extra_life() -> bool:
	if phase != Phase.SHOP or extra_lives_bought >= MAX_EXTRA_LIVES or credit < EXTRA_LIFE_COST:
		return false
	credit -= EXTRA_LIFE_COST
	extra_lives_bought += 1
	balls_left += 1
	update_menu()
	return true

func load_high_score() -> void:
	var config := ConfigFile.new()
	if config.load(high_score_path) == OK:
		var stored: Variant = config.get_value("records", "high_score", 0)
		if stored is int or stored is float:
			high_score = maxi(0, int(stored))

func update_high_score() -> void:
	if score <= high_score:
		return
	high_score = score
	var config := ConfigFile.new()
	config.set_value("records", "high_score", high_score)
	high_score_save_error = config.save(high_score_path)

func _process(_delta: float) -> void:
	var active := multiplier_remaining > 0.0
	multiplier_label.visible = active
	multiplier_label.text = "×2 Punkte · %.1f s" % multiplier_remaining
	var zones := $Table.get_node_or_null("MultiplierZones")
	if zones:
		for zone in zones.get_children():
			zone.get_node("Label").modulate = GOLD if active else TEXT
			zone.get_node("Sprite").modulate.a = 0.38 if active else 0.18
	for index in pin_levels.size():
		var pin := $Table/Pins.get_child(index)
		pin.modulate = Color.WHITE.lerp(Color(1.7, 1.7, 1.7), flashes[index] / 0.45)
		var points: Label = pin.get_node("Points")
		points.visible = flashes[index] > 0.0
		points.modulate.a = minf(flashes[index] * 6.0, 1.0)

func update_menu() -> void:
	menu.refresh()
	menu.show()
	queue_redraw()

