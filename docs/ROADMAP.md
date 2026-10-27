# OmegaWar roadmap

## Current branch: intentionally simple

This **classic-baseline** branch is focused on game feel:
- one arena and central obstruction;
- slow acceleration and momentum without passive decay;
- three to five Local Drones: limited-range 360-degree vision and turret fire,
  stationary sentry behaviour, and last-seen-position pursuit around obstacles;
- physical ship/enemy impacts with separation, impulses and temporary debris;
- ship death explosions with a brief wreckage phase before game over;
- projectiles that ricochet off walls and the core;
- keyboard and controller inputs, pause, score and five-second wave restarts.

There are intentionally **no power-ups, shields, boosts, gravity-well enemies,
special weapons or changing arenas** in this baseline.

## Once movement and combat feel right

Later branches can add weapon variants: rockets, lasers, homing missiles, timed
and sticky bombs, proximity mines and cluster projectiles; then defensive and
movement equipment such as shields and afterburners. Build shared damage,
physics and projectile interfaces before adding multiple weapon types.

Arena resources can later introduce broken rings, narrow channels, islands,
rotating obstacles, and attracting or repelling gravity fields. Any new
navigation should use the same collision clearance and remain testable around
obstacles.

## Near-term acceptance targets

1. The ship feels controllable and inertia is consistent at different frame rates.
2. Local Drones remain stationary until sighting, hold position while firing,
   and search along the last observed path without seeing through the core.
3. Bullet ricochets behave predictably against every arena surface.
4. Ramming transfers momentum, visibly deforms hull outlines, and causes
   damage at high closing speed, without sticky overlaps.
5. Controller input, pause and wave timing are reliable.
