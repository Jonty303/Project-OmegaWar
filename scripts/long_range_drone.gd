extends "res://scripts/enemy.gd"

# Long-range Local Drone: evasive sentry using compact tracking missiles.
# Keeps the Local Drone's vision, alerted-shot behaviour and repair interface.
const MIN_SPACING := 275.0
const IDEAL_SPACING := 325.0
const MAX_SPACING := 365.0
const MISSILE_RANGE := 395.0
const MISSILE_COOLDOWN := 3.15
const MISSILE_MUZZLE := 23.0

func _init() -> void:
	is_missile_drone = true
	health = 3.0
	max_health = 3.0
	shields = 1.0
	max_shields = 1.0
	fire_timer = 2.4

func combat_destination(player_position: Vector2, arena: Node2D) -> Vector2:
	var distance: float = position.distance_to(player_position)
	if distance > MAX_SPACING:
		return player_position
	if distance >= MIN_SPACING:
		return position

	# Flee methodically from the player, testing alternative side routes
	# before choosing an inaccessible position near a wall or the core.
	var away: Vector2 = (position - player_position).normalized()
	if away.is_zero_approx():
		away = -Vector2.from_angle(turret_angle)
	for offset in [0.0, 0.65, -0.65, 1.25, -1.25, 1.85, -1.85]:
		var candidate: Vector2 = position + away.rotated(offset) * 135.0
		if candidate.distance_to(player_position) <= distance + 14.0:
			continue
		if arena.blocked(candidate, COLLISION_RADIUS + 6.0):
			continue
		var waypoint: Vector2 = arena.approach_waypoint(position, candidate, COLLISION_RADIUS)
		if waypoint.distance_to(position) > 8.0:
			return candidate
	return position

func ready_to_fire(player_position: Vector2, arena: Node2D) -> bool:
	if not can_see_player or fire_timer > 0.0:
		return false
	var distance: float = position.distance_to(player_position)
	if distance < MIN_SPACING or distance > MISSILE_RANGE:
		return false
	if not arena.has_line_of_sight(position, player_position):
		return false
	return absf(wrapf(position.angle_to_point(player_position) - turret_angle, -PI, PI)) <= AIM_TOLERANCE

func muzzle_position() -> Vector2:
	return position + Vector2.from_angle(turret_angle) * MISSILE_MUZZLE

func fired() -> void:
	fire_timer = MISSILE_COOLDOWN + randf_range(-0.20, 0.25)

func _draw() -> void:
	# Distinct indigo rhombus and amber long gun, readable at arena scale.
	var body := Color(0.48, 0.66, 1.0)
	var gun := Color(1.0, 0.80, 0.37)
	var points := PackedVector2Array([
		Vector2(0, -17), Vector2(15, -4), Vector2(11, 12),
		Vector2(0, 17), Vector2(-11, 12), Vector2(-15, -4), Vector2(0, -17)
	])
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -17), Vector2(15, -4), Vector2(11, 12),
		Vector2(0, 17), Vector2(-11, 12), Vector2(-15, -4)
	]), Color(0.10, 0.14, 0.25))
	draw_polyline(points, body, 2.1, true)
	draw_circle(Vector2.ZERO, 5.0, body, false, 1.5, true)
	var end: Vector2 = Vector2.from_angle(turret_angle) * MISSILE_MUZZLE
	draw_line(Vector2.ZERO, end, gun, 3.0, true)
	draw_circle(end, 2.6, gun)
	if alert_flash > 0.0:
		var alpha: float = alert_flash / 0.65
		draw_arc(Vector2.ZERO, COLLISION_RADIUS + 8.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.40, alpha), 1.7, true)
