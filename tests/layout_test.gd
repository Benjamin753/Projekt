extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)

func frames(count: int) -> void:
	for frame in count:
		await physics_frame
	await process_frame

func launch(game) -> void:
	game.set_spring_pressed(true)
	game._physics_process(1.0)
	game.set_spring_pressed(false)

func place_ball(game, at: Vector2, velocity: Vector2) -> void:
	PhysicsServer2D.body_set_state(game.ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0, at))
	PhysicsServer2D.body_set_state(game.ball.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, velocity)
func run() -> void:
	var game = load("res://pinball.tscn").instantiate()
	game.high_score_path = "res://.godot/test_dynamic_layout.cfg"
	game.position = Vector2(23, -17)
	var table: Node2D = game.get_node("Table")
	table.position = Vector2(33, 19)
	table.rotation = 0.07
	var launcher: Node2D = table.get_node("Launcher")
	launcher.position += Vector2(-4, -12)
	launcher.rotation = -0.12
	root.add_child(game)
	await frames(2)
	var spawn: Marker2D = launcher.get_node("Spawn")
	var pull_end: Marker2D = launcher.get_node("PullEnd")
	check(game.ball.global_position.is_equal_approx(spawn.global_position), "Initial spawn follows transformed game, table and launcher nodes.")
	launcher.position += Vector2(6, 4)
	launcher.scale = Vector2(1.1, 0.9)
	game._physics_process(0.0)
	check(game.ball.global_position.is_equal_approx(spawn.global_position), "Moving the launcher updates the waiting ball.")
	game.set_spring_pressed(true)
	game._physics_process(1.0)
	check(game.ball.global_position.distance_to(spawn.global_position.lerp(pull_end.global_position, 0.5)) < 0.1, "Half charge uses the current Spawn-to-PullEnd segment.")
	var launch_direction: Vector2 = (spawn.global_position - pull_end.global_position).normalized()
	game.set_spring_pressed(false)
	check(game.ball.linear_velocity.normalized().dot(launch_direction) > 0.999, "Launch velocity follows the transformed spring direction.")
	game.ball.gravity_scale = 0.0
	var return_area: Area2D = launcher.get_node("ReturnArea")
	place_ball(game, return_area.global_position, -launch_direction * 80.0)
	await frames(8)
	check(game.phase == game.Phase.START and game.balls_left == 3, "The configured return sensor catches a returning shot without losing a life.")
	check(game.ball.global_position.distance_to(spawn.global_position) < 0.1, "A returned ball waits at the moved Spawn marker.")
	launch(game)
	game.ball.gravity_scale = 0.0
	var drain: Area2D = table.get_node("Drain")
	drain.position = Vector2(225, 185)
	await frames(2)
	place_ball(game, drain.global_position, Vector2(0, 15))
	await frames(8)
	check(game.phase == game.Phase.SHOP and game.balls_left == 2, "Moving Drain moves the actual loss trigger without a fixed y threshold.")
	game.start_round()
	await frames(2)
	launch(game)
	game.ball.gravity_scale = 0.0
	await frames(2)
	var save_spawn: Marker2D = table.get_node("BallSaveSpawn")
	save_spawn.position = Vector2(225, 520)
	save_spawn.rotation = 0.2
	game.save_time = 5.0
	place_ball(game, drain.global_position, Vector2(0, 15))
	await frames(5)
	check(game.phase == game.Phase.PLAY and game.balls_left == 2 and game.save_used, "An armed save intercepts the relocated drain once.")
	check(game.ball.global_position.distance_to(save_spawn.global_position) < 45.0, "Ball saving uses the transformed BallSaveSpawn marker.")
	check(game.ball.linear_velocity.dot(Vector2.UP.rotated(save_spawn.global_rotation)) > 0.0, "A saved ball travels upward from its marker.")
	place_ball(game, drain.global_position, Vector2(0, 15))
	await frames(8)
	check(game.phase == game.Phase.SHOP and game.balls_left == 1, "The used save cannot protect a second drain.")
	if failures == 0:
		print("Moved and rotated launcher, return, drain and ball-save checks passed")
	quit(1 if failures else 0)
