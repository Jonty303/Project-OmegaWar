extends "res://scripts/rocket.gd"

# Small guided hostile missile. Detonates on the FIRST physical contact,
# including arena walls/core, asteroids and either team's ships.
const SPEED := 375.0
var cruise_speed := SPEED
const TURN_RATE := 2.85
const BLAST_RANGE := 48.0
const DAMAGE := 1.0
const BLAST_KNOCKBACK := 100.0
const FLIGHT_RANGE := 780.0
const FLIGHT_LIFETIME := 3.0
const RADIUS := 4.0

var is_homing := true

func _init() -> void:
	super()
	is_homing = true
	hostile = true
	hit_radius = RADIUS
	blast_radius = BLAST_RANGE
	blast_impulse = BLAST_KNOCKBACK
	damage = DAMAGE
	max_range = FLIGHT_RANGE
	lifetime = FLIGHT_LIFETIME
	bounces_left = 0

func steer(delta: float, target_position: Vector2) -> void:
	var desired: Vector2 = (target_position - position).normalized()
	var current: Vector2 = velocity.normalized()
	if current.is_zero_approx():
		current = desired
	if not desired.is_zero_approx():
		var angle: float = rotate_toward(current.angle(), desired.angle(), TURN_RATE * delta)
		# Retain speed changes accumulated from gravity between guidance
		# steps; otherwise steering would erase the pull every frame.
		var retained_speed: float = clampf(velocity.length(), cruise_speed * 0.70, cruise_speed * 1.50)
		velocity = Vector2.from_angle(angle) * retained_speed
	elif velocity.is_zero_approx():
		velocity = Vector2.RIGHT * cruise_speed
	sync_visual_heading()

func _draw() -> void:
	var forward: Vector2 = visual_heading
	var lateral: Vector2 = Vector2(-forward.y, forward.x)
	var tip: Vector2 = forward * 6.0
	var tail: Vector2 = -forward * 6.0
	draw_colored_polygon(PackedVector2Array([
		tip, tail + lateral * 3.5, tail - lateral * 3.5
	]), Color(0.7, 0.22, 0.22))
	draw_polyline(PackedVector2Array([
		tip, tail + lateral * 3.5, tail - lateral * 3.5, tip
	]), Color(1.0, 0.55, 0.44), 1.8, true)
	draw_line(tail, tail - forward * (4.0 + 1.8 * sin(trail_time * 20.0)), Color(1.0, 0.79, 0.28), 2.0, true)
