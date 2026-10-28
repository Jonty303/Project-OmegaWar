# OmegaWar — classic baseline

A **Godot 4.5.2** vector-style arcade shooter inspired by the momentum combat
of Omega Race. This branch now adds a small between-wave upgrade progression to its
inertial combat, support units and collision physics. Gravity wells and
pickup-based power-ups are still deferred.
Personal shields are now a separate, finite health pool (not a pickup).

## Getting started

Open `project.godot` in Godot 4.5.2 and press **F5**. The ship starts with
three hull points, two shield points and two seconds of spawn protection.
The first wave appears after one second; at the end of each cleared wave
you choose one of three ship upgrades, then the next wave arrives after a
**five-second** countdown. Each wave contains **two to three ordinary Local
Drones, one long-range missile drone and one Repair Bot**.

| Keyboard | Joypad | Action |
| --- | --- | --- |
| W / Up | Left stick up, D-pad up or A | Thrust |
| A / D or Left / Right | Stick X or D-pad left/right | Rotate |
| S / Down / Shift | Left stick down, D-pad down or B (Special) | Retro burners / brake |
| Space | X, RB or RT | Pulse Laser |
| Q | LB | Launch unguided rocket |
| P / Escape | Start | Open / close pause menu |
| Arrow keys or Tab | D-pad up/down or left stick up/down | Navigate pause menu |
| Enter / Space | A (bottom face button) | Select focused menu option |
| Pause menu: Reset Run | Pause menu: Reset Run | Restart from the menu only |

The ship accelerates gently (145 units/s²) and **has no passive drag**:
velocity is retained until you thrust in another direction, apply the brakes
or hit a solid object. An explicit **320-unit/s ship maximum** prevents
unbounded thrust acceleration; this cap does not introduce passive drag
at any lower speed. A localized gravitational anomaly can bend
its trajectory without introducing friction. Outer walls and the central core retain **98.5% of the
normal component of impact speed** on a bounce. Momentum exchange with
other ships and heavy asteroids remains governed by their own collision rules.

The initial enemy is the **Local Drone**, a slow, territorial sentry. It spawns
at rest and uses **two separate vision zones**: close-range 360-degree
awareness within **90 units**, and a **400-unit forward view cone**, **60
degrees wide**, aligned with its visible gun barrel. The central core and asteroids block
both sensors. Its independently rotating turret now tracks at **7.5
radians/second** when alerted or aiming at an acquired target. The gun can now reach **240 units** and only
fires when the target is visible, in range and aligned.

When idle, the gun **slowly sweeps left and right** by up to
**0.85 radians (about 49°) either side of its watch direction**, rather
than pointing in a fixed direction. When searching after contact, its
scan widens to **1.55 radians (about 89°) either side**. Roughly every 15–28 seconds the drone changes its watch
direction by 180 degrees, with a visible turn rather than a snap. It stays
in place when it has a firing solution.

If it loses sight, the drone remembers the **last reported player location**
and moves there without updating the destination from unseen player
coordinates. Once it arrives, it **stops and looks around for six seconds**;
if it fails to reacquire, it returns to idle sentry scanning. It never fires
at an invisible target.
Movement uses corner-aware pathfinding around the central obstruction.

**Allied-hit alerts:** when a bullet strikes an allied drone or Repair Bot,
Local Drones that have the impact within their own 90-unit all-around sensor
or 400-unit forward cone, and an unobstructed view, become alert. The struck Local Drone notices its own hit and **turns toward the
direction from which the bullet arrived**, investigating along that firing
line and searching for a target. The turret rotates rather than snapping,
and cover limits its travel. Witnesses show an amber ring, turn their guns toward the **incoming shot
direction**, and investigate backward along its trajectory, rather than
looking directly at the damaged ally. None of these reactions reveal an
unseen shooter's exact position or allow blind firing. The central core and
asteroids can hide an impact from another sentry.

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

**Primary weapon — Pulse Laser:** baseline rapid pulses deal **1 damage**
per hit, generate **6 heat** per shot, and fire every **0.29 seconds**
when held (approximately 3.45 shots/s). Standard shot range is **1,150 units**.
Pulse Laser shots move at a fixed **500 units/s**, more than 1.5× the ship's
320-unit/s top speed. Their velocity is *exactly the ship's gun-forward heading
times 500*; no ship speed, drift, or momentum is inherited. For example,
while the ship flies upward and aims slightly downward-right, the laser fires
downward-right, not upward-diagonally. The bottom HUD names PULSE LASER as
the equipped primary. Shot damage and range now travel with the projectile
data, allowing future weapons to supply distinct values.

**Directional bullets:** projectile artwork always follows its actual
velocity, including immediately after ricochets. Bullets can travel up to
1,150 world units, bounce up to four times, and live for at most 3.2 seconds.
When they reach a limit, they stop and disintegrate into short-lived,
fading fragments for 0.34 seconds rather than suddenly disappearing.

## Between-wave upgrades and resupply

Clearing an entire wave pauses the action at a **three-choice upgrade
screen**. Select one card using the mouse, keyboard navigation, or
**D-pad / left stick + controller A**. The screen does not advance until
one of the three offers is selected; only then does the five-second next
wave countdown start.

Every completed wave also restores **25% of maximum hull health** (capped
at the current maximum), refills **100% of shields**, and replenishes
**50% of total rocket capacity** (three of the starter six), never exceeding
the currently equipped maximum. These resources carry across waves.

Upgrades accumulate across the run, and an upgrade can be selected again
on later screens:

| Upgrade | Effect per selection |
| --- | --- |
| Overcharged Thrusters | +15% thrust acceleration |
| Rapid Pulse Capacitors | Pulse Laser shoots 10% faster |
| Focused Pulse Emitters | +0.25 Pulse Laser damage |
| Reinforced Structure | +1 maximum and current hull |
| Expanded Shield Matrix | +1 maximum and current shields |
| Wider Pulse Bolts | +0.75 radius for Pulse Laser shots |
| Split Pulse Array | +1 projectile fired per Pulse Laser volley |
| Warhead Expansion | +20% secondary rocket blast radius |
| Pulse Shrapnel Cascade | +6 percentage points chance that an enemy destroyed by a Pulse Laser releases eight short-range radial pulses |

**Weapon-specific upgrades appear only when the matching weapon is
equipped.** The starting ship has both Pulse Laser and Unguided Rockets,
so the full initial deck is available. The cascade shards travel in eight
45-degree directions, deal 0.4 damage each, reach 175 units, and cannot
trigger further cascades.

## Quiet arcade sound effects

Short, low-volume procedural sound effects accompany Pulse Laser shots,
rocket/missile launches, explosions and rebounds. The **rebound tick is
deliberately much quieter** and has a minimum spacing between repeats to
avoid a rapid, distracting percussion effect during ricochets. Effects
are synthesized in Godot; no external audio assets are required.

## Gravitational anomaly

A **small dark gravity well** appears near **(846, 613)** in the lower-right
open arena. It is not a solid obstacle. Its faint violet/blue accretion rings
indicate a soft circular gravitational field extending **270 units**.
The pull strengthens smoothly toward the centre but never exceeds
**118 units/s²**, below the starter ship's **145 units/s² thrust**.
Holding thrust outward therefore still allows escape. The pull falls to
zero outside the field and is softened at the centre, avoiding unstable
high-speed slingshots through an infinite-force singularity.

Gravity pulls on **the player and all drone variants**, and applies a
reduced pull to heavy asteroids. **Projectiles are affected far more
strongly than craft**: Pulse Laser bullets experience **8× the normal pull**,
unguided rockets **9×**, and guided missiles **14×**. This produces
noticeably bent bullet paths and can overpower a homing missile's
steering near the centre. Guidance preserves gravity-induced speed and
heading changes instead of resetting them every frame.

**Local Drones actively avoid the well.** Both standard sentries and
long-range variants interrupt normal patrol, pursuit or idle behaviour
inside a **190-unit avoidance radius**. They seek a reachable route
away from the well, using up to **95 units/s of escape movement and
195 units/s² of temporary acceleration**. This makes escape possible
despite gravitational pull and preserves obstacle and ally separation.

Projectile launch direction and initial speed still ignore firing craft
velocity. Gravity bends trajectories **after launch**. The well itself
is not solid and inflicts no contact damage.

## Test-only wave difficulty escalation

At the end of each completed wave, alongside the normal three-card player
upgrade, the game **randomly applies exactly one** of four enemy difficulty
changes for the next wave. The change is shown on the upgrade screen:

| Automatic enemy change | Effect |
| --- | --- |
| More enemies | +1 ordinary Local Drone per wave |
| Higher weapon damage | +5% to enemy bullet and homing missile damage |
| Faster projectiles | +5% to enemy bullets and homing missiles |
| More enemy health | +0.5 maximum and starting hull to **every** enemy type |

These four counters **accumulate independently**: successive damage or
speed bonuses multiply by 1.05, while extra enemies and hull add to each
subsequent wave. A new run resets all four counters. This is intentionally
a simple, randomized stress-testing system, **not a finalized progression
or balance design**. The HUD shows the total number of accumulated enemy
difficulty increments.

## Drone spacing and collision avoidance

**Every drone maintains personal space from every other drone**, including
Local Drones, the long-range missile variant and Repair Bots. They turn
away from traffic when pursuing or fleeing and aim for a **12-unit gap
between their collision outlines**. All drones have a physical collision
barrier, even when they are chasing the same player or Repair Bots are
travelling toward a healing patient. They cannot intentionally move through
one another. Forced overlaps from blasts, asteroid shoves or collisions
are separated by the game simulation without dealing friendly collision
damage. Spawning also respects wider clearance between drones.

## Long-range Local Drone and homing missiles

One **long-range Local Drone** variant joins each wave. Its indigo, finned
silhouette and longer amber barrel distinguish it from ordinary sentries.
It retains the Local Drone's detection cones, last-sighting investigation
and incoming-fire reactions, but uses a **standoff tactic** instead of
approaching close. Its **preferred band is 275–365 units** from the player:
it backs away when too close, holds position inside the band and approaches
when the player is too far away, steering around the core and asteroids.
It has **3 hull HP and 1 shield point**.

Its launcher fires a small homing missile only when the target is visible,
the turret is aligned and the player is **275–395 units away**. Fire
interval averages **3.15 seconds**. The missile flies at **375 units/s**,
turns at up to **2.85 radians/s**, and has a maximum **780-unit flight
distance** or **3-second life**. It travels toward the player's current
position without phasing through barriers. Launch velocity is always
determined by the missile itself, without inheriting the firing drone's
movement or drift.

**Homing missiles explode on their first physical collision.** That
includes the player, either enemy variant, Repair Bots, asteroids, outer
arena walls and the central core. Unlike the player's unguided rockets,
enemy homing missiles **never bounce**. Their smaller blast has a
**48-unit radius**, up to **1 shield-first damage**, and up to **100
units/s outward knockback**; it may damage nearby allied enemies as well.
The normal ship damage cooldown applies to the player.

## Pause menu and reset

**Reset Run is no longer bound to Enter or controller Y during play.**
Press **P, Escape or controller Start** to open a proper pause overlay
with clickable, keyboard- and gamepad-navigable **Resume** and **Reset Run**
buttons. Use the **D-pad or left stick** to move focus and the **A button**
to confirm the focused option. This also works in the Ship Lost menu.
Movement, projectiles, missiles, waves and effects freeze while
the menu is open. Resume hides it and continues the existing run.
After a ship's death explosion, the menu opens automatically as
**Ship Lost**, with Resume disabled and Reset Run available. This makes
restart deliberate rather than an accidental key press.

## Repair Bot survival behaviour

Repair Bots now **evade incoming fire**, not just direct hits. A Pulse Laser
or rocket travelling toward the bot within **165 units** and a narrow
**34-unit corridor** triggers an evasive move if the line of sight is clear.
A surviving Repair Bot struck directly also reacts. For approximately
**2.8 seconds**, it interrupts healing and moves at up to **132 units/s**
toward a fellow armed drone, using the arena's obstacle-aware pathfinding.
It retains its existing patient assignment and resumes care afterward.
With no surviving armed drone to shelter near, it has no viable retreat.

**Once every armed enemy has been eliminated, any surviving Repair Bots
self-destruct automatically** in small green debris/shockwave bursts.
This prevents a harmless support-only remnant from extending the wave.
The self-destruction does not award unearned score or damage the player;
the standard five-second next-wave countdown follows.

## Repair Bots, shield pools and status displays

**Repair Bots** are the second enemy type. They have **no weapons**, six hull
points, and a two-point shield. They float at up to **105 units/second** (150 units/s² acceleration)
when responding to an injured allied unit, or hold position when one is close
enough to heal. They can detect a wounded ally **anywhere in the arena**; only
the green tether has limited range and requires clear line of sight. A jagged **green electrical tether** joins a Repair Bot to the
damaged ally, only within **170 units** and with clear line of sight. The tether
restores **0.9 hull HP and 0.75 shield points per second**, up to the ally's
normal maximum. The bot can repair other enemies (including allied Repair Bots),
but never the player or itself. It chooses the nearest wounded ally
**only while unassigned**. Once assigned, it stays focused on that patient
even if another drone is injured closer by. It continually tracks and
**follows its moving patient** until in clear tether range and keeps
healing whenever it is not actively fleeing incoming fire. It picks a
new patient only once the current one is fully healed, destroyed or removed.

**Shields are a separate health pool**: attacks must remove all current shields
before hull/structure HP can be reduced. Excess damage from a single hit
carries through to hull after the shield is depleted. The shared damage model
accepts separate shield and hull multipliers, ready for later energy/kinetic
weapon behaviours, but no weapon bypasses an active shield.

**Miniature health and shield bars** appear above any player ship or enemy
whose hull or shields are below full strength. The **blue shield bar is above the green hull/health bar**, matching the
shield-first damage order. Bars are omitted when both pools are full.

A **compact bottom HUD** displays live movement speed (world units/second),
thrust input percentage, retro burner input, hull HP, shield HP, weapon heat
and the equipped secondary weapon's remaining ammunition and cooldown. Primary shots
add six heat, cooling naturally at 12 heat per second. Heat is currently
informational: it does not throttle the basic weapon. Slots for **secondary
weapon/ammo and ability cooldown** are represented by the active limited
rocket count and its live launch cooldown.

## Retro burners and secondary unguided rockets

**Retro burners** operate on the **Special button** (Shift or joypad B);
S, Down and left-stick-down remain braking aliases. Applying retro thrust
fires a **tiny orange exhaust flame from each front shoulder** of the ship.
These rockets actively decelerate the existing motion at **265 units/s²**,
to a complete stop without reversing its course. They generate no passive
drag when released; their effect is independent of ship orientation.

The first secondary weapon is **Unguided Rockets** (Q or joypad LB).
You have **six rockets per run**; the HUD displays remaining ammunition
and a **0.85-second launch cooldown**. A rocket is launched at a fixed
**350 units/s strictly along the gun's forward direction**. Like the
Pulse Laser, it **does not inherit ship velocity or sideways momentum**.
Rockets fly ballistically with no homing or steering. Each has a **555-unit
flight path limit**, three solid-wall/core bounces, and a 3.2-second
maximum lifetime. Rockets bounce off walls and the core without losing
speed, but **detonate on enemy, player or asteroid contact**, or when
their range, bounce count or lifetime is exhausted.

The explosion has a **95-unit blast radius** with up to **2 points of
shield-first damage**, reduced by distance, and a substantial outward
momentum impulse (235 units/s at the centre) applied to every nearby ship,
including the player. Heavy asteroids are pushed by the blast. Self-inflicted
rocket explosions have **no friendly-fire exemption**, including short-range
and bounced-rocket explosions. Normal player invulnerability intervals still
apply, as for other attacks. The blast appears as an expanding amber shock
ring and debris, and can damage multiple enemies simultaneously. Rocket
launch generates 10 heat. Rocket ammo is replenished by three after
every completed wave, as well as being fully restored on restart.

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
Local Drone dual-zone vision, incoming-shot bearing investigation, quicker
turret tracking, witnessed allied-hit alerts, slow sweeping sentry turret
and last-sighting investigation, long-range standoff drones and contact
exploding homing missiles, menu-only reset with pause freeze,
stronger wall rebounds, shield-bar ordering, worldwide Repair
Bot awareness, incoming-fire evasion, lone-support self-destruction,
locked healing assignments and faster response,
rock/core occlusion and heavy asteroid impulses,
shot absorption, repeated thrust, blast force, stationary sentry behaviour,
last-known-position searching, independent turret alignment and firing,
shield-first damage and healing, Repair Bot targeting and tether, mixed waves,
live bottom HUD, strict ship speed limit, fixed-speed inertia-independent
Pulse Laser aiming/range/damage, retro deceleration and visible exhaust,
limited unguided inertia-independent rockets, blast splash/self-damage and
momentum impulses, body impacts, death explosions and debris, wall flashes,
bullet headings, shortened homing-missile range, range disintegration,
controller A/joypad menu navigation, pause and wave respawns.

Manual playtest:
- Thrust, release and coast; ensure no unexplained drift reduction.
- Accelerate to 320 units/s and confirm further thrust does not push above
  the ship speed limit. Your velocity below that limit never decays passively.
- Fly upward at speed while aiming slightly below horizontal to the right:
  Pulse Laser shots must travel precisely down-right with no upward drift.
  Confirm laser speed stays at 500 units/s regardless of your ship's speed.
- Slow down by thrusting backwards or using brake, and bounce off a wall.
- Watch a Local Drone stay where it spawns when you are far away.
- Approach a Local Drone from behind at roughly 150 units: it should not see
  you until its gun sweeps past or you get inside the 90-unit proximity radius.
- Approach along the gun barrel from farther away: the 400-unit, 50-degree
  forward cone should detect you, but its weapon only fires within 240 units.
- Watch the slightly wider (60°) forward view and the widened idle and
  searching turret sweeps, while keeping rear blind spots beyond 90 units.
- Watch the idle gun sweep gradually and occasionally turn to check its rear.
- Lead two Local Drones toward the same position: they should steer around
  each other and maintain a small gap instead of stacking. Repeat with a
  Repair Bot approaching an injured unit or retreating toward an ally.
- Knock drones together with rocket explosions and ensure they separate
  without inflicting collision damage on one another.
- Shoot an ally in front of another Local Drone: the witness should show an
  amber alert ring and investigate that impact, even if it never saw you.
  A witness with its back turned, outside range or behind cover should not
  react. A struck Local Drone should turn toward the incoming shot's source
  and investigate that bearing, even if the player has moved away; it must
  still see the player before firing.
- Hide behind one of the two upper-right asteroids and verify the drone
  cannot spot or shoot through it; circle the asteroid to ambush the drone.
- Crash into a rock: it should drift slowly, block your path without hurting
  the ship, and respond more strongly to sustained thrust.
- Shoot a rock with the Pulse Laser: pulses should be absorbed into dust,
  not reflected. Fire an unguided rocket: it should explode and push the rock.
- Test retro burners using Shift or controller B: two tiny FRONT flames should
  appear, and the ship should slow to a full stop without changing heading.
- Launch rockets while strafing sideways: they should follow the ship's
  barrel direction only, just like the Pulse Laser; no inherited drift.
  Test wall/core rebounds and range-end explosions.
- Fly into your own rocket or detonate one at close range: you should suffer
  the same shield-first blast damage and knockback as enemies, and nearby
  enemies should be hurt by the very same shockwave.
- Escape behind the core or out of its sight: the drone should move to your
  **last seen position**, stop to scan around, then resume idle behaviour if
  it fails to reacquire.
- Re-enter its range and verify it returns to a stationary firing position.
- Bounce against outer walls and the core: you should keep nearly all
  your speed. Other objects retain their existing impact physics.
- Shoot both outer walls and the core; check ricochets, bullet heading,
  and that only the struck wall section flashes.
- Let a bullet expire at the end of its range and watch its fading fragments.
- Ram a drone at speed: bodies bounce, a tiny debris cloud appears, and
  neither hull changes shape or blinks.
- Let the ship lose its last hull point: observe a broad debris explosion
  before the Ship Lost menu appears. Choose Reset Run in the menu.
- Approach an indigo long-range drone: it should retreat to preserve its
  preferred firing distance, then launch a small missile if it can see you.
  Dodge behind an asteroid, core or arena boundary: a homing missile that
  strikes any barrier must detonate on contact, never ricochet. Its reduced
  780-unit flight range should also limit extremely prolonged pursuit.
- Press P/Escape/Start during play and use the D-pad or left stick to
  highlight Resume or Reset Run, then press controller A to select. Verify
  that controller A also selects Reset Run after ship death. Enter and Y
  outside the menu must not restart the game.
- Shoot a shielded Repair Bot: its blue shield pool must reach zero before
  the green health pool is damaged. The shield/health mini-bars should appear.
- Injure a Local Drone anywhere in the arena: a Repair Bot should respond
  at up to 105 units/s, then tether once within 170 units. Injure a second,
  closer drone; the bot should finish healing its first patient before
  switching. Shoot toward a Repair Bot: it should break the tether,
  flee toward an allied combat drone, then resume its original patient.
  Destroy all armed drones: remaining Repair Bots should self-destruct and
  the five-second wave countdown should begin.
- Check the bottom HUD updates with speed, thrust percentage, health,
  shields and heat, plus live rocket ammunition and cooldown.
- Destroy a drone and verify its debris burst.
- Fly near the lower-right gravity well and test coasting; hold thrust
  outward to confirm you can escape, even close to its centre. Shoot
  horizontally near it and watch visible curvature in Pulse Laser bullets,
  unguided rockets and enemy homing missiles. Their paths should bend much
  more dramatically than the player's craft.
- Observe idle and long-range Local Drones close to the well: they should
  actively move outward and escape without phasing through the core,
  asteroids or other drones.
- Clear a wave: confirm the three-card bonus screen displays one random
  enemy escalation for the next wave, freezes play, supports controller A
  selection and retains your chosen upgrade. Hull should regain 25% of
  maximum, shields fully restore and rockets recover three rounds, capped
  at six. Repeated waves should stack the enemy difficulty modifiers.
- Check that a Repair Bot follows an injured drone which moves away, then
  heals as soon as it can establish tether contact.
- Shoot one enemy while another drone sees the impact: the witness should
  turn down the incoming firing line, not stare at the damaged ally.
- Test Pulse Shrapnel Cascade: after selecting it, some Pulse Laser kills
  should launch eight short-range projectiles. More selections make it
  more likely.
- Listen for soft shot, missile and explosion effects and a very quiet
  rebound sound with no repetitive ear-fatiguing effect.
- After selecting an upgrade, watch 2–3 Local Drones, one long-range
  missile drone and one Repair Bot return after five seconds.

All visuals are procedural line art; no external sprites or plugins are needed.
There is no audio, settings or save system yet. `docs/ROADMAP.md` retains the
longer-term weapon and arena ideas for later, once this baseline feels right.
