extends Node2D

const Projectile = preload("res://scripts/projectile.gd")
const Asteroid = preload("res://scripts/asteroid.gd")
const GravityWell = preload("res://scripts/gravity_well.gd")

const BOUNDS := Rect2(40, 110, 1120, 630)
const CORE := Rect2(490, 330, 220, 190)
const FLASH_SECONDS := 0.26
const WALL_RESTITUTION := 0.985
const DRONE_GAP := 12.0
const DRONE_HARD_GAP := 2.0
const DRONE_LOOKAHEAD := 82.0

signal wall_bounced(at: Vector2, speed: float)
signal asteroid_struck(at: Vector2, power: float)
signal projectile_rebounded

var asteroids: Array[Node2D] = []
var gravity_well := GravityWell.new()
# Classic mode is untouched; the dedicated flight-test scene enables this.
var flight_test_mode := false

func gravity_at(point: Vector2) -> Vector2:
	if flight_test_mode:
		return Vector2.ZERO
	return gravity_well.acceleration_at(point)

func projectile_gravity_at(point: Vector2, is_rocket: bool = false, is_homing: bool = false) -> Vector2:
	var scale: float = gravity_well.BULLET_PULL_MULTIPLIER
	if is_homing:
		scale = gravity_well.HOMING_PULL_MULTIPLIER
	elif is_rocket:
		scale = gravity_well.ROCKET_PULL_MULTIPLIER
	return gravity_at(point) * scale

func gravity_escape_waypoint(at: Vector2, radius: float, safe_radius: float) -> Vector2:
	# Choose reachable directions that INCREASE distance from the anomaly.
	# Avoid an exit goal inside the core, off the arena or in an asteroid.
	var from_well: Vector2 = at - gravity_well.position
	if from_well.is_zero_approx():
		from_well = Vector2.RIGHT
	var away: Vector2 = from_well.normalized()
	var best: Vector2 = at
	var best_score := -INF
	for angle in [0.0, 0.40, -0.40, 0.85, -0.85, 1.30, -1.30, 1.80, -1.80]:
		var direction: Vector2 = away.rotated(angle)
		var candidate: Vector2 = at + direction * minf(145.0, maxf(64.0, safe_radius - from_well.length() + 26.0))
		if blocked(candidate, radius + 3.0):
			continue
		var waypoint: Vector2 = approach_waypoint(at, candidate, radius)
		if blocked(waypoint, radius):
			continue
		var step_direction: Vector2 = (waypoint - at).normalized()
		var improvement: float = waypoint.distance_to(gravity_well.position) - from_well.length()
		if improvement < 2.0 or step_direction.dot(away) < 0.10:
			continue
		var score: float = improvement + step_direction.dot(away) * 20.0
		if score > best_score:
			best_score = score
			best = waypoint
	return best

func pull_body(body: Node2D, delta: float) -> void:
	body.velocity += gravity_at(body.position) * delta

func advance_gravity(delta: float) -> void:
	if not flight_test_mode:
		gravity_well.advance(delta)

var drone_bodies: Array[Node2D] = []

func set_drone_bodies(bodies: Array[Node2D]) -> void:
	drone_bodies = bodies.duplicate()

func drone_free(point: Vector2, radius: float, self_body: Node2D = null, margin: float = DRONE_HARD_GAP) -> bool:
	for other in drone_bodies:
		if other == self_body or not is_instance_valid(other) or other.health <= 0.0:
			continue
		if point.distance_squared_to(other.position) < pow(radius + other.COLLISION_RADIUS + margin, 2.0):
			return false
	return true

func avoid_drones(actor: Node2D, desired: Vector2) -> Vector2:
	# Steer around the other drones rather than navigating to their centres.
	# Idle sentries can remain still unless physically displaced.
	if desired.length_squared() < 0.0001:
		return desired
	var heading: Vector2 = desired.normalized()
	var strongest := 0.0
	var steering := Vector2.ZERO
	for other in drone_bodies:
		if other == actor or not is_instance_valid(other) or other.health <= 0.0:
			continue
		var toward: Vector2 = other.position - actor.position
		var forward: float = toward.dot(heading)
		var distance: float = toward.length()
		var clearance: float = actor.COLLISION_RADIUS + other.COLLISION_RADIUS + DRONE_GAP
		if distance > DRONE_LOOKAHEAD + clearance or forward < -clearance:
			continue
		var lateral: float = heading.cross(toward)
		if absf(lateral) > clearance + 10.0:
			continue
		var strength: float = clampf(1.0 - maxf(0.0, forward) / (DRONE_LOOKAHEAD + clearance), 0.0, 1.0)
		strength *= clampf(1.0 - absf(lateral) / (clearance + 10.0), 0.0, 1.0)
		if distance < clearance:
			strength = 1.0
		if strength <= strongest:
			continue
		strongest = strength
		var tangent: Vector2 = Vector2(-heading.y, heading.x)
		var side := -1.0 if lateral > 0.0 else 1.0
		if absf(lateral) < 0.1:
			# Mirrored headings naturally select opposite world directions.
			side = 1.0
		steering = tangent * side
		if distance < clearance and distance > 0.01:
			steering = (steering * 0.45 - toward.normalized()).normalized()
	if strongest <= 0.0:
		return desired
	return (heading * (1.0 - strongest * 0.88) + steering * strongest * 1.45).normalized() * desired.length()

func drone_move_clear(actor: Node2D, current: Vector2, next: Vector2, radius: float) -> bool:
	# Physical clearance is enforced in addition to steering.
	if not drone_bodies.has(actor):
		return true
	for other in drone_bodies:
		if other == actor or not is_instance_valid(other) or other.health <= 0.0:
			continue
		var clearance: float = radius + other.COLLISION_RADIUS + DRONE_HARD_GAP
		var current_sq: float = current.distance_squared_to(other.position)
		var next_sq: float = next.distance_squared_to(other.position)
		if next_sq < clearance * clearance and next_sq < current_sq - 0.00001:
			return false
	return true

# Five sections along horizontal outer walls, three along vertical sides.
# Segments also outline the central obstacle, each with independent flashes.
var segments: Array[Dictionary] = []

func _ready() -> void:
	build_sections()
	add_child(gravity_well)
	gravity_well.visible = not flight_test_mode
	spawn_asteroids()

func spawn_asteroids() -> void:
	if flight_test_mode:
		return
	# Two persistent pieces of cover in the upper-right corner.
	for spec in [
		{"at": Vector2(924, 226), "radius": 37.0, "mass": 24.0},
		{"at": Vector2(1038, 311), "radius": 30.0, "mass": 19.0}
	]:
		var rock := Asteroid.new()
		rock.configure(spec["at"], spec["radius"], spec["mass"])
		asteroids.append(rock)
		add_child(rock)

func reset_asteroids() -> void:
	for rock in asteroids:
		rock.reset_rock()

func asteroid_at(point: Vector2, padding: float = 0.0):
	for rock in asteroids:
		if point.distance_squared_to(rock.position) < pow(rock.radius + padding, 2.0):
			return rock
	return null

func blocked_static(point: Vector2, radius: float = 0.0) -> bool:
	return not BOUNDS.grow(-radius).has_point(point) or (not flight_test_mode and CORE.grow(radius).has_point(point))

func circle_segment_hits(from: Vector2, to: Vector2, center: Vector2, radius: float) -> bool:
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(center, from, to)
	return closest.distance_squared_to(center) <= radius * radius

func clear_for_rock(rock: Node2D, point: Vector2) -> bool:
	if blocked_static(point, rock.radius):
		return false
	for other in asteroids:
		if other != rock and point.distance_squared_to(other.position) < pow(rock.radius + other.radius + 3.0, 2.0):
			return false
	return true

func advance_asteroids(delta: float, bodies: Array) -> void:
	# Heavy rocks drift under impulses; environmental resistance eventually
	# settles them, unlike the player's frictionless inertial movement.
	for rock in asteroids:
		# Very heavy rocks feel only a quarter of the ship field pull.
		rock.velocity += gravity_at(rock.position) * delta * 0.25
		var speed: float = rock.velocity.length()
		if speed < 0.06:
			rock.velocity = Vector2.ZERO
			continue
		var steps := maxi(1, int(ceil(speed * delta / 4.0)))
		for i in range(steps):
			var next: Vector2 = rock.position + rock.velocity * delta / float(steps)
			if not clear_for_rock(rock, next):
				rock.velocity *= -0.10
				break
			var blocked_by_body := false
			for body in bodies:
				if not is_instance_valid(body) or not body.visible:
					continue
				var body_radius: float = body.COLLISION_RADIUS
				var reach: float = rock.radius + body_radius
				if body.position.distance_squared_to(next) >= reach * reach:
					continue
				var normal: Vector2 = (body.position - next).normalized()
				if normal.is_zero_approx():
					normal = Vector2.RIGHT
				var correction: Vector2 = next + normal * reach
				# The actor can be pushed safely, but never takes rock damage.
				if not blocked_static(correction, body_radius) and asteroid_at(correction, body_radius) == null:
					body.position = correction
					body.velocity += normal * minf(speed * 0.30, 38.0)
				else:
					blocked_by_body = true
				rock.velocity *= 0.7
			if blocked_by_body:
				break
			rock.position = next
		rock.velocity *= exp(-Asteroid.DRAG * delta)

func apply_blast(at: Vector2, strength: float, reach: float) -> void:
	for rock in asteroids:
		var offset: Vector2 = rock.position - at
		var distance: float = offset.length()
		if distance > reach + rock.radius:
			continue
		var attenuation: float = 1.0 - clampf(distance / (reach + rock.radius), 0.0, 1.0)
		var bearing: Vector2 = offset.normalized() if distance > 0.01 else Vector2.RIGHT
		rock.apply_impulse(bearing * strength * attenuation)


func add_sections(a: Vector2, b: Vector2, count: int, inner: bool) -> void:
	for i in range(count):
		var start: Vector2 = a.lerp(b, float(i) / float(count))
		var finish: Vector2 = a.lerp(b, float(i + 1) / float(count))
		var tangent: Vector2 = (finish - start).normalized()
		segments.append({
			"a": start + tangent * 4.0,
			"b": finish - tangent * 4.0,
			"inner": inner,
			"flash": 0.0
		})

func build_sections() -> void:
	segments.clear()
	var a: Vector2 = BOUNDS.position
	var c: Vector2 = BOUNDS.end
	add_sections(a, Vector2(c.x, a.y), 5, false)
	add_sections(Vector2(c.x, a.y), c, 3, false)
	add_sections(c, Vector2(a.x, c.y), 5, false)
	add_sections(Vector2(a.x, c.y), a, 3, false)
	if not flight_test_mode:
		a = CORE.position
		c = CORE.end
		add_sections(a, Vector2(c.x, a.y), 3, true)
		add_sections(Vector2(c.x, a.y), c, 3, true)
		add_sections(c, Vector2(a.x, c.y), 3, true)
		add_sections(Vector2(a.x, c.y), a, 3, true)
	queue_redraw()

func reset_flashes() -> void:
	for segment in segments:
		segment["flash"] = 0.0
	queue_redraw()

func advance_flashes(delta: float) -> void:
	var changed := false
	for segment in segments:
		var remaining: float = segment["flash"]
		if remaining > 0.0:
			segment["flash"] = maxf(0.0, remaining - delta)
			changed = true
	if changed:
		queue_redraw()

func flash_nearest(at: Vector2) -> void:
	var best := -1
	var best_distance := INF
	for i in range(segments.size()):
		var segment := segments[i]
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(at, segment["a"], segment["b"])
		var distance: float = at.distance_squared_to(nearest)
		if distance < best_distance:
			best_distance = distance
			best = i
	if best >= 0:
		segments[best]["flash"] = FLASH_SECONDS
		queue_redraw()

func wall_contact(next: Vector2, radius: float, x_axis: bool, travel: float) -> Vector2:
	if x_axis:
		if next.x <= BOUNDS.position.x + radius:
			return Vector2(BOUNDS.position.x, next.y)
		if next.x >= BOUNDS.end.x - radius:
			return Vector2(BOUNDS.end.x, next.y)
		var edge_x: float = CORE.position.x if travel > 0.0 else CORE.end.x
		return Vector2(edge_x, next.y)
	if next.y <= BOUNDS.position.y + radius:
		return Vector2(next.x, BOUNDS.position.y)
	if next.y >= BOUNDS.end.y - radius:
		return Vector2(next.x, BOUNDS.end.y)
	var edge_y: float = CORE.position.y if travel > 0.0 else CORE.end.y
	return Vector2(next.x, edge_y)

func register_bounce(next: Vector2, radius: float, x_axis: bool, travel: float, speed: float, debris: bool) -> void:
	var at: Vector2 = wall_contact(next, radius, x_axis, travel)
	flash_nearest(at)
	if debris and speed >= 25.0:
		wall_bounced.emit(at, speed)
	elif not debris:
		projectile_rebounded.emit()

func blocked(point: Vector2, radius: float = 0.0) -> bool:
	return blocked_static(point, radius) or asteroid_at(point, radius) != null

func beam_endpoint(origin: Vector2, direction: Vector2, requested_length: float) -> Vector2:
	# Exact segment intersections stop a hitscan beam at the FIRST wall or
	# piece of cover. Unlike pulses and rockets, the beam never ricochets.
	var heading: Vector2 = direction.normalized()
	if heading.is_zero_approx():
		return origin
	var maximum: float = maxf(0.0, requested_length)
	var far_end: Vector2 = origin + heading * maximum
	var nearest: float = maximum
	var rectangles: Array[Rect2] = [BOUNDS]
	if not flight_test_mode:
		rectangles.append(CORE)
	for rect in rectangles:
		var corners := PackedVector2Array([
			rect.position, Vector2(rect.end.x, rect.position.y),
			rect.end, Vector2(rect.position.x, rect.end.y)
		])
		for edge in range(4):
			var contact = Geometry2D.segment_intersects_segment(
				origin, far_end, corners[edge], corners[(edge + 1) % 4])
			if contact != null:
				nearest = minf(nearest, origin.distance_to(contact))
	for rock in asteroids:
		var radius: float = rock.radius
		var toward: Vector2 = rock.position - origin
		var forward: float = toward.dot(heading)
		var perpendicular_squared: float = toward.length_squared() - forward * forward
		if perpendicular_squared > radius * radius:
			continue
		var entry: float = forward - sqrt(maxf(0.0, radius * radius - perpendicular_squared))
		if entry >= 0.0:
			nearest = minf(nearest, entry)
	return origin + heading * nearest


func asteroid_body_impact(at: Vector2, velocity: Vector2, radius: float) -> Vector2:
	var rock = asteroid_at(at, radius)
	if rock == null:
		return velocity
	var normal: Vector2 = (at - rock.position).normalized()
	if normal.is_zero_approx():
		normal = -velocity.normalized() if not velocity.is_zero_approx() else Vector2.RIGHT
	var closing: float = maxf(0.0, -(velocity - rock.velocity).dot(normal))
	if closing <= 0.0:
		return velocity
	# Treat ship/drone as about one mass unit and asteroid as ~20.
	var impulse: float = 1.08 * closing / (1.0 + 1.0 / rock.mass)
	rock.apply_impulse(-normal * impulse)
	return velocity + normal * impulse

func move_body(body: Node2D, velocity: Vector2, radius: float, delta: float) -> Vector2:
	# The only drag on moving objects is from explicit inputs or collisions.
	var steps := maxi(1, int(ceil(velocity.length() * delta / 8.0)))
	for step in range(steps):
		var next := body.position + Vector2(velocity.x * delta / steps, 0)
		if blocked_static(next, radius):
			register_bounce(next, radius, true, velocity.x, absf(velocity.x), true)
			velocity.x *= -WALL_RESTITUTION
		elif asteroid_at(next, radius) != null:
			velocity = asteroid_body_impact(next, velocity, radius)
		elif not drone_move_clear(body, body.position, next, radius):
			velocity.x = 0.0
		else:
			body.position = next
		next = body.position + Vector2(0, velocity.y * delta / steps)
		if blocked_static(next, radius):
			register_bounce(next, radius, false, velocity.y, absf(velocity.y), true)
			velocity.y *= -WALL_RESTITUTION
		elif asteroid_at(next, radius) != null:
			velocity = asteroid_body_impact(next, velocity, radius)
		elif not drone_move_clear(body, body.position, next, radius):
			velocity.y = 0.0
		else:
			body.position = next
	return velocity

func move_shot(shot: Projectile, delta: float) -> void:
	# Axis-separated swept microsteps bounce off the outer walls and the core.
	# Shots lose no speed during a bounce, but expire after a few ricochets.
	var steps := maxi(1, int(ceil(shot.velocity.length() * delta / 4.0)))
	for step in range(steps):
		var starting_position: Vector2 = shot.position
		if shot.bounces_left <= 0:
			return
		var dt := delta / steps
		var proposed: Vector2 = shot.position + Vector2(shot.velocity.x * dt, 0)
		if asteroid_at(proposed, shot.hit_radius) != null:
			strike_asteroid(shot, proposed)
			return
		if blocked_static(proposed, shot.hit_radius):
			register_bounce(proposed, shot.hit_radius, true, shot.velocity.x, absf(shot.velocity.x), false)
			shot.velocity.x = -shot.velocity.x
			shot.sync_visual_heading()
			shot.bounces_left -= 1
		else:
			shot.position = proposed
		proposed = shot.position + Vector2(0, shot.velocity.y * dt)
		if asteroid_at(proposed, shot.hit_radius) != null:
			strike_asteroid(shot, proposed)
			return
		if blocked_static(proposed, shot.hit_radius):
			register_bounce(proposed, shot.hit_radius, false, shot.velocity.y, absf(shot.velocity.y), false)
			shot.velocity.y = -shot.velocity.y
			shot.sync_visual_heading()
			shot.bounces_left -= 1
		else:
			shot.position = proposed
		shot.distance_travelled += starting_position.distance_to(shot.position)

func strike_asteroid(shot: Projectile, next: Vector2) -> void:
	var rock = asteroid_at(next, shot.hit_radius)
	if rock == null:
		return
	if shot.is_rocket:
		# Rocket physics is handled centrally by the game so its blast hits
		# everything once, including the rock, enemies and player.
		shot.impact_pending = true
		return
	# Pulse Laser: harmless to the rock apart from a small kinetic nudge.
	rock.apply_impulse(shot.velocity.normalized() * 85.0)
	shot.begin_disintegrate()
	asteroid_struck.emit(shot.position, shot.velocity.length())

func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	# Sensor and weapon checks use the same obstruction geometry as navigation.
	if blocked(from) or blocked(to):
		return false
	if not flight_test_mode and segment_hits_rect(from, to, CORE.grow(1.0)):
		return false
	for rock in asteroids:
		if circle_segment_hits(from, to, rock.position, rock.radius + 2.0):
			return false
	return true

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

func navigation_clear(from: Vector2, to: Vector2, radius: float) -> bool:
	if not flight_test_mode and segment_hits_rect(from, to, CORE.grow(radius + 4.0)):
		return false
	for rock in asteroids:
		if circle_segment_hits(from, to, rock.position, rock.radius + radius + 4.0):
			return false
	return true

func approach_waypoint(origin: Vector2, goal: Vector2, radius: float) -> Vector2:
	# Visibility graph uses core corners plus octagonal ring waypoints
	# around each movable asteroid; updated against their current locations.
	if navigation_clear(origin, goal, radius):
		return goal
	var corner_box := CORE.grow(radius + 22.0)
	var nodes: Array[Vector2] = [
		origin, goal,
		corner_box.position,
		Vector2(corner_box.end.x, corner_box.position.y),
		corner_box.end,
		Vector2(corner_box.position.x, corner_box.end.y)
	]
	for rock in asteroids:
		for i in range(8):
			var theta: float = TAU * float(i) / 8.0
			var pt: Vector2 = rock.position + Vector2.from_angle(theta) * (rock.radius + radius + 23.0)
			if not blocked_static(pt, radius):
				nodes.append(pt)
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
			if not navigation_clear(nodes[best], nodes[j], radius):
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
	if not flight_test_mode:
		draw_rect(CORE, Color(0.035, 0.06, 0.12))
	for segment in segments:
		var base := Color(0.5, 0.35, 0.95) if segment["inner"] else Color(0.15, 0.85, 0.9)
		var flash: float = clampf(float(segment["flash"]) / FLASH_SECONDS, 0.0, 1.0)
		var bright: Color = base.lerp(Color(1.0, 1.0, 1.0), flash)
		if flash > 0.0:
			draw_line(segment["a"], segment["b"], Color(bright.r, bright.g, bright.b, flash * 0.28), 10.0, true)
		draw_line(segment["a"], segment["b"], bright, 3.0 + flash * 2.0, true)
	if not flight_test_mode:
		draw_rect(CORE.grow(-12), Color(0.25, 0.18, 0.5), false, 1)
		draw_string(ThemeDB.fallback_font, Vector2(530, 420), "OMEGA CORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.65, 0.5, 1))
