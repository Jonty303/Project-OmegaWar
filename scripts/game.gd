extends Node2D

const Arena = preload("res://scripts/arena.gd")
const Ship = preload("res://scripts/ship.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Projectile = preload("res://scripts/projectile.gd")

var arena := Arena.new()
var ship: Node2D
var enemies: Array[Node2D] = []
var shots: Array[Node2D] = []
var score := 0
var wave := 0
var wave_delay := 1.0
var waiting_for_wave := true
var paused := false
var game_over := false
var hud := Label.new()
var banner := Label.new()

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
	hud.position = Vector2(40, 20)
	hud.add_theme_font_size_override("font_size", 20)
	add_child(hud)
	banner.position = Vector2(330, 205)
	banner.add_theme_font_size_override("font_size", 28)
	add_child(banner)
	var help := Label.new()
	help.position = Vector2(40, 746)
	help.text = "KEYS: W/UP thrust  A/D turn  S brake  SPACE fire  P/ESC pause  ENTER restart\nPAD: Left stick steer/thrust/brake  A thrust  B brake  X/RT fire  START pause  Y restart"
	help.add_theme_font_size_override("font_size", 16)
	add_child(help)
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
	for entity in enemies + shots:
		entity.free()
	enemies.clear()
	shots.clear()
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
	ship.step(delta, arena)
	if Input.is_action_pressed("fire"):
		for shot in ship.weapon.fire(ship.position, Vector2.UP.rotated(ship.rotation), ship.velocity):
			spawn_shot(shot.position, shot.velocity, false)
	for enemy in enemies:
		enemy.step(delta, ship.position, arena)
		if enemy.fire_timer <= 0.0:
			enemy.fire_timer = randf_range(2.2, 3.2)
			# A short velocity lead rewards skillful changes of direction.
			var predicted: Vector2 = ship.position + ship.velocity * 0.25
			var aim: Vector2 = enemy.position.direction_to(predicted)
			spawn_shot(enemy.position + aim * 19.0, aim * 225.0, true)
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
		game_over = true
	update_hud()

func resolve_collisions() -> void:
	# Impulse-based ship/enemy impacts: separation, momentum transfer, crunch
	# animation, and damage on substantial closing speed. No sticky overlap.
	for i in range(enemies.size() - 1, -1, -1):
		var enemy = enemies[i]
		var offset: Vector2 = ship.position - enemy.position
		var distance := offset.length()
		var minimum := Ship.COLLISION_RADIUS + Enemy.COLLISION_RADIUS
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
		const ENEMY_MASS := 1.25
		const RESTITUTION := 0.55
		var impulse := (1.0 + RESTITUTION) * closing_speed / (1.0 / SHIP_MASS + 1.0 / ENEMY_MASS)
		ship.velocity += normal * impulse / SHIP_MASS
		enemy.velocity -= normal * impulse / ENEMY_MASS
		ship.crunch = maxf(ship.crunch, clampf(closing_speed / 170.0, 0.15, 1.0))
		if enemy.impact(closing_speed):
			defeat_enemy(i)
		if closing_speed >= 90.0:
			ship.hit()
	ship.queue_redraw()

func defeat_enemy(index: int) -> void:
	var enemy = enemies[index]
	score += 100
	enemies.remove_at(index)
	enemy.queue_free()

func step_shots(delta: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var shot = shots[i]
		shot.lifetime -= delta
		var steps := maxi(1, int(ceil(shot.velocity.length() * delta / 4.0)))
		for substep in range(steps):
			if shot.lifetime <= 0.0 or shot.bounces_left <= 0:
				break
			# Move in short segments to keep swept collisions and ricochets accurate.
			arena.move_shot(shot, delta / steps)
			if shot.hostile:
				if shot.position.distance_to(ship.position) < Ship.COLLISION_RADIUS + Projectile.HIT_RADIUS:
					ship.velocity += shot.velocity.normalized() * 24.0
					ship.crunch = maxf(ship.crunch, 0.35)
					ship.hit()
					shot.lifetime = 0.0
					break
			else:
				for j in range(enemies.size() - 1, -1, -1):
					var enemy = enemies[j]
					if shot.position.distance_to(enemy.position) < Enemy.COLLISION_RADIUS + Projectile.HIT_RADIUS:
						enemy.velocity += shot.velocity.normalized() * 30.0
						enemy.health -= 1
						enemy.crunch = maxf(enemy.crunch, 0.65)
						enemy.queue_redraw()
						shot.lifetime = 0.0
						if enemy.health <= 0:
							defeat_enemy(j)
						break
				if shot.lifetime <= 0.0:
					break
		if shot.lifetime <= 0.0 or shot.bounces_left <= 0:
			shots.remove_at(i)
			shot.queue_free()

func spawn_shot(origin: Vector2, velocity: Vector2, hostile: bool) -> void:
	if arena.blocked(origin, Projectile.HIT_RADIUS):
		return
	var shot := Projectile.new()
	shot.position = origin
	shot.velocity = velocity
	shot.hostile = hostile
	shots.append(shot)
	add_child(shot)

func safe_position() -> Vector2:
	for attempt in range(100):
		var point := Vector2(randf_range(80, 1120), randf_range(150, 700))
		if arena.blocked(point, Enemy.COLLISION_RADIUS + 8.0):
			continue
		if point.distance_to(ship.position) <= 220.0:
			continue
		var near_enemy := false
		for enemy in enemies:
			if point.distance_to(enemy.position) < 60.0:
				near_enemy = true
				break
		if not near_enemy:
			return point
	return Vector2(1050, 650) if ship.position.x < 600 else Vector2(150, 650)

func start_wave() -> void:
	wave += 1
	waiting_for_wave = false
	wave_delay = 0.0
	# Keep baseline encounters readable: just three to five identical drones.
	for i in range(randi_range(3, 5)):
		var enemy := Enemy.new()
		enemy.position = safe_position()
		enemy.fire_timer = randf_range(1.5, 3.0)
		enemies.append(enemy)
		add_child(enemy)

func update_hud() -> void:
	hud.text = "OMEGAWAR / CLASSIC    SCORE %05d    WAVE %02d    HULL %d\nSIMPLE DRONES  |  MOMENTUM + RICOCHET  |  CLEAR THE ARENA" % [score, wave, maxi(ship.hull, 0)]
	if game_over:
		banner.text = "SHIP LOST / ENTER OR Y TO RESTART"
	elif paused:
		banner.text = "PAUSED / P, ESC OR START TO RESUME"
	elif waiting_for_wave and wave > 0:
		banner.text = "ARENA CLEAR / NEXT WAVE IN %.1f" % maxf(0.0, wave_delay)
	else:
		banner.text = ""
