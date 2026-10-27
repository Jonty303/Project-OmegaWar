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
	check(game.ship.shields == 2.0 and game.ship.max_shields == 2.0, "Player starts with separate shields")
	var DamageModel = load("res://scripts/combat_health.gd")
	var shield_hit: Vector2 = DamageModel.apply(3.0, 2.0, 1.0, 2.0)
	check(shield_hit.is_equal_approx(Vector2(3.0, 0.0)), "Weapon shield modifier leaves hull intact")
	var overflow: Vector2 = DamageModel.apply(3.0, 1.0, 2.0)
	check(overflow.is_equal_approx(Vector2(2.0, 0.0)), "Only overflow damages hull after shield depletion")
	var cannot_bypass: Vector2 = DamageModel.apply(3.0, 2.0, 1.0, 0.0, 1.0)
	check(cannot_bypass.is_equal_approx(Vector2(3.0, 2.0)), "Hull always protected by active shields")
	check(game.status_hud.text.contains("SPEED") and game.status_hud.text.contains("THRUST") and game.status_hud.text.contains("HEAT"), "Bottom HUD shows motion and heat")
	check(game.status_hud.text.contains("SECONDARY: NONE") and game.status_hud.text.contains("COOLDOWN"), "HUD distinguishes unavailable secondary and cooldown")
	game.ship.fired_primary()
	game.update_hud()
	check(game.ship.heat > 0.0 and game.status_hud.text.contains("HEAT"), "Primary fire raises live heat readout")
	game.ship.heat = 0.0
	check(game.arena.segments.size() == 28, "Segmented outer walls and core")
	check(game.Enemy.SHORT_VISION_RANGE == 90.0 and game.Enemy.LONG_VISION_RANGE == 365.0, "Local Drone has near-360 and long forward sensors")
	check(game.Enemy.WEAPON_RANGE == 240.0 and game.Enemy.FRONT_VISION_HALF_ANGLE <= deg_to_rad(25.0), "Long-range vision is a gun-aligned cone")
	check(is_equal_approx(game.arena.WALL_RESTITUTION, 0.985), "Walls preserve 98.5 percent of impact speed")
	check(game.StatusBars.SHIELD_BAR_Y_OFFSET < game.StatusBars.HEALTH_BAR_Y_OFFSET, "Shield bar is physically above hull health")
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
	check(game.ship.velocity.x > 150.0, "Ship retains almost all speed from outer-wall impact")
	var lit := 0
	for segment in game.arena.segments:
		if float(segment["flash"]) > 0.0:
			lit += 1
	check(lit == 1, "Only the impacted wall section flashes")
	check(game.effects.size() > 0, "Wall impact emits temporary debris")
	game.ship.position = Vector2(450, 425)
	game.ship.velocity = Vector2(160, 0)
	game.ship.step(0.5, game.arena)
	check(game.ship.velocity.x < -150.0, "Central core also preserves momentum")
	# Rock collision restitution and other body impulse rules remain separate.

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

	# Near-field detection is omnidirectional, but the long sensor is the gun's view.
	var facing = game.Enemy.new()
	facing.position = Vector2(250, 230)
	facing.turret_angle = 0.0
	game.add_child(facing)
	facing.step(0.016, Vector2(560, 230), game.arena)
	check(facing.can_see_player, "Long-range player directly ahead is spotted")
	check(not facing.ready_to_fire(Vector2(560, 230), game.arena), "Long sensor does not increase weapon range")
	var sideways = game.Enemy.new()
	sideways.position = Vector2(250, 230)
	sideways.turret_angle = 0.0
	game.add_child(sideways)
	sideways.step(0.016, Vector2(250, 420), game.arena)
	check(not sideways.can_see_player, "Player outside gun cone remains hidden")
	var rear = game.Enemy.new()
	rear.position = Vector2(250, 230)
	rear.turret_angle = 0.0
	game.add_child(rear)
	rear.step(0.016, Vector2(85, 230), game.arena)
	check(not rear.can_see_player, "Can approach from behind outside near sensor")
	rear.step(0.016, Vector2(190, 230), game.arena)
	check(rear.can_see_player, "Close rear approach triggers 360-degree sensor")
	facing.free()
	sideways.free()
	rear.free()

	# Passive turret slowly scans its arc and occasionally checks behind.
	var scanner = game.Enemy.new()
	scanner.position = Vector2(250, 230)
	scanner.turret_angle = 0.0
	game.add_child(scanner)
	scanner.step(1.0, Vector2(1000, 600), game.arena)
	check(scanner.turret_angle > 0.10 and scanner.turret_angle < 0.81, "Idle gun sweeps slowly")
	var old_anchor: float = scanner.scan_anchor
	var old_aim: float = scanner.turret_angle
	scanner.scan_turn_timer = 0.01
	scanner.step(0.10, Vector2(1000, 600), game.arena)
	check(absf(wrapf(scanner.scan_anchor - old_anchor, -PI, PI)) > 3.0, "Occasional about-face updates watch direction")
	check(absf(wrapf(scanner.turret_angle - old_aim, -PI, PI)) <= scanner.IDLE_TURRET_RATE * 0.10 + 0.001, "About-face is an animated turret turn")
	scanner.free()

	# Local Drone: idle while unseen, detect in 360 degrees, respect range.
	var sentry = game.Enemy.new()
	sentry.position = Vector2(250, 230)
	game.add_child(sentry)
	sentry.fire_timer = 0.0
	sentry.step(0.1, Vector2(1020, 230), game.arena)
	check(not sentry.spotted_once and sentry.velocity.is_zero_approx(), "Unalerted drone holds position")
	var seen_at := Vector2(315, 230)
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
	check(sentry.searching and sentry.search_goal.is_equal_approx(seen_at), "Investigates exactly the last sighting")
	for search_frame in range(360):
		sentry.step(1.0 / 60.0, Vector2(1020, 650), game.arena)
		if sentry.looking_around:
			break
	check(sentry.looking_around and not sentry.searching, "At last sighting, drone stops to look around")
	var hold_position: Vector2 = sentry.position
	for search_frame in range(75):
		sentry.step(1.0 / 60.0, Vector2(1020, 650), game.arena)
	check(sentry.position.distance_to(hold_position) < 12.0, "Search stays near the last reported location")
	sentry.step(6.1, Vector2(1020, 650), game.arena)
	check(not sentry.looking_around and not sentry.spotted_once, "Drone eventually returns to idle scanning")

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


	# Repair Bot is a different, unarmed support unit with slow movement.
	var medic = game.RepairBot.new()
	medic.position = Vector2(300, 245)
	var patient = game.Enemy.new()
	patient.position = Vector2(390, 245)
	patient.health = 1.0
	game.add_child(medic)
	game.add_child(patient)
	var allies: Array[Node2D] = [medic, patient]
	var initial_health: float = patient.health
	medic.step_support(0.5, allies, game.arena)
	check(medic.is_repair_bot and not medic.has_method("ready_to_fire"), "Repair Bot carries no weapon")
	check(medic.MOVE_SPEED >= 85.0 and medic.ACCELERATION >= 120.0, "Repair Bot responds faster")
	check(medic.tether_target == patient, "Nearby ally receives electric repair tether")
	check(patient.health > initial_health and patient.health <= patient.max_health, "Repair Bot restores allied hull")
	check(medic.velocity.is_zero_approx(), "Repair Bot stays close while healing")
	patient.health = patient.max_health
	patient.shields = patient.max_shields
	medic.step_support(0.1, allies, game.arena)
	check(medic.tether_target == null, "Tether disengages after repair")
	medic.shields = 1.0
	var medic_hull: float = medic.health
	medic.take_damage(1.0)
	check(medic.shields == 0.0 and medic.health == medic_hull, "Repair Bot shields deplete before six hull HP")
	medic.take_damage(1.0)
	check(medic.health == medic_hull - 1.0, "Unshielded Repair Bot loses hull")
	medic.shields = medic.max_shields
	medic.health = medic.max_health
	patient.position = Vector2(950, 245)
	patient.health = 1.0
	medic.step_support(0.25, allies, game.arena)
	check(medic.find_patient(allies) == patient, "Repair Bot detects injured allies anywhere on map")
	check(medic.tether_target == null and medic.velocity.length() > 0.0, "Repair Bot moves toward a distant ally")
	check(medic.velocity.length() <= medic.MOVE_SPEED + 0.01, "Repair Bot movement is methodical")
	patient.free()
	medic.free()

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

	# Mixed waves include the support bot, which does not fire.
	game.start_wave()
	var repair_count := 0
	for member in game.enemies:
		if member.is_repair_bot:
			repair_count += 1
	check(repair_count == 1 and game.enemies.size() >= 3 and game.enemies.size() <= 5, "Wave has one Repair Bot and a few Local Drones")
	for member in game.enemies:
		member.free()
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
	game.ship.shields = 0.0 # Test a hull-only ram after shields have been depleted.
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
	game.ship.shields = 0.0
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
