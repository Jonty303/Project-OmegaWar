extends Node2D

const COLLISION_RADIUS := 14.0
const ACCELERATION := 95.0
const MAX_SPEED := 105.0

var velocity := Vector2.ZERO
var health := 2
var fire_timer := 1.8
var collision_cooldown := 0.0

func step(delta: float, target: Vector2, arena: Node2D) -> void:
	fire_timer -= delta
	collision_cooldown = maxf(0.0, collision_cooldown - delta)
	# Follow a clear route around the core instead of continually steering into it.
	var waypoint: Vector2 = arena.approach_waypoint(position, target, COLLISION_RADIUS)
	var desired_velocity := position.direction_to(waypoint) * MAX_SPEED
	var steering := (desired_velocity - velocity).limit_length(ACCELERATION * delta)
	velocity += steering
	velocity = arena.move_body(self, velocity, COLLISION_RADIUS, delta)
	if velocity.length_squared() > 4.0:
		rotation = velocity.angle() + PI / 2.0
	queue_redraw()

func impact(speed: float) -> bool:
	if speed >= 100.0 and collision_cooldown <= 0.0:
		health -= 1
		collision_cooldown = 0.6
	queue_redraw()
	return health <= 0

func _draw() -> void:
	var color := Color(1.0, 0.4, 0.25)
	var polygon := PackedVector2Array()
	for i in range(7):
		polygon.append(Vector2.from_angle(float(i) * TAU / 6.0) * 13.0)
	draw_polyline(polygon, color, 2.0, true)
	draw_circle(Vector2.ZERO, 4.0, color, false, 2.0, true)
