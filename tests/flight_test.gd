extends SceneTree
# Run using Godot 4.5.2: --headless --path . --script tests/flight_test.gd

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	seed(303)
	var game = load("res://scenes/flight_test.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	check(game.flight_test_mode and game.arena.flight_test_mode, "Dedicated clean flight-test scene")
	check(game.arena.asteroids.is_empty() and game.arena.segments.size() == 16, "Only perimeter walls remain")
	check(not game.arena.blocked(Vector2(600, 425), 15.0), "No central obstacle")
	check(game.arena.has_line_of_sight(Vector2(425, 425), Vector2(775, 425)), "Arena is clear for beams and sensors")
	check(game.arena.gravity_at(Vector2(600, 425)).is_zero_approx(), "Gravity is disabled")
	check(not game.arena.gravity_well.visible, "Gravity well is hidden")
	check(game.ship.profile_name == "Medium" and game.ship.engine_name == "Standard", "Classic handling is the starting chassis")
	check(is_equal_approx(game.ship.acceleration, 145.0) and is_equal_approx(game.ship.speed_limit, 320.0), "Medium chassis retains original handling")
	check(game.test_hull_picker.item_count == 3 and game.test_weapon_picker.item_count == 2 and game.test_secondary_picker.item_count == 2, "Chassis, primary and secondary choices are independently selectable")
	game.change_test_hull(0)
	check(game.ship.profile_name == "Light" and is_equal_approx(game.ship.mass, 0.5), "Light chassis has less mass")
	check(is_equal_approx(game.ship.speed_limit, 576.0) and game.ship.collision_radius < game.Ship.COLLISION_RADIUS, "Light chassis is smaller and faster")
	game.change_test_hull(2)
	check(game.ship.mass == 2.0 and game.ship.max_hull == 5.0, "Heavy chassis has more inertia and HP")
	check(game.ship.collision_radius > game.Ship.COLLISION_RADIUS, "Heavy chassis has a larger collision footprint")
	check(is_equal_approx(game.ship.speed_limit, 224.0), "Heavy chassis remains slow with standard engine")
	game.ship.position = Vector2(480, 420)
	game.ship.velocity = Vector2(200, 0)
	game.ship.step(0.2, game.arena)
	check(game.ship.position.x > 500.0 and game.ship.velocity.x > 199.0, "Ship coasts through old core without passive drag")
	game.reset_flight_test_motion()
	check(game.ship.velocity.is_zero_approx() and game.ship.position == Vector2(220, 425), "Motion reset restores start")

	var Beam = load("res://scripts/charge_beam.gd")
	var beam = Beam.new()
	var weak: Dictionary = Beam.spec_for(0.12)
	var strong: Dictionary = Beam.spec_for(Beam.MAX_CHARGE)
	check(float(strong["length"]) > float(weak["length"]) * 3.0, "Long charge makes a much longer beam")
	check(float(strong["damage"]) > float(weak["damage"]) * 3.0, "Long charge substantially increases damage")
	check(beam.advance(0.5, true).is_empty() and beam.charging, "Holding fire stores charge without shooting")
	var mid_charge: Dictionary = beam.advance(0.016, false)
	check(not mid_charge.is_empty() and beam.cooldown > 0.0, "Releasing fires once and starts cooldown")
	check(beam.advance(0.016, false).is_empty(), "Release cannot repeat the same beam")
	beam.reset()
	check(beam.advance(0.03, true).is_empty() and beam.advance(0.01, false).is_empty(), "Accidental short taps do not discharge")

	var boundary_hit: Vector2 = game.arena.beam_endpoint(Vector2(600, 425), Vector2.RIGHT, 900.0)
	check(boundary_hit.is_equal_approx(Vector2(1160, 425)), "Ray is absorbed at the outer wall")
	var short_ray: Vector2 = game.arena.beam_endpoint(Vector2(600, 425), Vector2.RIGHT, 125.0)
	check(short_ray.is_equal_approx(Vector2(725, 425)), "Short ray ends at its actual range")
	game.change_test_weapon(1)
	check(game.status_hud.text.contains("LIGHTNING") and game.test_weapon_index == 1, "Lightning selected and charge status shown")
	game.ship.position = Vector2(400, 425)
	game.ship.rotation = PI / 2.0
	var near_target = game.Enemy.new()
	near_target.position = Vector2(600, 425)
	game.add_child(near_target)
	game.enemies.append(near_target)
	var far_target = game.Enemy.new()
	far_target.position = Vector2(1000, 425)
	game.add_child(far_target)
	game.enemies.append(far_target)
	game.fire_charged_beam(strong)
	check(game.enemies.is_empty(), "Fully charged instant lightning pierces two aligned enemies")
	check(game.shots.is_empty() and game.serpentine_beams.is_empty(), "Lightning is instant and has no bouncing projectile")
	check(game.effects.size() > 0, "Lightning leaves a short visible discharge")
	check(game.ship.heat > 0.0, "Lightning generates heat on discharge")
	game.charge_beam.advance(0.6, true)
	game.change_test_weapon(0)
	check(not game.charge_beam.charging and game.charge_beam.charge_time == 0.0, "Switching to pulse cancels residual charge")
	check(game.status_hud.text.contains("PULSE LASER"), "Pulse weapon can be reselected")

	# Heavy secondary holds the ship stationary before a discharge. It does
	# not replace the lightning primary, nor does lightning gain ricochet.
	game.change_test_secondary(1)
	check(game.test_secondary_index == 1 and game.status_hud.text.contains("BEAM CANNON"), "Heavy beam selected in secondary slot")
	var SerpentCharge = load("res://scripts/serpentine_charge.gd")
	var charge_model = SerpentCharge.new()
	check(not charge_model.advance(1.0, true, 140.0), "Holding secondary does not fire while charging")
	check(not charge_model.advance(0.4, false, 0.0), "Early release cancels beam discharge")
	charge_model.reset()
	check(not charge_model.advance(1.8, true, 60.0), "Full charge does not automatically fire")
	check(not charge_model.advance(0.01, false, 60.0), "A moving ship cannot release the heavy beam")
	charge_model.reset()
	charge_model.advance(1.8, true, 0.0)
	check(charge_model.ready(0.0) and charge_model.advance(0.01, false, 0.0), "Full charge released from rest fires")
	check(charge_model.cooldown > 0.0, "Heavy beam incurs secondary cooldown")

	game.change_test_hull(0)
	game.ship.position = Vector2(230, 500)
	game.ship.rotation = PI / 2.0
	game.ship.velocity = Vector2(350, 0)
	game.wave = 1
	game.waiting_for_wave = true
	game.wave_delay = 100.0
	Input.action_press("fire_secondary")
	for cycle in range(20):
		game._physics_process(0.1)
	check(game.ship.velocity.length() <= 0.75, "Beam capacitor progressively brakes even a fast light hull to a halt")
	check(game.serpentine_charge.ready(game.ship.velocity.length()), "Secondary is armed only when fully charged and stopped")
	Input.action_release("fire_secondary")
	game._physics_process(0.016)
	check(game.serpentine_beams.size() == 1, "Releasing Q launches one travelling beam")
	check(game.rockets.is_empty(), "Beam secondary does not secretly fire a rocket")
	if game.serpentine_beams.size() > 0:
		game.step_serpentine_beams(0.15)
		check(game.serpentine_beams[0].points.size() >= 4, "Beam extends along successive path segments rather than appearing instantly")

	var Serpent = load("res://scripts/serpentine_beam.gd")
	var reflected = Serpent.new()
	reflected.configure(Vector2(1125, 425), Vector2.RIGHT)
	reflected.advance(0.20, game.arena)
	check(reflected.bounce_count >= 1, "Growing serpentine beam reflects from arena walls")
	check(reflected.heading.x < 0.0, "Head reverses its horizontal heading after reflecting")
	check(reflected.points.size() > 5 and reflected.travelled > 80.0, "Reflected beam continues growing after first bounce")
	reflected.advance(3.0, game.arena)
	check(reflected.fading and reflected.travelled <= reflected.MAX_RANGE + 0.1, "Growing beam has a finite travel budget")
	reflected.advance(0.5, game.arena)
	check(reflected.expired(), "Exhausted beam fades away")

	# Damage is applied along the new travelling segments, exactly once
	# per target even while the visible filament persists.
	var target = game.Enemy.new()
	target.position = Vector2(970, 425)
	game.add_child(target)
	game.enemies.append(target)
	var damage_test = Serpent.new()
	damage_test.configure(Vector2(1120, 425), Vector2.RIGHT)
	game.add_child(damage_test)
	game.serpentine_beams.append(damage_test)
	game.step_serpentine_beams(0.35)
	check(not game.enemies.has(target), "Bounced beam can strike a drone after reflecting")
	check(damage_test.hit_targets.size() == 1, "The beam hits a given enemy once")

	game.reset()
	check(game.ship.profile_name == "Light" and game.test_weapon_index == 0 and game.test_secondary_index == 1, "Reset retains chassis, primary and secondary selections")
	game.start_wave()
	check(game.enemies.size() == 3, "First wave has exactly three local drones")
	var all_local := true
	for enemy in game.enemies:
		all_local = all_local and not enemy.is_repair_bot and not enemy.is_missile_drone
	check(all_local, "Test arena has no missile or repair enemies")
	for enemy in game.enemies:
		enemy.free()
	game.enemies.clear()
	game.finish_wave()
	check(not game.bonus_active and game.waiting_for_wave, "No upgrade screen after test wave")
	game.start_wave()
	check(game.enemies.size() == 2, "Second wave has two enemies")
	game.free()
	await process_frame
	print("OMEGAWAR FLIGHT TEST: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
