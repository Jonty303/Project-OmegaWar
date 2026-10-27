extends Node2D

const COLLISION_RADIUS := 14.0
const ACCELERATION := 95.0
const MAX_SPEED := 105.0

var velocity := Vector2.ZERO
var health := 2
var fire_timer := 1.8
var crunch := 0.0
var collision_cooldown := 0.0

func step(delta: float, target: Vector2, arena: Node2D) -> void:
	fire_timer -= delta
	collision_cooldown = maxf(0.0, collision_cooldown - delta)
	crunch = maxf(0.0, crunch - delta * 1.8)
	# Follow a clear route around the core instead of continually steering into it.
	var waypoint: Vector2 = arena.approach_waypoint(position, target, COLLISION_RADIUS)
	var desired_velocity := position.direction_to(waypoint) * MAX_SPEED
	var steering := (desired_velocity - velocity).limit_length(ACCELERATION * delta)
	velocity += steering
	var before := velocity
	velocity = arena.move_body(self, velocity, COLLISION_RADIUS, delta)
	if (velocity - before).length() > 20.0:
		crunch = maxf(crunch, clampf((velocity - before).length() / 300.0, 0.1, 0.85))
	if velocity.length_squared() > 4.0:
		rotation = velocity.angle() + PI / 2.0
	queue_redraw()

func impact(speed: float) -> bool:
	crunch = maxf(crunch, clampf(speed / 150.0, 0.2, 1.0))
	if speed >= 100.0 and collision_cooldown <= 0.0:
		health -= 1
		collision_cooldown = 0.6
	queue_redraw()
	return health <= 0

func _draw() -> void:
	var color := Color(1.0, 0.4, 0.25)
	var polygon := PackedVector2Array()
	for i in range(7):
		var angle := i * TAU / 6.0
		var radius := 13.0 - crunch * (5.0 if i % 2 == 0 else 2.0)
		polygon.append(Vector2.from_angle(angle) * radius)
	draw_polyline(polygon, color, 2.0, true)
	draw_circle(Vector2.ZERO, 4.0 - crunch, color, false, 2.0, true)
	if crunch > 0.15:
		draw_line(Vector2(-5, -3), Vector2(6, 4), Color(1.0, 0.8, 0.35, crunch), 1.5)
