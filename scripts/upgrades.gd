extends RefCounted

# Persistent, stackable run upgrades. The deck is filtered by equipped
# weapons so equipment-specific options never appear without their weapon.
const CHOICES := [
	{"id":"thrust","title":"Overcharged Thrusters","description":"+15% thrust acceleration","equipment":"any"},
	{"id":"rate","title":"Rapid Pulse Capacitors","description":"Pulse Laser fires 10% faster","equipment":"pulse"},
	{"id":"damage","title":"Focused Pulse Emitters","description":"+0.25 Pulse Laser damage","equipment":"pulse"},
	{"id":"hull","title":"Reinforced Structure","description":"+1 maximum and current hull HP","equipment":"any"},
	{"id":"shield","title":"Expanded Shield Matrix","description":"+1 maximum and current shield HP","equipment":"any"},
	{"id":"size","title":"Wider Pulse Bolts","description":"+0.75 Pulse Laser shot radius","equipment":"pulse"},
	{"id":"double","title":"Split Pulse Array","description":"+1 simultaneous Pulse Laser projectile","equipment":"pulse"},
	{"id":"blast","title":"Warhead Expansion","description":"+20% rocket blast radius","equipment":"rockets"},
	{"id":"cascade","title":"Pulse Shrapnel Cascade","description":"Destroyed enemies may emit 8 short-range pulses (+6% chance)","equipment":"pulse"}
]

static func offer(ship: Node2D) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for choice in CHOICES:
		if choice["equipment"] == "rockets" and ship.secondary == null:
			continue
		if choice["equipment"] == "pulse" and ship.weapon == null:
			continue
		pool.append(choice)
	pool.shuffle()
	return [pool[0], pool[1], pool[2]]

static func apply(ship: Node2D, name: String) -> bool:
	match name:
		"thrust":
			ship.thrust_multiplier += 0.15
		"rate":
			ship.weapon.fire_interval *= 0.90
		"damage":
			ship.weapon.damage += 0.25
		"hull":
			ship.max_hull += 1.0
			ship.hull += 1.0
		"shield":
			ship.max_shields += 1.0
			ship.shields += 1.0
		"size":
			ship.weapon.shot_radius += 0.75
		"double":
			ship.weapon.projectile_count += 1
		"blast":
			ship.secondary.blast_radius *= 1.20
		"cascade":
			ship.weapon.cascade_chance = minf(1.0, ship.weapon.cascade_chance + 0.06)
		_:
			return false
	ship.queue_redraw()
	return true
