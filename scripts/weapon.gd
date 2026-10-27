extends RefCounted

# Baseline primary: Pulse Laser. Projectile speed and direction are determined
# solely by the gun's aim -- never by the firing ship's linear momentum.
const NAME := "Pulse Laser"
const SHOT_SPEED := 500.0
const FIRE_INTERVAL := 0.29
const HEAT_PER_SHOT := 6.0
const DAMAGE := 1.0
const MAX_RANGE := 1150.0
const MUZZLE_OFFSET := 17.0
var cooldown := 0.0

func tick(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)

func fire(origin: Vector2, heading: Vector2) -> Array[Dictionary]:
	if cooldown > 0.0 or heading.is_zero_approx():
		return []
	cooldown = FIRE_INTERVAL
	var direction: Vector2 = heading.normalized()
	return [{
		"position": origin + direction * MUZZLE_OFFSET,
		"velocity": direction * SHOT_SPEED,
		"damage": DAMAGE,
		"max_range": MAX_RANGE
	}]
