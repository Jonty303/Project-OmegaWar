extends Node2D

const HIT_RADIUS := 3.0
const MAX_RANGE := 1150.0
const DISSOLVE_SECONDS := 0.34

var velocity := Vector2.ZERO
var damage := 1.0
var max_range := MAX_RANGE
var visual_heading := Vector2.RIGHT
var hostile := false
var lifetime := 3.2
var bounces_left := 4
var distance_travelled := 0.0
var dissolving := false
var dissolve_remaining := DISSOLVE_SECONDS

func sync_visual_heading() -> void:
	if velocity.length_squared() > 0.001:
		visual_heading = velocity.normalized()
	queue_redraw()

func begin_disintegrate() -> void:
	if dissolving:
		return
	sync_visual_heading()
	dissolving = true
	dissolve_remaining = DISSOLVE_SECONDS
	queue_redraw()

func step_disintegration(delta: float) -> bool:
	dissolve_remaining = maxf(0.0, dissolve_remaining - delta)
	queue_redraw()
	return dissolve_remaining <= 0.0

func _draw() -> void:
	var base := Color(1.0, 0.4, 0.2) if hostile else Color(0.6, 1.0, 0.6)
	if dissolving:
		var progress: float = 1.0 - dissolve_remaining / DISSOLVE_SECONDS
		for i in range(6):
			var angle: float = TAU * float(i) / 6.0 + (0.25 if hostile else 0.0)
			var direction := Vector2.from_angle(angle)
			var centre: Vector2 = direction * (2.0 + progress * (8.0 + float(i % 3) * 4.0))
			var color := Color(base.r, base.g, base.b, (1.0 - progress) * 0.85)
			draw_line(centre - visual_heading * (2.0 - progress), centre + visual_heading * (2.0 - progress), color, 1.6, true)
		return
	draw_line(-visual_heading * 7.0, visual_heading * 2.5, base, 2.0, true)
