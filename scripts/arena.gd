extends Node2D

const BOUNDS := Rect2(40, 110, 1120, 630)
const CORE := Rect2(470, 320, 260, 210)

func blocked(point: Vector2, radius: float = 0.0) -> bool:
	return not BOUNDS.grow(-radius).has_point(point) or CORE.grow(radius).has_point(point)

func move_body(body: Node2D, velocity: Vector2, radius: float, delta: float) -> Vector2:
	# Axis-separated movement slides/bounces around rectangular obstacles.
	# Substeps keep boosted ships from tunnelling through the core.
	var steps := maxi(1, int(ceil(velocity.length() * delta / 8.0)))
	for step in range(steps):
		var next := body.position + Vector2(velocity.x * delta / steps, 0)
		if blocked(next, radius):
			velocity.x *= -0.65
		else:
			body.position = next
		next = body.position + Vector2(0, velocity.y * delta / steps)
		if blocked(next, radius):
			velocity.y *= -0.65
		else:
			body.position = next
	return velocity

func _draw() -> void:
	for x in range(40, 1161, 40):
		draw_line(Vector2(x, 110), Vector2(x, 740), Color(0.04, 0.10, 0.16))
	for y in range(110, 741, 40):
		draw_line(Vector2(40, y), Vector2(1160, y), Color(0.04, 0.10, 0.16))
	draw_rect(BOUNDS, Color(0.15, 0.85, 0.9), false, 3)
	draw_rect(CORE, Color(0.035, 0.06, 0.12))
	draw_rect(CORE, Color(0.5, 0.35, 0.95), false, 3)
	draw_rect(CORE.grow(-12), Color(0.25, 0.18, 0.5), false, 1)
	draw_string(ThemeDB.fallback_font, Vector2(532, 420), "OMEGA CORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.65, 0.5, 1))
