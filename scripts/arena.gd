extends Node2D

const Projectile = preload("res://scripts/projectile.gd")

const BOUNDS := Rect2(40, 110, 1120, 630)
const CORE := Rect2(490, 330, 220, 190)

func blocked(point: Vector2, radius: float = 0.0) -> bool:
	return not BOUNDS.grow(-radius).has_point(point) or CORE.grow(radius).has_point(point)

func move_body(body: Node2D, velocity: Vector2, radius: float, delta: float) -> Vector2:
	# The only drag on moving objects is from explicit inputs or collisions.
	var steps := maxi(1, int(ceil(velocity.length() * delta / 8.0)))
	for step in range(steps):
		var next := body.position + Vector2(velocity.x * delta / steps, 0)
		if blocked(next, radius):
			velocity.x *= -0.7
		else:
			body.position = next
		next = body.position + Vector2(0, velocity.y * delta / steps)
		if blocked(next, radius):
			velocity.y *= -0.7
		else:
			body.position = next
	return velocity

func move_shot(shot: Projectile, delta: float) -> void:
	# Axis-separated swept microsteps bounce off the outer walls and the core.
	# Shots lose no speed during a bounce, but expire after a few ricochets.
	var steps := maxi(1, int(ceil(shot.velocity.length() * delta / 4.0)))
	for step in range(steps):
		if shot.bounces_left <= 0:
			return
		var dt := delta / steps
		var proposed: Vector2 = shot.position + Vector2(shot.velocity.x * dt, 0)
		if blocked(proposed, Projectile.HIT_RADIUS):
			shot.velocity.x = -shot.velocity.x
			shot.bounces_left -= 1
		else:
			shot.position = proposed
		proposed = shot.position + Vector2(0, shot.velocity.y * dt)
		if blocked(proposed, Projectile.HIT_RADIUS):
			shot.velocity.y = -shot.velocity.y
			shot.bounces_left -= 1
		else:
			shot.position = proposed

func segment_hits_rect(from: Vector2, to: Vector2, rect: Rect2) -> bool:
	# Rect2 has no intersects_segment() method in Godot 4.5.
	if rect.has_point(from) or rect.has_point(to):
		return true
	var a := rect.position
	var b := Vector2(rect.end.x, rect.position.y)
	var c := rect.end
	var d := Vector2(rect.position.x, rect.end.y)
	return (
		Geometry2D.segment_intersects_segment(from, to, a, b) != null
		or Geometry2D.segment_intersects_segment(from, to, b, c) != null
		or Geometry2D.segment_intersects_segment(from, to, c, d) != null
		or Geometry2D.segment_intersects_segment(from, to, d, a) != null
	)

func approach_waypoint(origin: Vector2, goal: Vector2, radius: float) -> Vector2:
	# Tiny visibility graph over the four corners of an inflated core.
	# Returns the first navigable waypoint in the shortest unobstructed route.
	var obstacle := CORE.grow(radius + 4.0)
	if not segment_hits_rect(origin, goal, obstacle):
		return goal
	var corner_box := CORE.grow(radius + 22.0)
	var nodes: Array[Vector2] = [
		origin, goal,
		corner_box.position,
		Vector2(corner_box.end.x, corner_box.position.y),
		corner_box.end,
		Vector2(corner_box.position.x, corner_box.end.y)
	]
	var costs: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	for i in range(nodes.size()):
		costs.append(INF)
		previous.append(-1)
		visited.append(false)
	costs[0] = 0.0
	for iteration in range(nodes.size()):
		var best := -1
		for i in range(nodes.size()):
			if not visited[i] and (best == -1 or costs[i] < costs[best]):
				best = i
		if best == -1 or is_inf(costs[best]) or best == 1:
			break
		visited[best] = true
		for j in range(1, nodes.size()):
			if j == best or visited[j]:
				continue
			if segment_hits_rect(nodes[best], nodes[j], obstacle):
				continue
			var candidate := costs[best] + nodes[best].distance_to(nodes[j])
			if candidate < costs[j]:
				costs[j] = candidate
				previous[j] = best
	if previous[1] == -1:
		return goal
	var index := 1
	while previous[index] > 0:
		index = previous[index]
	return nodes[index]

func _draw() -> void:
	for x in range(40, 1161, 40):
		draw_line(Vector2(x, 110), Vector2(x, 740), Color(0.04, 0.10, 0.16))
	for y in range(110, 741, 40):
		draw_line(Vector2(40, y), Vector2(1160, y), Color(0.04, 0.10, 0.16))
	draw_rect(BOUNDS, Color(0.15, 0.85, 0.9), false, 3)
	draw_rect(CORE, Color(0.035, 0.06, 0.12))
	draw_rect(CORE, Color(0.5, 0.35, 0.95), false, 3)
	draw_rect(CORE.grow(-12), Color(0.25, 0.18, 0.5), false, 1)
	draw_string(ThemeDB.fallback_font, Vector2(530, 420), "OMEGA CORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.65, 0.5, 1))
