extends AnimatableBody2D

const BASE_LENGTH := 111.0
const REST_ANGLE := 0.27
const RAISED_ANGLE := -0.47

var side := 1.0
var held := 0.0
var ready_time := 0.0
var stored_power := 1.0
var strike_time := 0.0
var strike_power := 1.0
var pressed := false
var struck := false
var length := BASE_LENGTH
var collider := CollisionShape2D.new()

static func charge_multiplier(seconds: float) -> float:
	return 1.0 + clampf(seconds / 2.0, 0.0, 1.0)

func _ready() -> void:
	sync_to_physics = false
	collider.shape = CapsuleShape2D.new()
	add_child(collider)
	set_length_level(0)
	rotation = REST_ANGLE * side

func set_length_level(level: int) -> void:
	length = BASE_LENGTH * (1.0 + 0.05 * level)
	var shape := collider.shape as CapsuleShape2D
	shape.radius = 10.0
	shape.height = length + 20.0
	collider.rotation = PI / 2.0
	collider.position.x = side * length / 2.0

func set_pressed(value: bool, charge_window: float) -> void:
	if pressed == value:
		return
	pressed = value
	if value:
		strike_power = stored_power if ready_time > 0.0 else 1.0
		ready_time = 0.0
		strike_time = 0.11
		struck = false
		held = 0.0
	else:
		stored_power = charge_multiplier(held)
		ready_time = charge_window if held > 0.025 else 0.0
		held = 0.0

func reset() -> void:
	pressed = false
	struck = false
	held = 0.0
	ready_time = 0.0
	strike_time = 0.0
	rotation = REST_ANGLE * side

func _physics_process(delta: float) -> void:
	if pressed:
		held = minf(held + delta, 2.0)
	ready_time = maxf(ready_time - delta, 0.0)
	strike_time = maxf(strike_time - delta, 0.0)
	var angle := RAISED_ANGLE if pressed else REST_ANGLE
	rotation = move_toward(rotation, angle * side, delta * (13.0 if pressed else 23.0))
	queue_redraw()

func hit(ball: RigidBody2D) -> void:
	if struck or strike_time <= 0.0:
		return
	var contact := to_local(ball.global_position)
	if contact.y > 3.0 or contact.x * side < -9.0 or contact.x * side > length + 14.0:
		return
	struck = true
	var offset := clampf(contact.x * side / length, 0.0, 1.0)
	var direction := Vector2(lerpf(0.10, 0.62, offset) * side, -1.0).rotated(rotation * 0.55)
	ball.apply_central_impulse(direction.normalized() * (570.0 + 125.0 * offset) * strike_power)

func _draw() -> void:
	var tip := Vector2(length * side, 0.0)
	var steel := Color("#9ddeec")
	if ready_time > 0.0 or (pressed and held >= 2.0):
		steel = Color("#ffbe66")
	draw_line(Vector2.ZERO, tip, Color("#0a121f"), 25.0, true)
	draw_line(Vector2.ZERO, tip, steel, 15.0, true)
	draw_circle(tip, 7.5, steel, true, -1.0, true)
	draw_circle(Vector2.ZERO, 14.0, Color("#36516a"), true, -1.0, true)
	draw_circle(Vector2.ZERO, 7.0, steel, true, -1.0, true)
