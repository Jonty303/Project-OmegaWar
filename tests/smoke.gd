extends SceneTree
# Deterministic integration checks; run with --headless --path . --script tests/smoke.gd.
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	seed(303)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	check(game.ship.hull == 3 and game.pickups.size() == 3, "Initial state")
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
	check(not game.arena.blocked(game.ship.position, 14), "Core collision")
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
	check(game.enemies.size() == 4, "First wave")
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
	game.wave_delay = 0
	game._physics_process(0.01)
	check(game.wave == 2 and game.enemies.size() == 5, "Wave progression")
	game.paused = true
	start = game.ship.position
	game._physics_process(1)
	check(game.ship.position == start, "Pause freezes simulation")
	game.paused = false
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
