extends RefCounted

# Heavy secondary cannon: siphon propulsion into a capacitor, bringing the
# ship to a complete halt. Only a full charge released at rest can fire.
const CHARGE_DURATION := 1.8
const COOLDOWN := 1.25
const STOP_TOLERANCE := 0.75

var charge_time := 0.0
var charging := false
var cooldown := 0.0

func reset() -> void:
	charge_time = 0.0
	charging = false
	cooldown = 0.0

func fraction() -> float:
	return clampf(charge_time / CHARGE_DURATION, 0.0, 1.0)

func ready(ship_speed: float) -> bool:
	return charging and charge_time >= CHARGE_DURATION and ship_speed <= STOP_TOLERANCE

func advance(delta: float, held: bool, ship_speed: float) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	if held:
		if not charging and cooldown <= 0.0:
			charging = true
			charge_time = 0.0
		if charging:
			charge_time = minf(CHARGE_DURATION, charge_time + delta)
		return false
	if not charging:
		return false
	var discharge := ready(ship_speed)
	charging = false
	charge_time = 0.0
	if discharge:
		cooldown = COOLDOWN
	return discharge
