extends Node2D

const COLLISION_RADIUS := 11.0
const Weapon = preload("res://scripts/weapon.gd")
var weapon := Weapon.new()
var velocity := Vector2.ZERO
var hull := 3
var shield := 0.0
var rapid := 0.0
var boost := 0.0
var invulnerable := 2.0
var thrusting := false

func step(delta: float, arena: Node2D, gravity: Vector2) -> void:
	rotation += Input.get_axis("turn_left", "turn_right") * 3.8 * delta
	var thrust_strength := Input.get_action_strength("thrust")
	thrusting = thrust_strength > 0.02
	var acceleration := 700.0 if boost > 0 and Input.is_action_pressed("boost") else 320.0
	if thrusting:
		velocity += Vector2.UP.rotated(rotation) * acceleration * thrust_strength * delta
	if Input.is_action_pressed("brake"):
		velocity *= exp(-3.5 * delta)
	velocity += gravity * delta
	velocity = velocity.limit_length(520 if boost > 0 else 330)
	velocity = arena.move_body(self, velocity, COLLISION_RADIUS, delta)
	shield = maxf(0, shield - delta)
	rapid = maxf(0, rapid - delta)
	boost = maxf(0, boost - delta)
	invulnerable = maxf(0, invulnerable - delta)
	weapon.tick(delta)
	queue_redraw()

func hit() -> bool:
	if invulnerable > 0:
		return false
	invulnerable = 1.4
	if shield > 0:
		shield = maxf(0, shield - 3)
	else:
		hull -= 1
	return true

func _draw() -> void:
	var color := Color(0.3, 1, 0.95)
	if invulnerable > 0 and fmod(invulnerable, 0.2) < 0.1:
		color.a = 0.35
	draw_polyline(PackedVector2Array([Vector2(0, -15), Vector2(10, 10), Vector2(0, 6), Vector2(-10, 10), Vector2(0, -15)]), color, 2.5, true)
	if thrusting:
		draw_polyline(PackedVector2Array([Vector2(-5, 10), Vector2(0, 21 + randf() * 6), Vector2(5, 10)]), Color(1, 0.6, 0.2), 2, true)
	if shield > 0:
		draw_arc(Vector2.ZERO, 20, 0, TAU, 40, Color(0.3, 0.6, 1), 2, true)
