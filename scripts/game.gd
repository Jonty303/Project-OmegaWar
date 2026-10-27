extends Node2D

const Arena = preload("res://scripts/arena.gd")
const Ship = preload("res://scripts/ship.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Pickup = preload("res://scripts/pickup.gd")
var arena := Arena.new()
var ship: Node2D
var enemies: Array[Node2D] = []
var shots: Array[Node2D] = []
var pickups: Array[Node2D] = []
var score := 0
var wave := 0
var wave_delay := 1.0
var waiting_for_wave := true
var pickup_delay := 6.0
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
	bind_key("boost", [KEY_SHIFT])
	bind_key("pause_game", [KEY_P, KEY_ESCAPE])
	bind_key("restart", [KEY_ENTER])
	# Controller: sticks/D-pad steer; left stick Y or A/B controls thrust/brake.
	bind_pad_button("turn_left", [JOY_BUTTON_DPAD_LEFT])
	bind_pad_button("turn_right", [JOY_BUTTON_DPAD_RIGHT])
	bind_pad_button("thrust", [JOY_BUTTON_A, JOY_BUTTON_DPAD_UP])
	bind_pad_button("brake", [JOY_BUTTON_B, JOY_BUTTON_DPAD_DOWN])
	bind_pad_button("fire", [JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER])
	bind_pad_button("boost", [JOY_BUTTON_LEFT_SHOULDER])
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
	help.text = "KEYS: W/UP thrust   A/D turn   S brake   SPACE fire   SHIFT boost   P/ESC pause   ENTER restart\nPAD: Left stick steer/thrust/brake   A thrust   B brake   X/RT fire   LB boost   START pause   Y restart"
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
	for entity in enemies + shots + pickups:
		entity.free()
	enemies.clear()
	shots.clear()
	pickups.clear()
	if is_instance_valid(ship):
		ship.free()
	ship = Ship.new()
	ship.position = Vector2(220, 425)
	add_child(ship)
	score = 0
	wave = 0
	wave_delay = 1.0
	waiting_for_wave = true
	pickup_delay = 6
	paused = false
	game_over = false
	for i in range(3):
		spawn_pickup(Vector2(220 + i * 100, 240), i)
	update_hud()

func _unhandled_input(event: InputEvent) -> void:
	# Accept keyboard and controller buttons, ignoring held-key repeat.
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
	var gravity := Vector2.ZERO
	for enemy in enemies:
		gravity += enemy.gravity_at(ship.position)
	ship.step(delta, arena, gravity.limit_length(320))
	if Input.is_action_pressed("fire"):
		for shot in ship.weapon.fire(ship.position, Vector2.UP.rotated(ship.rotation), ship.velocity, ship.rapid > 0):
			spawn_shot(shot.position, shot.velocity, false)
	for enemy in enemies:
		enemy.step(delta, ship.position, arena)
		if enemy.fire_timer <= 0:
			enemy.fire_timer = 2.8 if enemy.gravity_well else 2.0
			var aim: Vector2 = enemy.position.direction_to(ship.position)
			spawn_shot(enemy.position + aim * 20, aim * 220, true)
		if enemy.position.distance_to(ship.position) < Ship.COLLISION_RADIUS + Enemy.COLLISION_RADIUS + 2.0:
			ship.hit()
	step_shots(delta)
	for i in range(pickups.size() - 1, -1, -1):
		var pickup = pickups[i]
		pickup.lifetime -= delta
		if pickup.position.distance_to(ship.position) < Ship.COLLISION_RADIUS + Pickup.RADIUS + 2.0:
			match pickup.kind:
				0: ship.shield = 12
				1: ship.boost = 15
				2: ship.rapid = 10
			pickup.lifetime = 0
		if pickup.lifetime <= 0:
			pickups.remove_at(i)
			pickup.queue_free()
	if enemies.is_empty():
		if not waiting_for_wave:
			waiting_for_wave = true
			wave_delay = 5.0 # Full five seconds after the last enemy dies.
		else:
			wave_delay -= delta
			if wave_delay <= 0.0:
				start_wave()
	pickup_delay -= delta
	if pickup_delay <= 0:
		pickup_delay = 9
		spawn_pickup(safe_position(), randi_range(0, 2))
	if ship.hull <= 0:
		game_over = true
	update_hud()

func step_shots(delta: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var shot = shots[i]
		shot.lifetime -= delta
		# Sweep in short segments so fast shots cannot skip targets or walls.
		var steps := maxi(1, int(ceil(shot.velocity.length() * delta / 5.0)))
		for substep in range(steps):
			shot.position += shot.velocity * delta / steps
			if arena.blocked(shot.position, Projectile.HIT_RADIUS):
				shot.lifetime = 0
				break
			if shot.hostile:
				if shot.position.distance_to(ship.position) < Ship.COLLISION_RADIUS + Projectile.HIT_RADIUS:
					ship.hit()
					shot.lifetime = 0
					break
			else:
				for j in range(enemies.size() - 1, -1, -1):
					var enemy = enemies[j]
					if shot.position.distance_to(enemy.position) < Enemy.COLLISION_RADIUS + Projectile.HIT_RADIUS:
						enemy.health -= 1
						shot.lifetime = 0
						if enemy.health <= 0:
							score += 250 if enemy.gravity_well else 100
							if randf() < 0.3:
								spawn_pickup(enemy.position, randi_range(0, 2))
							enemies.remove_at(j)
							enemy.queue_free()
						break
				if shot.lifetime <= 0:
					break
		if shot.lifetime <= 0:
			shots.remove_at(i)
			shot.queue_free()

func spawn_shot(origin: Vector2, velocity: Vector2, hostile: bool) -> void:
	# Reject muzzle positions inside walls.
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
		var point := Vector2(randf_range(75, 1125), randf_range(145, 705))
		if arena.blocked(point, 28) or point.distance_to(ship.position) <= 220:
			continue
		var overlaps_enemy := false
		for enemy in enemies:
			if point.distance_to(enemy.position) < 55:
				overlaps_enemy = true
				break
		if not overlaps_enemy:
			return point
	return Vector2(1050, 650) if ship.position.x < 600 else Vector2(150, 650)

func spawn_pickup(point: Vector2, kind: int) -> void:
	var pickup := Pickup.new()
	pickup.position = point
	pickup.kind = kind
	pickups.append(pickup)
	add_child(pickup)

func start_wave() -> void:
	wave += 1
	waiting_for_wave = false
	wave_delay = 0.0
	# Count, types and positions vary on every new wave.
	var enemy_count := mini(3 + wave + randi_range(0, 2), 14)
	for i in range(enemy_count):
		var enemy := Enemy.new()
		enemy.position = safe_position()
		enemy.gravity_well = i == 0 or randf() < minf(0.45, 0.27 + wave * 0.015)
		enemy.health = 4 if enemy.gravity_well else 2
		enemy.fire_timer = randf_range(1.2, 2.6)
		enemies.append(enemy)
		add_child(enemy)

func update_hud() -> void:
	hud.text = "OMEGAWAR    /    SCORE %05d    /    WAVE %02d    /    HULL %d\nSHIELD %02ds   BOOST %02ds   RAPID %02ds    |    Clear the arena to advance" % [score, wave, maxi(ship.hull, 0), ceili(ship.shield), ceili(ship.boost), ceili(ship.rapid)]
	if game_over:
		banner.text = "SHIP LOST  /  ENTER OR Y TO RESTART"
	elif paused:
		banner.text = "PAUSED  /  P, ESC OR START TO RESUME"
	elif waiting_for_wave and wave > 0:
		banner.text = "ARENA CLEAR / NEXT WAVE IN %.1f" % maxf(0.0, wave_delay)
	else:
		banner.text = ""
