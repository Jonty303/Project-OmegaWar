extends Node2D

# Repair Bot: armoured support unit, no weapons or offensive targeting.
const COLLISION_RADIUS := 16.0
const MAX_HEALTH := 6.0
const MAX_SHIELDS := 2.0
const MOVE_SPEED := 105.0
const ACCELERATION := 150.0
const TETHER_RANGE := 170.0
const HULL_REPAIR_RATE := 0.9
const SHIELD_REPAIR_RATE := 0.75
const DamageModel = preload("res://scripts/combat_health.gd")

var is_repair_bot := true
var is_missile_drone := false
var velocity := Vector2.ZERO
var health := MAX_HEALTH
var shields := MAX_SHIELDS
var max_health := MAX_HEALTH
var max_shields := MAX_SHIELDS
var collision_cooldown := 0.0
var tether_target: Node2D = null
var assigned_patient: Node2D = null
var tether_phase := 0.0

func needs_healing(ally: Node2D) -> bool:
	return ally.health < ally.max_health - 0.001 or ally.shields < ally.max_shields - 0.001

# Full-map allied distress awareness; repair range itself is still limited.
func find_patient(allies: Array[Node2D]) -> Node2D:
	# A repair assignment is sticky. Newly injured closer drones cannot
	# steal the bot until its existing patient is fully healed or dead.
	if is_instance_valid(assigned_patient) and allies.has(assigned_patient):
		if assigned_patient.health > 0.0 and needs_healing(assigned_patient):
			return assigned_patient
	assigned_patient = null

	var best: Node2D = null
	var nearest := INF
	for ally in allies:
		if ally == self or not is_instance_valid(ally) or ally.health <= 0.0:
			continue
		if not needs_healing(ally):
			continue
		var distance := position.distance_squared_to(ally.position)
		if distance < nearest:
			nearest = distance
			best = ally
	assigned_patient = best
	return best

func step_support(delta: float, allies: Array[Node2D], arena: Node2D) -> void:
	collision_cooldown = maxf(0.0, collision_cooldown - delta)
	tether_phase += delta * 23.0
	tether_target = null
	var destination_velocity := Vector2.ZERO
	var patient := find_patient(allies)
	if patient != null:
		var distance := position.distance_to(patient.position)
		if distance <= TETHER_RANGE and arena.has_line_of_sight(position, patient.position):
			tether_target = patient
			patient.receive_healing(HULL_REPAIR_RATE * delta, SHIELD_REPAIR_RATE * delta)
		else:
			var waypoint: Vector2 = arena.approach_waypoint(position, patient.position, COLLISION_RADIUS)
			if position.distance_to(waypoint) > 8.0:
				destination_velocity = position.direction_to(waypoint) * MOVE_SPEED
	velocity = velocity.move_toward(destination_velocity, ACCELERATION * delta)
	velocity = arena.move_body(self, velocity, COLLISION_RADIUS, delta)
	queue_redraw()

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
	# Different from the hexagonal Local Drone: a compact support diamond.
	var shell := Color(0.34, 0.97, 0.68)
	var edge := Color(0.15, 0.51, 0.36)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -15), Vector2(15, 0),
		Vector2(0, 15), Vector2(-15, 0)
	]), Color(0.065, 0.18, 0.14))
	draw_polyline(PackedVector2Array([
		Vector2(0, -15), Vector2(15, 0), Vector2(0, 15),
		Vector2(-15, 0), Vector2(0, -15)
	]), shell, 2.1, true)
	draw_line(Vector2(-6, 0), Vector2(6, 0), shell, 2.0, true)
	draw_line(Vector2(0, -6), Vector2(0, 6), shell, 2.0, true)
	draw_circle(Vector2.ZERO, 8.0, edge, false, 1.2, true)
	if tether_target != null and is_instance_valid(tether_target):
		var target: Vector2 = to_local(tether_target.global_position)
		var unit: Vector2 = target.normalized()
		var normal := Vector2(-unit.y, unit.x)
		var path := PackedVector2Array()
		for i in range(10):
			var fraction := float(i) / 9.0
			var flicker := 0.0 if i == 0 or i == 9 else sin(float(i) * 4.3 + tether_phase) * 4.2
			path.append(target * fraction + normal * flicker)
		draw_polyline(path, Color(0.14, 1.0, 0.39, 0.95), 2.0, true)
		draw_circle(target, 4.0 + sin(tether_phase) * 0.9, Color(0.24, 1.0, 0.53, 0.8), false, 1.6, true)
