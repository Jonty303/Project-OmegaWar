# OmegaWar — classic baseline

A **Godot 4.5.2** vector-style arcade shooter inspired by the momentum combat
of Omega Race. This branch intentionally removes all power-ups, boosts, shields,
rapid-fire modifiers and gravity wells to focus on movement and combat feel.

## Getting started

Open \`project.godot\` in Godot 4.5.2 and press **F5**. The ship starts with
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
momentum using an impulse, briefly distort their outlines ("crunch"), and
can cause damage. Three hull points lost ends the run.

## Test

From the project root:

\`\`\`sh
godot --headless --path . --editor --quit
godot --headless --path . --script tests/smoke.gd
godot --headless --path . --quit-after 600
\`\`\`

The smoke test covers conserved momentum, slow thrust, braking, core impacts,
AI navigation around the central obstruction, body impulse and deformation,
shot hits and rebounds, controller mappings, pause, and five-second waves.

Manual playtest:
- Thrust, release and coast; ensure no unexplained drift reduction.
- Slow down by thrusting backwards or using brake, and bounce off a wall.
- Watch a drone chase you around the middle of the arena, not into the core.
- Shoot both outer walls and the core; check ricochets.
- Ram a drone at speed and watch both bodies bounce and distort.
- Clear a wave, pause during the countdown, then watch 3–5 drones return.

All visuals are procedural line art; no external sprites or plugins are needed.
There is no audio, settings or save system yet. \`docs/ROADMAP.md\` retains the
longer-term weapon and arena ideas for later, once this baseline feels right.
