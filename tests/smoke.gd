extends SceneTree
# Run using Godot 4.5.2: --headless --path . --script tests/smoke.gd

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

	check(game.ship.hull == 3 and game.enemies.is_empty(), "Clean initial state")
	check(game.arena.segments.size() == 28, "Segmented outer walls and core")
	check(game.Ship.THRUST_ACCELERATION < 320.0, "Slow acceleration preserved")
	check(game.ship.weapon.SHOT_SPEED < 650.0, "Slower projectiles preserved")

	Input.action_press("thrust")
	game._physics_process(0.1)
	Input.action_release("thrust")
	var velocity: Vector2 = game.ship.velocity
	game._physics_process(0.1)
	check(game.ship.velocity.is_equal_approx(velocity), "No passive momentum decay")

	# Wall flash is local: exactly one section lights up, and ship stays intact.
	game.ship.position = Vector2(60, 200)
	game.ship.velocity = Vector2(-160, 0)
	game.ship.step(0.3, game.arena)
	check(game.ship.velocity.x > 0.0, "Ship bounces from left wall")
	var lit := 0
	for segment in game.arena.segments:
		if float(segment["flash"]) > 0.0:
			lit += 1
	check(lit == 1, "Only the impacted wall section flashes")
	check(game.effects.size() > 0, "Wall impact emits temporary debris")

	game.ship.position = Vector2(220, 425)
	game.ship.velocity = Vector2.ZERO
	game.spawn_shot(Vector2(100, 220), Vector2(-415, 0), false)
	var wall_shot = game.shots[game.shots.size() - 1]
	check(wall_shot.visual_heading.x < 0.0, "Shot starts facing its travel direction")
	game.step_shots(0.22)
	check(wall_shot.velocity.x > 0.0 and wall_shot.bounces_left == 3, "Outer ricochet")
	check(wall_shot.visual_heading.is_equal_approx(wall_shot.velocity.normalized()), "Heading matches rebound")

	game.spawn_shot(Vector2(440, 425), Vector2(415, 0), false)
	var core_shot = game.shots[game.shots.size() - 1]
	game.step_shots(0.2)
	check(core_shot.velocity.x < 0.0, "Central-core ricochet")
	check(core_shot.visual_heading.is_equal_approx(core_shot.velocity.normalized()), "Core bounce rotates bullet")

	# Distance expiration produces a fade phase before removal.
	game.spawn_shot(Vector2(220, 240), Vector2(415, 0), false)
	var expired = game.shots[game.shots.size() - 1]
	expired.distance_travelled = game.Projectile.MAX_RANGE - 1.0
	game.step_shots(0.1)
	check(expired.dissolving and game.shots.has(expired), "Range expiry starts disintegration")
	game.step_shots(0.4)
	check(not game.shots.has(expired), "Shot removed after disintegration")

	# Ramming applies an impulse and draws a particle cloud.
	var target = game.Enemy.new()
	target.position = Vector2(320, 210)
	target.velocity = Vector2.ZERO
	target.health = 2
	game.add_child(target)
	game.enemies.append(target)
	game.ship.position = Vector2(297, 210)
	game.ship.velocity = Vector2(150, 0)
	game.ship.invulnerable = 0.0
	var particles_before: int = game.effects.size()
	game.resolve_collisions()
	check(game.ship.velocity.x < 150.0 and target.velocity.x > 0.0, "Impulse shares momentum")
	check(game.effects.size() > particles_before, "Body collision spawns debris")
	check(game.ship.hull == 2, "High-speed ram deals damage")

	# Shooting the drone removes it and produces a separate impact cloud.
	target.health = 1
	target.position = Vector2(320, 210)
	game.ship.position = Vector2(100, 600)
	particles_before = game.effects.size()
	game.spawn_shot(Vector2(265, 210), Vector2(415, 0), false)
	game.step_shots(0.2)
	check(game.enemies.is_empty() and game.score == 100, "Bullet kills drone")
	check(game.effects.size() > particles_before, "Bullet hit emits fragments")

	game._physics_process(0.01)
	check(game.waiting_for_wave and is_equal_approx(game.wave_delay, 5.0), "Five-second delay after clear")
	var pause_button := InputEventJoypadButton.new()
	pause_button.button_index = JOY_BUTTON_START
	pause_button.pressed = true
	game._unhandled_input(pause_button)
	game._physics_process(1.0)
	check(game.paused and is_equal_approx(game.wave_delay, 5.0), "Controller pause freezes countdown")
	game._unhandled_input(pause_button)
	check(not game.paused, "Controller resumes")

	game.reset()
	check(game.arena.segments.size() == 28 and game.effects.is_empty(), "Restart clears particle effects")
	game.free()
	await process_frame
	print("OMEGAWAR SMOKE: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
