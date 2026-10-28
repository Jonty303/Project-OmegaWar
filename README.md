# Omega War: Fleet Command — first playable test

This exploratory branch tests **one heavy player-controlled warship** in a large, scrolling battlefield before introducing fleet AI or campaign progression. Three capital-sized cruiser silhouettes serve as stationary gunnery targets. It was branched from `codex/omega-war-classic-baseline`; the classic game remains on that branch and its scene/scripts have not been overwritten.

## Start

Open `project.godot` using **Godot 4.5.2** and press **F5**. The project now opens `scenes/fleet_test.tscn` by default. The earlier classic level remains available as `scenes/main.tscn`.

## Controls

| Keyboard | Joypad | Action |
| --- | --- | --- |
| W / Up | Left stick up / A | Main thrusters |
| S / Down | Left stick down / B | Brakes |
| A / D or Left / Right | Left stick X / D-pad | Slow, momentum-based rotation |
| Q | X | Fire **port** battery (two projectile cannons) |
| E | Y | Fire **starboard** battery (two projectile cannons) |
| **Hold and release Space** | Hold and release RT | Charge and fire **bow beam** |
| - / = | — | Zoom out / in for different fleet-scale framing |
| R | — | Reset test |

## Test behaviour

- **Epic-scale open theatre:** the world is **6,000 × 4,200 units** (roughly 5.5 times the previous test width and 7.2 times its height). A smooth tracking camera starts at **0.52× zoom**, making the capital ship about 60 pixels long on screen while keeping three other capital-sized target hulls visible. **- / =** changes zoom from 0.38× to 0.78×. A tactical radar shows the world beyond the camera.
- **Heavy flight dynamics:** acceleration is 54 world-units/s², maximum speed is 112 units/s; maximum turn rate is **0.55 radians/s** (about 31.5°/s) with a limited angular acceleration of 0.43 radians/s². There is no ordinary passive translational drag; you must brake or change direction to remove drift. A distant boundary prevents leaving the test theatre; it should not normally intrude into view.
- **Bow spinal beam:** hold the trigger to accumulate charge for up to **2.4 seconds**. Power diverted to the weapon progressively reduces thrust and slows the ship; full charge brings it to a stop. **Release to fire** a snake-like, visibly extending beam. Charge determines beam reach and damage. It can rebound from the test arena boundary up to twice. A brief cooldown follows.
- **Two independent broadsides:** Q and E each fire a pair of solid projectiles from their respective side's hardpoints, with independent **0.56-second** reload intervals. They fire sideways relative to the hull, not toward the cursor. There are **no rear weapons**.
- **Capital ship targets:** one ahead and one on each beam/broadside line; they have warship silhouettes, armour bars, and respawn after destruction. They are **stationary, unarmed targets**, not implemented enemy AI.
- **Environmental space:** sparse, physically blocking asteroid clusters and one distant gravity well (pulling the ship and deflecting shells) give the theatre landmarks and room for later turrets, mines and fleet encounters. The beam is absorbed by asteroids but can rebound from the arena perimeter.
- **Presentation:** vector-style warship, glowing charging emitter, beam and shell trails, hit markers and very quiet procedural sounds borrowed from the classic project.
- **Performance pass (October 28):** static grid, starfield, asteroid silhouettes and gravity rings are now rendered by `scripts/fleet_environment.gd` in a separate **cached CanvasItem**; the main ship scene only redraws moving objects. The static scenery's camera transform changes without rebuilding the draw commands. Star count is reduced from 1,800 to 850. The top-right HUD shows current **FPS** to compare performance on your machine. Battlefield size and ship zoom are unchanged.

## Deliberately not in this first test

Enemy AI, fighters, fleet orders, ship acquisition, health/damage to the player, turrets, mines, upgrades and battle progression. Those depend on how the **weight and weapon feel** test goes.

For the wider experiment and later feature proposals, read [the Fleet Command concept](docs/fleet-command-concept.md).

## Suggested quick test

1. From spawn, observe **four capital-scale ships** in a large view: the flagship and three stationary target cruisers.
2. Hold **Q** to fire north; hold **E** to fire south. Their projectile batteries have independent cooldowns.
3. Hold **Space** until full. Watch speed drop to zero; release to grow the bow beam toward the eastern cruiser.
4. Thrust away from the centre and turn: the smooth camera tracks the player while the minimap shows where you are in the much larger arena.
5. Fly toward one of the distant asteroid clusters or the gravity anomaly. Try **- / =** to compare framing.
6. Hold thrust while charging the beam: propulsion should fade as charge builds. Tap **R** to repeat.

**Validation note:** The changes are committed to GitHub, but Godot is not available in this authoring environment to run a headless benchmark. Please test with F5 and check the FPS counter at the top right. In particular, compare idle FPS with constant movement/turning and continuous broadside fire. If performance remains poor, the next step should be a captured Godot Profiler frame rather than further speculative visual changes.
