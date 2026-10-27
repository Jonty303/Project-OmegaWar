extends SceneTree
# Run with: godot --headless --path . --script tests/smoke.gd
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func has_pad_button(action: String, button: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return true
	return false

func has_pad_axis(action: String, axis: int, value: float) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and event.axis == axis and is_equal_approx(event.axis_value, value):
			return true
	return false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	seed(303)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	check(game.ship.hull == 3 and game.enemies.is_empty(), "Initial three hull, no enemies")
	check(not InputMap.has_action("boost"), "No boost input action in clean project")
	check(has_pad_button("pause_game", JOY_BUTTON_START), "Controller pause")
	check(has_pad_axis("turn_left", JOY_AXIS_LEFT_X, -1.0), "Analog steering")
	check(has_pad_axis("thrust", JOY_AXIS_LEFT_Y, -1.0), "Analog thrust")
	check(has_pad_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0), "Controller trigger")
	check(game.Ship.THRUST_ACCELERATION < 320.0, "Thrust slowed")
	check(game.ship.weapon.SHOT_SPEED < 650.0, "Projectile speed slowed")

	var original: Vector2 = game.ship.position
	Input.action_press("thrust")
	game._physics_process(0.1)
	Input.action_release("thrust")
	check(game.ship.position.distance_to(original) > 0.0, "Thrust moves ship")
	var velocity: Vector2 = game.ship.velocity
	game._physics_process(0.1)
	check(game.ship.velocity.is_equal_approx(velocity), "No passive momentum decay")
	Input.action_press("brake")
	game._physics_process(0.1)
	Input.action_release("brake")
	check(game.ship.velocity.length() < velocity.length(), "Braking is an external force")
	game.ship.position = Vector2(450, 425)
	game.ship.velocity = Vector2(160, 0)
	game.ship.step(0.5, game.arena)
	check(not game.arena.blocked(game.ship.position, game.Ship.COLLISION_RADIUS), "Core collision")
	check(game.ship.velocity.x < 0.0, "Ship bounces off core")

	# Enemies should route around the core, rather than steer directly through it.
	var waypoint: Vector2 = game.arena.approach_waypoint(Vector2(350, 425), Vector2(850, 425), game.Enemy.COLLISION_RADIUS)
	check(waypoint != Vector2(850, 425), "Obstacle-aware enemy navigation")
	check(not game.arena.blocked(waypoint, game.Enemy.COLLISION_RADIUS), "Waypoint is navigable")

	game.ship.position = Vector2(220, 425)
	game.ship.velocity = Vector2.ZERO
	game.start_wave()
	check(game.enemies.size() >= 3 and game.enemies.size() <= 5, "Only a few enemies")
	check(game.enemies[0].health == 2, "No special enemy types")
	for enemy in game.enemies:
		enemy.free()
	game.enemies.clear()

	# Collision transfers momentum from player to enemy and causes a crunch.
	var target = game.Enemy.new()
	target.position = Vector2(320, 210)
	target.velocity = Vector2.ZERO
	target.health = 1
	game.add_child(target)
	game.enemies.append(target)
	game.ship.position = Vector2(297, 210)
	game.ship.velocity = Vector2(150, 0)
	game.ship.invulnerable = 0.0
	game.resolve_collisions()
	check(game.ship.velocity.x < 150.0 and target.velocity.x > 0.0, "Impulse transfers momentum")
	check(game.ship.crunch > 0.0 and target.crunch > 0.0, "Collision crunches ships")
	check(game.ship.hull == 2, "Hard body collision deals damage")

	# Projectile damages the remaining drone once; no pickups appear.
	target.position = Vector2(320, 210)
	target.health = 1
	game.ship.position = Vector2(100, 600)
	game.spawn_shot(Vector2(230, 210), Vector2(415, 0), false)
	game.step_shots(0.25)
	check(game.enemies.is_empty() and game.score == 100, "Bullet collision and score")

	# Bounce from outer boundary and also from the central obstruction.
	game.spawn_shot(Vector2(100, 220), Vector2(-415, 0), false)
	var wall_shot = game.shots[game.shots.size() - 1]
	game.step_shots(0.22)
	check(wall_shot.velocity.x > 0.0 and wall_shot.bounces_left == 3, "Projectile reflects from outer wall")
	game.spawn_shot(Vector2(440, 425), Vector2(415, 0), false)
	var core_shot = game.shots[game.shots.size() - 1]
	game.step_shots(0.2)
	check(core_shot.velocity.x < 0.0, "Projectile reflects from central core")
	for shot in game.shots:
		shot.free()
	game.shots.clear()

	game._physics_process(0.01)
	check(game.waiting_for_wave and is_equal_approx(game.wave_delay, 5.0), "Wave clear starts five-second timer")
	var pause_event := InputEventJoypadButton.new()
	pause_event.button_index = JOY_BUTTON_START
	pause_event.pressed = true
	game._unhandled_input(pause_event)
	check(game.paused, "Controller pauses")
	game._physics_process(1.0)
	check(is_equal_approx(game.wave_delay, 5.0), "Paused countdown freezes")
	game._unhandled_input(pause_event)
	check(not game.paused, "Controller resumes")
	game.ship.position = Vector2(220, 425)
	game.ship.velocity = Vector2.ZERO
	game._physics_process(4.99)
	check(game.wave == 1 and game.enemies.is_empty(), "No early respawn")
	game._physics_process(0.02)
	check(game.wave == 2 and game.enemies.size() >= 3 and game.enemies.size() <= 5, "Few enemies after five seconds")

	game.ship.hull = 0
	game._physics_process(0.01)
	check(game.game_over, "Game over")
	game.reset()
	check(game.ship.hull == 3 and game.wave == 0 and game.shots.is_empty() and game.enemies.is_empty(), "Restart resets state")
	game.free()
	await process_frame
	print("OMEGAWAR CLASSIC SMOKE: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
