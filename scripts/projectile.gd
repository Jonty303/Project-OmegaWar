extends Node2D

var velocity := Vector2.ZERO
var hostile := false
var lifetime := 3.0

func _draw() -> void:
	var color := Color(1, 0.4, 0.2) if hostile else Color(0.6, 1, 0.6)
	draw_line(-velocity.normalized() * 9, velocity.normalized() * 3, color, 3, true)
