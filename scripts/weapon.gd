extends RefCounted

# Single fixed weapon for the baseline. Future weapons can plug in here.
const SHOT_SPEED := 415.0
const FIRE_INTERVAL := 0.29
var cooldown := 0.0

func tick(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)

func fire(origin: Vector2, heading: Vector2, inherited_velocity: Vector2) -> Array[Dictionary]:
	if cooldown > 0.0:
		return []
	cooldown = FIRE_INTERVAL
	return [{
		"position": origin + heading * 17.0,
		"velocity": heading * SHOT_SPEED + inherited_velocity * 0.45
	}]
