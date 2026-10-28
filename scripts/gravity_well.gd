extends Node2D

# Small non-solid gravitational anomaly. The capped acceleration stays below
# the stock ship's 145 u/s² thrust even directly on the event horizon.
const CENTRE := Vector2(846.0, 613.0)
const VISUAL_RADIUS := 15.0
const FIELD_RADIUS := 270.0
const MAX_PULL := 118.0
# Projectiles feel a much stronger force than craft. Kept separate from
# escape-balanced gravity so the well visibly bends shots and missiles.
const BULLET_PULL_MULTIPLIER := 6.0
const ROCKET_PULL_MULTIPLIER := 7.0
const HOMING_PULL_MULTIPLIER := 6.5
const SOFTENING := 78.0
var spin := 0.0

func _init() -> void:
	position = CENTRE

func advance(delta: float) -> void:
	spin = wrapf(spin + delta * 0.36, 0.0, TAU)
	queue_redraw()

func acceleration_at(world_point: Vector2) -> Vector2:
	var toward: Vector2 = position - world_point
	var distance: float = toward.length()
	if distance < 0.01 or distance >= FIELD_RADIUS:
		return Vector2.ZERO
	# Softened falloff avoids an impossible singularity at the centre;
	# a smooth field boundary avoids abrupt velocity jumps.
	var edge: float = 1.0 - smoothstep(FIELD_RADIUS * 0.78, FIELD_RADIUS, distance)
	var pull: float = MAX_PULL * SOFTENING / sqrt(SOFTENING * SOFTENING + distance * distance) * edge
	return toward / distance * pull

func _draw() -> void:
	draw_arc(Vector2.ZERO, FIELD_RADIUS * 0.60, spin, spin + TAU * 0.76, 70, Color(0.18, 0.48, 0.80, 0.11), 1.3, true)
	draw_arc(Vector2.ZERO, 32.0, -spin, -spin + TAU * 0.77, 48, Color(0.28, 0.68, 1.0, 0.24), 1.8, true)
	draw_arc(Vector2.ZERO, 23.0, spin, spin + TAU * 0.84, 48, Color(0.60, 0.32, 1.0, 0.47), 2.0, true)
	draw_circle(Vector2.ZERO, VISUAL_RADIUS + 5.0, Color(0.23, 0.16, 0.44, 0.42))
	draw_circle(Vector2.ZERO, VISUAL_RADIUS, Color(0.002, 0.004, 0.016))
	draw_arc(Vector2.ZERO, VISUAL_RADIUS + 1.0, 0.0, TAU, 48, Color(0.55, 0.43, 0.97, 0.95), 1.8, true)
