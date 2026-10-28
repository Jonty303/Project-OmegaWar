# Omega War: Fleet Command — exploratory branch

**Status:** Early concept / gameplay prototype proposal  
**Parent branch:** `codex/omega-war-classic-baseline`  
**Prototype engine:** Godot 4.5.2 (retaining the repository's existing vector-style presentation)

## High concept

A real-time, 2D open-arena warship combat game. The player directly pilots and fights with a flagship while building a small fleet whose other ships follow tactical AI orders assigned **before each engagement**. Heavy capital ships, directional weapon slots, fighters, asteroids and gravity anomalies make positioning and loadout matter.

**Core fantasy:** Captain a formidable warship, bring your fleet into battle, line up devastating broadsides, launch fighter wings, and watch supporting ships execute your plan without constant micromanagement.

This branch is a **separate experiment**, not a replacement for Omega War's arcade shooter. Keep the original baseline untouched.

## Core play loop

1. **Fleet bay / pre-battle:** Select the flagship, install weapons in hardpoints, set fighter loadouts, assign one standing AI order and optional target preference to each supporting vessel.
2. **Deploy:** Enter an open arena containing hostile ships, cover from drifting asteroids, and occasionally gravity wells.
3. **Captain:** Pilot the flagship with momentum/inertia. Turn to present the desired firing arc, fire independently selectable weapon banks, and launch fighters.
4. **Support:** Allied AI ships carry out their standing orders. Some damage, escort, shield, intercept, repair, or supply others. No need to micro every ship.
5. **Resolve:** Win the battle, collect salvage/credits/upgrades, repair/refit the survivors, and grow the fleet before the next encounter.

## Ships and hardpoints

Each hull defines:
- Mass, inertia, acceleration, turn rate, hull/armour/shield statistics, reactor output and heat capacity.
- Weapon slot positions with **front / port / starboard / aft** arcs; optional future dorsal or turret mounts.
- Slot size and allowable weapon class, so a light frigate cannot mount a battleship spinal gun.
- Hangar capacity, fighter launch rate, and any support/utility slots.
- A tactical role (brawler, broadside, artillery, carrier, escort, support).

Firing should be visibly arc-restricted. A gun cannot shoot through the warship's own hull; hull orientation determines which batteries can engage. Prefer **independent port and starboard firing banks**, rather than making all weapons simply fire forward. Each slot has distinct muzzle position, cooldown, range, projectile/beam behaviour and energy/heat cost.

Candidate weapons:
- **Bow rail cannon:** heavy, long range, narrow forward arc.
- **Broadside batteries:** sustained side fire; rewarding for crossing an enemy's path.
- **Point defence:** automatic interception of missiles/fighters within short range.
- **Aft missile rack:** slow-turning capital ships still have rear defence.
- **Lightning gun:** very brief, instant-looking discharge on release, no ricochet.
- **Siege beam:** ship slows as it charges, stops when fully charged, then releases a growing sinuous beam; a later upgrade enables / modifies wall bounces.

Lightning and siege beam are ideas inherited from the arcade design; **not mandated** for the first prototype.

## Moment-to-moment piloting

The flagship is directly controlled, always. It is deliberately weighty: slower to turn and accelerate than fighters, with inertia that creates interesting choices around gun arcs, braking and gravity. Let the player choose which bank to fire and when, rather than automatically firing everything at all times. Accessibility option later: hold a bank trigger to fire ready weapons in that arc.

Consider a **target-lock / focus** input so broadside weapons can coordinate on one enemy without turning into an aim-heavy twin-stick game.

## Fighter wings

Fighters launch from hangars during combat, not as permanently independent fleet ships. They consume a limited, recoverable wing capacity; their orders can be set to **attack**, **intercept**, **screen**, or **return**. Fighters should be useful against large ships but vulnerable to point defence, enemy fighters and environmental hazards. Carrier-style ships sacrifice some heavy direct firepower to field more wings.

For an early prototype: one fighter wing per carrier, a visible launch/cooldown, and a simple intercept-or-attack mode.

## Pre-battle orders for allied ships

Use an intentionally concise, Dark Reign-inspired **standing-order** model, with predictable behaviour and transparent priorities. The player can adjust plans between battles; optional emergency commands during battle are a later feature.

| Order | Behaviour |
| --- | --- |
| **Attack** | Seek designated or highest-priority enemy; reposition to maintain effective firing arcs/range. |
| **Escort** | Remain near a chosen friendly ship, match motion as practical, and engage threats against that ship. |
| **Defend** | Hold a position/zone, engage hostiles that threaten it, then return. |
| **Screen** | Stay between a protected ship and incoming threats; prioritise fighters and missiles. |
| **Support** | Follow a designated ally; repair, shield, buff or resupply as fitted and within range. |
| **Artillery** | Keep stand-off distance and use long-range weapons; retreat from close threats. |

Orders describe **desired behaviour**, not a guarantee. The ship must still avoid obstacles, recover from collisions, respect cooldowns/weapon arcs, and escape a gravity well when its thrust permits.

Every allied ship needs a simple visible order indicator and a clear target/escort link. Example: `Escort → Flagship`, `Artillery → Enemy Cruiser`.

## Arena and environmental tactics

- **Asteroids / rocks:** destructible or persistent cover, physical collision hazards, and lines-of-sight blockers. Their positions create flanking routes.
- **Gravity wells:** local fields that influence ships, missiles and bullets. Projectiles may bend much more strongly than capital ships, as in the classic prototype.
- **Open space:** no mandatory central wall or maze. A large arena and a restrained camera make fleets and long-range exchanges legible.
- **Readable damage:** hull, shields, engine trails, muzzle flashes, hits and destroyed modules should be easy to distinguish at a glance.

Do not assume every object bounces as in the original arcade mode; warships and asteroids should have a different, heavier collision response.

## Fleet progression

Start with one controllable warship. Between encounters, acquire additional hulls and upgrade equipment. The pilot stays with one selected flagship while other owned ships fight under preconfigured AI orders. Losing a fleet ship should matter without instantly terminating the run; flagship loss and persistent ship loss are **open design decisions**.

Possible shared attributes carried over from the other game experiment:
- **Power:** weapon output, reactor capacity and drone/fighter effectiveness.
- **Structure:** hull, armour, survivability and repair effectiveness.
- **Heat:** firing endurance, cooling and system efficiency.

These are candidates, not locked decisions. Distinct builds might include a single-gun glass cannon, an armoured broadside fortress, and a carrier/support flotilla.

## First playable vertical slice

**Goal:** Prove that directional capital-ship combat and autonomous escorts are fun **before** implementing campaign progression.

- One manually piloted medium warship with 4 directional hardpoints (bow, port, starboard, aft) and visibly different firing arcs.
- Two enemy warships with basic range control and arc-aware attack behaviour.
- One friendly escort, initially ordered to **Escort flagship**, with an alternative **Attack** order selected on a simple pre-battle panel.
- One launchable fighter wing with a clear cooldown and attack target.
- A spacious arena, several asteroids, and one gravity anomaly.
- HP/shields, simple destruction and a win/lose/restart state.
- Minimal HUD showing selected weapon bank, shield/hull health, launch readiness, allied order and targets.
- Distinct ship silhouettes and sensible hit/audio feedback.

**Not yet:** fleet economy, procedurally generated missions, large-scale fleet battles, complex equipment rarity, module-by-module damage, sophisticated formations or multiplayer.

## Design questions to test

1. Is the most enjoyable skill **steering a battleship into its firing arc** or **choosing tactical targets**? Preserve whichever feels stronger.
2. How many weapon banks can the player comfortably manage without losing awareness of manoeuvring?
3. How autonomous can escort/support AI be before players feel they have lost meaningful command?
4. Is fleet size best limited to 3–5 major hulls, with fighters as sub-units, to preserve readability?
5. Are upgrades earned **per battle**, **per campaign run**, or through persistent roster growth?

## Guiding principle

**The player fights a warship battle, not a spreadsheet battle.** Pre-battle planning should materially change each encounter, but the main interaction remains direct action: turning, thrusting, firing and launching wings.
