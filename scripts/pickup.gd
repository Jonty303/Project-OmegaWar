extends Node2D

const RADIUS := 13.0

const COLORS := [Color(0.3, 0.65, 1), Color(1, 0.8, 0.2), Color(0.5, 1, 0.4)]
const LABELS := ["S", "B", "R"]
var kind := 0
var lifetime := 18.0

func _draw() -> void:
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 24, COLORS[kind], 2, true)
	draw_string(ThemeDB.fallback_font, Vector2(-5, 5), LABELS[kind], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLORS[kind])
