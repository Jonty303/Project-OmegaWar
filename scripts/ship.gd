extends Node2D

const COLLISION_RADIUS := 11.0
const THRUST_ACCELERATION := 145.0
const RETRO_DECELERATION := 265.0
const MAX_SPEED := 320.0
const BASE_TURN_RATE := 3.5
const PERFORMANCE_CEILING := 3.0
# Multipliers relative to the unmodified classic fighter. Hull and engine
# handling are independent of the Power / Integrity / Cooling progression.
const HULL_PROFILES := {
	"Light": {"mass":0.5, "acceleration":1.60, "braking":1.50, "speed":1.80, "turn":1.40, "size":0.82, "hp":2.0},
	"Medium": {"mass":1.0, "acceleration":1.0, "braking":1.0, "speed":1.0, "turn":1.0, "size":1.0, "hp":3.0},
	"Heavy": {"mass":2.0, "acceleration":0.60, "braking":0.65, "speed":0.70, "turn":0.75, "size":1.34, "hp":5.0}
}
const ENGINE_PROFILES := {
	"Standard": {"acceleration":1.0, "braking":1.0, "speed":1.0, "turn":1.0},
	"High-Thrust": {"acceleration":1.20, "braking":0.90, "speed":1.0, "turn":1.0},
	"Vector Drive": {"acceleration":1.0, "braking":1.15, "speed":0.95, "turn":1.15},
	"Overdrive": {"acceleration":1.10, "braking":0.85, "speed":1.25, "turn":1.0}
}
const Weapon = preload("res://scripts/weapon.gd")
const RocketLauncher = preload("res://scripts/secondary_rockets.gd")
const DamageModel = preload("res://scripts/combat_health.gd")

var weapon := Weapon.new()
var secondary := RocketLauncher.new()
var thrust_multiplier := 1.0
var profile_name := "Medium"
var engine_name := "Standard"
var mass := 1.0
var acceleration := THRUST_ACCELERATION
var braking := RETRO_DECELERATION
var speed_limit := MAX_SPEED
var rotation_speed := BASE_TURN_RATE
var collision_radius := COLLISION_RADIUS
var visual_scale := 1.0
var handling_test_multiplier := 1.0
var velocity := Vector2.ZERO
var hull := 3.0
var max_hull := 3.0
var shields := 2.0
var max_shields := 2.0
var heat := 0.0
const MAX_HEAT := 100.0
const COOLING_RATE := 12.0
const FIRE_HEAT := Weapon.HEAT_PER_SHOT
var invulnerable := 2.0
var thrusting := false
var retro_active := false
var beam_charge_visual := 0.0
# Negative disables; 0..1 diverts the engine into the heavy beam capacitor.
var heavy_charge_fraction := -1.0

func configure(new_hull: String, new_engine: String, test_multiplier: float = 1.0) -> void:
	profile_name = new_hull if HULL_PROFILES.has(new_hull) else "Medium"
	engine_name = new_engine if ENGINE_PROFILES.has(new_engine) else "Standard"
	handling_test_multiplier = clampf(test_multiplier, 0.5, PERFORMANCE_CEILING)
	var hull_spec: Dictionary = HULL_PROFILES[profile_name]
	var engine_spec: Dictionary = ENGINE_PROFILES[engine_name]
	mass = float(hull_spec["mass"])
	visual_scale = float(hull_spec["size"])
	collision_radius = COLLISION_RADIUS * visual_scale
	acceleration = minf(THRUST_ACCELERATION * PERFORMANCE_CEILING,
		THRUST_ACCELERATION * float(hull_spec["acceleration"]) * float(engine_spec["acceleration"]) * handling_test_multiplier)
	braking = minf(RETRO_DECELERATION * PERFORMANCE_CEILING,
		RETRO_DECELERATION * float(hull_spec["braking"]) * float(engine_spec["braking"]) * handling_test_multiplier)
	speed_limit = minf(MAX_SPEED * PERFORMANCE_CEILING,
		MAX_SPEED * float(hull_spec["speed"]) * float(engine_spec["speed"]))
	rotation_speed = BASE_TURN_RATE * float(hull_spec["turn"]) * float(engine_spec["turn"])
	var health_fraction: float = hull / maxf(1.0, max_hull)
	max_hull = float(hull_spec["hp"])
	hull = max_hull * health_fraction
	enforce_speed_limit()
	queue_redraw()

func step(delta: float, arena: Node2D) -> void:
	rotation += Input.get_axis("turn_left", "turn_right") * rotation_speed * delta
	var thrust_strength := Input.get_action_strength("thrust")
	thrusting = thrust_strength > 0.02 and heavy_charge_fraction < 0.0
	# Nothing reduces momentum passively. Thrust, brake and impacts are forces.
	if thrusting:
		velocity += Vector2.UP.rotated(rotation) * acceleration * thrust_multiplier * thrust_strength * delta
	# Front-mounted retro thrusters arrest momentum without reversing it.
	# The old brake inputs remain aliases; Special is the explicit control.
	var retro_strength: float = maxf(Input.get_action_strength("special"), Input.get_action_strength("brake"))
	retro_active = retro_strength > 0.02 and velocity.length() > 0.01
	if retro_active:
		velocity = velocity.move_toward(Vector2.ZERO, braking * retro_strength * delta)
	if heavy_charge_fraction >= 0.0:
		# Charging drains propulsive power; increasing electromagnetic braking
		# eventually brings even the Light hull completely to rest.
		velocity = velocity.move_toward(Vector2.ZERO, (115.0 + 800.0 * heavy_charge_fraction) * delta)
		if heavy_charge_fraction >= 0.999 and velocity.length() < 12.0:
			velocity = Vector2.ZERO
	# Maximum ship speed is enforced without any passive damping below it.
	# Projectile speed is deliberately higher and ignores this velocity.
	enforce_speed_limit()
	velocity = arena.move_body(self, velocity, collision_radius, delta)
	enforce_speed_limit()
	invulnerable = maxf(0.0, invulnerable - delta)
	heat = maxf(0.0, heat - COOLING_RATE * delta)
	weapon.tick(delta)
	secondary.tick(delta)
	queue_redraw()

func enforce_speed_limit() -> void:
	velocity = velocity.limit_length(speed_limit)

func fired_primary() -> void:
	# Heat is tracked for the new HUD; no heat lockout until weapons are tuned.
	heat = minf(MAX_HEAT, heat + FIRE_HEAT)

func fired_secondary() -> void:
	heat = minf(MAX_HEAT, heat + secondary.HEAT_PER_SHOT)

func hit(amount: float = 1.0, shield_factor: float = 1.0, hull_factor: float = 1.0) -> bool:
	if invulnerable > 0.0:
		return false
	var result: Vector2 = DamageModel.apply(hull, shields, amount, shield_factor, hull_factor)
	hull = result.x
	shields = result.y
	invulnerable = 1.3
	queue_redraw()
	return true

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * visual_scale)
	# The hull is always identical: impacts never deform or flash the ship.
	draw_polyline(PackedVector2Array([
		Vector2(0, -15), Vector2(10, 10), Vector2(0, 6),
		Vector2(-10, 10), Vector2(0, -15)
	]), Color(0.3, 1.0, 0.95), 2.5, true)
	if beam_charge_visual > 0.0:
		var glow: float = clampf(beam_charge_visual, 0.0, 1.0)
		draw_circle(Vector2(0, -16), 3.0 + glow * 8.0, Color(0.25, 0.78, 1.0, 0.12 + glow * 0.28), true)
		draw_arc(Vector2(0, -16), 5.0 + glow * 9.0, -PI * 0.5, -PI * 0.5 + TAU * glow, 28, Color(0.72, 0.96, 1.0, 0.8), 2.5, true)
	if thrusting:
		draw_polyline(PackedVector2Array([
			Vector2(-5, 10), Vector2(0, 21 + randf() * 6), Vector2(5, 10)
		]), Color(1, 0.6, 0.2), 2.0, true)
	if retro_active:
		# Two tiny flames at the FRONT shoulders, pointing forward to
		# represent reverse-facing exhaust jets.
		for side in [-1.0, 1.0]:
			var port := Vector2(side * 7.0, -5.0)
			var tip := port + Vector2(side * 2.0, -(7.0 + randf_range(0.0, 3.0)))
			draw_line(port, tip, Color(1.0, 0.68, 0.26), 2.4, true)
			draw_line(port, port.lerp(tip, 0.55), Color(1.0, 0.96, 0.67), 1.2, true)
