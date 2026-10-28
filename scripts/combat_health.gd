extends RefCounted

# Shared shield-first damage calculation. Multipliers allow future weapons
# to affect the two pools differently, but no weapon can bypass an active shield.
# Result is (remaining hull, remaining shields).
static func apply(hull: float, shields: float, damage: float, shield_factor: float = 1.0, hull_factor: float = 1.0) -> Vector2:
	var remaining := maxf(0.0, damage)
	var protection := maxf(0.0, shields)
	var structure := maxf(0.0, hull)
	if protection > 0.0:
		if shield_factor <= 0.0:
			return Vector2(structure, protection)
		var consumed := minf(remaining, protection / shield_factor)
		protection = maxf(0.0, protection - consumed * shield_factor)
		remaining -= consumed
	if remaining > 0.0 and protection <= 0.0:
		structure = maxf(0.0, structure - remaining * maxf(0.0, hull_factor))
	return Vector2(structure, protection)
