extends Node2D

# Lightning Gun discharge: a brief, instantaneous zigzag lightning flash.
# Gameplay hit testing is a single wall-clipped ray, with NO reflection.
const DURATION := 0.18
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
	var length: float = end_offset.length()
	if length <= 0.5:
		return
	var axis: Vector2 = end_offset / length
	var side := Vector2(-axis.y, axis.x)
	var vertices := PackedVector2Array()
	var parts: int = maxi(5, int(ceil(length / 24.0)))
	var time_shift: float = floorf(remaining * 46.0)
	for i in range(parts + 1):
		var t: float = float(i) / float(parts)
		var point := end_offset * t
		if i > 0 and i < parts:
			# Sharp independent zigzags, rather than a smooth laser line.
			var jitter: float = sin(float(i) * 17.13 + time_shift * 11.1)
			point += side * jitter * (7.0 + power * 9.0)
		vertices.append(point)
	draw_polyline(vertices, Color(0.19, 0.53, 1.0, 0.23 * fade), beam_width + 12.0, true)
	draw_polyline(vertices, Color(0.48, 0.79, 1.0, 0.74 * fade), beam_width + 3.0, true)
	draw_polyline(vertices, Color(0.98, 1.0, 1.0, fade), maxf(1.5, beam_width * 0.32), true)
	draw_circle(end_offset, 3.0 + power * 3.0, Color(0.67, 0.92, 1.0, fade), true)
