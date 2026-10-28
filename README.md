# Omega War: Fleet Command — First Contact

**Branch:** `codex/omega-war-fleet-combat`  
**Engine:** Godot 4.5.2  
**Scope:** First playable, single-flagship combat experiment (not the fleet campaign yet).

The original `codex/omega-war-classic-baseline` is unchanged. This branch boots the separate `scenes/fleet_test.tscn` gunnery/combat scene when you press **F5** from `project.godot`.

## First Contact: what to test

Pilot a deliberately heavy flagship through a **6,000 × 4,200** world against two moving enemies:

- A **heavy cruiser** with port/starboard batteries. It accelerates and turns slowly, closes the distance when too far away, attempts to establish a broadside at engagement range, and retreats when the player gets too close.
- A **smaller frigate**, faster and more agile, with a forward gun. It attempts to approach and turn onto the flagship.
- Both have hull and **recharging shields**, collisions against asteroid cover, basic gravity-well avoidance, weapon cooldowns and finite firing arcs. They aim using a simple predictive lead rather than perfect hitscan accuracy.

The ship is smaller on screen (0.52× starting camera zoom), with smooth tracking and a strategic radar. The starfield, asteroid drawings, grid and gravity rings are in a **cached scenery layer** for performance.

## Controller layout — left-stick piloting, face-button fire orders

| Xbox-layout face button | Action | Equivalent keyboard |
| --- | --- | --- |
| **Left stick up** | Main thrust | W / Up |
| **Left stick down** | Brake | S / Down |
| **Left stick left/right** | Rotate heavy hull | A/D or Left/Right |
| **X (left face)** | Toggle **port battery** automatic fire order | Q |
| **B (right face)** | Toggle **starboard battery** automatic fire order | E |
| **Y (upper face)** | **Hold to charge** bow beam, release to fire | Hold/release Space |
| **A (lower face)** | **Cease fire** on both side batteries | C |
| — | Toggle visible target/firing arc overlays | V |
| — | Change tactical camera zoom | - / = |
| — | Reset the engagement | R |

The **D-pad and triggers are deliberately unassigned** in this test, reserving them for future shield-direction and command-menu controls. Face-button positions are used as the mnemonic: left = port, right = starboard, top = bow, bottom = cease.

## Automatic batteries

- Tap **Q / X** or **E / B** to order the corresponding battery to **open fire**. Tap again to order **cease fire**. Both side batteries can be active simultaneously.
- Each battery independently **acquires an enemy within its 120° firing arc**, no farther than **800 units**, with an unobstructed line of sight past asteroids.
- Acquired targets persist within a slightly wider **150° tracking arc**, but guns only shoot a tracked ship when it's actually within the narrower firing arc.
- If there is no valid target, the battery still fires outward along the default perpendicular side direction. This uses ammunition, so remember to cease fire.
- Each battery fires a two-shell volley every **0.56 seconds**, with a finite magazine (18 shells) replenishing gradually (1.7 shells/second). They keep attempting to fire automatically as long as the order is active.
- **V** overlays the firing arcs, tracking arcs and enemy weapon arcs; faint lines reveal current battery target locks.
- Projectiles from either side are physically simulated and take strong deflection inside the gravity well; rocks block them.

## Bow spinal weapon

Keep holding **Y / Space** to charge the beam for up to **2.4 seconds**. Propulsion gradually declines, then the ship stops at full charge. Release to fire an extending, slightly serpentine beam. Charge strength determines range and damage. The beam is physically obstructed by asteroids, and may bounce off the distant world boundary. There is a recovery cooldown.

This is still the previous simple **charge-and-release** behaviour, not the future timed captain's firing order, final commitment phase or costly cancellation mechanic.

## Hull, shields and destruction

- Player flagship: **30 hull + 18 shields**.
- Cruiser: **34 hull + 15 shields**.
- Frigate: **18 hull + 7 shields**.
- Shields absorb damage before hull. After a damage-free delay they begin to regenerate. Shield arcs brighten momentarily under fire.
- Enemy projectiles and impacts are tinted red; player batteries use orange/blue.
- Explosions spawn short-lived debris, and victory is achieved by destroying both enemy ships. Losing the flagship ends the test.
- Press **R** to restart immediately.

## Performance and diagnostics

- The 6,000 × 4,200 arena stays intact.
- Static background geometry is drawn by `scripts/fleet_environment.gd` in a separate cached `CanvasItem`. Only dynamic objects need repeated draw commands.
- The overlay shows **FPS**. Compare stationary, normal piloting, two sides firing, the beam discharging and viewing range arcs with V.
- If the framerate is still poor, use the Godot Profiler to distinguish script time from renderer time before attempting further reductions in scale.

## Deferred intentionally

Allied corvettes, captain personalities, bridge voice acknowledgements, two-level command radial menu, directional shield transfer, mines, fixed turrets, complex weapon effects (fires / penetration / subsystem disruption), campaign progression and ship upgrades.

These are follow-on experiments once directional ship combat and auto-targeting are satisfying. See [the larger design concept](docs/fleet-command-concept.md).

**Test status:** Committed to GitHub. No Godot runtime was available in the authoring environment to execute an engine smoke test, so run the branch in Godot 4.5.2 to confirm parsing and FPS.
