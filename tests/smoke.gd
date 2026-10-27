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
	check(game.Enemy.VISION_RANGE == 250.0 and game.Enemy.WEAPON_RANGE == 200.0, "Local Drone has reduced ambush-friendly ranges")
	check(game.arena.asteroids.size() == 2, "Exactly two permanent asteroids")
	check(game.arena.asteroids[0].mass > 15.0, "Asteroids are heavy")
	check(game.arena.blocked(game.arena.asteroids[0].position, 5.0), "Asteroids are solid")
	check(not game.arena.has_line_of_sight(Vector2(800, 226), Vector2(1045, 226)), "Asteroid blocks line of sight inside vision range")
	check(game.arena.has_line_of_sight(Vector2(785, 405), Vector2(1000, 405)), "Clear route still provides visibility")
	var nav_goal := Vector2(1045, 226)
	var nav_first: Vector2 = game.arena.approach_waypoint(Vector2(800, 226), nav_goal, game.Enemy.COLLISION_RADIUS)
	check(nav_first != nav_goal and not game.arena.blocked(nav_first, game.Enemy.COLLISION_RADIUS), "Drones path around asteroid cover")

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

	# Shots dissipate on asteroid contact, imparting only a small impulse.
	var rock = game.arena.asteroids[0]
	game.spawn_shot(Vector2(800, 226), Vector2(415, 0), false)
	var rock_shot = game.shots[game.shots.size() - 1]
	game.step_shots(0.25)
	check(rock_shot.dissolving and rock_shot.bounces_left == 4, "Asteroid absorbs shot without ricochet")
	check(rock.velocity.x > 0.0 and rock.velocity.length() < 10.0, "Shot lightly nudges heavy asteroid")
	game.step_shots(0.4)
	check(not game.shots.has(rock_shot), "Absorbed shot fades completely")

	# Persistent player thrust moves the asteroid; it does not cause hull damage.
	game.arena.reset_asteroids()
	game.ship.position = Vector2(813, 226)
	game.ship.velocity = Vector2(180, 0)
	var hull_before: int = game.ship.hull
	game.ship.step(0.55, game.arena)
	check(game.ship.hull == hull_before, "Ramming an asteroid does not hurt ship")
	check(rock.velocity.x > 0.0, "Ship contact transfers momentum into rock")
	check(not game.arena.blocked(game.ship.position, game.Ship.COLLISION_RADIUS), "Ship remains outside rock")
	game.arena.reset_asteroids()
	game.ship.position = Vector2(874, 226)
	game.ship.velocity = Vector2.ZERO
	game.ship.rotation = PI / 2.0
	Input.action_press("thrust")
	for frame in range(180):
		game.arena.advance_asteroids(1.0 / 60.0, [game.ship])
		game.ship.step(1.0 / 60.0, game.arena)
	Input.action_release("thrust")
	check(rock.position.x > rock.starting_position.x + 2.0, "Repeated thrust slowly pushes heavy rock")
	check(game.ship.hull == hull_before, "Sustained rock contact remains harmless")
	var rock_speed: float = rock.velocity.length()
	game.arena.apply_blast(rock.position + Vector2(-50, 0), 850.0, 180.0)
	check(rock.velocity.length() > rock_speed, "Large explosion can give asteroid a stronger impulse")

	# Rocks reset cleanly between lives.
	game.arena.reset_asteroids()
	check(rock.position == rock.starting_position and rock.velocity == Vector2.ZERO, "Restartable asteroid positions")
	game.ship.rotation = 0.0
	game.ship.position = Vector2(220, 425)
	game.ship.velocity = Vector2.ZERO

	# Local Drone: idle while unseen, detect in 360 degrees, respect range.
	var sentry = game.Enemy.new()
	sentry.position = Vector2(250, 230)
	game.add_child(sentry)
	sentry.fire_timer = 0.0
	sentry.step(0.1, Vector2(1020, 230), game.arena)
	check(not sentry.spotted_once and sentry.velocity.is_zero_approx(), "Unalerted drone holds position")
	var seen_at := Vector2(350, 230)
	sentry.step(0.1, seen_at, game.arena)
	check(sentry.spotted_once and sentry.can_see_player, "Drone acquires 360 degree sight")
	check(sentry.velocity.is_zero_approx(), "Sentry does not pursue a target already in firing range")
	check(sentry.ready_to_fire(seen_at, game.arena), "Turret aligned with seen in-range target")
	check(not sentry.ready_to_fire(Vector2(610, 230), game.arena), "Weapon range is shorter than sight")

	# Turret rotation is independent of hull motion; only fires once aligned.
	sentry.turret_angle = PI
	sentry.step(0.02, seen_at, game.arena)
	check(not sentry.ready_to_fire(seen_at, game.arena), "No instant firing through turret turn")
	sentry.step(0.60, seen_at, game.arena)
	check(sentry.ready_to_fire(seen_at, game.arena), "Turret turns toward target at finite speed")

	# Out of sight, pursue the LAST sighting, never the unseen player position.
	sentry.step(0.1, Vector2(1020, 230), game.arena)
	check(not sentry.can_see_player and sentry.velocity.x > 0.0, "Search moves toward last sighting")
	check(sentry.last_seen_position.is_equal_approx(seen_at), "Lost drone remembers old position")
	check(not sentry.ready_to_fire(Vector2(1020, 230), game.arena), "No shooting at unseen targets")

	# Cross-core visibility check, despite the player being within sensor radius.
	var hidden = game.Enemy.new()
	hidden.position = Vector2(465, 425)
	game.add_child(hidden)
	hidden.step(0.1, Vector2(715, 425), game.arena)
	check(not hidden.spotted_once and not hidden.can_see_player, "Core blocks drone vision")
	check(hidden.velocity.is_zero_approx(), "Unalerted drone ignores unseen players")
	hidden.free()
	var behind_rock = game.Enemy.new()
	behind_rock.position = Vector2(800, 226)
	game.add_child(behind_rock)
	behind_rock.step(0.1, Vector2(1045, 226), game.arena)
	check(not behind_rock.spotted_once and behind_rock.velocity.is_zero_approx(), "Asteroid allows Local Drone ambush")
	behind_rock.free()
	sentry.free()

	# Integrate sentry fire through the main coordinator.
	var shooter = game.Enemy.new()
	shooter.position = Vector2(250, 230)
	shooter.turret_angle = 0.0
	shooter.fire_timer = 0.0
	game.add_child(shooter)
	game.enemies.append(shooter)
	game.ship.position = Vector2(350, 230)
	game.ship.velocity = Vector2.ZERO
	game._physics_process(0.016)
	var hostile_shots := 0
	for shot in game.shots:
		if shot.hostile:
			hostile_shots += 1
	check(hostile_shots == 1, "Local Drone shoots from its turret only when aligned")
	game.enemies.clear()
	shooter.free()
	for shot in game.shots:
		shot.free()
	game.shots.clear()

	# Start a real wave, then isolate the final drone for collision tests.
	# This also exercises the actual last-enemy wave-clear transition.
	game.start_wave()
	for drone in game.enemies:
		drone.free()
	game.enemies.clear()

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

	# Final player hit creates a large, visible death cloud BEFORE game over.
	game.ship.hull = 1
	game.ship.invulnerable = 0.0
	check(game.ship.hit(), "Final hull hit registered")
	game._physics_process(0.01)
	check(game.dying and not game.ship.visible and not game.game_over, "Ship replaced by death explosion")
	check(game.death_timer > 0.0 and game.death_timer <= game.DEATH_EXPLOSION_TIME, "Death presentation timer running")
	var wreckage = game.effects[game.effects.size() - 1]
	check(wreckage.fragments.size() >= 30 and wreckage.duration >= 0.85, "Death spawns extended wreckage cloud")
	game._physics_process(0.4)
	check(game.dying and not game.game_over and wreckage.remaining > 0.0, "Death debris remains visible before game over")
	game._physics_process(0.55)
	check(game.game_over and not game.dying, "Game over waits until debris animation")

	game.reset()
	check(game.ship.visible and not game.game_over and not game.dying, "Restart restores player ship")
	check(game.arena.asteroids[0].position == game.arena.asteroids[0].starting_position, "Restart puts asteroids back")
	check(game.arena.segments.size() == 28 and game.effects.is_empty(), "Restart clears particle effects")
	game.free()
	await process_frame
	print("OMEGAWAR SMOKE: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
