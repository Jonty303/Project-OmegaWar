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
	check(game.flight_test_mode, "The flight-test scene opts into test mode")
	check(game.arena.flight_test_mode, "Arena receives flight-test flag before _ready")
	check(game.arena.asteroids.is_empty(), "No asteroids or movable cover")
	check(game.arena.segments.size() == 16, "Only outer perimeter walls remain")
	check(not game.arena.blocked(Vector2(600, 425), 15.0), "Central core is traversable")
	check(game.arena.has_line_of_sight(Vector2(425, 425), Vector2(775, 425)), "No centre obstruction blocks sensors")
	check(game.arena.gravity_at(Vector2(600, 425)).is_zero_approx(), "No active gravity in test arena")
	check(not game.arena.gravity_well.visible, "Invisible gravity well does not distract testing")
	check(game.ship.profile_name == "Medium" and game.ship.engine_name == "Standard", "Default loadout is yesterday's standard ship")
	check(is_equal_approx(game.ship.acceleration, 145.0) and is_equal_approx(game.ship.speed_limit, 320.0), "Medium/Standard matches original handling")
	check(game.test_hull_picker.item_count == 3 and game.test_engine_picker.item_count == 4, "All hulls and engines available in live panel")
	game.change_test_hull(0)
	check(game.ship.profile_name == "Light" and is_equal_approx(game.ship.mass, 0.5), "Light hull reduces mass")
	check(is_equal_approx(game.ship.speed_limit, 576.0) and game.ship.collision_radius < game.Ship.COLLISION_RADIUS, "Light hull accelerates past standard top speed and is smaller")
	game.change_test_engine(3)
	check(is_equal_approx(game.ship.speed_limit, 720.0), "Overdrive raises light ship top speed")
	game.change_test_multiplier(3.0)
	check(game.ship.acceleration <= game.Ship.THRUST_ACCELERATION * 3.0 + 0.001, "Three-times acceleration safety ceiling applies")
	check(game.ship.braking <= game.Ship.RETRO_DECELERATION * 3.0 + 0.001, "Three-times braking safety ceiling applies")
	game.change_test_hull(2)
	check(game.ship.mass == 2.0 and game.ship.max_hull == 5.0, "Heavy hull has more inertia and health")
	check(game.ship.collision_radius > game.Ship.COLLISION_RADIUS, "Heavy hull has a physically larger footprint")
	game.change_test_engine(0)
	game.change_test_multiplier(1.0)
	check(is_equal_approx(game.ship.speed_limit, 224.0), "Heavy standard ship is slow")
	game.ship.position = Vector2(480, 420)
	game.ship.velocity = Vector2(200, 0)
	game.ship.step(0.2, game.arena)
	check(game.ship.position.x > 500.0 and game.ship.velocity.x > 199.0, "Ship coasts through old central core without drag")
	game.reset_flight_test_motion()
	check(game.ship.velocity.is_zero_approx() and game.ship.position == Vector2(220, 425), "Motion reset restores standard test origin")
	game.start_wave()
	check(game.enemies.size() == 3, "First wave has exactly three local drones")
	var all_local := true
	for enemy in game.enemies:
		all_local = all_local and not enemy.is_repair_bot and not enemy.is_missile_drone
	check(all_local, "No special enemies obstruct handling evaluation")
	for enemy in game.enemies:
		enemy.free()
	game.enemies.clear()
	game.finish_wave()
	check(not game.bonus_active and game.waiting_for_wave, "No upgrade screen after a test wave")
	game.start_wave()
	check(game.enemies.size() == 2, "Second wave has only two enemies")
	game.free()
	await process_frame
	print("OMEGAWAR FLIGHT TEST: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
