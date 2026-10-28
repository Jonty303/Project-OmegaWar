# Omega War — Fleet Command: First Contact (Heavy Weapons Pass)

**Godot 4.5.2** · Branch: `codex/omega-war-fleet-combat`

A separate capital-ship combat prototype in a **6,000 × 4,200** world. Open `project.godot` and press **F5**. The classic baseline branch remains untouched.

This pass focuses on the flagship's weapon roles, motion readability and destructive consequences. The two moving enemies remain: a slow broadside cruiser and a nimble forward-gun frigate. Asteroids and the gravity well remain on the map, with a cached static scenery layer and FPS overlay.

## Xbox-style controller

| Input | Effect |
| --- | --- |
| Left stick up | Forward thrust |
| Left stick down | **Reverse thrust** (not friction/brake); can move backwards from rest |
| Left stick left / right | Slow, inertial hull rotation |
| **X** (left face) | Toggle persistent automatic **port** battery order |
| **B** (right face) | Toggle persistent automatic **starboard** battery order |
| **Y** (top face) | **Press once** to start a 5-second spinal-beam charge; press again to **cancel** |
| **A** (bottom face) | Launch a four-missile **cold-launch** aft salvo |
| D-pad | Not assigned yet; reserved for directional shield controls |

Keyboard: **W/S** forward/reverse, **A/D** turn, **Q/E** toggle port/starboard fire orders, **Space** press once to arm beam / press again to cancel, **F** launch missiles, **C** cease fire on both gun batteries, **V** show firing/targeting arcs, **-/=** zoom, **R** restart.

## Main batteries

Port and starboard guns auto-acquire enemies within their 120° firing arcs and 800-unit range, respecting asteroid obstruction. They retain an existing lock within a slightly wider 150° targeting arc. Pressing the corresponding button toggles sustained fire; without a valid target they shoot straight outwards, consuming ammunition. Batteries have per-side ammo, cooldown and gradual ammunition replenishment. Press **V** for the debug overlay showing firing/vision arcs, enemy arcs and target locks.

## Spinal beam — shield interception versus hull penetration

- **Tap Y / Space** to arm a **5-second automatic countdown**. The ship progressively surrenders propulsion power during the charge. The beam fires itself when the countdown reaches zero: there is **no hold/release requirement**.
- **Tap again before firing** to abort. Cancellation dumps the charge and imposes a short recovery cooldown.
- Beam grows out from the ship's bow in a slightly wandering line. Rocks absorb it; the arena boundary can reflect it.
- If it meets an **active enemy shield**, the shield takes very heavy damage and **absorbs the entire discharge**. Even if this shot depletes the shield, it does not punch through in that same shot; the flare marks the shield's position.
- If the target's **shield is already depleted**, the beam inflicts **massive hull damage**, visually cuts through the ship's silhouette with a bright entry-to-exit wound, and **continues beyond** to potentially damage another ship.
- Penetrated vessels vent glowing debris and a small smoke/atmosphere trail from the breach. Damage to each hull is applied only once per discharge, never once per rendering frame.

## Macross-style aft missile system

- **A / F** ejects **four independent small missiles from the stern**. They initially drift with the flagship's inertia and spread away from the hull without engines.
- After **one second**, rocket motors ignite, leaving blue curved trails. Each missile independently finds the nearest living hostile, predicts its movement and uses bounded-turn steering to home toward it.
- A short-range avoidance controller bends guidance around **asteroids** and the friendly flagship. Ally clearance is deliberately structured for later friendly AI vessels, but **there are no allied ships yet**.
- **Direct hits** do high damage. If a missile narrowly overshoots a target, the **proximity air-burst** produces a smaller area-damage explosion instead. Expiring or rock-struck missiles also burst, damaging enemies only if they are near the explosion.
- Launches have a cooldown. The implementation supports a configurable salvo count (up to 96 in this prototype) so larger upgraded salvos won't need a different projectile type. Large swarms still require performance testing.

## Movement, collisions, visual health

- **Reverse thrust** is directional propulsion rather than a brake. Reverse acceleration and maximum reverse velocity are lower than forward values.
- Player and enemy ships leave restrained **ion trails** aligned with *actual velocity*, not nose direction; faster motion leaves a stronger/longer trail.
- Both friendly and hostile ships suffer **kinetic asteroid impact damage directly to hull** at sufficient approach speeds. Shields do not protect against asteroid collisions; low-speed grazing causes little or no harm.
- The bars above enemy ships are ordered **shields on top, hull underneath**. The main HUD still displays **hull on the far left, followed by shields**.
- Both hostiles retain hull HP and rechargeable shields. Impacts, shield flashes, debris, and victory/defeat states remain.

## Playtest checklist

1. With the ship stationary, pull the left stick down: the vessel should accelerate **stern first**, leaving a trail in the correct direction.
2. Tap **Y** once: observe the five-second countdown and propulsion loss, then automatic discharge. Start another charge and press **Y** again to verify cancellation and cooldown.
3. Hit enemy shields with the beam: it should **terminate with a bright shield flare**, not pass through. After shield collapse, charge again to see hull damage, penetration, glowing breach and debris.
4. Tap **A**: watch the missiles drift for one second, then ignite and arc toward moving enemies. Near-misses should detonate with weaker splash damage.
5. Strike an asteroid fast enough to damage the **hull**, while **shield HP remains unchanged**. Repeat with an enemy if practical.
6. Confirm shield bar position above hull; test automatic broadside firing, enemy manoeuvres and FPS with the missile salvo active.

## Deferred

Allied captains, personalities, voice acknowledgements, radial command menus, directional shield redistribution, mines/turrets, persistent upgrades, fires and module damage. This is still an isolated **single-flagship test**, not a fleet campaign.

**Validation:** Source changes are committed and cross-checked. The authoring environment does not have a Godot 4.5.2 executable, so engine parsing, gameplay feel and performance must be verified by running the project in Godot.
