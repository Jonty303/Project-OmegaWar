extends Node2D

const COLLISION_RADIUS := 11.0
const THRUST_ACCELERATION := 145.0
const MAX_SPEED := 275.0
const Weapon = preload("res://scripts/weapon.gd")

var weapon := Weapon.new()
var velocity := Vector2.ZERO
var hull := 3
var invulnerable := 2.0
var thrusting := false
var crunch := 0.0

func step(delta: float, arena: Node2D) -> void:
	rotation += Input.get_axis("turn_left", "turn_right") * 3.5 * delta
	var thrust_strength := Input.get_action_strength("thrust")
	thrusting = thrust_strength > 0.02
	# Nothing reduces momentum passively. Thrust, brake and impacts are forces.
	if thrusting:
		velocity += Vector2.UP.rotated(rotation) * THRUST_ACCELERATION * thrust_strength * delta
	if Input.get_action_strength("brake") > 0.02:
		velocity *= exp(-3.0 * Input.get_action_strength("brake") * delta)
	velocity = velocity.limit_length(MAX_SPEED)
	var before := velocity
	velocity = arena.move_body(self, velocity, COLLISION_RADIUS, delta)
	if (velocity - before).length() > 20.0:
		crunch = maxf(crunch, clampf((velocity - before).length() / 340.0, 0.1, 0.85))
	crunch = maxf(0.0, crunch - delta * 1.8)
	invulnerable = maxf(0.0, invulnerable - delta)
	weapon.tick(delta)
	queue_redraw()

func hit() -> bool:
	if invulnerable > 0.0:
		return false
	hull -= 1
	invulnerable = 1.3
	crunch = maxf(crunch, 0.8)
	queue_redraw()
	return true

func _draw() -> void:
	var color := Color(0.3, 1.0, 0.95)
	if invulnerable > 0.0 and fmod(invulnerable, 0.2) < 0.1:
		color.a = 0.35
	var dent := crunch * 5.0
	draw_polyline(PackedVector2Array([
		Vector2(0, -15 + dent),
		Vector2(10 - dent, 10),
		Vector2(0, 6 - dent * 0.5),
		Vector2(-10 + dent * 0.6, 10 - dent * 0.7),
		Vector2(0, -15 + dent)
	]), color, 2.5, true)
	if thrusting:
		draw_polyline(PackedVector2Array([
			Vector2(-5, 10), Vector2(0, 21 + randf() * 6), Vector2(5, 10)
		]), Color(1, 0.6, 0.2), 2, true)
	if crunch > 0.2:
		draw_line(Vector2(-4, -3), Vector2(3, 3), Color(1.0, 0.65, 0.3, crunch), 2)
