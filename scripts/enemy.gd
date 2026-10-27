extends Node2D

# Local Drone: a territorial sentry, not a continuously homing attacker.
const COLLISION_RADIUS := 14.0
const VISION_RANGE := 250.0
const WEAPON_RANGE := 200.0
const TRAVEL_SPEED := 54.0
const ACCELERATION := 75.0
const TURRET_TURN_RATE := 6.0
const AIM_TOLERANCE := 0.12
const FIRE_INTERVAL := 2.1
const MUZZLE_DISTANCE := 19.0
const SEARCH_DISTANCE := 170.0

var velocity := Vector2.ZERO
var health := 2
var fire_timer := 1.8
var collision_cooldown := 0.0
var turret_angle := 0.0
var spotted_once := false
var can_see_player := false
var last_seen_position := Vector2.ZERO
var search_heading := Vector2.RIGHT
var search_goal := Vector2.ZERO

func step(delta: float, player_position: Vector2, arena: Node2D) -> void:
	fire_timer = maxf(0.0, fire_timer - delta)
	collision_cooldown = maxf(0.0, collision_cooldown - delta)

	var distance_to_player := position.distance_to(player_position)
	can_see_player = (
		distance_to_player <= VISION_RANGE
		and arena.has_line_of_sight(position, player_position)
	)
	if can_see_player:
		spotted_once = true
		last_seen_position = player_position
		var direction := position.direction_to(player_position)
		if direction.length_squared() > 0.01:
			search_heading = direction
		search_goal = player_position

	var destination := position
	var should_move := false
	if can_see_player:
		# Once the drone can fire from where it stands, it holds that location.
		if distance_to_player > WEAPON_RANGE * 0.90:
			destination = player_position
			should_move = true
	elif spotted_once:
		# Search last-known location; then continue methodically along the last
		# observed bearing. Never seek the player's actual unseen position.
		if position.distance_to(search_goal) < 23.0:
			search_goal += search_heading * SEARCH_DISTANCE
		destination = search_goal
		should_move = true

	var desired_velocity := Vector2.ZERO
	if should_move:
		var waypoint: Vector2 = arena.approach_waypoint(position, destination, COLLISION_RADIUS)
		if position.distance_to(waypoint) > 8.0:
			desired_velocity = position.direction_to(waypoint) * TRAVEL_SPEED
	velocity = velocity.move_toward(desired_velocity, ACCELERATION * delta)
	velocity = arena.move_body(self, velocity, COLLISION_RADIUS, delta)

	# A separate rotating clock hand represents the gun's independent facing.
	var aim_point := last_seen_position if spotted_once else position + Vector2.from_angle(turret_angle)
	var bearing := position.direction_to(aim_point)
	if bearing.length_squared() > 0.01:
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

func impact(speed: float) -> bool:
	if speed >= 100.0 and collision_cooldown <= 0.0:
		health -= 1
		collision_cooldown = 0.6
	return health <= 0

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
