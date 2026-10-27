extends Node2D

const Arena = preload("res://scripts/arena.gd")
const Ship = preload("res://scripts/ship.gd")
const Enemy = preload("res://scripts/enemy.gd")
const RepairBot = preload("res://scripts/repair_bot.gd")
const StatusBars = preload("res://scripts/status_bars.gd")
const Projectile = preload("res://scripts/projectile.gd")
const ImpactParticles = preload("res://scripts/impact_particles.gd")

var arena := Arena.new()
var ship: Node2D
var enemies: Array[Node2D] = []
var shots: Array[Node2D] = []
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

func _ready() -> void:
	bind_key("turn_left", [KEY_A, KEY_LEFT])
	bind_key("turn_right", [KEY_D, KEY_RIGHT])
	bind_key("thrust", [KEY_W, KEY_UP])
	bind_key("brake", [KEY_S, KEY_DOWN])
	bind_key("fire", [KEY_SPACE])
	bind_key("pause_game", [KEY_P, KEY_ESCAPE])
	bind_key("restart", [KEY_ENTER])
	bind_pad_button("turn_left", [JOY_BUTTON_DPAD_LEFT])
	bind_pad_button("turn_right", [JOY_BUTTON_DPAD_RIGHT])
	bind_pad_button("thrust", [JOY_BUTTON_A, JOY_BUTTON_DPAD_UP])
	bind_pad_button("brake", [JOY_BUTTON_B, JOY_BUTTON_DPAD_DOWN])
	bind_pad_button("fire", [JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER])
	bind_pad_button("pause_game", [JOY_BUTTON_START])
	bind_pad_button("restart", [JOY_BUTTON_Y])
	bind_pad_axis("turn_left", JOY_AXIS_LEFT_X, -1.0)
	bind_pad_axis("turn_right", JOY_AXIS_LEFT_X, 1.0)
	bind_pad_axis("turn_left", JOY_AXIS_RIGHT_X, -1.0)
	bind_pad_axis("turn_right", JOY_AXIS_RIGHT_X, 1.0)
	bind_pad_axis("thrust", JOY_AXIS_LEFT_Y, -1.0)
	bind_pad_axis("brake", JOY_AXIS_LEFT_Y, 1.0)
	bind_pad_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	add_child(arena)
	arena.wall_bounced.connect(on_wall_bounced)
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
	for entity in enemies + shots + effects:
		entity.free()
	enemies.clear()
	shots.clear()
	effects.clear()
	arena.reset_flashes()
	arena.reset_asteroids()
	if is_instance_valid(ship):
		ship.free()
	ship = Ship.new()
	ship.position = Vector2(220, 425)
	add_child(ship)
	score = 0
	wave = 0
	wave_delay = 1.0
	waiting_for_wave = true
	paused = false
	game_over = false
	dying = false
	death_timer = 0.0
	update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_echo():
		return
	if event.is_action_pressed("restart"):
		reset()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause_game") and not game_over:
		paused = not paused
		update_hud()
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if paused or game_over:
		return
	arena.advance_flashes(delta)
	step_effects(delta)
	var moving_bodies: Array[Node2D] = [ship]
	moving_bodies.append_array(enemies)
	arena.advance_asteroids(delta, moving_bodies)
	if dying:
		death_timer = maxf(0.0, death_timer - delta)
		if death_timer <= 0.0:
			dying = false
			game_over = true
		update_hud()
		return
	ship.step(delta, arena)
	if Input.is_action_pressed("fire"):
		for shot in ship.weapon.fire(ship.position, Vector2.UP.rotated(ship.rotation), ship.velocity):
			spawn_shot(shot.position, shot.velocity, false)
			ship.fired_primary()
	for enemy in enemies:
		if enemy.is_repair_bot:
			enemy.step_support(delta, enemies, arena)
		else:
			enemy.step(delta, ship.position, arena)
			# Only Local Drones have weapons. Their turret must be lined up.
			if enemy.ready_to_fire(ship.position, arena):
				spawn_shot(enemy.muzzle_position(), enemy.turret_direction() * 225.0, true)
				enemy.fired()
	resolve_collisions()
	step_shots(delta)
	if enemies.is_empty():
		if not waiting_for_wave:
			waiting_for_wave = true
			wave_delay = 5.0
		else:
			wave_delay -= delta
			if wave_delay <= 0.0:
				start_wave()
	if ship.hull <= 0:
		begin_player_death()
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
	arena.apply_blast(ship.position, 850.0, 180.0)

func resolve_collisions() -> void:
	# Impulse-based ship/enemy impacts: separation, momentum transfer and
	# independent debris bursts. Hull geometry never changes.
	for i in range(enemies.size() - 1, -1, -1):
		var enemy = enemies[i]
		var offset: Vector2 = ship.position - enemy.position
		var distance := offset.length()
		var minimum: float = Ship.COLLISION_RADIUS + enemy.COLLISION_RADIUS
		if distance >= minimum:
			continue
		var normal := offset / distance if distance > 0.001 else Vector2.RIGHT
		var correction := normal * ((minimum - distance) * 0.5 + 0.1)
		if not arena.blocked(ship.position + correction, Ship.COLLISION_RADIUS):
			ship.position += correction
		if not arena.blocked(enemy.position - correction, Enemy.COLLISION_RADIUS):
			enemy.position -= correction
		var closing_speed := maxf(0.0, -(ship.velocity - enemy.velocity).dot(normal))
		if closing_speed <= 0.0:
			continue
		const SHIP_MASS := 1.0
		var enemy_mass: float = 2.2 if enemy.is_repair_bot else 1.25
		const RESTITUTION := 0.55
		var impulse := (1.0 + RESTITUTION) * closing_speed / (1.0 / SHIP_MASS + 1.0 / enemy_mass)
		ship.velocity += normal * impulse / SHIP_MASS
		enemy.velocity -= normal * impulse / enemy_mass
		var impact_point: Vector2 = (ship.position + enemy.position) * 0.5
		spawn_debris(impact_point, Color(1.0, 0.8, 0.45), clampf(closing_speed / 120.0, 0.7, 1.6))
		if enemy.impact(closing_speed):
			defeat_enemy(i)
		if closing_speed >= 90.0:
			ship.hit()
	ship.queue_redraw()

func defeat_enemy(index: int) -> void:
	var enemy = enemies[index]
	var tint := Color(0.25, 1.0, 0.55) if enemy.is_repair_bot else Color(1.0, 0.5, 0.25)
	spawn_debris(enemy.position, tint, 1.4, 16, 0.62)
	arena.apply_blast(enemy.position, 320.0, 100.0)
	score += 200 if enemy.is_repair_bot else 100
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
				if shot.bounces_left <= 0 or shot.distance_travelled >= Projectile.MAX_RANGE:
					break
				arena.move_shot(shot, delta / float(steps))
				if shot.dissolving:
					break # Hit heavy asteroid cover: no damage or ricochet.
				if shot.hostile:
					if shot.position.distance_to(ship.position) < Ship.COLLISION_RADIUS + Projectile.HIT_RADIUS:
						ship.velocity += shot.velocity.normalized() * 24.0
						ship.hit()
						spawn_debris(shot.position, Color(0.5, 1.0, 1.0), 0.75)
						hit_target = true
						break
				else:
					for j in range(enemies.size() - 1, -1, -1):
						var enemy = enemies[j]
						if shot.position.distance_to(enemy.position) < enemy.COLLISION_RADIUS + Projectile.HIT_RADIUS:
							enemy.velocity += shot.velocity.normalized() * 30.0
							var destroyed: bool = enemy.take_damage(1.0)
							var tint := Color(0.25, 1.0, 0.55) if enemy.is_repair_bot else Color(1.0, 0.5, 0.25)
							spawn_debris(shot.position, tint, 0.8)
							hit_target = true
							if destroyed:
								defeat_enemy(j)
							break
					if hit_target:
						break
		if hit_target:
			shots.remove_at(i)
			shot.queue_free()
		elif shot.lifetime <= 0.0 or shot.bounces_left <= 0 or shot.distance_travelled >= Projectile.MAX_RANGE:
			shot.begin_disintegrate()

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

func spawn_shot(origin: Vector2, velocity: Vector2, hostile: bool) -> void:
	if arena.blocked(origin, Projectile.HIT_RADIUS):
		return
	var shot := Projectile.new()
	shot.position = origin
	shot.velocity = velocity
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
	return Vector2(1050, 650) if ship.position.x < 600 else Vector2(150, 650)

func start_wave() -> void:
	wave += 1
	waiting_for_wave = false
	wave_delay = 0.0
	# Small mixed wave: two to four sentries supported by one Repair Bot.
	for i in range(randi_range(2, 4)):
		var enemy := Enemy.new()
		enemy.position = safe_position()
		enemy.fire_timer = randf_range(1.5, 3.0)
		enemy.turret_angle = randf_range(-PI, PI)
		enemies.append(enemy)
		add_child(enemy)

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
	enemies.append(bot)
	add_child(bot)

func _draw() -> void:
	draw_rect(Rect2(0, 743, 1200, 57), Color(0.035, 0.065, 0.10, 0.96), true)
	draw_line(Vector2(0, 743), Vector2(1200, 743), Color(0.22, 0.64, 0.72), 2.0)
	if not is_instance_valid(ship):
		return
	StatusBars.draw_for(self, ship.hull, ship.max_hull, ship.shields, ship.max_shields, -28.0, ship.position)
	for enemy in enemies:
		if is_instance_valid(enemy):
			StatusBars.draw_for(self, enemy.health, enemy.max_health, enemy.shields, enemy.max_shields, -27.0 - enemy.COLLISION_RADIUS * 0.3, enemy.position)

func update_hud() -> void:
	hud.text = "OMEGAWAR / CLASSIC    SCORE %05d    WAVE %02d    HOSTILES %02d" % [score, wave, enemies.size()]
	var thrust: int = roundi(Input.get_action_strength("thrust") * 100.0)
	status_hud.text = "SPEED %5.0f u/s    THRUST %3d%%    HEALTH %.0f/%.0f    SHIELDS %.0f/%.0f    HEAT %3.0f%%\nSECONDARY: NONE    AMMO: --    ABILITY COOLDOWN: --    |    W/A/S/D + SPACE, P/ESC PAUSE" % [
		ship.velocity.length(), thrust, ship.hull, ship.max_hull,
		ship.shields, ship.max_shields, ship.heat / ship.MAX_HEAT * 100.0
	]
	if dying:
		banner.text = ""
	elif game_over:
		banner.text = "SHIP LOST / ENTER OR Y TO RESTART"
	elif paused:
		banner.text = "PAUSED / P, ESC OR START TO RESUME"
	elif waiting_for_wave and wave > 0:
		banner.text = "ARENA CLEAR / NEXT WAVE IN %.1f" % maxf(0.0, wave_delay)
	else:
		banner.text = ""
	queue_redraw()
