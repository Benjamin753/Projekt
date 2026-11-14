extends RigidBody2D

# Pixel-space tuning for a solid ball rolling on the inclined playfield.
# The 2D solver handles in-plane spin and contact friction.
@export var rolling_resistance := 8.0
@export var maximum_speed := 2400.0
var previous_active_pads: Dictionary = {}
@onready var radius: float = $Collision.shape.radius
var roll_angle := 0.0
var last_position := Vector2.ZERO

func _ready() -> void:
	var diameter := radius * 2.0
	$Visual/Sprite.scale = Vector2.ONE * diameter / $Visual/Sprite.texture.get_size()
	$Visual/Shadow.position = Vector2(-1.18, -0.74) * radius
	$Visual/Shadow.size = Vector2(2.85, 2.48) * radius
	$Visual/Reflection.position = -Vector2.ONE * radius
	$Visual/Reflection.size = Vector2.ONE * diameter
	last_position = global_position
	$Visual.global_position = global_position

func _process(delta: float) -> void:
	var travel := global_position - last_position
	if not freeze and travel.length() < maximum_speed * delta * 2.0 + radius:
		var direction := -1.0 if travel.x < 0.0 else 1.0
		roll_angle = wrapf(roll_angle + direction * travel.length() / radius, -PI, PI)
	last_position = global_position
	$Visual.global_position = global_position
	$Visual/Sprite.rotation = roll_angle

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var active_pads: Dictionary = {}
	for index in state.get_contact_count():
		var body := state.get_contact_collider_object(index)
		if not is_instance_valid(body):
			continue
		var id := body.get_instance_id()
		var normal := state.get_contact_local_normal(index).normalized()
		if body.has_method("strike_boost"):
			var point := state.get_contact_local_position(index)
			state.linear_velocity += body.strike_boost(point, normal)
		elif body.has_method("bounce_velocity") and body.accepts_normal(normal):
			if not previous_active_pads.has(id) and not active_pads.has(id):
				state.linear_velocity = body.bounce_velocity(state.linear_velocity, normal)
			active_pads[id] = true
	previous_active_pads = active_pads
	state.linear_velocity = state.linear_velocity.move_toward(Vector2.ZERO, rolling_resistance * state.step)
	state.linear_velocity = state.linear_velocity.limit_length(maximum_speed)
