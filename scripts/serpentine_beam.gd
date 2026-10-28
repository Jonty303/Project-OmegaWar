extends Node2D

# A travelling, growing energy filament. Its leading tip moves forward and
# turns into walls; the luminous body remains along the travelled path until
# the finite range budget is consumed, then fades. Unlike lightning this ray
# is not instantaneous.
const HEAD_SPEED := 930.0
const MAX_RANGE := 1800.0
const STEP_LENGTH := 7.0
const DAMAGE := 3.2
const WIDTH := 8.0
const FADE_DURATION := 0.42

var heading := Vector2.UP
var points: Array[Vector2] = []
var travelled := 0.0
var bounce_count := 0
var hit_targets: Dictionary = {}
var fading := false
var remaining := FADE_DURATION
var shimmer := 0.0

func configure(origin: Vector2, facing: Vector2) -> void:
	position = origin
	heading = facing.normalized()
	if heading.is_zero_approx():
		heading = Vector2.UP
	points.clear()
	points.append(origin)
	travelled = 0.0
	bounce_count = 0
	hit_targets.clear()
	fading = false
	remaining = FADE_DURATION
	shimmer = 0.0
	queue_redraw()

func advance(delta: float, arena: Node2D) -> Array[Dictionary]:
	var produced: Array[Dictionary] = []
	shimmer += delta * 19.0
	if fading:
		remaining = maxf(0.0, remaining - delta)
		queue_redraw()
		return produced
	var budget: float = minf(HEAD_SPEED * delta, MAX_RANGE - travelled)
	var steps: int = maxi(1, int(ceil(budget / STEP_LENGTH)))
	for index in range(steps):
		if travelled >= MAX_RANGE - 0.001:
			break
		var distance: float = minf(STEP_LENGTH, budget / float(steps), MAX_RANGE - travelled)
		var from: Vector2 = points[points.size() - 1]
		# Gentle phase-based curvature creates a moving caterpillar/snake
		# silhouette without making the overall weapon homing.
		var moving: Vector2 = heading.rotated(sin(travelled * 0.051) * 0.18)
		var to: Vector2 = arena.beam_endpoint(from, moving, distance)
		var actual: float = from.distance_to(to)
		if actual > 0.0001:
			points.append(to)
			produced.append({"from":from, "to":to})
			travelled += actual
		if actual < distance - 0.005:
			bounce_count += 1
			var bounds: Rect2 = arena.BOUNDS
			if absf(to.x - bounds.position.x) < 0.5 or absf(to.x - bounds.end.x) < 0.5:
				heading.x = -heading.x
			elif absf(to.y - bounds.position.y) < 0.5 or absf(to.y - bounds.end.y) < 0.5:
				heading.y = -heading.y
			else:
				# Core/asteroid fallback for a future nonempty test arena.
				heading = -heading
			heading = heading.normalized()
			if actual <= 0.0001:
				# Avoid a zero-distance lock at a wall.
				var inward: Vector2 = from + heading * 0.1
				points.append(inward)
				travelled += 0.1
		else:
			# Travel is reflected by walls, not by the procedural wiggle.
			pass
	if travelled >= MAX_RANGE - STEP_LENGTH:
		fading = true
	queue_redraw()
	return produced

func expired() -> bool:
	return fading and remaining <= 0.0

func _draw() -> void:
	if points.size() < 2:
		return
	var alpha := remaining / FADE_DURATION if fading else 1.0
	var local_points := PackedVector2Array()
	for i in range(points.size()):
		var p: Vector2 = points[i] - position
		# Oscillating lateral movement of the visible body, vanishing at
		# both ends so it stays pinned to impact locations.
		if i > 0 and i < points.size() - 1:
			var tangent: Vector2 = (points[i + 1] - points[i - 1]).normalized()
			var lateral := Vector2(-tangent.y, tangent.x)
			p += lateral * sin(float(i) * 0.72 - shimmer) * 3.8
		local_points.append(p)
	draw_polyline(local_points, Color(0.12, 0.54, 1.0, 0.19 * alpha), WIDTH + 16.0, true)
	draw_polyline(local_points, Color(0.38, 0.80, 1.0, 0.73 * alpha), WIDTH + 4.0, true)
	draw_polyline(local_points, Color(0.94, 0.99, 1.0, 0.94 * alpha), WIDTH * 0.37, true)
	var tip: Vector2 = points[points.size() - 1] - position
	draw_circle(tip, 6.0, Color(0.72, 0.94, 1.0, 0.85 * alpha), true)
