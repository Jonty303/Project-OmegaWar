extends "res://scripts/projectile.gd"

# A moving missile: bounces off solid walls, explodes against ships/asteroids,
# and detonates on running out of range or life. Blast is never team-filtered.
const ROCKET_RADIUS := 5.0
var blast_radius := 95.0
var blast_impulse := 235.0
var trail_time := 0.0

func _init() -> void:
	is_rocket = true
	hit_radius = ROCKET_RADIUS
	bounces_left = 3
	lifetime = 3.2

func _draw() -> void:
	var forward: Vector2 = visual_heading
	var lateral: Vector2 = Vector2(-forward.y, forward.x)
	var nose: Vector2 = forward * 7.0
	var tail: Vector2 = -forward * 8.0
	var left: Vector2 = tail + lateral * 4.5
	var right: Vector2 = tail - lateral * 4.5
	var shell := Color(1.0, 0.73, 0.28)
	draw_colored_polygon(PackedVector2Array([nose, left, right]), Color(0.3, 0.23, 0.14))
	draw_polyline(PackedVector2Array([nose, left, right, nose]), shell, 2.0, true)
	draw_line(tail, tail - forward * (5.0 + 2.0 * sin(trail_time * 25.0)), Color(1.0, 0.43, 0.16), 2.8, true)
	draw_circle(nose, 1.6, Color(1.0, 0.98, 0.6))
