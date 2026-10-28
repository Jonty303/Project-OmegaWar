extends Node2D

const Arena = preload("res://scripts/arena.gd")
const Ship = preload("res://scripts/ship.gd")
const Enemy = preload("res://scripts/enemy.gd")
const LongRangeDrone = preload("res://scripts/long_range_drone.gd")
const HomingMissile = preload("res://scripts/homing_missile.gd")
const RepairBot = preload("res://scripts/repair_bot.gd")
const StatusBars = preload("res://scripts/status_bars.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Rocket = preload("res://scripts/rocket.gd")
const Explosion = preload("res://scripts/explosion.gd")
const ImpactParticles = preload("res://scripts/impact_particles.gd")
const Upgrades = preload("res://scripts/upgrades.gd")
const SoundBus = preload("res://scripts/sound_bus.gd")

var arena := Arena.new()
var ship: Node2D
var enemies: Array[Node2D] = []
var shots: Array[Node2D] = []
var rockets: Array[Node2D] = []
var homing_missiles: Array[Node2D] = []
var effects: Array[Node2D] = []
var score := 0
var wave := 0
var wave_delay := 1.0
var waiting_for_wave := true
var paused := false
var game_over := false
var dying := false
var death_timer := 0.0
const DEATH_EXPLOSION_TIME := 0.90
var hud := Label.new()
var banner := Label.new()
var status_hud := Label.new()
var pause_menu_layer := CanvasLayer.new()
var pause_menu_title := Label.new()
var pause_resume_button := Button.new()
var pause_reset_button := Button.new()
var sound_bus := SoundBus.new()
var bonus_layer := CanvasLayer.new()
var bonus_title := Label.new()
var bonus_buttons: Array[Button] = []
var bonus_choices: Array[Dictionary] = []
var bonus_active := false
var upgrade_counts: Dictionary = {}
# Four independent, deliberately simple automatic test-scaling tracks.
const DIFFICULTY_OPTIONS := ["count", "damage", "speed", "health"]
var difficulty_levels := {"count":0, "damage":0, "speed":0, "health":0}
var last_difficulty := "NONE"

# The separate flight-test scene opts into these settings; classic mode
# and its comprehensive smoke checks continue to use their old behaviour.
var flight_test_mode := false
const TEST_HULLS := ["Light", "Medium", "Heavy"]
const TEST_ENGINES := ["Standard", "High-Thrust", "Vector Drive", "Overdrive"]
var test_hull_index := 1
var test_engine_index := 0
var test_handling_multiplier := 1.0
var test_controls_layer := CanvasLayer.new()
var test_hull_picker := OptionButton.new()
var test_engine_picker := OptionButton.new()
var test_multiplier_slider := HSlider.new()
var test_multiplier_readout := Label.new()
const DIFFICULTY_PROJECTILE_FACTOR := 1.05
const DIFFICULTY_HEALTH_STEP := 0.5

func enemy_damage(base: float) -> float:
	return base * pow(DIFFICULTY_PROJECTILE_FACTOR, int(difficulty_levels["damage"]))

func enemy_shot_speed(base: float) -> float:
	return base * pow(DIFFICULTY_PROJECTILE_FACTOR, int(difficulty_levels["speed"]))

func increase_difficulty(category: String) -> bool:
	if not difficulty_levels.has(category):
		return false
	difficulty_levels[category] += 1
	match category:
		"count":
			last_difficulty = "+1 LOCAL DRONE"
		"damage":
			last_difficulty = "+5% ENEMY SHOT / MISSILE DAMAGE"
		"speed":
			last_difficulty = "+5% ENEMY SHOT / MISSILE SPEED"
		"health":
			last_difficulty = "+0.5 HULL HP TO ALL ENEMIES"
	return true

func scale_enemy_health(enemy: Node2D) -> void:
	var bonus: float = float(difficulty_levels["health"]) * DIFFICULTY_HEALTH_STEP
	enemy.max_health += bonus
	enemy.health += bonus

const CASCADE_SHARD_RANGE := 175.0
const CASCADE_SHARD_SPEED := 360.0
const CASCADE_SHARD_DAMAGE := 0.40

func _ready() -> void:
	bind_key("turn_left", [KEY_A, KEY_LEFT])
	bind_key("turn_right", [KEY_D, KEY_RIGHT])
	bind_key("thrust", [KEY_W, KEY_UP])
	bind_key("brake", [KEY_S, KEY_DOWN])
	bind_key("special", [KEY_SHIFT])
	bind_key("fire_secondary", [KEY_Q])
	bind_key("fire", [KEY_SPACE])
	bind_key("pause_game", [KEY_P, KEY_ESCAPE])
	# Reset is intentionally available only as a button in the pause menu.
	bind_pad_button("turn_left", [JOY_BUTTON_DPAD_LEFT])
	bind_pad_button("turn_right", [JOY_BUTTON_DPAD_RIGHT])
	bind_pad_button("thrust", [JOY_BUTTON_A, JOY_BUTTON_DPAD_UP])
	bind_pad_button("brake", [JOY_BUTTON_B, JOY_BUTTON_DPAD_DOWN])
	bind_pad_button("special", [JOY_BUTTON_B])
	bind_pad_button("fire_secondary", [JOY_BUTTON_LEFT_SHOULDER])
	bind_pad_button("fire", [JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER])
	bind_pad_button("pause_game", [JOY_BUTTON_START])
	# Menu navigation: the joypad A/primary-face button activates whichever
	# Button currently has focus. D-pad and left stick move that focus.
	bind_pad_button("ui_accept", [JOY_BUTTON_A])
	bind_pad_button("ui_up", [JOY_BUTTON_DPAD_UP])
	bind_pad_button("ui_down", [JOY_BUTTON_DPAD_DOWN])
	bind_pad_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	bind_pad_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	# Do not bind Y to global reset; accidental mid-run resets are disabled.
	bind_pad_axis("turn_left", JOY_AXIS_LEFT_X, -1.0)
	bind_pad_axis("turn_right", JOY_AXIS_LEFT_X, 1.0)
	bind_pad_axis("turn_left", JOY_AXIS_RIGHT_X, -1.0)
	bind_pad_axis("turn_right", JOY_AXIS_RIGHT_X, 1.0)
	bind_pad_axis("thrust", JOY_AXIS_LEFT_Y, -1.0)
	bind_pad_axis("brake", JOY_AXIS_LEFT_Y, 1.0)
	bind_pad_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	arena.flight_test_mode = flight_test_mode
	add_child(arena)
	add_child(sound_bus)
	arena.wall_bounced.connect(on_wall_bounced)
	arena.projectile_rebounded.connect(on_projectile_rebounded)
	arena.asteroid_struck.connect(on_asteroid_struck)
	hud.position = Vector2(40, 20)
	hud.add_theme_font_size_override("font_size", 20)
	add_child(hud)
	banner.position = Vector2(330, 205)
	banner.add_theme_font_size_override("font_size", 28)
	add_child(banner)
	status_hud.position = Vector2(34, 752)
	status_hud.add_theme_font_size_override("font_size", 16)
	add_child(status_hud)
	setup_pause_menu()
	setup_bonus_menu()
	if flight_test_mode:
		setup_flight_test_controls()
	reset()

func setup_pause_menu() -> void:
	pause_menu_layer.layer = 10
	add_child(pause_menu_layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.01, 0.02, 0.05, 0.79)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_menu_layer.add_child(backdrop)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(350, 190)
	centre.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 15)
	panel.add_child(stack)
	pause_menu_title.text = "PAUSED"
	pause_menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_menu_title.add_theme_font_size_override("font_size", 25)
	stack.add_child(pause_menu_title)
	pause_resume_button.text = "RESUME"
	pause_resume_button.custom_minimum_size = Vector2(300, 45)
	pause_resume_button.focus_mode = Control.FOCUS_ALL
	pause_resume_button.pressed.connect(resume_from_menu)
	stack.add_child(pause_resume_button)
	pause_reset_button.text = "RESET RUN"
	pause_reset_button.custom_minimum_size = Vector2(300, 45)
	pause_reset_button.focus_mode = Control.FOCUS_ALL
	pause_reset_button.pressed.connect(reset_from_menu)
	stack.add_child(pause_reset_button)
	# Explicit wrapping links guarantee pad navigation in either direction.
	pause_resume_button.focus_neighbor_bottom = pause_reset_button.get_path()
	pause_resume_button.focus_neighbor_top = pause_reset_button.get_path()
	pause_reset_button.focus_neighbor_top = pause_resume_button.get_path()
	pause_reset_button.focus_neighbor_bottom = pause_resume_button.get_path()
	pause_menu_layer.visible = false

func setup_bonus_menu() -> void:
	bonus_layer.layer = 12
	add_child(bonus_layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.018, 0.027, 0.052, 0.95)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	bonus_layer.add_child(backdrop)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(575, 395)
	centre.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	panel.add_child(stack)
	bonus_title.text = "WAVE CLEARED / CHOOSE ONE UPGRADE"
	bonus_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_title.add_theme_font_size_override("font_size", 22)
	stack.add_child(bonus_title)
	for index in range(3):
		var option := Button.new()
		option.custom_minimum_size = Vector2(515, 88)
		option.focus_mode = Control.FOCUS_ALL
		option.pressed.connect(choose_upgrade.bind(index))
		stack.add_child(option)
		bonus_buttons.append(option)
	for i in range(3):
		var before: int = (i + 2) % 3
		var after: int = (i + 1) % 3
		bonus_buttons[i].focus_neighbor_top = bonus_buttons[before].get_path()
		bonus_buttons[i].focus_neighbor_bottom = bonus_buttons[after].get_path()
	bonus_layer.visible = false

func setup_flight_test_controls() -> void:
	test_controls_layer.layer = 2
	add_child(test_controls_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(899, 63)
	panel.custom_minimum_size = Vector2(276, 230)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.09, 0.92)
	style.border_color = Color(0.20, 0.65, 0.80, 0.8)
	style.set_border_width_all(1)
	style.set_content_margin_all(9)
	panel.add_theme_stylebox_override("panel", style)
	test_controls_layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "FLIGHT LAB / LIVE LOADOUT"
	column.add_child(heading)
	var hull_label := Label.new()
	hull_label.text = "Hull"
	column.add_child(hull_label)
	for hull_name in TEST_HULLS:
		test_hull_picker.add_item(hull_name)
	test_hull_picker.select(test_hull_index)
	column.add_child(test_hull_picker)
	var engine_label := Label.new()
	engine_label.text = "Engine"
	column.add_child(engine_label)
	for engine_name in TEST_ENGINES:
		test_engine_picker.add_item(engine_name)
	test_engine_picker.select(test_engine_index)
	column.add_child(test_engine_picker)
	test_multiplier_readout.text = "Thrust / brake multiplier: 1.00x"
	column.add_child(test_multiplier_readout)
	test_multiplier_slider.min_value = 0.5
	test_multiplier_slider.max_value = 3.0
	test_multiplier_slider.step = 0.25
	test_multiplier_slider.value = test_handling_multiplier
	column.add_child(test_multiplier_slider)
	var reset_motion := Button.new()
	reset_motion.text = "RESET POSITION + VELOCITY"
	reset_motion.pressed.connect(reset_flight_test_motion)
	column.add_child(reset_motion)
	test_hull_picker.item_selected.connect(change_test_hull)
	test_engine_picker.item_selected.connect(change_test_engine)
	test_multiplier_slider.value_changed.connect(change_test_multiplier)

func change_test_hull(index: int) -> void:
	test_hull_index = index
	apply_flight_test_loadout()

func change_test_engine(index: int) -> void:
	test_engine_index = index
	apply_flight_test_loadout()

func change_test_multiplier(value: float) -> void:
	test_handling_multiplier = value
	test_multiplier_readout.text = "Thrust / brake multiplier: %.2fx" % value
	apply_flight_test_loadout()

func apply_flight_test_loadout() -> void:
	if not flight_test_mode or not is_instance_valid(ship):
		return
	ship.configure(TEST_HULLS[test_hull_index], TEST_ENGINES[test_engine_index], test_handling_multiplier)
	update_hud()

func reset_flight_test_motion() -> void:
	if not flight_test_mode or not is_instance_valid(ship):
		return
	ship.position = Vector2(220, 425)
	ship.velocity = Vector2.ZERO
	ship.rotation = 0.0
	ship.invulnerable = 2.0
	update_hud()

func finish_wave() -> void:
	if bonus_active or game_over or dying or wave <= 0:
		return
	if flight_test_mode:
		# Keep the test repeatable: no upgrade screens or difficulty scaling.
		waiting_for_wave = true
		wave_delay = 2.5
		update_hud()
		return
	# Fractional hull restoration preserves precise shield-first damage
	# values. Ammunition recovers by half of the TOTAL equipped capacity.
	ship.hull = minf(ship.max_hull, ship.hull + ship.max_hull * 0.25)
	ship.shields = ship.max_shields
	ship.secondary.ammo = mini(ship.secondary.MAX_AMMO, ship.secondary.ammo + ceili(ship.secondary.MAX_AMMO * 0.50))
	ship.queue_redraw()
	# Exactly ONE of four difficulty changes is selected per completed wave.
	increase_difficulty(DIFFICULTY_OPTIONS.pick_random())
	waiting_for_wave = true
	wave_delay = 5.0
	bonus_choices = Upgrades.offer(ship)
	for i in range(3):
		var choice: Dictionary = bonus_choices[i]
		var count: int = int(upgrade_counts.get(choice["id"], 0))
		var stack_label := "  (owned %d)" % count if count > 0 else ""
		bonus_buttons[i].text = "%s%s\n%s" % [choice["title"], stack_label, choice["description"]]
	bonus_title.text = "WAVE %02d COMPLETE / PICK ONE UPGRADE\nNEXT WAVE: %s" % [wave, last_difficulty]
	bonus_active = true
	bonus_layer.visible = true
	bonus_buttons[0].grab_focus()
	update_hud()

func choose_upgrade(index: int) -> void:
	if not bonus_active or index < 0 or index >= bonus_choices.size():
		return
	var upgrade_id: String = bonus_choices[index]["id"]
	if not Upgrades.apply(ship, upgrade_id):
		return
	upgrade_counts[upgrade_id] = int(upgrade_counts.get(upgrade_id, 0)) + 1
	bonus_active = false
	bonus_layer.visible = false
	bonus_choices.clear()
	# The existing 5s intermission starts AFTER the choice, not while
	# the player is reading the upgrade cards.
	waiting_for_wave = true
	wave_delay = 5.0
	update_hud()

func set_paused(value: bool) -> void:
	paused = value
	pause_menu_layer.visible = value
	if value:
		pause_menu_title.text = "SHIP LOST" if game_over else "PAUSED"
		pause_resume_button.disabled = game_over
		if game_over:
			pause_reset_button.grab_focus()
		else:
			pause_resume_button.grab_focus()
	update_hud()

func resume_from_menu() -> void:
	if paused and not game_over:
		set_paused(false)

func reset_from_menu() -> void:
	if paused:
		reset()

func bind_key(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)

func bind_pad_button(action: String, buttons: Array) -> void:
	for button in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		InputMap.action_add_event(action, event)

func bind_pad_axis(action: String, axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_set_deadzone(action, 0.20)
	InputMap.action_add_event(action, event)

func reset() -> void:
	for entity in enemies + shots + rockets + homing_missiles + effects:
		entity.free()
	enemies.clear()
	shots.clear()
	rockets.clear()
	homing_missiles.clear()
	effects.clear()
	arena.reset_flashes()
	arena.reset_asteroids()
	arena.set_drone_bodies(enemies)
	if is_instance_valid(ship):
		ship.free()
	ship = Ship.new()
	if flight_test_mode:
		ship.configure(TEST_HULLS[test_hull_index], TEST_ENGINES[test_engine_index], test_handling_multiplier)
	ship.position = Vector2(220, 425)
	add_child(ship)
	score = 0
	wave = 0
	wave_delay = 1.0
	waiting_for_wave = true
	paused = false
	bonus_active = false
	bonus_layer.visible = false
	bonus_choices.clear()
	upgrade_counts.clear()
	for category in DIFFICULTY_OPTIONS:
		difficulty_levels[category] = 0
	last_difficulty = "NONE"
	game_over = false
	dying = false
	death_timer = 0.0
	pause_menu_layer.visible = false
	update_hud()

func _input(event: InputEvent) -> void:
	if not paused and not bonus_active:
		return
	if event is InputEventKey and event.is_echo():
		return
	if bonus_active:
		var focused := 0
		for i in range(bonus_buttons.size()):
			if bonus_buttons[i].has_focus():
				focused = i
				break
		if event.is_action_pressed("ui_down"):
			bonus_buttons[(focused + 1) % 3].grab_focus()
		elif event.is_action_pressed("ui_up"):
			bonus_buttons[(focused + 2) % 3].grab_focus()
		elif event.is_action_pressed("ui_accept"):
			choose_upgrade(focused)
		else:
			return
		get_viewport().set_input_as_handled()
		return
	# Pause panel retains the existing controller confirm handling.
	if event.is_action_pressed("ui_down"):
		pause_reset_button.grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		(pause_reset_button if game_over else pause_resume_button).grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if game_over or pause_reset_button.has_focus():
			reset_from_menu()
		else:
			resume_from_menu()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_echo():
		return
	if bonus_active:
		return
	if event.is_action_pressed("pause_game"):
		# The pause overlay owns Reset. After death it remains open until
		# the user explicitly chooses Reset Run.
		if not game_over or not paused:
			set_paused(not paused)
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if paused or game_over or bonus_active:
		return
	sound_bus.advance(delta)
	arena.advance_gravity(delta)
	arena.advance_flashes(delta)
	step_effects(delta)
	arena.set_drone_bodies(enemies)
	var moving_bodies: Array[Node2D] = [ship]
	moving_bodies.append_array(enemies)
	arena.advance_asteroids(delta, moving_bodies)
	resolve_drone_spacing()
	if dying:
		death_timer = maxf(0.0, death_timer - delta)
		if death_timer <= 0.0:
			dying = false
			game_over = true
			set_paused(true)
		update_hud()
		return
	arena.pull_body(ship, delta)
	ship.step(delta, arena)
	if Input.is_action_pressed("fire"):
		var volley: Array[Dictionary] = ship.weapon.fire(ship.position, Vector2.UP.rotated(ship.rotation))
		if not volley.is_empty():
			ship.fired_primary()
			sound_bus.play("pulse")
		for shot in volley:
			spawn_shot(shot.position, shot.velocity, false, shot.damage, shot.max_range, shot.radius)
	if Input.is_action_just_pressed("fire_secondary"):
		fire_player_rocket()
	for enemy in enemies:
		arena.pull_body(enemy, delta)
		if enemy.is_repair_bot:
			enemy.step_support(delta, enemies, arena)
		else:
			enemy.step(delta, ship.position, arena)
			if enemy.ready_to_fire(ship.position, arena):
				if enemy.is_missile_drone:
					launch_enemy_homing_missile(enemy)
				else:
					spawn_shot(enemy.muzzle_position(), enemy.turret_direction() * enemy_shot_speed(225.0), true, enemy_damage(1.0))
					sound_bus.play("pulse")
				enemy.fired()
	resolve_collisions()
	resolve_drone_spacing()
	step_shots(delta)
	step_rockets(delta)
	step_homing_missiles(delta)
	self_destruct_orphaned_repair_bots()
	# Weapon knockback and ramming can add impulses after ship.step.
	ship.enforce_speed_limit()
	if ship.hull <= 0:
		begin_player_death()
	elif enemies.is_empty():
		if not waiting_for_wave:
			finish_wave()
		elif wave == 0:
			wave_delay -= delta
			if wave_delay <= 0.0:
				start_wave()
		else:
			wave_delay -= delta
			if wave_delay <= 0.0:
				start_wave()
	update_hud()

func begin_player_death() -> void:
	if dying or game_over:
		return
	dying = true
	death_timer = DEATH_EXPLOSION_TIME
	ship.visible = false
	ship.velocity = Vector2.ZERO
	# Larger, longer-lived burst than ordinary hits: the ship disintegrates
	# into moving wreckage before the game-over banner appears.
	spawn_debris(ship.position, Color(0.3, 1.0, 0.95), 2.1, 32, DEATH_EXPLOSION_TIME)
	sound_bus.play("explosion")
	arena.apply_blast(ship.position, 850.0, 180.0)

func resolve_drone_spacing() -> void:
	# Spatial separation fixes forced overlaps from blasts, asteroid pushes,
	# and impacts; unlike ramming the player this deals no contact damage.
	for iteration in range(8):
		var changed := false
		for i in range(enemies.size()):
			var first = enemies[i]
			if not is_instance_valid(first) or first.health <= 0.0:
				continue
			for j in range(i + 1, enemies.size()):
				var second = enemies[j]
				if not is_instance_valid(second) or second.health <= 0.0:
					continue
				var diff: Vector2 = second.position - first.position
				var distance: float = diff.length()
				var minimum: float = first.COLLISION_RADIUS + second.COLLISION_RADIUS + arena.DRONE_HARD_GAP
				if distance >= minimum:
					continue
				changed = true
				var normal: Vector2 = diff / distance if distance > 0.0001 else Vector2.RIGHT.rotated(float(i + j) * 1.19)
				var correction: Vector2 = normal * (minimum - distance + 0.02)
				var half: Vector2 = correction * 0.5
				var first_ok: bool = not arena.blocked(first.position - half, first.COLLISION_RADIUS)
				var second_ok: bool = not arena.blocked(second.position + half, second.COLLISION_RADIUS)
				if first_ok and second_ok:
					first.position -= half
					second.position += half
				elif first_ok:
					if not arena.blocked(first.position - correction, first.COLLISION_RADIUS):
						first.position -= correction
				elif second_ok:
					if not arena.blocked(second.position + correction, second.COLLISION_RADIUS):
						second.position += correction
				var closing: float = (first.velocity - second.velocity).dot(normal)
				if closing > 0.0:
					first.velocity -= normal * closing * 0.5
					second.velocity += normal * closing * 0.5
				first.queue_redraw()
				second.queue_redraw()
		if not changed:
			break

func resolve_collisions() -> void:
	# Impulse-based ship/enemy impacts: separation, momentum transfer and
	# independent debris bursts. Hull geometry never changes.
	for i in range(enemies.size() - 1, -1, -1):
		var enemy = enemies[i]
		var offset: Vector2 = ship.position - enemy.position
		var distance := offset.length()
		var minimum: float = ship.collision_radius + enemy.COLLISION_RADIUS
		if distance >= minimum:
			continue
		var normal := offset / distance if distance > 0.001 else Vector2.RIGHT
		var correction := normal * ((minimum - distance) * 0.5 + 0.1)
		if not arena.blocked(ship.position + correction, ship.collision_radius):
			ship.position += correction
		if not arena.blocked(enemy.position - correction, enemy.COLLISION_RADIUS):
			enemy.position -= correction
		var closing_speed := maxf(0.0, -(ship.velocity - enemy.velocity).dot(normal))
		if closing_speed <= 0.0:
			continue
		var ship_mass: float = ship.mass
		var enemy_mass: float = 2.2 if enemy.is_repair_bot else 1.25
		const RESTITUTION := 0.55
		var impulse := (1.0 + RESTITUTION) * closing_speed / (1.0 / ship_mass + 1.0 / enemy_mass)
		ship.velocity += normal * impulse / ship_mass
		enemy.velocity -= normal * impulse / enemy_mass
		var impact_point: Vector2 = (ship.position + enemy.position) * 0.5
		spawn_debris(impact_point, Color(1.0, 0.8, 0.45), clampf(closing_speed / 120.0, 0.7, 1.6))
		if enemy.impact(closing_speed):
			defeat_enemy(i)
		if closing_speed >= 90.0:
			ship.hit()
	ship.queue_redraw()

func notify_drones_of_hit(victim: Node2D, incoming_velocity: Vector2 = Vector2.ZERO) -> void:
	# Witnesses investigate the visible impact as before. A struck Local
	# Drone additionally looks BACK along the projectile's incoming bearing,
	# without magically knowing the player's exact position.
	for observer in enemies:
		if observer.is_repair_bot:
			continue
		observer.alert_to_ally_hit(victim.position, arena, observer == victim, incoming_velocity)
	if victim.is_repair_bot and victim.health > 0.0:
		victim.alert_incoming_fire(incoming_velocity, enemies)
	elif victim.health > 0.0:
		victim.react_to_incoming_shot(incoming_velocity, arena)

func self_destruct_orphaned_repair_bots() -> void:
	# If only support units survive, no combatants remain to defend.
	# Dispose of all remaining Repair Bots immediately with green debris.
	# This is a visual self-destruct rather than an attack on the player.
	if enemies.is_empty():
		return
	for enemy in enemies:
		if not enemy.is_repair_bot and enemy.health > 0.0:
			return
	for index in range(enemies.size() - 1, -1, -1):
		var bot = enemies[index]
		if not bot.is_repair_bot:
			continue
		spawn_debris(bot.position, Color(0.24, 1.0, 0.47), 1.6, 20, 0.64)
		var cloud := Explosion.new()
		cloud.position = bot.position
		cloud.configure(43.0)
		effects.append(cloud)
		add_child(cloud)
		arena.apply_blast(bot.position, 190.0, 65.0)
		enemies.remove_at(index)
		bot.queue_free()
	sound_bus.play("explosion")
	# Wave-clear countdown is handled normally after the final bot is gone.

func alert_repair_bots_to_fire(shot_position: Vector2, shot_velocity: Vector2) -> void:
	for bot in enemies:
		if bot.is_repair_bot and bot.health > 0.0:
			bot.observe_incoming_shot(shot_position, shot_velocity, enemies, arena)

func defeat_enemy(index: int) -> void:
	var enemy = enemies[index]
	var tint := Color(0.25, 1.0, 0.55) if enemy.is_repair_bot else (Color(0.48, 0.66, 1.0) if enemy.is_missile_drone else Color(1.0, 0.5, 0.25))
	spawn_debris(enemy.position, tint, 1.4, 16, 0.62)
	sound_bus.play("explosion")
	arena.apply_blast(enemy.position, 320.0, 100.0)
	score += 200 if enemy.is_repair_bot else (150 if enemy.is_missile_drone else 100)
	enemies.remove_at(index)
	enemy.queue_free()

func step_shots(delta: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var shot = shots[i]
		if shot.dissolving:
			if shot.step_disintegration(delta):
				shots.remove_at(i)
				shot.queue_free()
			continue
		shot.lifetime -= delta
		var steps := maxi(1, int(ceil(shot.velocity.length() * delta / 4.0)))
		var hit_target := false
		if shot.lifetime > 0.0:
			for substep in range(steps):
				if shot.bounces_left <= 0 or shot.distance_travelled >= shot.max_range:
					break
				if not shot.hostile:
					alert_repair_bots_to_fire(shot.position, shot.velocity)
				shot.velocity += arena.projectile_gravity_at(shot.position) * delta / float(steps)
				shot.sync_visual_heading()
				arena.move_shot(shot, delta / float(steps))
				if shot.dissolving:
					break # Hit heavy asteroid cover: no damage or ricochet.
				if shot.hostile:
					if shot.position.distance_to(ship.position) < Ship.COLLISION_RADIUS + Projectile.HIT_RADIUS:
						ship.velocity += shot.velocity.normalized() * 24.0
						ship.hit(shot.damage)
						spawn_debris(shot.position, Color(0.5, 1.0, 1.0), 0.75)
						hit_target = true
						break
				else:
					for j in range(enemies.size() - 1, -1, -1):
						var enemy = enemies[j]
						if shot.position.distance_to(enemy.position) < enemy.COLLISION_RADIUS + shot.hit_radius:
							enemy.velocity += shot.velocity.normalized() * 30.0
							var destroyed: bool = enemy.take_damage(shot.damage)
							notify_drones_of_hit(enemy, shot.velocity)
							var tint := Color(0.25, 1.0, 0.55) if enemy.is_repair_bot else (Color(0.48, 0.66, 1.0) if enemy.is_missile_drone else Color(1.0, 0.5, 0.25))
							spawn_debris(shot.position, tint, 0.8)
							hit_target = true
							if destroyed:
								if not shot.cascade_shard:
									maybe_cascade(enemy.position)
								defeat_enemy(j)
							break
					if hit_target:
						break
		if hit_target:
			shots.remove_at(i)
			shot.queue_free()
		elif shot.lifetime <= 0.0 or shot.bounces_left <= 0 or shot.distance_travelled >= shot.max_range:
			shot.begin_disintegrate()

func maybe_cascade(at: Vector2) -> void:
	# Pulse-specific on-kill proc. Shards are deliberately unable to
	# recursively generate another cascade.
	if ship.weapon.cascade_chance <= 0.0 or randf() >= ship.weapon.cascade_chance:
		return
	for direction_index in range(8):
		var direction: Vector2 = Vector2.from_angle(TAU * float(direction_index) / 8.0)
		var origin: Vector2 = at + direction * 17.0
		if arena.blocked(origin, 2.0):
			continue
		spawn_shot(origin, direction * CASCADE_SHARD_SPEED, false, CASCADE_SHARD_DAMAGE, CASCADE_SHARD_RANGE, 2.0, true)
	sound_bus.play("explosion")

func launch_enemy_homing_missile(enemy: Node2D) -> void:
	var origin: Vector2 = enemy.muzzle_position()
	if arena.blocked(origin, HomingMissile.RADIUS):
		return
	var missile := HomingMissile.new()
	missile.position = origin
	missile.cruise_speed = enemy_shot_speed(HomingMissile.SPEED)
	missile.velocity = enemy.turret_direction() * missile.cruise_speed
	missile.damage = enemy_damage(HomingMissile.DAMAGE)
	missile.sync_visual_heading()
	homing_missiles.append(missile)
	add_child(missile)
	sound_bus.play("missile")

func step_homing_missiles(delta: float) -> void:
	for index in range(homing_missiles.size() - 1, -1, -1):
		var missile = homing_missiles[index]
		missile.lifetime -= delta
		missile.trail_time += delta
		var detonate: bool = missile.lifetime <= 0.0 or missile.distance_travelled >= missile.max_range
		if not detonate:
			if ship.visible:
				missile.steer(delta, ship.position, arena.gravity_at(missile.position).length() / arena.gravity_well.MAX_PULL)
			var substeps: int = maxi(1, int(ceil(missile.velocity.length() * delta / 3.0)))
			for substep in range(substeps):
				missile.velocity += arena.projectile_gravity_at(missile.position, true, true) * delta / float(substeps)
				missile.sync_visual_heading()
				var next: Vector2 = missile.position + missile.velocity * (delta / float(substeps))
				# Missiles NEVER bounce: both the core and exterior walls
				# count as barriers that trigger an immediate explosion.
				if arena.blocked_static(next, missile.hit_radius) or arena.asteroid_at(next, missile.hit_radius) != null:
					detonate = true
					break
				missile.distance_travelled += missile.position.distance_to(next)
				missile.position = next
				if missile.distance_travelled >= missile.max_range:
					detonate = true
					break
				if ship.visible and missile.position.distance_to(ship.position) <= Ship.COLLISION_RADIUS + missile.hit_radius:
					detonate = true
					break
				for enemy in enemies:
					if missile.position.distance_to(enemy.position) <= enemy.COLLISION_RADIUS + missile.hit_radius:
						detonate = true
						break
				if detonate:
					break
		if detonate:
			detonate_rocket(missile)
			homing_missiles.remove_at(index)
			missile.queue_free()
		else:
			missile.queue_redraw()

func fire_player_rocket() -> void:
	var direction: Vector2 = Vector2.UP.rotated(ship.rotation)
	var launch_point: Vector2 = ship.position + direction * ship.secondary.MUZZLE_OFFSET
	# Do not consume scarce ammunition when the muzzle is already obstructed.
	if arena.blocked(launch_point, Rocket.ROCKET_RADIUS):
		return
	var launch: Dictionary = ship.secondary.fire(ship.position, direction)
	if launch.is_empty():
		return
	var missile := Rocket.new()
	missile.position = launch["position"]
	missile.velocity = launch["velocity"]
	missile.max_range = launch["max_range"]
	missile.damage = launch["damage"]
	missile.blast_radius = launch["blast_radius"]
	missile.blast_impulse = launch["blast_impulse"]
	missile.sync_visual_heading()
	rockets.append(missile)
	add_child(missile)
	ship.fired_secondary()
	sound_bus.play("missile")

func detonate_rocket(rocket: Node2D) -> void:
	sound_bus.play("explosion")
	var origin: Vector2 = rocket.position
	var radius: float = rocket.blast_radius
	var strength: float = rocket.blast_impulse
	var damage: float = rocket.damage

	# Radial shockwave: all teams, including the launching player, are hit.
	# Ship invulnerability is honored, exactly as for any other damage source.
	var ship_distance: float = origin.distance_to(ship.position)
	if ship.visible and ship_distance < radius + ship.collision_radius:
		var falloff: float = clampf(1.0 - ship_distance / (radius + ship.collision_radius), 0.0, 1.0)
		var away: Vector2 = (ship.position - origin).normalized()
		if away.is_zero_approx():
			away = -rocket.velocity.normalized()
			if away.is_zero_approx():
				away = Vector2.UP
		ship.velocity += away * strength * falloff / ship.mass
		ship.hit(damage * falloff)

	for index in range(enemies.size() - 1, -1, -1):
		var enemy = enemies[index]
		var distance: float = origin.distance_to(enemy.position)
		if distance >= radius + enemy.COLLISION_RADIUS:
			continue
		var falloff: float = clampf(1.0 - distance / (radius + enemy.COLLISION_RADIUS), 0.0, 1.0)
		var away: Vector2 = (enemy.position - origin).normalized()
		if away.is_zero_approx():
			away = -rocket.velocity.normalized()
			if away.is_zero_approx():
				away = Vector2.RIGHT
		enemy.velocity += away * strength * falloff
		var destroyed: bool = enemy.take_damage(damage * falloff)
		notify_drones_of_hit(enemy, enemy.position - origin)
		if destroyed:
			defeat_enemy(index)
	arena.apply_blast(origin, strength * 2.5, radius)
	var burst := Explosion.new()
	burst.position = origin
	burst.configure(radius)
	effects.append(burst)
	add_child(burst)
	spawn_debris(origin, Color(1.0, 0.68, 0.24), 1.7, 18, 0.55)

func step_rockets(delta: float) -> void:
	for index in range(rockets.size() - 1, -1, -1):
		var rocket = rockets[index]
		rocket.lifetime -= delta
		rocket.trail_time += delta
		var detonate: bool = rocket.lifetime <= 0.0 or rocket.bounces_left <= 0 or rocket.distance_travelled >= rocket.max_range
		if not detonate:
			# Sample in short increments so fast missiles cannot tunnel through
			# a ship, a dense rock, or a narrow section of arena wall.
			var substeps: int = maxi(1, int(ceil(rocket.velocity.length() * delta / 3.0)))
			for substep in range(substeps):
				rocket.velocity += arena.projectile_gravity_at(rocket.position, true) * delta / float(substeps)
				rocket.sync_visual_heading()
				alert_repair_bots_to_fire(rocket.position, rocket.velocity)
				arena.move_shot(rocket, delta / float(substeps))
				if rocket.impact_pending:
					detonate = true
					break
				if rocket.bounces_left <= 0 or rocket.distance_travelled >= rocket.max_range:
					detonate = true
					break
				# Unlike the Pulse Laser, this rocket can strike its owner,
				# including after a rebound or a low-speed shot.
				if rocket.position.distance_to(ship.position) <= Ship.COLLISION_RADIUS + rocket.hit_radius and ship.visible:
					detonate = true
					break
				for enemy in enemies:
					if rocket.position.distance_to(enemy.position) <= enemy.COLLISION_RADIUS + rocket.hit_radius:
						detonate = true
						break
				if detonate:
					break
		if detonate:
			detonate_rocket(rocket)
			rockets.remove_at(index)
			rocket.queue_free()
		else:
			rocket.queue_redraw()

func spawn_debris(at: Vector2, color: Color, strength: float = 1.0, amount: int = 8, lifespan: float = 0.42) -> void:
	var effect := ImpactParticles.new()
	effect.position = at
	effect.configure(color, amount, strength, lifespan)
	effects.append(effect)
	add_child(effect)

func on_wall_bounced(at: Vector2, speed: float) -> void:
	spawn_debris(at, Color(0.55, 0.9, 1.0), clampf(speed / 170.0, 0.5, 1.6))

func on_asteroid_struck(at: Vector2, power: float) -> void:
	spawn_debris(at, Color(0.62, 0.73, 0.77), clampf(power / 420.0, 0.5, 1.1), 5, 0.27)

func step_effects(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		var effect = effects[i]
		if effect.advance(delta):
			effects.remove_at(i)
			effect.queue_free()

func spawn_shot(origin: Vector2, velocity: Vector2, hostile: bool, damage: float = 1.0, range_limit: float = Projectile.MAX_RANGE, radius: float = Projectile.HIT_RADIUS, cascade_shard: bool = false) -> void:
	if arena.blocked(origin, radius):
		return
	var shot := Projectile.new()
	shot.position = origin
	shot.velocity = velocity
	shot.damage = damage
	shot.max_range = range_limit
	shot.hit_radius = radius
	shot.cascade_shard = cascade_shard
	shot.sync_visual_heading()
	shot.hostile = hostile
	shots.append(shot)
	add_child(shot)

func safe_position(radius: float = Enemy.COLLISION_RADIUS) -> Vector2:
	for attempt in range(100):
		var point := Vector2(randf_range(80, 1120), randf_range(150, 700))
		if arena.blocked(point, radius + 8.0):
			continue
		if point.distance_to(ship.position) <= 220.0:
			continue
		var near_enemy := false
		for enemy in enemies:
			if point.distance_to(enemy.position) < radius + enemy.COLLISION_RADIUS + 30.0:
				near_enemy = true
				break
		if not near_enemy:
			return point
	# Random spawn attempts are normally sufficient. A deterministic
	# search guarantees the fallback also respects all drone footprints.
	for y in range(165, 705, 46):
		for x in range(95, 1110, 46):
			var candidate := Vector2(x, y)
			if arena.blocked(candidate, radius + 8.0) or candidate.distance_to(ship.position) <= 220.0:
				continue
			var free := true
			for other in enemies:
				if candidate.distance_to(other.position) < radius + other.COLLISION_RADIUS + 30.0:
					free = false
					break
			if free:
				return candidate
	# This only occurs if the arena is completely full. Callers can
	# still use normal spawn logic in the ordinary 4-5 enemy waves.
	return Vector2(1050, 650) if ship.position.x < 600 else Vector2(150, 650)

func start_wave() -> void:
	wave += 1
	waiting_for_wave = false
	wave_delay = 0.0
	if flight_test_mode:
		# Two or three ordinary Local Drones, never an escalating swarm.
		for i in range(2 + wave % 2):
			var test_enemy := Enemy.new()
			test_enemy.position = safe_position()
			test_enemy.fire_timer = randf_range(2.0, 3.0)
			test_enemy.turret_angle = randf_range(-PI, PI)
			enemies.append(test_enemy)
			add_child(test_enemy)
		arena.set_drone_bodies(enemies)
		return
	# Early mixed waves: two to three sentries, one long-range missile
	# variant and one support bot. Preserve the original 3-5 hostiles.
	for i in range(randi_range(2, 3) + int(difficulty_levels["count"])):
		var enemy := Enemy.new()
		enemy.position = safe_position()
		enemy.fire_timer = randf_range(1.5, 3.0)
		enemy.turret_angle = randf_range(-PI, PI)
		scale_enemy_health(enemy)
		enemies.append(enemy)
		add_child(enemy)

	var standoff := LongRangeDrone.new()
	standoff.position = safe_position(LongRangeDrone.COLLISION_RADIUS)
	standoff.turret_angle = randf_range(-PI, PI)
	scale_enemy_health(standoff)
	enemies.append(standoff)
	add_child(standoff)

	var bot := RepairBot.new()
	# Try to place support within reasonable distance of a drone.
	var found := false
	for attempt in range(24):
		var candidate: Vector2 = enemies[0].position + Vector2.from_angle(randf_range(0.0, TAU)) * randf_range(80.0, 125.0)
		if arena.blocked(candidate, RepairBot.COLLISION_RADIUS + 7.0):
			continue
		if candidate.distance_to(ship.position) < 220.0:
			continue
		var overlaps := false
		for ally in enemies:
			if candidate.distance_to(ally.position) < RepairBot.COLLISION_RADIUS + ally.COLLISION_RADIUS + 30.0:
				overlaps = true
				break
		if not overlaps:
			bot.position = candidate
			found = true
			break
	if not found:
		bot.position = safe_position(RepairBot.COLLISION_RADIUS)
	scale_enemy_health(bot)
	enemies.append(bot)
	add_child(bot)
	arena.set_drone_bodies(enemies)

func _draw() -> void:
	draw_rect(Rect2(0, 743, 1200, 57), Color(0.035, 0.065, 0.10, 0.96), true)
	draw_line(Vector2(0, 743), Vector2(1200, 743), Color(0.22, 0.64, 0.72), 2.0)
	if not is_instance_valid(ship):
		return
	StatusBars.draw_for(self, ship.hull, ship.max_hull, ship.shields, ship.max_shields, -28.0, ship.position)
	for enemy in enemies:
		if is_instance_valid(enemy):
			StatusBars.draw_for(self, enemy.health, enemy.max_health, enemy.shields, enemy.max_shields, -27.0 - enemy.COLLISION_RADIUS * 0.3, enemy.position)

func on_projectile_rebounded() -> void:
	sound_bus.play("rebound")

func update_hud() -> void:
	hud.text = "OMEGAWAR / CLASSIC    SCORE %05d    WAVE %02d    HOSTILES %02d    TEST THREAT %d" % [score, wave, enemies.size(), int(difficulty_levels["count"]) + int(difficulty_levels["damage"]) + int(difficulty_levels["speed"]) + int(difficulty_levels["health"])]
	var thrust: int = roundi(Input.get_action_strength("thrust") * 100.0)
	var retro: int = roundi(maxf(Input.get_action_strength("special"), Input.get_action_strength("brake")) * 100.0)
	status_hud.text = "SPEED %4.0f   THRUST %3d%%   RETRO %3d%%   HEALTH %.1f/%.0f   SHIELDS %.1f/%.0f   HEAT %3.0f%%\nPRIMARY: PULSE LASER   SECONDARY: ROCKETS %d/%d   READY IN %.1fs   SPECIAL: RETRO   Q/LB: ROCKET" % [
		ship.velocity.length(), thrust, retro, ship.hull, ship.max_hull,
		ship.shields, ship.max_shields, ship.heat / ship.MAX_HEAT * 100.0,
		ship.secondary.ammo, ship.secondary.MAX_AMMO, ship.secondary.cooldown
	]
	if flight_test_mode:
		hud.text = "OMEGAWAR / FLIGHT LAB     TEST %02d     HOSTILES %02d     NO OBSTACLES" % [wave, enemies.size()]
		status_hud.text = "%s / %s   SPEED %4.0f / %4.0f   THRUST %3.0f%%   RETRO %3.0f%%   HEAT %3.0f%%\nACCEL %5.0f   BRAKE %5.0f   TURN %.2f   MASS %.2f   HULL %.1f/%.0f   ROCKETS %d/%d" % [
			ship.profile_name.to_upper(), ship.engine_name.to_upper(), ship.velocity.length(), ship.speed_limit,
			Input.get_action_strength("thrust") * 100.0,
			maxf(Input.get_action_strength("special"), Input.get_action_strength("brake")) * 100.0,
			ship.heat / ship.MAX_HEAT * 100.0, ship.acceleration * ship.thrust_multiplier,
			ship.braking, ship.rotation_speed, ship.mass, ship.hull, ship.max_hull,
			ship.secondary.ammo, ship.secondary.MAX_AMMO
		]
	if dying or paused or game_over or bonus_active:
		banner.text = ""
	elif waiting_for_wave and wave > 0:
		banner.text = "ARENA CLEAR / NEXT WAVE IN %.1f" % maxf(0.0, wave_delay)
	else:
		banner.text = ""
	queue_redraw()
