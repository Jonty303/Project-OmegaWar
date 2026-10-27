extends Node2D

const HIT_RADIUS := 3.0
var velocity := Vector2.ZERO
var hostile := false
var lifetime := 3.2
var bounces_left := 4

func _draw() -> void:
	var color := Color(1.0, 0.4, 0.2) if hostile else Color(0.6, 1.0, 0.6)
	draw_line(-velocity.normalized() * 7.0, velocity.normalized() * 2.5, color, 2, true)
