extends Node2D

# Movable cover: high inertia, no contact damage, resistant to stray bullets.
const DRAG := 0.85
const MAX_SPEED := 165.0
var radius := 34.0
var mass := 24.0
var velocity := Vector2.ZERO
var starting_position := Vector2.ZERO
var rock_shape := PackedVector2Array()
var surface_rotation := 0.0

func configure(at: Vector2, size: float, weight: float) -> void:
	position = at
	starting_position = at
	radius = size
	mass = weight
	velocity = Vector2.ZERO
	# Fixed asymmetric silhouette so these read as rocks rather than drones.
	rock_shape.clear()
	for i in range(11):
		var angle: float = float(i) * TAU / 11.0
		var variation: float = [0.92, 1.06, 0.90, 1.12, 0.86, 1.02, 0.91, 1.09, 0.95, 1.05, 0.88][i]
		rock_shape.append(Vector2.from_angle(angle) * radius * variation)
	queue_redraw()

func apply_impulse(impulse: Vector2) -> void:
	velocity = (velocity + impulse / mass).limit_length(MAX_SPEED)

func reset_rock() -> void:
	position = starting_position
	velocity = Vector2.ZERO
	surface_rotation = 0.0
	queue_redraw()

func _draw() -> void:
	var surface := Color(0.16, 0.22, 0.29)
	var edge := Color(0.58, 0.72, 0.77)
	draw_colored_polygon(rock_shape, surface)
	var closed := rock_shape.duplicate()
	closed.append(rock_shape[0])
	draw_polyline(closed, edge, 2.5, true)
	draw_line(Vector2(-radius * 0.40, -radius * 0.22), Vector2(-radius * 0.08, -radius * 0.42), Color(0.37, 0.50, 0.54), 1.5)
	draw_line(Vector2(radius * 0.08, radius * 0.12), Vector2(radius * 0.47, radius * 0.28), Color(0.33, 0.43, 0.49), 1.5)
	draw_arc(Vector2(-radius * 0.12, radius * 0.22), radius * 0.17, 0.0, TAU, 16, Color(0.33, 0.43, 0.49), 1.5, true)
