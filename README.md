# OmegaWar — classic baseline

A **Godot 4.5.2** vector-style arcade shooter inspired by the momentum combat
of Omega Race. This branch omits power-ups, boosts, rapid-fire modifiers and gravity wells,
and concentrates on small-scale combat, support units and momentum physics.
Personal shields are now a separate, finite health pool (not a pickup).

## Getting started

Open `project.godot` in Godot 4.5.2 and press **F5**. The ship starts with
three hull points, two shield points and two seconds of spawn protection.
The first wave appears after one second; subsequent waves appear **five seconds
after the last enemy dies**, with **two to four Local Drones and one Repair Bot**.

| Keyboard | Joypad | Action |
| --- | --- | --- |
| W / Up | Left stick up, D-pad up or A | Thrust |
| A / D or Left / Right | Stick X or D-pad left/right | Rotate |
| S / Down | Left stick down, D-pad down or B | Brake |
| Space | X, RB or RT | Shoot |
| P / Escape | Start | Pause / resume |
| Enter | Y | Restart |

The ship accelerates gently and **never slows down by itself**: velocity is
retained until you thrust in another direction, apply the brakes, or hit a
solid object. The central core and arena walls reflect moving ships, with some
energy lost on collision.

The initial enemy is the **Local Drone**, a slow, territorial sentry. It spawns
at rest, watching in every direction within **250 world units**. The central
core and asteroids block its line of sight. Once it sees the player, its visible gun turret
(a bright clock hand extending from the drone's centre) turns independently
up to **6 radians/second**. It shoots only if the player is visible, within
the **200-unit weapon range**, and the turret is aligned. At a firing position
it holds steady rather than constantly chasing.

If the player leaves sight, the drone remembers their **last observed
location and bearing**, moves slowly toward that location and continues a
methodical search along the same bearing until it reacquires the player.
It never fires at an invisible target or telepathically updates its target.
Movement uses corner-aware pathfinding around the central obstruction.

Shots from either side **ricochet off arena
walls and the core** at full speed; they expire after four bounces or 3.2
seconds, whichever comes first. Friendly shots hit drones and hostile shots
hit the player. High-speed ship/drone collisions separate both bodies, transfer
momentum using an impulse, and can cause damage. The ship and enemy
silhouettes never deform or blink after hits. Instead, small bursts of debris
scatter and fade. **When the third hull point is lost, the player ship
explodes into a larger 32-fragment debris cloud lasting 0.9 seconds.**
Its intact silhouette is hidden immediately, while the game-over message
waits until the wreckage has finished dispersing. Destroyed drones also
leave a burst of debris instead of merely disappearing.

**Sectioned walls:** five individually flashing sections span each horizontal
arena wall, and three span each vertical arena wall. The central core is also
split into separate sections. When a ship or shot bounces, the particular
section hit briefly flashes white, like the original Omega Race.

**Directional bullets:** projectile artwork always follows its actual
velocity, including immediately after ricochets. Bullets can travel up to
1,150 world units, bounce up to four times, and live for at most 3.2 seconds.
When they reach a limit, they stop and disintegrate into short-lived,
fading fragments for 0.34 seconds rather than suddenly disappearing.

## Repair Bots, shield pools and status displays

**Repair Bots** are the second enemy type. They have **no weapons**, six hull
points, and a two-point shield. They float at about 42 units/second when
responding to an injured allied unit, or hold position when one is close enough
to heal. A jagged **green electrical tether** joins a Repair Bot to the
damaged ally, only within 148 units and with clear line of sight. The tether
restores **0.9 hull HP and 0.75 shield points per second**, up to the ally's
normal maximum. The bot can repair other enemies (including allied Repair Bots),
but never the player or itself. It chooses the nearest wounded ally.

**Shields are a separate health pool**: attacks must remove all current shields
before hull/structure HP can be reduced. Excess damage from a single hit
carries through to hull after the shield is depleted. The shared damage model
accepts separate shield and hull multipliers, ready for later energy/kinetic
weapon behaviours, but no weapon bypasses an active shield.

**Miniature health and shield bars** appear above any player ship or enemy
whose hull or shields are below full strength. Green shows hull HP, blue
shows shields. Bars are omitted when both pools are full.

A **compact bottom HUD** displays live movement speed (world units/second),
thrust input percentage, hull HP, shield HP and weapon heat. Primary shots
add six heat, cooling naturally at 12 heat per second. Heat is currently
informational: it does not throttle the basic weapon. Slots for **secondary
weapon/ammo and ability cooldown** explicitly show unavailable until those
systems are added, rather than suggesting nonexistent equipment.

## Two heavy asteroids

Two irregular, slate-coloured asteroids provide additional cover in the
**upper-right corner** of the arena, near (924, 226) and (1038, 311).
They are genuine physical and tactical obstacles:

- Both block all-round Local Drone sensors and direct turret fire.
- Player ships and drones cannot pass through them, but can steer around
  them, and drone routefinding uses movable-asteroid waypoints.
- They **never cause hull damage**, even during an impact.
- Shots from either side **dissipate** on the surface rather than ricocheting,
  leaving a short dusty impact burst. Each hit nudges the asteroid a little.
- Repeated thrust into a rock can push it further, while large explosions
  impart stronger impulses. Rock masses (24 and 19) and environmental
  resistance give their movement a slow, heavy feel.
- Their momentum dissipates gradually, unlike the player's inertial flight.
  Rock positions reset when starting a new run.

## Test

From the project root:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script tests/smoke.gd
godot --headless --path . --quit-after 600
```

The smoke test covers conserved momentum, slow thrust, braking, core impacts,
Local Drone detection range and rock/core occlusion, heavy asteroid impulses,
shot absorption, repeated thrust, blast force, stationary sentry behaviour,
last-known-position searching, independent turret alignment and firing,
shield-first damage and healing, Repair Bot targeting and tether, mixed waves,
live bottom HUD, body impulses, death explosions and debris, wall flashes,
bullet headings, range disintegration, controller pause and wave respawns.

Manual playtest:
- Thrust, release and coast; ensure no unexplained drift reduction.
- Slow down by thrusting backwards or using brake, and bounce off a wall.
- Watch a Local Drone stay where it spawns when you are far away.
- Move into its 250-unit vision circle: watch the bright turret rotate like a
  clock hand and fire only once it is facing you inside its shorter gun range.
- Hide behind one of the two upper-right asteroids and verify the drone
  cannot spot or shoot through it; circle the asteroid to ambush the drone.
- Crash into a rock: it should drift slowly, block your path without hurting
  the ship, and respond more strongly to sustained thrust.
- Shoot a rock: shots should be absorbed into dust, not reflected.
- Escape behind the core or outside vision: the drone should search your last
  known direction, but stop shooting until it sees you again.
- Re-enter its range and verify it returns to a stationary firing position.
- Shoot both outer walls and the core; check ricochets, bullet heading,
  and that only the struck wall section flashes.
- Let a bullet expire at the end of its range and watch its fading fragments.
- Ram a drone at speed: bodies bounce, a tiny debris cloud appears, and
  neither hull changes shape or blinks.
- Let the ship lose its last hull point: observe a broad debris explosion
  before the game-over message appears; restart with Enter or controller Y.
- Shoot a shielded Repair Bot: its blue shield pool must reach zero before
  the green health pool is damaged. The shield/health mini-bars should appear.
- Injure a Local Drone and watch a nearby Repair Bot connect its green
  electrical tether and replenish health; check that it never heals the player.
- Check the bottom HUD updates with speed, thrust percentage, health,
  shields and heat. Secondary ammo/cooldown should explicitly say unavailable.
- Destroy a drone and verify its debris burst.
- Clear a wave, pause during the countdown, then watch 2–4 Local Drones
  and one Repair Bot return.

All visuals are procedural line art; no external sprites or plugins are needed.
There is no audio, settings or save system yet. `docs/ROADMAP.md` retains the
longer-term weapon and arena ideas for later, once this baseline feels right.
