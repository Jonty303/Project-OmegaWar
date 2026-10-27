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
	check(game.status_hud.text.contains("SECONDARY: ROCKETS 6/6") and game.status_hud.text.contains("READY IN"), "HUD tracks secondary ammunition and cooldown")
	game.ship.fired_primary()
	game.update_hud()
	check(game.ship.heat > 0.0 and game.status_hud.text.contains("HEAT"), "Primary fire raises live heat readout")
	game.ship.heat = 0.0
	check(game.arena.segments.size() == 28, "Segmented outer walls and core")
	check(game.Enemy.SHORT_VISION_RANGE == 90.0 and game.Enemy.LONG_VISION_RANGE == 400.0, "Local Drone has near-360 and long forward sensors")
	check(game.Enemy.WEAPON_RANGE == 240.0 and is_equal_approx(game.Enemy.FRONT_VISION_HALF_ANGLE, deg_to_rad(25.0)), "Forward view widens to 50 degrees without changing weapon range")
	var wide_view = game.Enemy.new()
	wide_view.position = Vector2(350, 140)
	wide_view.turret_angle = 0.0
	check(wide_view.has_sight_on(Vector2(690, 290), game.arena), "Wider cone detects an off-axis player")
	check(wide_view.has_sight_on(Vector2(745, 140), game.arena), "Extended forward view reaches almost 400 units")
	check(not wide_view.has_sight_on(Vector2(755, 140), game.arena), "Long-range view still has a hard limit")
	wide_view.free()
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
	check(game.ship.weapon.NAME == "Pulse Laser", "Initial primary weapon is Pulse Laser")
	check(is_equal_approx(game.Ship.MAX_SPEED, 320.0), "Ship has an explicit practical top speed")
	check(is_equal_approx(game.ship.weapon.SHOT_SPEED, 500.0), "Pulse Laser travels at fixed speed")
	check(game.ship.weapon.SHOT_SPEED > game.Ship.MAX_SPEED * 1.5, "Pulse Laser outpaces maximum ship speed by over 50 percent")
	check(is_equal_approx(game.ship.weapon.DAMAGE, 1.0) and is_equal_approx(game.ship.weapon.MAX_RANGE, game.Projectile.MAX_RANGE), "Pulse Laser has standard damage and range")
	check(is_equal_approx(game.ship.weapon.FIRE_INTERVAL, 0.29) and is_equal_approx(game.ship.weapon.HEAT_PER_SHOT, 6.0), "Pulse Laser retains basic rate and heat")
	check(game.status_hud.text.contains("PRIMARY: PULSE LASER"), "HUD identifies equipped Pulse Laser")

	Input.action_press("thrust")
	game._physics_process(0.1)
	Input.action_release("thrust")
	var velocity: Vector2 = game.ship.velocity
	game._physics_process(0.1)
	check(game.ship.velocity.is_equal_approx(velocity), "No passive momentum decay")

	# Ship velocity is capped without damping ordinary coasting.
	game.ship.position = Vector2(220, 220)
	game.ship.rotation = PI / 2.0
	game.ship.velocity = Vector2(319.0, 0.0)
	Input.action_press("thrust")
	game.ship.step(0.2, game.arena)
	Input.action_release("thrust")
	check(game.ship.velocity.length() <= game.Ship.MAX_SPEED + 0.001, "Thrust cannot exceed ship top speed")
	var coasting_at_cap: Vector2 = game.ship.velocity
	game.ship.step(0.1, game.arena)
	check(game.ship.velocity.is_equal_approx(coasting_at_cap), "Speed cap does not introduce coasting drag")
	game.ship.velocity = Vector2(600, 0)
	game.ship.enforce_speed_limit()
	check(is_equal_approx(game.ship.velocity.length(), game.Ship.MAX_SPEED), "Knockback cannot exceed the top speed")

	# Ship moving UP and gun pointing slightly DOWN-RIGHT, as in screenshot:
	# Pulse Laser must travel strictly DOWN-RIGHT, not inherit upward drift.
	game.ship.position = Vector2(220, 600)
	game.ship.rotation = PI / 2.0 + 0.12
	game.ship.velocity = Vector2(0, -255)
	game.ship.weapon.cooldown = 0.0
	Input.action_press("fire")
	game._physics_process(1.0 / 60.0)
	Input.action_release("fire")
	check(game.shots.size() == 1, "Pulse Laser spawns during sideways flight")
	if game.shots.size() > 0:
		var pulse = game.shots[0]
		var muzzle_heading: Vector2 = Vector2.UP.rotated(game.ship.rotation)
		check(pulse.velocity.is_equal_approx(muzzle_heading * game.ship.weapon.SHOT_SPEED), "Laser ignores perpendicular ship velocity")
		check(pulse.velocity.y > 0.0 and game.ship.velocity.y < 0.0, "Laser follows aim even when ship flies opposite bullet's vertical component")
		check(is_equal_approx(pulse.velocity.length(), game.ship.weapon.SHOT_SPEED), "Laser speed never inherits ship momentum")
		check(pulse.visual_heading.is_equal_approx(muzzle_heading), "Visible shot axis follows gun, not ship drift")
		check(is_equal_approx(pulse.damage, game.ship.weapon.DAMAGE) and is_equal_approx(pulse.max_range, game.ship.weapon.MAX_RANGE), "Pulse Laser passes damage and range to projectile")
		var shot_origin: Vector2 = pulse.position
		game.step_shots(0.10)
		check(absf((pulse.position - shot_origin).cross(muzzle_heading)) < 0.05, "Projectile flies straight along gun heading after launch")
	for pulse in game.shots:
		pulse.free()
	game.shots.clear()
	game.ship.position = Vector2(220, 425)
	game.ship.rotation = 0.0
	game.ship.velocity = Vector2.ZERO


	# Retro burners use the special action and slow a coasting ship without
	# introducing passive friction or reversing it through zero.
	check(InputMap.has_action("special") and InputMap.has_action("fire_secondary"), "Special and rocket controls are mapped")
	game.ship.velocity = Vector2(300, 0)
	game.ship.rotation = 0.0
	Input.action_press("special")
	game.ship.step(0.25, game.arena)
	check(game.ship.retro_active and game.ship.velocity.x < 300.0 and game.ship.velocity.x > 0.0, "Retro burners reduce speed and activate twin front flames")
	var speed_during_retro: float = game.ship.velocity.length()
	Input.action_release("special")
	game.ship.step(0.1, game.arena)
	check(not game.ship.retro_active and is_equal_approx(game.ship.velocity.length(), speed_during_retro), "Flames stop on release and inertia persists")
	game.ship.velocity = Vector2(3, 0)
	Input.action_press("special")
	game.ship.step(0.5, game.arena)
	Input.action_release("special")
	check(game.ship.velocity.is_zero_approx(), "Retro burners stop without reversing")
	game.ship.position = Vector2(220, 425)
	game.ship.velocity = Vector2.ZERO

	# Rockets inherit ALL launch momentum; Pulse Laser does not.
	check(game.ship.secondary.NAME == "Unguided Rockets", "Secondary is unguided rockets")
	check(game.ship.secondary.MAX_AMMO == 6 and game.ship.secondary.ammo == 6, "Limited six-rocket supply")
	check(game.ship.secondary.SHOT_SPEED < game.ship.weapon.SHOT_SPEED, "Rockets travel slower than Pulse Laser relative to ship")
	game.ship.rotation = PI / 2.0
	game.ship.position = Vector2(220, 600)
	game.ship.velocity = Vector2(120, -60)
	var before_heat: float = game.ship.heat
	game.fire_player_rocket()
	check(game.rockets.size() == 1 and game.ship.secondary.ammo == 5, "Rockets launch and consume one round")
	if game.rockets.size() > 0:
		var rocket = game.rockets[0]
		check(rocket.is_rocket and rocket.velocity.is_equal_approx(Vector2(470, -60)), "Rocket inherits horizontal and vertical launch inertia")
		check(rocket.visual_heading.is_equal_approx(rocket.velocity.normalized()), "Rocket visual faces actual momentum-adjusted heading")
		check(rocket.max_range < game.Projectile.MAX_RANGE and rocket.damage == 2.0, "Rocket medium range and damage")
	check(game.ship.heat > before_heat, "Rocket launch adds heat")
	game.fire_player_rocket()
	check(game.rockets.size() == 1 and game.ship.secondary.ammo == 5, "Secondary cooldown blocks double shots")
	game.ship.secondary.tick(1.0)
	for rocket in game.rockets:
		rocket.free()
	game.rockets.clear()
	game.ship.velocity = Vector2.ZERO
	game.ship.rotation = 0.0

	# Rockets ricochet on arena/core walls rather than exploding there.
	var wall_rocket = game.Rocket.new()
	wall_rocket.position = Vector2(100, 230)
	wall_rocket.velocity = Vector2(-350, 0)
	wall_rocket.sync_visual_heading()
	game.add_child(wall_rocket)
	game.rockets.append(wall_rocket)
	game.step_rockets(0.20)
	check(game.rockets.has(wall_rocket) and wall_rocket.velocity.x > 0.0 and wall_rocket.bounces_left == 2, "Rocket bounces and remains live after wall impact")
	check(wall_rocket.visual_heading.is_equal_approx(wall_rocket.velocity.normalized()), "Rocket sprite turns after bounce")
	for rocket in game.rockets:
		rocket.free()
	game.rockets.clear()

	# A rocket striking a heavy asteroid explodes and imparts impulse.
	game.arena.reset_asteroids()
	var blast_rock = game.arena.asteroids[0]
	var asteroid_rocket = game.Rocket.new()
	asteroid_rocket.position = Vector2(820, 226)
	asteroid_rocket.velocity = Vector2(350, 0)
	asteroid_rocket.sync_visual_heading()
	game.add_child(asteroid_rocket)
	game.rockets.append(asteroid_rocket)
	var before_effects: int = game.effects.size()
	game.step_rockets(0.30)
	check(game.rockets.is_empty() and game.effects.size() > before_effects, "Asteroid contact produces medium expanding explosion")
	check(blast_rock.velocity.x > 0.0, "Rocket explosion shifts heavy asteroid")
	game.arena.reset_asteroids()

	# Blast damage is radial, affects multiple enemies, and pushes inertia.
	game.ship.position = Vector2(150, 600)
	game.ship.velocity = Vector2.ZERO
	var near_enemy = game.Enemy.new()
	near_enemy.position = Vector2(370, 230)
	near_enemy.health = 1.0
	var far_enemy = game.Enemy.new()
	far_enemy.position = Vector2(425, 230)
	far_enemy.health = 2.0
	game.add_child(near_enemy)
	game.add_child(far_enemy)
	game.enemies.append(near_enemy)
	game.enemies.append(far_enemy)
	var cluster_rocket = game.Rocket.new()
	cluster_rocket.position = Vector2(355, 230)
	cluster_rocket.velocity = Vector2(350, 0)
	game.add_child(cluster_rocket)
	game.rockets.append(cluster_rocket)
	game.step_rockets(0.04)
	check(game.rockets.is_empty(), "Rocket detonates on enemy contact")
	check(not game.enemies.has(near_enemy), "Close blast can destroy local drone")
	check(far_enemy.health < far_enemy.max_health and far_enemy.velocity.x > 0.0, "Outer blast damages and pushes another drone")
	for ally in game.enemies:
		ally.free()
	game.enemies.clear()

	# The blast has NO friendly-fire exemption: its owner loses shields first,
	# then hull after depletion. Invulnerability is still honored normally.
	game.ship.position = Vector2(220, 580)
	game.ship.velocity = Vector2.ZERO
	game.ship.shields = 2.0
	game.ship.hull = 3.0
	game.ship.invulnerable = 0.0
	var own_rocket = game.Rocket.new()
	own_rocket.position = Vector2(230, 580)
	own_rocket.velocity = Vector2(350, 0)
	game.add_child(own_rocket)
	game.rockets.append(own_rocket)
	game.step_rockets(0.01)
	check(game.rockets.is_empty() and game.ship.shields < 2.0 and game.ship.hull == 3.0, "Self-explosion depletes shield before player hull")
	check(game.ship.velocity.length() > 0.0, "Self blast changes player's inertia")
	game.ship.shields = 0.0
	game.ship.invulnerable = 0.0
	var close_blast = game.Rocket.new()
	close_blast.position = game.ship.position + Vector2(12, 0)
	close_blast.velocity = Vector2(-100, 0)
	game.detonate_rocket(close_blast)
	check(game.ship.hull < 3.0, "Own rocket explosion damages unshielded hull")
	close_blast.free()

	# Mid-range flight end detonates instead of quietly fading, and each
	# rocket can only explode once.
	game.ship.position = Vector2(150, 600)
	game.ship.velocity = Vector2.ZERO
	var range_rocket = game.Rocket.new()
	range_rocket.position = Vector2(350, 170)
	range_rocket.velocity = Vector2(350, 0)
	range_rocket.max_range = 100.0
	range_rocket.distance_travelled = 99.0
	game.add_child(range_rocket)
	game.rockets.append(range_rocket)
	game.step_rockets(0.1)
	check(game.rockets.is_empty(), "Rocket range limit causes explosion")
	game.reset()
	check(game.rockets.is_empty() and game.ship.secondary.ammo == 6 and game.ship.secondary.cooldown == 0.0, "Restart clears rockets and replenishes secondary ammo")
	check(game.status_hud.text.contains("SECONDARY: ROCKETS 6/6") and game.status_hud.text.contains("SPECIAL: RETRO"), "HUD shows rocket supply and retro input")

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


	# The new long-range Local Drone inherits core sentry perception but
	# tries to keep a safe minimum distance and uses a slower guided weapon.
	var standoff = game.LongRangeDrone.new()
	standoff.position = Vector2(300, 230)
	standoff.turret_angle = 0.0
	standoff.fire_timer = 0.0
	game.add_child(standoff)
	check(standoff.is_missile_drone and standoff.health == 3.0 and standoff.shields == 1.0, "Long-range variant has a distinct identity and protection")
	check(standoff.combat_destination(Vector2(435, 230), game.arena).x < standoff.position.x, "Long-range drone retreats when player crosses minimum distance")
	check(standoff.combat_destination(Vector2(620, 230), game.arena).is_equal_approx(standoff.position), "Long-range drone holds its desired standoff distance")
	check(standoff.combat_destination(Vector2(685, 230), game.arena).x > standoff.position.x, "Long-range drone advances if player is beyond its preferred band")
	check(not standoff.ready_to_fire(Vector2(435, 230), game.arena), "Missile launcher will not fire inside minimum standoff distance")
	standoff.can_see_player = true
	check(standoff.ready_to_fire(Vector2(620, 230), game.arena), "Missile fires only with sight, range and barrel alignment")
	standoff.step(0.1, Vector2(435, 230), game.arena)
	check(standoff.velocity.x < 0.0, "Drone actually backs away from close player")
	standoff.position = Vector2(300, 230)
	standoff.velocity = Vector2.ZERO
	standoff.can_see_player = true
	standoff.fire_timer = 0.0
	standoff.turret_angle = 0.0
	standoff.step(0.016, Vector2(620, 230), game.arena)
	check(standoff.ready_to_fire(Vector2(620, 230), game.arena), "Long-range gun acquires distant visible player")
	standoff.free()

	# Guided missile turns gradually, then detonates at the first barrier
	# rather than reflecting. Core and exterior walls both count.
	var turn_missile = game.HomingMissile.new()
	turn_missile.position = Vector2(210, 220)
	turn_missile.velocity = Vector2(375, 0)
	turn_missile.steer(0.1, Vector2(210, 100))
	check(turn_missile.is_homing and turn_missile.hostile and turn_missile.velocity.y < 0.0, "Enemy missile steers toward player instead of flying straight")
	check(turn_missile.velocity.x > 0.0 and is_equal_approx(turn_missile.velocity.length(), turn_missile.SPEED), "Homing turn is gradual at fixed missile speed")
	check(turn_missile.blast_radius < game.Rocket.BLAST_RANGE and turn_missile.damage == 1.0, "Enemy missile has smaller blast and damage than player rocket")
	turn_missile.free()

	game.ship.position = Vector2(180, 600)
	game.ship.velocity = Vector2.ZERO
	var barrier_missile = game.HomingMissile.new()
	barrier_missile.position = Vector2(478, 425)
	barrier_missile.velocity = Vector2(375, 0)
	barrier_missile.sync_visual_heading()
	game.add_child(barrier_missile)
	game.homing_missiles.append(barrier_missile)
	var homing_effects_before: int = game.effects.size()
	game.step_homing_missiles(0.05)
	check(game.homing_missiles.is_empty(), "Homing missile explodes against the central barrier")
	check(game.effects.size() > homing_effects_before, "Barrier hit creates a shockwave")

	var edge_missile = game.HomingMissile.new()
	edge_missile.position = Vector2(55, 225)
	edge_missile.velocity = Vector2(-375, 0)
	game.add_child(edge_missile)
	game.homing_missiles.append(edge_missile)
	game.step_homing_missiles(0.05)
	check(game.homing_missiles.is_empty(), "Homing missile detonates on outside wall without bouncing")

	game.arena.reset_asteroids()
	var rock_missile = game.HomingMissile.new()
	rock_missile.position = Vector2(875, 226)
	rock_missile.velocity = Vector2(375, 0)
	game.add_child(rock_missile)
	game.homing_missiles.append(rock_missile)
	game.step_homing_missiles(0.05)
	check(game.homing_missiles.is_empty(), "Homing missile explodes against heavy asteroid")
	game.arena.reset_asteroids()

	# A missile detonates on friendly units too, creating small-area
	# collateral damage rather than passing through allies.
	var other_drone = game.Enemy.new()
	other_drone.position = Vector2(360, 230)
	game.add_child(other_drone)
	game.enemies.append(other_drone)
	var ally_missile = game.HomingMissile.new()
	ally_missile.position = Vector2(340, 230)
	ally_missile.velocity = Vector2(375, 0)
	game.add_child(ally_missile)
	game.homing_missiles.append(ally_missile)
	game.step_homing_missiles(0.03)
	check(game.homing_missiles.is_empty() and other_drone.health < other_drone.max_health, "Homing missile collides with and damages allied drones")
	game.enemies.clear()
	other_drone.free()

	game.ship.position = Vector2(320, 240)
	game.ship.velocity = Vector2.ZERO
	game.ship.shields = 2.0
	game.ship.hull = 3.0
	game.ship.invulnerable = 0.0
	var strike_missile = game.HomingMissile.new()
	strike_missile.position = Vector2(303, 240)
	strike_missile.velocity = Vector2(375, 0)
	game.add_child(strike_missile)
	game.homing_missiles.append(strike_missile)
	game.step_homing_missiles(0.01)
	check(game.homing_missiles.is_empty(), "Homing missile explodes on player contact")
	check(game.ship.shields < 2.0 and game.ship.hull == 3.0, "Small explosion applies shield-first damage")
	check(game.ship.velocity.length() > 0.0, "Guided missile explosion changes player inertia")

	game.ship.position = Vector2(220, 425)
	game.ship.velocity = Vector2.ZERO
	game.ship.invulnerable = 2.0

	# A mixed wave contains one long-range missile drone alongside ordinary
	# sentries and a Repair Bot, without increasing overall wave size.
	game.start_wave()
	var missile_units := 0
	var support_units := 0
	var ordinary_units := 0
	for unit in game.enemies:
		if unit.is_missile_drone:
			missile_units += 1
		elif unit.is_repair_bot:
			support_units += 1
		else:
			ordinary_units += 1
	check(missile_units == 1 and support_units == 1 and ordinary_units >= 2, "Mixed wave adds one standoff drone and one repair unit")
	check(game.enemies.size() >= 4 and game.enemies.size() <= 5, "Mixed wave remains compact")
	for unit in game.enemies:
		unit.free()
	game.enemies.clear()

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

	# Repair Bot must remain assigned to its original patient, regardless of
	# more convenient newcomers, until that patient is healed or destroyed.
	var assigned_bot = game.RepairBot.new()
	assigned_bot.position = Vector2(240, 250)
	var first_patient = game.Enemy.new()
	first_patient.position = Vector2(360, 250)
	first_patient.health = 1.0
	var new_patient = game.Enemy.new()
	new_patient.position = Vector2(265, 250)
	new_patient.health = 1.0
	game.add_child(assigned_bot)
	game.add_child(first_patient)
	game.add_child(new_patient)
	var waiting_allies: Array[Node2D] = [assigned_bot, first_patient]
	check(assigned_bot.MOVE_SPEED == 105.0 and assigned_bot.ACCELERATION == 150.0, "Repair Bots move slightly faster")
	check(assigned_bot.TETHER_RANGE == 170.0, "Repair tether reaches further")
	assigned_bot.step_support(0.1, waiting_allies, game.arena)
	check(assigned_bot.assigned_patient == first_patient and assigned_bot.tether_target == first_patient, "First wounded ally becomes assigned patient")
	waiting_allies.append(new_patient)
	var unserved_health: float = new_patient.health
	assigned_bot.step_support(0.2, waiting_allies, game.arena)
	check(assigned_bot.assigned_patient == first_patient, "Closer wounded ally cannot interrupt current assignment")
	check(new_patient.health == unserved_health, "Another injured ally waits until current patient is healed")
	first_patient.receive_healing(2.0, 2.0)
	assigned_bot.step_support(0.1, waiting_allies, game.arena)
	check(assigned_bot.assigned_patient == new_patient and assigned_bot.tether_target == new_patient, "Bot switches to next patient only after full recovery")
	first_patient.health = 1.0
	assigned_bot.step_support(0.1, waiting_allies, game.arena)
	check(assigned_bot.assigned_patient == new_patient, "Reinjured original patient does not steal current assignment")
	new_patient.health = 0.0
	assigned_bot.step_support(0.1, waiting_allies, game.arena)
	check(assigned_bot.assigned_patient == first_patient, "Patient death releases current healing assignment")
	waiting_allies.erase(first_patient)
	assigned_bot.step_support(0.1, waiting_allies, game.arena)
	check(assigned_bot.assigned_patient == null and assigned_bot.tether_target == null, "Removed patient clears assignment safely")
	assigned_bot.free()
	first_patient.free()
	new_patient.free()


	# An actual shield hit alerts observers able to SEE the impact, never
	# revealing the unseen attacker's position.
	for leftover in game.shots:
		leftover.free()
	game.shots.clear()
	var witness = game.Enemy.new()
	witness.position = Vector2(220, 250)
	witness.turret_angle = 0.0
	var ally_bot = game.RepairBot.new()
	ally_bot.position = Vector2(390, 250)
	game.add_child(witness)
	game.add_child(ally_bot)
	game.enemies.append(witness)
	game.enemies.append(ally_bot)
	game.ship.position = Vector2(220, 610)
	game.ship.velocity = Vector2.ZERO
	game.spawn_shot(Vector2(345, 250), Vector2(415, 0), false)
	game.step_shots(0.14)
	check(ally_bot.health == ally_bot.max_health and ally_bot.shields == ally_bot.max_shields - 1.0, "Allied shield hit registers without damaging hull")
	check(witness.searching and witness.search_goal.is_equal_approx(ally_bot.position), "Drone witnesses a shot striking ally in its forward cone")
	check(witness.alert_flash > 0.0, "Witness shows an immediate amber alert")
	check(witness.last_seen_position == Vector2.ZERO and not witness.spotted_once, "Shot never reveals unseen attacker coordinates")
	witness.step(0.12, Vector2(1040, 610), game.arena)
	check(not witness.ready_to_fire(Vector2(1040, 610), game.arena), "Alerted drone cannot fire without actual contact")
	check(witness.velocity.x > 0.0, "Alerted drone starts investigating the hit")
	game.enemies.clear()
	witness.free()
	ally_bot.free()

	# A witness must actually be able to perceive the shot: no alerts from
	# behind its gun, beyond vision, or through the core. Self-hit is special.
	var victim_point := Vector2(390, 250)
	var flank = game.Enemy.new()
	flank.position = Vector2(220, 375)
	flank.turret_angle = 0.0
	game.add_child(flank)
	check(not flank.alert_to_ally_hit(victim_point, game.arena), "Sideways impact outside cone does not alert")
	check(not flank.searching, "Sentry keeps scanning after unseen hit")
	flank.free()
	var close_rear = game.Enemy.new()
	close_rear.position = Vector2(460, 250)
	close_rear.turret_angle = 0.0
	game.add_child(close_rear)
	check(close_rear.alert_to_ally_hit(victim_point, game.arena), "90-unit omnidirectional sensor sees rear impact")
	check(close_rear.searching, "Close rear impact starts investigation")
	close_rear.free()
	var too_far = game.Enemy.new()
	too_far.position = Vector2(140, 170)
	too_far.turret_angle = 0.0
	game.add_child(too_far)
	check(not too_far.alert_to_ally_hit(Vector2(560, 170), game.arena), "Impact beyond 400 units does not alert")
	too_far.free()
	var occluded = game.Enemy.new()
	occluded.position = Vector2(465, 425)
	occluded.turret_angle = 0.0
	game.add_child(occluded)
	check(not occluded.alert_to_ally_hit(Vector2(715, 425), game.arena), "Core blocks witness vision of shot")
	occluded.free()
	var struck = game.Enemy.new()
	struck.position = Vector2(390, 250)
	struck.turret_angle = PI
	game.add_child(struck)
	check(struck.alert_to_ally_hit(struck.position, game.arena, true), "Drone notices being struck even with turret backwards")
	check(struck.searching and struck.last_seen_position == Vector2.ZERO, "Own shot impact does not reveal shooter")
	struck.free()

	# A wounded Local Drone looks back along the projectile's path, not at
	# the unseen attacker's real position, with a finite turret turn rate.
	var counterfire = game.Enemy.new()
	counterfire.position = Vector2(350, 230)
	counterfire.turret_angle = PI / 2.0
	game.add_child(counterfire)
	check(is_equal_approx(counterfire.TURRET_TURN_RATE, 7.5), "Sentry gun tracks faster when alerted")
	counterfire.react_to_incoming_shot(Vector2(415, 0), game.arena)
	check(counterfire.searching and counterfire.search_goal.x < counterfire.position.x, "Hit from left initiates investigation left")
	check(absf(counterfire.search_goal.y - counterfire.position.y) < 0.01, "Firing-line investigation has correct bearing")
	check(not counterfire.spotted_once and counterfire.last_seen_position == Vector2.ZERO, "Incoming bearing does not reveal player position")
	check(is_equal_approx(counterfire.turret_angle, PI / 2.0), "Turret does not snap instantly after a hit")
	counterfire.step(0.1, Vector2(1030, 680), game.arena)
	check(counterfire.turret_angle > PI / 2.0 and counterfire.turret_angle < PI, "Sentry visibly rotates toward incoming fire")
	check(not counterfire.ready_to_fire(Vector2(1030, 680), game.arena), "No blind counterfire without seeing target")
	counterfire.free()

	# Real projectile hit through game coordinator also passes shot direction.
	var hit_sentry = game.Enemy.new()
	hit_sentry.position = Vector2(350, 230)
	hit_sentry.turret_angle = PI / 2.0
	game.add_child(hit_sentry)
	game.enemies.append(hit_sentry)
	game.ship.position = Vector2(110, 600)
	game.spawn_shot(Vector2(260, 230), Vector2(415, 0), false)
	game.step_shots(0.25)
	check(is_equal_approx(hit_sentry.health, 1.0), "Projectile damage still registers")
	check(hit_sentry.searching and hit_sentry.search_goal.x < hit_sentry.position.x, "Actual hit redirects drone toward source bearing")
	check(hit_sentry.alert_flash > 0.0, "Directly struck sentry displays alert")
	check(hit_sentry.last_seen_position == Vector2.ZERO, "Sentry cannot learn attacker position from bullet alone")
	game.enemies.clear()
	hit_sentry.free()

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
	check(game.pause_menu_layer.visible and game.pause_reset_button.text == "RESET RUN", "Pause displays Reset Run button")
	check(game.pause_resume_button.text == "RESUME", "Pause menu provides Resume action")
	game._unhandled_input(pause_button)
	check(not game.paused and not game.pause_menu_layer.visible, "Controller resumes and hides menu")
	# Old Enter/Y restart hotkeys must not bypass the menu.
	var prior_wave: int = game.wave
	var old_restart := InputEventKey.new()
	old_restart.physical_keycode = KEY_ENTER
	old_restart.pressed = true
	game._unhandled_input(old_restart)
	check(game.wave == prior_wave and not game.paused, "Enter cannot reset a running game")
	var old_pad_restart := InputEventJoypadButton.new()
	old_pad_restart.button_index = JOY_BUTTON_Y
	old_pad_restart.pressed = true
	game._unhandled_input(old_pad_restart)
	check(game.wave == prior_wave, "Y cannot reset a running game")

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
	check(game.paused and game.pause_menu_layer.visible, "Game over opens the pause menu for restart")
	check(game.pause_resume_button.disabled, "Resume is disabled after ship destruction")
	game.reset_from_menu()
	check(not game.paused and not game.pause_menu_layer.visible and not game.game_over, "Pause-menu Reset Run starts a fresh game")

	game.reset()
	check(game.ship.visible and not game.game_over and not game.dying, "Restart restores player ship")
	check(game.arena.asteroids[0].position == game.arena.asteroids[0].starting_position, "Restart puts asteroids back")
	check(game.arena.segments.size() == 28 and game.effects.is_empty(), "Restart clears particle effects")
	game.free()
	await process_frame
	print("OMEGAWAR SMOKE: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
