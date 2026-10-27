# Project-OmegaWar

An original vector-style arena shooter inspired by the momentum combat of Omega Race.
Initial playable vertical slice for **Godot 4.5.2**, with no external assets or plugins.

## Play

1. Check out this feature branch (or download its ZIP and extract it).
2. In Godot 4.5.2, Import the root `project.godot`.
3. Press **F6** with the main scene open, or **F5** to run the project.
4. Clear waves, collect the lettered pickups, and survive. Enter starts a fresh run.

| Control | Action |
| --- | --- |
| W / Up | Thrust; releasing retains momentum |
| A/D or Left/Right | Turn |
| S / Down | Brake |
| Space | Fire |
| Shift + thrust | Afterburner while B pickup is active |
| P / Escape | Pause / resume |
| Enter | Restart |

Cyan is your ship. Orange drones chase and shoot. Magenta gravity enemies pull
your ship within their visible rings; destroy them to remove their fields.
Walls and the central core bounce ships and absorb bullets.
S grants a 12-second shield (hits consume 3 seconds), B grants 15 seconds of
boost availability, and R grants 10 seconds of rapid fire. Timers run from pickup
collection and freeze while paused. Duplicate pickups refresh their timer.
The ship starts with three hull points and two seconds of spawn protection.
Enemy projectiles and contact deal damage; walls do not. Waves are endless,
with population capped at fourteen. There is no victory screen.

## Validation

Run these commands with your Godot 4.5.2 executable (replace `godot` with its path):

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script tests/smoke.gd
godot --headless --path . --quit-after 600
```

The integration smoke test checks momentum, brakes, bounds/core collision,
all three pickups, shields, invulnerability, gravity range/direction, swept bullet
hits, scoring, wave advancement, pause, death, restart, and projectile cleanup.

Manual playtest checklist:
- Fly around every side of the core; test diagonal corners and boosted wall impacts.
- Release thrust, turn while drifting, brake, and compare boosted acceleration.
- Collect S/B/R on the upper-left route; observe timers, shield damage, and fire cadence.
- Approach a magenta enemy and feel its pull; destroy it and confirm the pull stops.
- Fire through the core: shots should stop. Destroy all enemies to advance.
- Take three unshielded hits separated by the damage cooldown; restart from game over.
- Pause during combat, wait, resume; resize the window and check HUD legibility.

Headless tests do not establish visual quality, keyboard feel, or game balance.
This prototype has no audio, controller bindings, save system, or settings menu.

## Structure and next steps

See [the design roadmap](docs/ROADMAP.md). Drawing uses Godot `_draw()` primitives;
there are no imported sprites. Actor logic and weapon cadence are separate from
the world coordinator, which owns collisions, scoring, spawning, and wave state.
