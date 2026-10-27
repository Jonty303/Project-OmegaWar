# OmegaWar — classic baseline

A **Godot 4.5.2** vector-style arcade shooter inspired by the momentum combat
of Omega Race. This branch intentionally removes all power-ups, boosts, shields,
rapid-fire modifiers and gravity wells to focus on movement and combat feel.

## Getting started

Open `project.godot` in Godot 4.5.2 and press **F5**. The ship starts with
three hull points and two seconds of spawn protection. A first wave appears
after one second; subsequent waves appear **five seconds after the last enemy
dies**, with three to five ordinary drones chosen each time.

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

The only enemy is a small orange drone. Its steering follows a short path
around the core when the direct line to the ship is obstructed, and it fires
at a slightly predicted position. Shots from either side **ricochet off arena
walls and the core** at full speed; they expire after four bounces or 3.2
seconds, whichever comes first. Friendly shots hit drones and hostile shots
hit the player. High-speed ship/drone collisions separate both bodies, transfer
momentum using an impulse, and can cause damage. The ship and enemy
silhouettes never deform or blink after hits. Instead, small bursts of debris
scatter and fade. Three hull points lost ends the run.

**Sectioned walls:** five individually flashing sections span each horizontal
arena wall, and three span each vertical arena wall. The central core is also
split into separate sections. When a ship or shot bounces, the particular
section hit briefly flashes white, like the original Omega Race.

**Directional bullets:** projectile artwork always follows its actual
velocity, including immediately after ricochets. Bullets can travel up to
1,150 world units, bounce up to four times, and live for at most 3.2 seconds.
When they reach a limit, they stop and disintegrate into short-lived,
fading fragments for 0.34 seconds rather than suddenly disappearing.

## Test

From the project root:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script tests/smoke.gd
godot --headless --path . --quit-after 600
```

The smoke test covers conserved momentum, slow thrust, braking, core impacts,
AI navigation around the central obstruction, body impulse and debris particles, segmented wall flashes, bullet heading,
shot hits, range expiry with disintegration, and rebounds, controller mappings, pause, and five-second waves.

Manual playtest:
- Thrust, release and coast; ensure no unexplained drift reduction.
- Slow down by thrusting backwards or using brake, and bounce off a wall.
- Watch a drone chase you around the middle of the arena, not into the core.
- Shoot both outer walls and the core; check ricochets, bullet heading,
  and that only the struck wall section flashes.
- Let a bullet expire at the end of its range and watch its fading fragments.
- Ram a drone at speed: bodies bounce, a tiny debris cloud appears, and
  neither hull changes shape or blinks.
- Clear a wave, pause during the countdown, then watch 3–5 drones return.

All visuals are procedural line art; no external sprites or plugins are needed.
There is no audio, settings or save system yet. `docs/ROADMAP.md` retains the
longer-term weapon and arena ideas for later, once this baseline feels right.
