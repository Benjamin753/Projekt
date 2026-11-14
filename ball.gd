extends RigidBody2D

# Pixel-space tuning for a solid ball rolling on the inclined playfield.
# The 2D solver handles in-plane spin and contact friction.
@export var rolling_resistance := 8.0
@export var maximum_speed := 2400.0
var previous_contacts: Dictionary = {}

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var contacts: Dictionary = {}
	for index in state.get_contact_count():
		var body := state.get_contact_collider_object(index)
		if not is_instance_valid(body):
			continue
		var id := body.get_instance_id()
		var normal := state.get_contact_local_normal(index).normalized()
		if body.has_method("strike_boost"):
			var point := state.get_contact_local_position(index)
			state.linear_velocity += body.strike_boost(point, normal)
		elif body.has_method("bounce_velocity") and not previous_contacts.has(id) and not contacts.has(id):
			# The pad owns its front/back rule; passive contacts never add energy.
			if body.accepts_normal(normal):
				state.linear_velocity = body.bounce_velocity(state.linear_velocity, normal)
		contacts[id] = true
	previous_contacts = contacts
	state.linear_velocity = state.linear_velocity.move_toward(Vector2.ZERO, rolling_resistance * state.step)
	state.linear_velocity = state.linear_velocity.limit_length(maximum_speed)
