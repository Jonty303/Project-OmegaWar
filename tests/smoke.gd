extends SceneTree
# Deterministic integration checks; run with --headless --path . --script tests/smoke.gd.
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
	check(game.ship.hull == 3 and game.pickups.size() == 3, "Initial state")
	check(has_pad_button("pause_game", JOY_BUTTON_START), "Controller Start pauses")
	check(has_pad_button("restart", JOY_BUTTON_Y), "Controller Y restarts")
	check(has_pad_button("boost", JOY_BUTTON_LEFT_SHOULDER), "Controller boost")
	check(has_pad_axis("turn_left", JOY_AXIS_LEFT_X, -1.0), "Analog steering mapped")
	check(has_pad_axis("thrust", JOY_AXIS_LEFT_Y, -1.0), "Analog thrust mapped")
	check(has_pad_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0), "Controller right trigger fires")
	var start: Vector2 = game.ship.position
	Input.action_press("thrust")
	game._physics_process(0.1)
	Input.action_release("thrust")
	check(game.ship.position.distance_to(start) > 0, "Thrust moves ship")
	var speed: float = game.ship.velocity.length()
	game._physics_process(0.1)
	check(is_equal_approx(game.ship.velocity.length(), speed), "Momentum persists")
	Input.action_press("brake")
	game._physics_process(0.1)
	Input.action_release("brake")
	check(game.ship.velocity.length() < speed, "Brake reduces speed")
	game.ship.position = Vector2(450, 425)
	game.ship.velocity = Vector2(520, 0)
	game.ship.step(0.2, game.arena, Vector2.ZERO)
	check(not game.arena.blocked(game.ship.position, game.Ship.COLLISION_RADIUS), "Core collision")
	game.ship.position = Vector2(60, 200)
	game.ship.velocity = Vector2(-520, 0)
	game.ship.step(0.2, game.arena, Vector2.ZERO)
	check(not game.arena.blocked(game.ship.position, 14), "Boundary collision")
	game.ship.velocity = Vector2.ZERO
	for i in range(3):
		game.ship.position = game.pickups[0].position
		game._physics_process(0.01)
	check(game.ship.shield > 0 and game.ship.boost > 0 and game.ship.rapid > 0, "All pickup effects")
	game.ship.invulnerable = 0
	game.ship.hit()
	check(game.ship.hull == 3, "Shield absorbs damage")
	game.ship.shield = 0
	game.ship.invulnerable = 0
	game.ship.hit()
	game.ship.hit()
	check(game.ship.hull == 2, "Damage and invulnerability window")
	game.start_wave()
	check(game.enemies.size() >= 4 and game.enemies.size() <= 6, "Randomized first wave count")
	var well = game.enemies[0]
	check(well.gravity_at(well.position + Vector2(100, 0)).x < 0, "Gravity attracts")
	check(well.gravity_at(well.position + Vector2(300, 0)) == Vector2.ZERO, "Gravity range")
	# Isolate swept bullet collision from AI motion.
	for enemy in game.enemies:
		enemy.free()
	game.enemies.clear()
	var target = game.Enemy.new()
	target.position = Vector2(300, 200)
	target.health = 1
	game.add_child(target)
	game.enemies.append(target)
	game.spawn_shot(Vector2(200, 200), Vector2(650, 0), false)
	game.step_shots(0.2)
	check(game.enemies.is_empty() and game.score == 100, "Swept projectile kill and score")
	game.spawn_shot(Vector2(450, 400), Vector2(650, 0), false)
	game.step_shots(0.2)
	check(game.shots.is_empty(), "Core blocks bullets")
	game._physics_process(0.01)
	check(game.waiting_for_wave and is_equal_approx(game.wave_delay, 5.0), "Wave clear starts five-second countdown")
	var pause_button := InputEventJoypadButton.new()
	pause_button.button_index = JOY_BUTTON_START
	pause_button.pressed = true
	game._unhandled_input(pause_button)
	check(game.paused, "Controller pauses gameplay")
	start = game.ship.position
	game._physics_process(1.0)
	check(game.ship.position == start and is_equal_approx(game.wave_delay, 5.0), "Pause freezes movement and countdown")
	game._unhandled_input(pause_button)
	check(not game.paused, "Controller resumes gameplay")
	game._physics_process(4.99)
	check(game.wave == 1 and game.enemies.is_empty(), "No enemies before five seconds")
	game._physics_process(0.02)
	check(game.wave == 2 and game.enemies.size() >= 5 and game.enemies.size() <= 7, "Randomized wave respawns after five seconds")
	game.ship.hull = 0
	game._physics_process(0.01)
	check(game.game_over, "Game over")
	game.reset()
	check(game.ship.hull == 3 and game.wave == 0 and game.score == 0 and game.shots.is_empty(), "Restart reset")
	# Exercise sustained fire and several thousand simulation frames.
	Input.action_press("fire")
	for frame in range(3600):
		game.ship.invulnerable = 2
		game._physics_process(1.0 / 60)
	Input.action_release("fire")
	check(game.shots.size() < 100, "Projectile lifetime bounds")
	game.free()
	await process_frame
	print("OMEGAWAR SMOKE: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
