extends Node2D

# Separate blast VFX from physics/damage. Gameplay detonations resolve at
# one instant; the visual shockwave expands and fades over a short interval.
const DURATION := 0.48
var remaining := DURATION
var blast_radius := 95.0
var tint := Color(1.0, 0.55, 0.20)

func configure(radius: float) -> void:
	blast_radius = radius
	remaining = DURATION
	queue_redraw()

func advance(delta: float) -> bool:
	remaining = maxf(0.0, remaining - delta)
	queue_redraw()
	return remaining <= 0.0

func _draw() -> void:
	var progress: float = 1.0 - remaining / DURATION
	var alpha: float = 1.0 - progress
	var expanding: float = blast_radius * progress
	draw_arc(Vector2.ZERO, maxf(1.0, expanding), 0.0, TAU, 50, Color(tint.r, tint.g, tint.b, alpha * 0.9), 3.0, true)
	draw_arc(Vector2.ZERO, maxf(1.0, expanding * 0.68), 0.0, TAU, 42, Color(1.0, 0.88, 0.37, alpha * 0.7), 2.0, true)
	for i in range(12):
		var direction: Vector2 = Vector2.from_angle(TAU * float(i) / 12.0)
		var where: Vector2 = direction * expanding * 0.92
		draw_line(where, where + direction * (9.0 * alpha), Color(1.0, 0.74, 0.4, alpha), 2.0, true)
