# OmegaWar roadmap

## Current branch: compact wave roguelite

This **classic-baseline** branch is focused on game feel:
- one arena and central obstruction, plus two heavy movable asteroids as cover;
- 145-unit/s² acceleration, 320-unit/s maximum ship speed and momentum
  without passive decay; 98.5% wall/core bounce restitution (but independent
  asteroid/ship impact physics);
- two to three Local Drones: 90-unit omnidirectional vision and a 400-unit,
  60-degree barrel-facing cone, 240-unit weapon reach, 0.85-radian idle
  and 1.55-radian search turret sweeps,
  rare about-faces, 7.5-radian/s tracking, last-sighting and incoming-shot
  bearing investigation, and witnesses looking back toward incoming fire
  rather than at damaged allies, subject to cover occlusion;
- one indigo long-range Local Drone per wave, maintaining 275–365 units
  from the player and launching 375-unit/s guided missiles from 275–395
  units when in sight. Missiles have a 780-unit maximum flight path,
  no launch velocity inheritance, and a 48-unit blast; they detonate
  against any physical barrier, enemy or player without bouncing;
- shared all-drone collision clearance, 12-unit preferred personal space,
  and separation of forced overlaps caused by blasts or obstacle shoves;
- one unarmed Repair Bot per wave with global awareness of damaged allies,
  persistent tracking of an injured moving patient until healed or destroyed,
  105-unit/s movement
  and a 170-unit electrical healing tether. Repair Bots flee toward armed
  allies when shot at and self-destruct if only support units remain;
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
- limited-ammo **Unguided Rockets** on secondary input: six per run,
  fixed 350-unit/s forward speed independent of ship velocity,
  three wall ricochets, 555-unit range, and
  95-unit blast radius damaging both teams with physical knockback;
- projectiles that ricochet off walls and the core, but disintegrate
  against asteroids and apply a small kinetic push;
- keyboard and controller inputs, a Resume / Reset Run pause menu with
  D-pad/stick navigation and controller A selection instead of a global
  restart key, score and five-second wave restarts;
- between-wave 3-card upgrade selection with stacking movement, hull, shield,
  Pulse Laser and rocket effects, including eight-direction kill cascade;
- wave-completion resupply of 25% maximum hull, full shields and 50% total
  rocket capacity;
- procedurally synthesized, deliberately quiet shot, missile, explosion
  and low-volume throttled rebound audio cues.

There are still **no collectible power-ups, boost equipment, gravity-well
enemies or changing arenas**; upgrades are awarded on an inter-wave screen.

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
2. Ordinary Local Drones can be ambushed from behind, only see far in their
   turret cone; long-range variants attempt to maintain a standoff distance,
   and investigate the last sighting, a witnessed allied impact, or the
   reverse bearing of an incoming shot. Alerts never expose the unseen
   attacker's exact coordinates.
3. Bullet ricochets behave predictably against every arena surface.
4. Ramming enemies transfers momentum, emits debris, and can cause damage.
   Drones avoid each other and never occupy the same footprint;
   Asteroid impacts never damage ships and persistent thrust slowly moves them.
5. Controller A selects focused menu options, menu-only restart, pause
   and wave timing are reliable;
   missile contact with walls, core, asteroids and all ships detonates
   instead of bouncing.
