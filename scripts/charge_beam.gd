extends RefCounted

# Lightning Gun: a charged, instantaneous flash released by primary fire.
# Range and damage scale with charge; it is always absorbed by walls.
const MIN_CHARGE := 0.10
const MAX_CHARGE := 1.50
const COOLDOWN := 0.55
const MIN_LENGTH := 180.0
const MAX_LENGTH := 850.0
const MIN_DAMAGE := 0.75
const MAX_DAMAGE := 4.25

var charge_time := 0.0
var charging := false
var cooldown := 0.0

static func spec_for(seconds: float) -> Dictionary:
	var power := clampf(seconds / MAX_CHARGE, 0.0, 1.0)
	return {
		"power": power,
		"length": lerpf(MIN_LENGTH, MAX_LENGTH, power),
		"damage": lerpf(MIN_DAMAGE, MAX_DAMAGE, power),
		"width": lerpf(3.0, 11.0, power),
		"heat": lerpf(8.0, 40.0, power)
	}

func reset() -> void:
	charge_time = 0.0
	charging = false
	cooldown = 0.0

func charge_fraction() -> float:
	return clampf(charge_time / MAX_CHARGE, 0.0, 1.0)

func advance(delta: float, held: bool) -> Dictionary:
	cooldown = maxf(0.0, cooldown - delta)
	if held:
		if not charging and cooldown <= 0.0:
			charging = true
			charge_time = 0.0
		if charging:
			charge_time = minf(MAX_CHARGE, charge_time + delta)
		return {}
	if not charging:
		return {}
	charging = false
	var elapsed := charge_time
	charge_time = 0.0
	if elapsed < MIN_CHARGE:
		return {}
	cooldown = COOLDOWN
	return spec_for(elapsed)
