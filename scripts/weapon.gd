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
var fire_interval := FIRE_INTERVAL
var damage := DAMAGE
var shot_radius := 3.0
var projectile_count := 1
var cascade_chance := 0.0

func tick(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)

func fire(origin: Vector2, heading: Vector2) -> Array[Dictionary]:
	if cooldown > 0.0 or heading.is_zero_approx():
		return []
	cooldown = fire_interval
	var direction: Vector2 = heading.normalized()
	var bullets: Array[Dictionary] = []
	for i in range(projectile_count):
		var spread: float = (float(i) - float(projectile_count - 1) * 0.5) * 0.10
		var heading_vector: Vector2 = direction.rotated(spread)
		bullets.append({
			"position": origin + heading_vector * MUZZLE_OFFSET,
			"velocity": heading_vector * SHOT_SPEED,
			"damage": damage,
			"max_range": MAX_RANGE,
			"radius": shot_radius
		})
	return bullets
