extends RefCounted

# Limited, unguided medium-range secondary. Launch velocity follows the
# gun direction alone, just like the Pulse Laser: no ship momentum inherited.
const NAME := "Unguided Rockets"
const MAX_AMMO := 6
const SHOT_SPEED := 350.0
const FIRE_INTERVAL := 0.85
const MAX_RANGE := 555.0
const DAMAGE := 2.0
const BLAST_RADIUS := 95.0
const BLAST_IMPULSE := 235.0
const HEAT_PER_SHOT := 10.0
const MUZZLE_OFFSET := 23.0

var ammo := MAX_AMMO
var blast_radius := BLAST_RADIUS
var cooldown := 0.0

func tick(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)

func fire(origin: Vector2, heading: Vector2) -> Dictionary:
	if ammo <= 0 or cooldown > 0.0 or heading.is_zero_approx():
		return {}
	ammo -= 1
	cooldown = FIRE_INTERVAL
	var direction: Vector2 = heading.normalized()
	return {
		"position": origin + direction * MUZZLE_OFFSET,
		"velocity": direction * SHOT_SPEED,
		"max_range": MAX_RANGE,
		"damage": DAMAGE,
		"blast_radius": blast_radius,
		"blast_impulse": BLAST_IMPULSE
	}
