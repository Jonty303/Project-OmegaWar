extends Node2D

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
	thrusting = Input.is_action_pressed("thrust")
	var acceleration := 700.0 if boost > 0 and Input.is_action_pressed("boost") else 320.0
	if thrusting:
		velocity += Vector2.UP.rotated(rotation) * acceleration * delta
	if Input.is_action_pressed("brake"):
		velocity *= exp(-3.5 * delta)
	velocity += gravity * delta
	velocity = velocity.limit_length(520 if boost > 0 else 330)
	velocity = arena.move_body(self, velocity, 14, delta)
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
	draw_polyline(PackedVector2Array([Vector2(0, -19), Vector2(13, 13), Vector2(0, 7), Vector2(-13, 13), Vector2(0, -19)]), color, 2.5, true)
	if thrusting:
		draw_polyline(PackedVector2Array([Vector2(-6, 13), Vector2(0, 27 + randf() * 8), Vector2(6, 13)]), Color(1, 0.6, 0.2), 2, true)
	if shield > 0:
		draw_arc(Vector2.ZERO, 25, 0, TAU, 40, Color(0.3, 0.6, 1), 2, true)
