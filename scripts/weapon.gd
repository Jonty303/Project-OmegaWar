extends RefCounted
# A weapon owns cadence and shot descriptors; the world owns spawning/collision.
# Future weapon resources can replace fire() without changing ship movement.
var cooldown := 0.0

func tick(delta: float) -> void:
	cooldown = maxf(0, cooldown - delta)

func fire(origin: Vector2, heading: Vector2, inherited_velocity: Vector2, rapid: bool) -> Array[Dictionary]:
	if cooldown > 0:
		return []
	cooldown = 0.10 if rapid else 0.24
	return [{"position": origin + heading * 17, "velocity": heading * 650 + inherited_velocity * 0.4}]
