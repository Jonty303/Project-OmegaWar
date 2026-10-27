extends Node2D

const COLLISION_RADIUS := 11.0
const THRUST_ACCELERATION := 145.0
const MAX_SPEED := 320.0
const Weapon = preload("res://scripts/weapon.gd")
const DamageModel = preload("res://scripts/combat_health.gd")

var weapon := Weapon.new()
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

func step(delta: float, arena: Node2D) -> void:
	rotation += Input.get_axis("turn_left", "turn_right") * 3.5 * delta
	var thrust_strength := Input.get_action_strength("thrust")
	thrusting = thrust_strength > 0.02
	# Nothing reduces momentum passively. Thrust, brake and impacts are forces.
	if thrusting:
		velocity += Vector2.UP.rotated(rotation) * THRUST_ACCELERATION * thrust_strength * delta
	if Input.get_action_strength("brake") > 0.02:
		velocity *= exp(-3.0 * Input.get_action_strength("brake") * delta)
	# Maximum ship speed is enforced without any passive damping below it.
	# Projectile speed is deliberately higher and ignores this velocity.
	enforce_speed_limit()
	velocity = arena.move_body(self, velocity, COLLISION_RADIUS, delta)
	enforce_speed_limit()
	invulnerable = maxf(0.0, invulnerable - delta)
	heat = maxf(0.0, heat - COOLING_RATE * delta)
	weapon.tick(delta)
	queue_redraw()

func enforce_speed_limit() -> void:
	velocity = velocity.limit_length(MAX_SPEED)

func fired_primary() -> void:
	# Heat is tracked for the new HUD; no heat lockout until weapons are tuned.
	heat = minf(MAX_HEAT, heat + FIRE_HEAT)

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
	# The hull is always identical: impacts never deform or flash the ship.
	draw_polyline(PackedVector2Array([
		Vector2(0, -15), Vector2(10, 10), Vector2(0, 6),
		Vector2(-10, 10), Vector2(0, -15)
	]), Color(0.3, 1.0, 0.95), 2.5, true)
	if thrusting:
		draw_polyline(PackedVector2Array([
			Vector2(-5, 10), Vector2(0, 21 + randf() * 6), Vector2(5, 10)
		]), Color(1, 0.6, 0.2), 2.0, true)
