@tool
extends AnimatableBody2D

const BASE_LENGTH := 57.0
const REST_ANGLE := 0.27
const RAISED_ANGLE := -0.47

@export var side := 1.0
var held := 0.0
var discharge_seconds := 3.0
var strike_time := 0.0
var strike_power := 1.0
var pressed := false
var struck := false
var length := BASE_LENGTH
var swing_velocity := 0.0
var base_rotation := 0.0
@onready var collider: CollisionShape2D = $Collision

static func charge_multiplier(seconds: float) -> float:
	return 1.0 + clampf(seconds / 2.0, 0.0, 1.0)

func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	base_rotation = rotation
	sync_to_physics = false
	set_length_level(0)
	rotation = base_rotation + REST_ANGLE * side

func set_length_level(level: int) -> void:
	length = BASE_LENGTH * (1.0 + 0.05 * level)
	var shape := collider.shape as CapsuleShape2D
	shape.radius = 8.0
	shape.height = length + 16.0
	collider.rotation = PI / 2.0
	collider.position.x = side * length / 2.0

func set_pressed(value: bool, decay_duration: float) -> void:
	if pressed == value:
		return
	pressed = value
	discharge_seconds = maxf(decay_duration, 0.1)
	if value:
		strike_power = charge_multiplier(held)
		strike_time = 0.11
		struck = false

func reset() -> void:
	pressed = false
	struck = false
	held = 0.0
	strike_time = 0.0
	swing_velocity = 0.0
	strike_power = 1.0
	rotation = base_rotation + REST_ANGLE * side

func _physics_process(delta: float) -> void:
	if pressed:
		held = minf(held + delta, 2.0)
	else:
		held = maxf(held - delta * 2.0 / discharge_seconds, 0.0)
	strike_time = maxf(strike_time - delta, 0.0)
	var angle := RAISED_ANGLE if pressed else REST_ANGLE
	var previous_angle := rotation
	rotation = move_toward(rotation, base_rotation + angle * side, delta * (13.0 if pressed else 23.0))
	swing_velocity = (rotation - previous_angle) / maxf(delta, 0.00001)
	queue_redraw()

func strike_boost(world_contact: Vector2, normal: Vector2) -> Vector2:
	if struck or not pressed or strike_time <= 0.0 or swing_velocity * side >= -0.001:
		return Vector2.ZERO
	var contact := to_local(world_contact)
	if normal.dot(Vector2.UP.rotated(global_rotation)) < 0.3 or contact.x * side < 0.0 or contact.x * side > length + 10.0:
		return Vector2.ZERO
	struck = true
	held = 0.0
	# The solver supplies the ordinary strike; charge adds one extra surface impulse.
	var radius := world_contact - global_position
	var surface_velocity := Vector2(-radius.y, radius.x) * swing_velocity
	var surface_speed := maxf(surface_velocity.dot(normal), 0.0)
	return normal * surface_speed * 1.25 * (strike_power - 1.0)

func _draw() -> void:
	var tip := Vector2(length * side, 0.0)
	var charge := held / 2.0
	var rubber := Color("#d94761").lerp(Color("#ffb75e"), charge)
	draw_line(Vector2(1, 2), tip + Vector2(1, 2), Color("#090e17"), 20, true)
	draw_line(Vector2.ZERO, tip, rubber.darkened(0.33), 15, true)
	draw_circle(tip, 7.5, rubber.darkened(0.33), true, -1.0, true)
	var highlight_tip := tip + Vector2(0, -1.5)
	draw_line(Vector2(0, -1.5), highlight_tip, rubber, 11, true)
	draw_circle(highlight_tip, 5.5, rubber, true, -1.0, true)
	draw_line(Vector2(5 * side, -4), tip * 0.92 + Vector2(0, -4), rubber.lightened(0.34), 2, true)
	draw_circle(Vector2.ZERO, 8.5, rubber.darkened(0.33), true, -1.0, true)
	draw_circle(Vector2.ZERO, 4.0, Color("#ffd3bc").lerp(Color("#fff0c4"), charge), true, -1.0, true)
