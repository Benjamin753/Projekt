extends AnimatableBody2D

const BASE_LENGTH := 111.0
const REST_ANGLE := 0.27
const RAISED_ANGLE := -0.47

@export var side := 1.0
var held := 0.0
var discharge_seconds := 3.0
var animation_time := 0.0
var strike_time := 0.0
var strike_power := 1.0
var pressed := false
var struck := false
var length := BASE_LENGTH
var swing_velocity := 0.0
@onready var collider: CollisionShape2D = $Collision
@onready var sprite: Sprite2D = $Sprite

static func charge_multiplier(seconds: float) -> float:
	return 1.0 + clampf(seconds / 2.0, 0.0, 1.0)

func _ready() -> void:
	sync_to_physics = false
	sprite.flip_h = side > 0.0
	set_length_level(0)
	rotation = REST_ANGLE * side

func set_length_level(level: int) -> void:
	length = BASE_LENGTH * (1.0 + 0.05 * level)
	sprite.position.x = side * length / 2.0
	sprite.scale = Vector2((length + 28.0) / 328.0, 28.0 / 90.0)
	var shape := collider.shape as CapsuleShape2D
	shape.radius = 10.0
	shape.height = length + 20.0
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
	rotation = REST_ANGLE * side

func _physics_process(delta: float) -> void:
	animation_time += delta
	if pressed:
		held = minf(held + delta, 2.0)
	else:
		held = maxf(held - delta * 2.0 / discharge_seconds, 0.0)
	strike_time = maxf(strike_time - delta, 0.0)
	var angle := RAISED_ANGLE if pressed else REST_ANGLE
	var previous_angle := rotation
	rotation = move_toward(rotation, angle * side, delta * (13.0 if pressed else 23.0))
	swing_velocity = (rotation - previous_angle) / maxf(delta, 0.00001)
	queue_redraw()

func strike_boost(world_contact: Vector2, normal: Vector2) -> Vector2:
	if struck or not pressed or strike_time <= 0.0 or swing_velocity * side >= -0.001:
		return Vector2.ZERO
	var contact := to_local(world_contact)
	if normal.dot(Vector2.UP.rotated(rotation)) < 0.3 or contact.x * side < 0.0 or contact.x * side > length + 10.0:
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
	var pulse := 0.5 + 0.5 * sin(animation_time * (4.0 + charge * 6.0))
	if charge > 0.0:
		var glow := Color("#ffbe66")
		glow.a = charge * (0.12 + 0.1 * pulse)
		draw_line(Vector2.ZERO, tip, glow, 31.0 + 6.0 * pulse * charge, true)
	sprite.modulate = Color("#ee82b9").lerp(Color("#ffbe66"), charge)
	if charge > 0.0:
		for index in 3:
			var progress := fposmod(animation_time * 0.55 + index / 3.0, 1.0)
			var spark := Color("#fff4d9")
			spark.a = charge * sin(progress * PI)
			draw_circle(tip * progress, 1.5 + charge, spark, true, -1.0, true)
