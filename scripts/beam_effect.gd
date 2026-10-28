extends Node2D

# Short-lived, world-space drawing of an instantaneous hitscan beam.
# It is entirely visual; damage is applied once on release by the game.
const DURATION := 0.23
var end_offset := Vector2.ZERO
var remaining := DURATION
var beam_width := 4.0
var power := 0.0

func configure(from: Vector2, to: Vector2, width: float, charge: float) -> void:
	position = from
	end_offset = to - from
	beam_width = width
	power = clampf(charge, 0.0, 1.0)
	remaining = DURATION
	queue_redraw()

func advance(delta: float) -> bool:
	remaining -= delta
	queue_redraw()
	return remaining <= 0.0

func _draw() -> void:
	var fade := clampf(remaining / DURATION, 0.0, 1.0)
	draw_line(Vector2.ZERO, end_offset, Color(0.25, 0.65, 1.0, 0.20 * fade), beam_width + 13.0, true)
	draw_line(Vector2.ZERO, end_offset, Color(0.37, 0.79, 1.0, 0.72 * fade), beam_width + 3.0, true)
	draw_line(Vector2.ZERO, end_offset, Color(0.95, 0.99, 1.0, fade), maxf(1.5, beam_width * 0.34), true)
	draw_circle(end_offset, 3.0 + power * 3.5, Color(0.65, 0.90, 1.0, 0.8 * fade), true)
