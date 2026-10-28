# Omega War: Fleet Command — first playable test

This exploratory branch tests **one heavy warship** and its weapons, before introducing fleet AI or campaign progression. It was branched from `codex/omega-war-classic-baseline`; the classic game remains on that branch and its scene/scripts have not been overwritten.

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
| R | — | Reset test |

## Test behaviour

- **Heavy flight dynamics:** acceleration is 54 world-units/s², maximum speed is 112 units/s; maximum turn rate is **0.55 radians/s** (about 31.5°/s) with a limited angular acceleration of 0.43 radians/s². There is no ordinary passive translational drag; you must brake or change direction to remove drift. The thin blue rectangular perimeter is a safety limit for this test, not a maze.
- **Bow spinal beam:** hold the trigger to accumulate charge for up to **2.4 seconds**. Power diverted to the weapon progressively reduces thrust and slows the ship; full charge brings it to a stop. **Release to fire** a snake-like, visibly extending beam. Charge determines beam reach and damage. It can rebound from the test arena boundary up to twice. A brief cooldown follows.
- **Two independent broadsides:** Q and E each fire a pair of solid projectiles from their respective side's hardpoints, with independent **0.56-second** reload intervals. They fire sideways relative to the hull, not toward the cursor. There are **no rear weapons**.
- **Practice hulks:** one ahead and one on each beam/broadside line, each displaying remaining armour. They reset automatically shortly after destruction. This is a gunnery range, not a full encounter.
- **Presentation:** vector-style warship, glowing charging emitter, beam and shell trails, hit markers and very quiet procedural sounds borrowed from the classic project.

## Deliberately not in this first test

Enemy AI, fighters, fleet orders, ship acquisition, health/damage to the player, asteroids, gravity wells, upgrades and battle progression. Those depend on how the **weight and weapon feel** test goes.

For the wider experiment and later feature proposals, read [the Fleet Command concept](docs/fleet-command-concept.md).

## Suggested quick test

1. From spawn, hold **Q**: the ship's port cannons should repeatedly strike the northern target.
2. Hold **E**: the starboard cannons should strike the southern target independently.
3. Hold **Space** until full. Watch speed drop to zero; release to grow the bow beam into the eastern target.
4. Thrust, release thrust, then turn. Notice retained lateral drift and how slowly the hull swings round.
5. Hold thrust while charging the beam: propulsion should fade as beam power builds. Tap **R** to repeat.

**Validation note:** This scene has been committed to GitHub, but Godot is not available in this authoring environment to execute a headless runtime test. Verify locally with F5 before treating it as a confirmed runnable build.
