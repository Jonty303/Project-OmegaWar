# OmegaWar roadmap

## Current branch: intentionally simple

This **classic-baseline** branch is focused on game feel:
- one arena and central obstruction, plus two heavy movable asteroids as cover;
- slow acceleration and momentum without passive decay;
- two to four Local Drones: limited-range 360-degree vision and turret fire,
  stationary sentry behaviour, 250-unit detection / 200-unit weapon range,
  and last-seen-position pursuit around obstacles;
- one unarmed Repair Bot per wave with slow allied healing over an electric tether;
- separate hull HP and shield HP, shield-first damage, on-damage mini-bars,
  and a compact bottom HUD for speed, thrust, health, shields, heat and
  placeholders for secondary ammunition and ability cooldown;
- physical ship/enemy impacts with separation, impulses and temporary debris;
- ship death explosions with a brief wreckage phase before game over;
- projectiles that ricochet off walls and the core, but disintegrate
  against asteroids and apply a small kinetic push;
- keyboard and controller inputs, pause, score and five-second wave restarts.

There are intentionally **no power-ups, boost equipment, gravity-well enemies,
special weapons or changing arenas** in this baseline.

## Once movement and combat feel right

Later branches can add weapon variants: rockets, lasers, homing missiles, timed
and sticky bombs, proximity mines and cluster projectiles; then defensive and
movement equipment such as shield recharge and afterburners. Build shared damage,
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
4. Ramming enemies transfers momentum, emits debris, and can cause damage.
   Asteroid impacts never damage ships and persistent thrust slowly moves them.
5. Controller input, pause and wave timing are reliable.
