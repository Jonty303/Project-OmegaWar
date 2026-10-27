# OmegaWar roadmap

## Current slice
One rectangular arena with a central obstruction; momentum movement, brake,
temporary afterburner, pulse shots, chasing drones, gravity wells, shield and
rapid-fire pickups, score, escalating waves, pause, death, and restart.
Gravity currently affects the player only. Enemies can overlap one another.
All art is original procedural linework.

## Weapon extension seam
`weapon.gd` owns cooldown and returns shot descriptors; `game.gd` spawns them.
Before adding weapon types, promote these descriptors to a typed ShotSpec resource
(damage, team, lifetime, speed, collision radius, scene) and move collision and
damage dispatch into a combat service. Keep movement independent of equipment.
Use a shared damage receiver contract and explicit owner/team filtering to avoid
self-hits. Pool projectiles only after measuring performance.

| Planned equipment | Behaviour / implementation |
| --- | --- |
| Rockets | Straight flight, impact blast, radius damage with obstruction checks |
| Lasers | Ray query stopping at walls, visible beam, per-target damage cadence |
| Missiles | Target selection, limited turn rate, reacquire when target dies |
| Timed bombs | Fuse component, visible countdown, shared blast service |
| Sticky bombs | Attach to hit actor/local point; detach safely when host dies |
| Proximity mines | Arming delay, team-aware trigger radius, capped active count |
| Cluster munitions | Spawn bounded child projectiles once on detonation |
| Boost | Current timed pickup; later heat/fuel equipment with recharge |
| Shields | Current timed absorption; later capacity/recharge and impact feedback |

Weapon effects should use a common detonation guard so impact and timer expiry
cannot explode twice. Cluster children must not recursively produce clusters.
Add tests for friendly fire, destroyed targets, wall occlusion, fuse timing,
and upper bounds on simultaneous explosives.

## Arena and gravity progression
Replace the fixed rectangle/core with ArenaDefinition resources and reusable
collision geometry: offset cores, narrow channels, rotating hazards, and
multiple islands. Keep spawn validation radius-aware and test reachable routes.
Add attracting/repelling/orbiting field components with softening near the center
and a cap on combined acceleration. Decide explicitly whether each weapon,
enemy, and pickup responds to gravity.

## Subsequent milestones
1. Playtest movement and readability; add sound and hit/destruction feedback.
2. Ship rockets and mines through the shared damage/weapon contracts.
3. Add arena selection and gravity variants with deterministic seeded waves.
4. Add remaining weapons, controller/remapping UI, difficulty options, and saves.

No additional weapon types or arena layouts in this roadmap are implemented yet.
