extends Node2D

# Local Drone: a territorial sentry, not a continuously homing attacker.
const COLLISION_RADIUS := 14.0
const DamageModel = preload("res://scripts/combat_health.gd")
const SHORT_VISION_RANGE := 90.0
const LONG_VISION_RANGE := 365.0
const FRONT_VISION_HALF_ANGLE := deg_to_rad(20.0)
const WEAPON_RANGE := 240.0
const IDLE_TURRET_RATE := 0.80
const IDLE_SWEEP := 0.65
const LOOK_SWEEP := 1.30
const LOOK_AROUND_SECONDS := 6.0
const SEARCH_ARRIVAL_RADIUS := 17.0
const TRAVEL_SPEED := 54.0
const ACCELERATION := 75.0
const TURRET_TURN_RATE := 6.0
const AIM_TOLERANCE := 0.12
const FIRE_INTERVAL := 2.1
const MUZZLE_DISTANCE := 19.0

var velocity := Vector2.ZERO
var health := 2.0
var max_health := 2.0
var shields := 0.0
var max_shields := 0.0
var is_repair_bot := false
var fire_timer := 1.8
var collision_cooldown := 0.0
var turret_angle := 0.0
var spotted_once := false
var can_see_player := false
var last_seen_position := Vector2.ZERO
var search_heading := Vector2.RIGHT
var search_goal := Vector2.ZERO
var searching := false
var looking_around := false
var look_timer := 0.0
var scan_initialized := false
var scan_phase := 0.0
var scan_anchor := 0.0
var scan_turn_timer := 18.0

func scan_gun(delta: float) -> void:
	# Slowly sweep the forward arc, with occasional deliberate 180-degree
	# changes in the search direction. No instant sensor rotation.
	if not scan_initialized:
		scan_anchor = turret_angle
		scan_initialized = true
	scan_phase += delta * 0.60
	scan_turn_timer -= delta
	if scan_turn_timer <= 0.0:
		scan_anchor = wrapf(scan_anchor + PI, -PI, PI)
		scan_turn_timer = randf_range(15.0, 28.0)
	var sweep: float = LOOK_SWEEP if looking_around else IDLE_SWEEP
	var desired: float = scan_anchor + sin(scan_phase) * sweep
	turret_angle = rotate_toward(turret_angle, desired, IDLE_TURRET_RATE * delta)

func has_sight_on(player_position: Vector2, arena: Node2D) -> bool:
	var to_player: Vector2 = player_position - position
	var distance: float = to_player.length()
	if distance > LONG_VISION_RANGE:
		return false
	if not arena.has_line_of_sight(position, player_position):
		return false
	if distance <= SHORT_VISION_RANGE:
		return true # Close proximity sensor sees in all 360 degrees.
	var angle: float = to_player.angle()
	return absf(wrapf(angle - turret_angle, -PI, PI)) <= FRONT_VISION_HALF_ANGLE

func step(delta: float, player_position: Vector2, arena: Node2D) -> void:
	fire_timer = maxf(0.0, fire_timer - delta)
	collision_cooldown = maxf(0.0, collision_cooldown - delta)
	var was_visible := can_see_player

	if not spotted_once or looking_around:
		scan_gun(delta)
	can_see_player = has_sight_on(player_position, arena)
	if can_see_player:
		spotted_once = true
		searching = false
		looking_around = false
		last_seen_position = player_position
		search_goal = player_position
		var direction: Vector2 = position.direction_to(player_position)
		if not direction.is_zero_approx():
			search_heading = direction
	elif was_visible and spotted_once:
		# Only remember the last ACTUALLY seen point. Never cheat by using
		# player_position again after LOS or detection is lost.
		searching = true
		looking_around = false
		search_goal = last_seen_position

	var destination: Vector2 = position
	var should_move := false
	if can_see_player:
		if position.distance_to(player_position) > WEAPON_RANGE * 0.90:
			destination = player_position
			should_move = true
	elif searching:
		if position.distance_to(search_goal) <= SEARCH_ARRIVAL_RADIUS:
			searching = false
			looking_around = true
			look_timer = LOOK_AROUND_SECONDS
			scan_anchor = search_heading.angle()
			scan_phase = 0.0
			scan_initialized = true
		else:
			destination = search_goal
			should_move = true
	elif looking_around:
		look_timer = maxf(0.0, look_timer - delta)
		if look_timer <= 0.0:
			looking_around = false
			spotted_once = false
			scan_anchor = turret_angle

	var desired_velocity := Vector2.ZERO
	if should_move:
		var waypoint: Vector2 = arena.approach_waypoint(position, destination, COLLISION_RADIUS)
		if position.distance_to(waypoint) > 8.0:
			desired_velocity = position.direction_to(waypoint) * TRAVEL_SPEED
	velocity = velocity.move_toward(desired_velocity, ACCELERATION * delta)
	velocity = arena.move_body(self, velocity, COLLISION_RADIUS, delta)

	if can_see_player:
		var bearing: Vector2 = position.direction_to(player_position)
		if not bearing.is_zero_approx():
			turret_angle = rotate_toward(turret_angle, bearing.angle(), TURRET_TURN_RATE * delta)
	elif searching:
		# Gun watches last reported contact while travelling there.
		var bearing: Vector2 = position.direction_to(search_goal)
		if not bearing.is_zero_approx():
			turret_angle = rotate_toward(turret_angle, bearing.angle(), TURRET_TURN_RATE * delta)
	queue_redraw()

func ready_to_fire(player_position: Vector2, arena: Node2D) -> bool:
	if not can_see_player or fire_timer > 0.0:
		return false
	if position.distance_to(player_position) > WEAPON_RANGE:
		return false
	if not arena.has_line_of_sight(position, player_position):
		return false
	var target_angle := position.angle_to_point(player_position)
	return absf(wrapf(target_angle - turret_angle, -PI, PI)) <= AIM_TOLERANCE

func muzzle_position() -> Vector2:
	return position + Vector2.from_angle(turret_angle) * MUZZLE_DISTANCE

func turret_direction() -> Vector2:
	return Vector2.from_angle(turret_angle)

func fired() -> void:
	fire_timer = FIRE_INTERVAL + randf_range(-0.20, 0.20)

func receive_healing(hull_amount: float, shield_amount: float) -> void:
	health = minf(max_health, health + maxf(0.0, hull_amount))
	shields = minf(max_shields, shields + maxf(0.0, shield_amount))
	queue_redraw()

func take_damage(amount: float, shield_factor: float = 1.0, hull_factor: float = 1.0) -> bool:
	var result: Vector2 = DamageModel.apply(health, shields, amount, shield_factor, hull_factor)
	health = result.x
	shields = result.y
	queue_redraw()
	return health <= 0.0

func impact(speed: float) -> bool:
	if speed >= 100.0 and collision_cooldown <= 0.0:
		collision_cooldown = 0.6
		return take_damage(1.0)
	return health <= 0.0

func _draw() -> void:
	var shell := Color(1.0, 0.4, 0.25)
	var barrel := Color(1.0, 0.89, 0.5)
	var polygon := PackedVector2Array()
	for i in range(7):
		polygon.append(Vector2.from_angle(float(i) * TAU / 6.0) * 13.0)
	draw_polyline(polygon, shell, 2.0, true)
	draw_circle(Vector2.ZERO, 5.0, shell, false, 1.5, true)
	# Thin visible clock hand, with its muzzle at the outer tip.
	var end: Vector2 = Vector2.from_angle(turret_angle) * MUZZLE_DISTANCE
	draw_line(Vector2.ZERO, end, barrel, 2.4, true)
	draw_circle(end, 2.3, barrel, true)
