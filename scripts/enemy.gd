extends Node2D

const COLLISION_RADIUS := 14.0

var velocity := Vector2.ZERO
var gravity_well := false
var health := 2
var fire_timer := 1.5
var phase := 0.0

func gravity_at(point: Vector2) -> Vector2:
	if not gravity_well:
		return Vector2.ZERO
	var offset := position - point
	var distance := offset.length()
	if distance > 230:
		return Vector2.ZERO
	return offset.normalized() * 230 * (1.0 - distance / 230.0)

func step(delta: float, target: Vector2, arena: Node2D) -> void:
	phase += delta
	fire_timer -= delta
	var direction := position.direction_to(target)
	velocity += direction * (45 if gravity_well else 95) * delta
	velocity = velocity.limit_length(65 if gravity_well else 125)
	velocity = arena.move_body(self, velocity, COLLISION_RADIUS, delta)
	rotation += delta * (0.7 if gravity_well else -1.8)
	queue_redraw()

func _draw() -> void:
	var color := Color(0.95, 0.35, 0.8) if gravity_well else Color(1, 0.4, 0.25)
	var points := PackedVector2Array()
	for i in range(7):
		points.append(Vector2.from_angle(i * TAU / 6) * (17 if gravity_well else 13))
	draw_polyline(points, color, 2, true)
	draw_circle(Vector2.ZERO, 4, color, false, 2, true)
	if gravity_well:
		draw_arc(Vector2.ZERO, 230, 0, TAU, 80, Color(0.8, 0.25, 0.7, 0.18), 1, true)
		draw_arc(Vector2.ZERO, 35 + fmod(phase * 45, 185), 0, TAU, 64, Color(0.9, 0.3, 0.7, 0.3), 1, true)
