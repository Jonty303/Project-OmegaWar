# Omega War — Fleet Command: Scanner & Asteroid Field Pass

**Godot 4.5.2** · Branch: `codex/omega-war-fleet-combat`

A separate capital-ship combat prototype in a **6,000 × 4,200** world. Open `project.godot` and press **F5**. The classic baseline branch remains untouched.

This iteration adds a **testable sensor progression** and **destructible, mobile asteroids**. Previous heavy-weapon and flight changes remain, including a straight spinal beam, homing missile swarms, automatically firing broadsides, persistent shield collapse and reverse thrust. The two moving hostiles remain: a slow broadside cruiser and a nimble forward-gun frigate. The world remains 6,000 × 4,200 units with an FPS overlay. **The test flagship now starts at (1250, 950)**, clear of nearby rocks and approximately 2,290 units from the cruiser / 1,875 units from the frigate, rather than starting in immediate combat range.

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
| **R3** (right stick click) | Cycle scanner upgrade test tiers (also **T** on keyboard) |
| D-pad | Not assigned yet; reserved for directional shield controls |

Keyboard: **W/S** forward/reverse, **A/D** turn, **Q/E** toggle port/starboard fire orders, **Space** press once to arm beam / press again to cancel, **F** launch missiles, **C** cease fire on both gun batteries, **V** show firing/targeting arcs and asteroid integrity, **T** cycle scanner test tiers, **-/=** zoom, **R** restart. The face buttons and D-pad remain unchanged.

## Main batteries

Port and starboard guns auto-acquire enemies within their 120° firing arcs and 800-unit range, respecting asteroid obstruction. They retain an existing lock within a slightly wider 150° targeting arc. Pressing the corresponding button toggles sustained fire; without a valid target they shoot straight outwards, consuming ammunition. Batteries have per-side ammo, cooldown and gradual ammunition replenishment. Active batteries now **prioritize an incoming hostile missile** within their firing arc and switch to point defence. A shell must physically intersect the missile's flight path to destroy it; the missile then explodes with a visible blast, debris and its regular proximity splash. The frigate periodically launches a small hostile salvo so this can be tested. Press **V** for the debug overlay showing firing/vision arcs, enemy arcs and target locks.

## Scanner upgrades — off-screen contacts and incoming threats

**Press T** to cycle four test modes. This is a temporary upgrade simulator, not a persistent progression/equipment screen. A ship's sensor range affects what appears on the radar as well as edge markers.

| Scanner test tier | Detection range | New information |
| --- | ---: | --- |
| **Basic** | 1,100 units | Nearby enemy contacts on local radar, no off-screen arrows |
| **Improved** | 1,900 units | Blue off-screen arrows for detected enemy contacts |
| **Long Range** | 3,250 units | More distant enemy arrows with class and distance |
| **Tactical** | 4,700 units | All previous features, plus **grouped red incoming missile warnings** and amber approaching gunfire warnings |

The arrows sit on the playable viewport edge, pointing towards each detected off-screen target. Multiple missiles approaching from the same bearing are condensed into **MISSILES ×N** rather than spawning one arrow per missile; friendly ordnance is not flagged as incoming.

**Deliberately deferred:** jamming, spoofed/uncertain detections, nebula sensor occlusion, counter-jamming and actual equipment upgrades. This pass separates sensor presentation from acquisition range so those mechanics can be added later without rewriting the UI.

## Destructible asteroid fields

Asteroids are no longer baked into the cached background: the starfield, grid and gravity well remain cached, while only moving/damaged rocks are redrawn each frame.

| Asteroid stage | Integrity | Breakup |
| --- | ---: | --- |
| **Large** (radius at least 68) | 13 HP | Splits into **3 medium** drifting asteroids |
| **Medium** | 7 HP | Splits into **4 small** drifting asteroids |
| **Small** | 3 HP | Bursts into **7 fast, short-lived kinetic fragments** |
| **Kinetic fragments** | Short lifetime | Cannot split again; physically hit ship hulls, **ignoring shields** |

- **Cannon shells** remove HP gradually (normally 1.45 per hit); repeated hits produce chips before the rock finally breaks.
- **Missile explosions** apply heavy rock damage (up to 11, with falloff), meaning weakened large rocks or intact medium/small rocks may break. Nearby rocks can be damaged by the same blast. Intercepted missiles still detonate, so point defence may inadvertently fracture nearby cover.
- **Spinal beams** instantly destroy any pre-existing asteroid they physically cross and **continue straight through**, potentially breaking several before striking a ship. Fresh fragments created by this discharge are excluded from its remaining collision checks, preventing recursive breakup loops.
- Drift, ejection impulses, modest gravity effects, moving fragment collisions with ships, rock-damage flashes and breakup debris make cover hazardous after destruction.
- Active simulation is bounded to **110 rocks** and **144 kinetic fragments**; the latter have short lifetimes rather than full rock simulation.
- **V** overlays asteroid health indicators for testing, alongside the existing firing arcs.

A direct collision with a sufficiently fast asteroid, or impact from a final fragment, damages **hull only**. Shields do not intercept kinetic rock impact.

## Spinal beam — shield interception versus hull penetration

- **Tap Y / Space** to arm a **5-second automatic countdown**. The ship progressively surrenders propulsion power during the charge. The beam fires itself when the countdown reaches zero: there is **no hold/release requirement**.
- **Tap again before firing** to abort. Cancellation dumps the charge and imposes a short recovery cooldown.
- The spinal beam is **straight and true**, with no waviness or wandering. At a world boundary, it can reflect into another straight segment. Asteroids fracture instantly as the beam passes through; shield surfaces stop it precisely at the interception point.
- **Steering/propulsion are locked during the brief beam discharge**, keeping the firing path aligned to the flagship's bow as it finishes expanding. Normal controls resume after the beam effect ends. This also prevents the ship visibly rotating across its own fixed beam.
- If it meets an **active enemy shield**, the shield takes very heavy damage and **absorbs the entire discharge**. Even if this shot depletes the shield, it does not punch through in that same shot; the flare marks the shield's position.
- If the target's **shield is already depleted**, the beam inflicts **massive hull damage**, visually cuts through the ship's silhouette with a bright entry-to-exit wound, and **continues beyond** to potentially damage another ship.
- Penetrated vessels vent glowing debris and a small smoke/atmosphere trail from the breach. Damage to each hull is applied only once per discharge, never once per rendering frame.

## Macross-style aft missile system

- **A / F** ejects **four independent small missiles from the stern**. They initially drift with the flagship's inertia and spread away from the hull without engines.
- After **one second**, rocket motors ignite, leaving blue curved trails. Each missile independently finds the nearest living hostile, predicts its movement and uses bounded-turn steering to home toward it.
- A short-range avoidance controller bends guidance around **asteroids** and the friendly flagship. Ally clearance is deliberately structured for later friendly AI vessels, but **there are no allied ships yet**.
- **Direct hits** do high damage. If a missile narrowly overshoots a target, the **proximity air-burst** produces a smaller area-damage explosion instead. Expiring or rock-struck missiles also burst, damaging enemies only if they are near the explosion.
- Both friendly and hostile missiles now use the same cold-launch, steering and detonation logic. **Direct gunfire can shoot missiles down**: only opposing-faction projectiles intercept, triggering a visible explosion with splash damage. The enemy frigate cold-launches **two missiles roughly every 11.5 seconds** for point-defence testing.
- Launches have a cooldown. The implementation supports a configurable salvo count (up to 96 in this prototype) so larger upgraded salvos won't need a different projectile type. Large swarms still require performance testing.

## Movement, collisions, visual health

- **Reverse thrust** is directional propulsion rather than a brake. Reverse acceleration is now **40 units/s²** (forward: 54), with maximum reverse speed **78 units/s** (forward: 112). Two conspicuous, pulsing **blue bow jets** show reverse thrust, plus a HUD reverse-thrust indicator.
- Player and enemy ships leave **longer, thicker, brighter blue-white ion trails** aligned with *actual velocity*, not nose direction; faster motion leaves a more pronounced wake. Trail particles persist for about **0.46–1.24 seconds** depending on speed.
- Both friendly and hostile ships suffer **kinetic asteroid impact damage directly to hull** at sufficient approach speeds. Shields do not protect against asteroid collisions; low-speed grazing causes little or no harm.
- **Every hull-damaging hit throws off physical debris**, whether the source is a bullet, missile or future bomb. Shield-only hits remain clean. Fragments inherit some ship velocity and spray away from the entry point. The same generic ship-damage path supports later weapon types.
- For the beam-turning death investigation, a temporary **HIT** label records the latest player damage source and amount. If the flagship is destroyed, **FINAL HIT** identifies the recorded cause: hostile shell, hostile missile, missile blast, asteroid collision, asteroid fragment or a **beam-shattered asteroid fragment**. The beam itself never directly damages the flagship; its rock fragments can still legitimately strike the hull.
- The bars above enemy ships are ordered **shields on top, hull underneath**. The main HUD still displays **hull on the far left, followed by shields**.
- Both hostiles retain hull HP and shields. **A shield reduced to zero goes permanently offline for the remainder of the battle**, for both enemies and player. Partial shields only regenerate very slowly (**0.35 shield HP/second**, after **6 seconds** without further damage). The HUD labels depleted shields **OFFLINE**; there is no shield-restart ability in this pass. Future skills, properties or upgrades may provide an explicit restart/recharge mechanism. Impacts, shield flashes, debris, and victory/defeat states remain.

## Playtest checklist

1. With the ship stationary, pull the left stick down: the vessel should accelerate **stern first**, show **bright blue bow thrusters**, and leave a longer trail in the correct direction. Compare reverse with stronger forward propulsion.
2. Tap **Y** once: observe the five-second countdown and propulsion loss, then automatic discharge. Try rotating the stick during the actual beam expansion: the flagship should maintain its firing heading until the discharge finishes, then accept turning again. Start another charge and press **Y** again to verify cancellation and cooldown.
3. Hit enemy shields with the beam: it should **terminate with a bright shield flare**, not pass through. When shields collapse, they should **stay OFFLINE** for the whole encounter even after waiting; the next beam should penetrate the exposed hull, leaving a glowing breach and debris.
4. Tap **A**: watch the missiles drift for one second, then ignite and arc toward moving enemies. Near-misses should detonate with weaker splash damage.
5. Toggle **V** and wear down a large asteroid with cannon fire; it should show damage, fracture into **three medium** rocks, then smaller pieces when struck again. Verify final fragments can strike ships and bypass shields.
6. Launch a missile into a rock cluster and watch the heavy blast damage multiple rocks. A weakened large rock should break; a small one should shatter.
7. Fire the **straight spinal beam** through an asteroid: it should immediately fracture the rock, keep travelling, and potentially strike something behind it. The rock should never simply absorb the beam.
8. Press **T** to compare scanner modes. Verify off-screen enemy arrows, then Tactical's grouped missile warnings and incoming cannon warnings. Nearby radar contacts should reflect scanner range.
9. Wait for the hostile frigate to launch its **two-missile salvo**. Activate a broadside, orient the enemy missiles into its arc and watch the point-defence guns track and **explode** incoming missiles. Verify the splash can affect nearby targets, and that bullets don't destroy friendly missiles.
10. Confirm any bullet, missile or beam strike that damages hull produces **visible flying fragments**. Shield-only hits should not shed hull plating.
11. Confirm shield bar position above hull; test automatic broadside firing, enemy manoeuvres and FPS with the missile salvo active.
12. Check the new distant flagship start and verify that pressing **R** restores this same position. If unexpected damage or death occurs during a beam, note the **HIT / FINAL HIT** label: `BEAM-SHATTERED ROCK` identifies secondary shrapnel, while hostile fire and actual asteroid collisions are reported separately.

## Deferred

Allied captains, personalities, voice acknowledgements, radial command menus, directional shield redistribution, **jamming and nebula interference**, mines/turrets, persistent upgrades, fires and module damage. This is still an isolated **single-flagship test**, not a fleet campaign.

**Validation:** Source changes are committed and cross-checked. The authoring environment does not have a Godot 4.5.2 executable, so engine parsing, gameplay feel and performance must be verified by running the project in Godot.
