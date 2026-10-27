extends Node2D

# Small independent debris cloud. Never modifies a ship's outline or opacity.
const DURATION := 0.42
var remaining := DURATION
var fragments: Array[Dictionary] = []

func configure(tint: Color, amount: int = 8, energy: float = 1.0) -> void:
	fragments.clear()
	for i in range(amount):
		var direction := Vector2.from_angle(randf_range(0.0, TAU))
		fragments.append({
			"direction": direction,
			"speed": randf_range(30.0, 95.0) * clampf(energy, 0.5, 2.0),
			"length": randf_range(2.0, 5.0),
			"color": tint.lerp(Color(1.0, 0.85, 0.55), randf_range(0.0, 0.55))
		})
	queue_redraw()

func advance(delta: float) -> bool:
	remaining = maxf(0.0, remaining - delta)
	queue_redraw()
	return remaining <= 0.0

func _draw() -> void:
	var age: float = DURATION - remaining
	var opacity: float = remaining / DURATION
	for fragment in fragments:
		var direction: Vector2 = fragment["direction"]
		var start: Vector2 = direction * float(fragment["speed"]) * age
		var length: float = float(fragment["length"]) * opacity
		var tint: Color = fragment["color"]
		tint.a = opacity
		draw_line(start, start + direction * length, tint, 1.8, true)
