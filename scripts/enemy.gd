extends Node2D

# Local Drone: a territorial sentry, not a continuously homing attacker.
const COLLISION_RADIUS := 14.0
const DamageModel = preload("res://scripts/combat_health.gd")
const SHORT_VISION_RANGE := 90.0
const LONG_VISION_RANGE := 400.0
const FRONT_VISION_HALF_ANGLE := deg_to_rad(30.0)
const WEAPON_RANGE := 240.0
const IDLE_TURRET_RATE := 0.80
const IDLE_SWEEP := 0.85
const LOOK_SWEEP := 1.55
const LOOK_AROUND_SECONDS := 6.0
const SEARCH_ARRIVAL_RADIUS := 17.0
const TRAVEL_SPEED := 54.0
const ACCELERATION := 75.0
const TURRET_TURN_RATE := 7.5
const SHOT_INVESTIGATION_RANGE := 260.0
const AIM_TOLERANCE := 0.12
const FIRE_INTERVAL := 2.1
const MUZZLE_DISTANCE := 19.0

var velocity := Vector2.ZERO
var health := 2.0
var max_health := 2.0
var shields := 0.0
var max_shields := 0.0
var is_repair_bot := false
var is_missile_drone := false
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
var alert_flash := 0.0

func alert_to_ally_hit(hit_position: Vector2, arena: Node2D, hit_self: bool = false) -> bool:
	# A shot striking an ally is an observable event, not a report of the
	# unseen attacker's coordinates. Use the same sensor rules and cover LOS.
	if health <= 0.0 or (not hit_self and not has_sight_on(hit_position, arena)):
		return false
	alert_flash = 0.65
	if can_see_player:
		# Keep tracking the player if there is an actual visual contact.
		queue_redraw()
		return true
	searching = true
	looking_around = false
	look_timer = 0.0
	search_goal = hit_position
	# An impact does not reveal the attacker's position or count as sighting.
	# Do not change last_seen_position or spotted_once.
	if not hit_self:
		var bearing: Vector2 = position.direction_to(hit_position)
		if not bearing.is_zero_approx():
			search_heading = bearing
	else:
		search_heading = Vector2.from_angle(turret_angle)
	queue_redraw()
	return true

func react_to_incoming_shot(incoming_velocity: Vector2, arena: Node2D) -> void:
	# The projectile's incoming velocity identifies a DIRECTION only, never
	# the exact location of the shooter. Turn toward its source and investigate.
	if health <= 0.0 or incoming_velocity.is_zero_approx():
		return
	alert_flash = 0.65
	var source_bearing: Vector2 = -incoming_velocity.normalized()
	search_heading = source_bearing
	scan_anchor = source_bearing.angle()
	scan_phase = 0.0
	scan_initialized = true

	# Follow the reverse firing line only as far as accessible open space.
	# Stop at core/asteroid cover, instead of selecting an unreachable point.
	var last_clear: Vector2 = position
	for sample in range(1, 40):
		var distance: float = minf(float(sample) * 8.0, SHOT_INVESTIGATION_RANGE)
		var candidate: Vector2 = position + source_bearing * distance
		if arena.blocked(candidate, COLLISION_RADIUS + 2.0):
			break
		last_clear = candidate
		if distance >= SHOT_INVESTIGATION_RANGE:
			break
	search_goal = last_clear
	if position.distance_to(last_clear) <= SEARCH_ARRIVAL_RADIUS:
		searching = false
		looking_around = true
		look_timer = LOOK_AROUND_SECONDS
	else:
		searching = true
		looking_around = false
		look_timer = 0.0
	# Leave last_seen_position unchanged: being hit does not locate a player.
	# The barrel rotates visibly during step(), not instantaneously here.
	queue_redraw()

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

	alert_flash = maxf(0.0, alert_flash - delta)
	if (not spotted_once and not searching) or looking_around:
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
		destination = combat_destination(player_position, arena)
		should_move = position.distance_to(destination) > 8.0
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
			var approach_speed := TRAVEL_SPEED
			if searching:
				# Decelerate before reaching the reported position instead of
				# overshooting it and drifting away while looking around.
				var runway := maxf(0.0, position.distance_to(search_goal) - SEARCH_ARRIVAL_RADIUS)
				approach_speed = minf(TRAVEL_SPEED, sqrt(2.0 * ACCELERATION * runway))
			desired_velocity = position.direction_to(waypoint) * approach_speed
	desired_velocity = arena.avoid_drones(self, desired_velocity)
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

func combat_destination(player_position: Vector2, _arena: Node2D) -> Vector2:
	# Ordinary Local Drones approach only until their turret is in range.
	if position.distance_to(player_position) > WEAPON_RANGE * 0.90:
		return player_position
	return position

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
	if alert_flash > 0.0:
		var alpha: float = alert_flash / 0.65
		draw_arc(Vector2.ZERO, COLLISION_RADIUS + 7.0 + (1.0 - alpha) * 6.0, 0.0, TAU, 24, Color(1.0, 0.82, 0.25, alpha), 1.5, true)
