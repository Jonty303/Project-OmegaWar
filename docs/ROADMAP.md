# OmegaWar roadmap

## Current branch: intentionally simple

This **classic-baseline** branch is focused on game feel:
- one arena and central obstruction, plus two heavy movable asteroids as cover;
- 145-unit/s² acceleration, 320-unit/s maximum ship speed and momentum
  without passive decay; 98.5% wall/core bounce restitution (but independent
  asteroid/ship impact physics);
- two to four Local Drones: 90-unit omnidirectional vision and a 400-unit,
  50-degree barrel-facing cone, 240-unit weapon reach, slow idle turret sweeps,
  rare about-faces, last-sighting investigation and witnessing ally hits
  only within their real sensors, subject to cover occlusion;
- one unarmed Repair Bot per wave with global awareness of damaged allies,
  faster movement and short-range electric repair tether;
- separate hull HP and shield HP, shield-first damage, shield-above-hull mini-bars,
  and a compact bottom HUD for speed, thrust, health, shields, heat and
  placeholders for secondary ammunition and ability cooldown;
- physical ship/enemy impacts with separation, impulses and temporary debris;
- ship death explosions with a brief wreckage phase before game over;
- baseline primary **Pulse Laser** with 500-unit/s aim-aligned velocity
  independent of the ship's velocity, one damage, 1,150-unit range,
  0.29-second cadence, six heat per shot;
- **Special retro burners** with front-shoulder flame exhaust and active
  265-unit/s² deceleration, without adding passive drag;
- limited-ammo **Unguided Rockets** on secondary input: six per run, full
  inherited ship velocity, three wall ricochets, 555-unit range, and
  95-unit blast radius damaging both teams with physical knockback;
- projectiles that ricochet off walls and the core, but disintegrate
  against asteroids and apply a small kinetic push;
- keyboard and controller inputs, pause, score and five-second wave restarts.

There are intentionally **no power-ups, boost equipment, gravity-well enemies
or changing arenas** in this baseline beyond the new basic rocket secondary.

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

1. The ship feels controllable and inertia is consistent at different frame
   rates, with a 320-unit/s max and no friction below it; Pulse Laser shots
   outpace the ship and never inherit the ship's velocity.
2. Local Drones can be ambushed from behind, only see far in their turret cone,
   and travel to a last sighting or witnessed allied impact before stopping
   to scan. Witness alerts never expose unseen attacker coordinates.
3. Bullet ricochets behave predictably against every arena surface.
4. Ramming enemies transfers momentum, emits debris, and can cause damage.
   Asteroid impacts never damage ships and persistent thrust slowly moves them.
5. Controller input, pause and wave timing are reliable.
