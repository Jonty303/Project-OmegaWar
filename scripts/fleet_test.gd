extends Node2D
## Isolated Fleet Command handling / gunnery range.
## The classic Omega War scripts and scene remain unchanged on this branch.

const SoundBus = preload("res://scripts/sound_bus.gd")
const FleetScenery = preload("res://scripts/fleet_environment.gd")
# Broad, scrolling theatre: 5x the original width, >7x its height.
const FIELD := Rect2(0.0, 0.0, 6000.0, 4200.0)
const VIEW_SIZE := Vector2(1200.0, 800.0)
const INITIAL_ZOOM := 0.52
const GRAVITY_CENTER := Vector2(4490.0, 2310.0)
const GRAVITY_RADIUS := 520.0
const THRUST := 54.0
const MAX_SPEED := 112.0
const BRAKE := 110.0
const TURN_SPEED := 0.55
const TURN_ACCEL := 0.43
const CHARGE_SECONDS := 5.0
const REVERSE_THRUST := 40.0
const MAX_REVERSE_SPEED := 78.0
const ASTEROID_SAFE_IMPACT := 20.0
const TRAIL_INTERVAL := 0.052
const SHIELD_REGEN_RATE := 0.35
const SHIELD_REGEN_DELAY := 6.0
const MISSILES_PER_SALVO := 4
const MISSILE_COLD_TIME := 1.0
const MISSILE_RELOAD := 5.5
const MISSILE_MAX_SPEED := 340.0
const MISSILE_ACCEL := 370.0
const MISSILE_TURN_RATE := 3.0
const MISSILE_DIRECT_DAMAGE := 5.0
const MISSILE_BURST_DAMAGE := 1.7
const MISSILE_BURST_RADIUS := 102.0
const MISSILE_INTERCEPT_RADIUS := 12.0
const FRIGATE_MISSILE_INTERVAL := 11.5
const MISSILE_FUEL_LIFE := 7.5
const BROADSIDE_INTERVAL := 0.56
const SHELL_SPEED := 390.0
const BEAM_EXPAND_SPEED := 1450.0
const BEAM_SHIELD_DAMAGE := 26.0
const BEAM_HULL_DAMAGE := 26.0
const BATTERY_RANGE := 800.0
const BATTERY_HALF_ARC := PI / 3.0
const TRACKING_HALF_ARC := 5.0 * PI / 12.0
const BOW_HALF_ARC := PI / 18.0
const SHIP_RADIUS := 45.0
const PLAYER_MAX_HULL := 30.0
const PLAYER_MAX_SHIELDS := 18.0
const AMMO_CAPACITY := 18.0
const AMMO_RECHARGE := 1.7
const CRUISER_WEAPON_RANGE := 760.0
const FRIGATE_WEAPON_RANGE := 610.0

const WHITE := Color(0.80, 0.91, 0.97)
const MUTED := Color(0.43, 0.57, 0.70)
const PORT_COLOR := Color(1.0, 0.69, 0.37)
const STARBOARD_COLOR := Color(0.37, 0.84, 1.0)
const BEAM_COLOR := Color(0.54, 0.93, 1.0)

var ship_pos := Vector2(2500.0, 2100.0)
var camera_pos := Vector2(2500.0, 2100.0)
var camera_offset := Vector2.ZERO
var view_zoom := INITIAL_ZOOM
var ship_angle := PI / 2.0
var velocity := Vector2.ZERO
var angular_velocity := 0.0
var thrusting := false
var braking := false
var charge := 0.0
var beam_recovery := 0.0
var beam_charging := false
var trail_tick := 0.0
var missile_cooldown := 0.0
var missile_boom_audio := 0.0
var missiles: Array[Dictionary] = []
var missile_blasts: Array[Dictionary] = []
var ion_trails: Array[Dictionary] = []
var beam_path: PackedVector2Array = PackedVector2Array()
var beam_visible := 0.0
var beam_total := 0.0
var beam_linger := 0.0
var beam_power := 0.0
var beam_hit_targets: Dictionary = {}
var beam_absorption_point := Vector2.ZERO
var beam_absorption_timer := 0.0
var beam_scars: Array[Dictionary] = []
var smoke: Array[Dictionary] = []
var smoke_tick := 0.0
var port_cooldown := 0.0
var starboard_cooldown := 0.0
var port_flash := 0.0
var starboard_flash := 0.0
var time_passed := 0.0
var port_order := false
var starboard_order := false
var port_target := -1
var starboard_target := -1
var port_ammo := AMMO_CAPACITY
var starboard_ammo := AMMO_CAPACITY
var player_hull := PLAYER_MAX_HULL
var player_shields := PLAYER_MAX_SHIELDS
var player_shield_delay := 0.0
var player_shield_flash := 0.0
var encounter_finished := false
var player_destroyed := false
var show_arcs := false
var sound_message := ""
var sound_message_timer := 0.0
var shots: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
var debris: Array[Dictionary] = []
var targets: Array[Dictionary] = []
var asteroids: Array[Dictionary] = []
var environment := FleetScenery.new()
var sound_bus := SoundBus.new()

func _ready() -> void:
    make_inputs()
    add_child(sound_bus)
    setup_asteroids()
    setup_targets()
    # Static scenery owns its own cached draw list. Ship/weapon redraws will
    # not rebuild the starfield, asteroid polygons, grid or gravity rings.
    environment.show_behind_parent = true
    environment.configure(FIELD, GRAVITY_CENTER, GRAVITY_RADIUS, asteroids)
    add_child(environment)
    update_environment_transform()
    queue_redraw()

func make_inputs() -> void:
    key_action("fc_thrust", KEY_W)
    key_action("fc_thrust", KEY_UP)
    key_action("fc_brake", KEY_S)
    key_action("fc_brake", KEY_DOWN)
    key_action("fc_turn_left", KEY_A)
    key_action("fc_turn_left", KEY_LEFT)
    key_action("fc_turn_right", KEY_D)
    key_action("fc_turn_right", KEY_RIGHT)
    key_action("fc_port", KEY_Q)
    key_action("fc_starboard", KEY_E)
    key_action("fc_beam", KEY_SPACE)
    key_action("fc_reset", KEY_R)
    key_action("fc_cease", KEY_C)
    key_action("fc_missile", KEY_F)
    key_action("fc_arcs", KEY_V)
    key_action("fc_zoom_out", KEY_MINUS)
    key_action("fc_zoom_in", KEY_EQUAL)
    # Left stick is full directional propulsion/turning. Face buttons:
    # X port, B starboard, Y beam arm/cancel, A launch aft missiles.
    pad_button("fc_port", JOY_BUTTON_X)
    pad_button("fc_starboard", JOY_BUTTON_B)
    pad_button("fc_beam", JOY_BUTTON_Y)
    pad_button("fc_missile", JOY_BUTTON_A)
    # D-pad remains free for later shield/command radial menu.
    pad_axis("fc_turn_left", JOY_AXIS_LEFT_X, -1.0)
    pad_axis("fc_turn_right", JOY_AXIS_LEFT_X, 1.0)
    pad_axis("fc_thrust", JOY_AXIS_LEFT_Y, -1.0)
    pad_axis("fc_brake", JOY_AXIS_LEFT_Y, 1.0)
    # No trigger binding: beam is on the upper face button.

func key_action(action: String, code: int) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    var event := InputEventKey.new()
    event.physical_keycode = code
    InputMap.action_add_event(action, event)

func pad_button(action: String, code: int) -> void:
    var event := InputEventJoypadButton.new()
    event.button_index = code
    InputMap.action_add_event(action, event)

func pad_axis(action: String, axis: int, sign: float) -> void:
    var event := InputEventJoypadMotion.new()
    event.axis = axis
    event.axis_value = sign
    InputMap.action_add_event(action, event)

func setup_asteroids() -> void:
    # Sparse tactical landmarks, not a cramped maze.
    asteroids = []
    var locations := [
        Vector3(1640, 1590, 105), Vector3(1810, 1690, 46),
        Vector3(2020, 1150, 67), Vector3(3760, 1620, 90),
        Vector3(3940, 1720, 52), Vector3(3500, 2840, 82),
        Vector3(3630, 2980, 37), Vector3(1320, 2700, 73),
        Vector3(4810, 3230, 108), Vector3(4670, 3120, 54),
        Vector3(2920, 3480, 71), Vector3(5200, 1160, 92),
        Vector3(740, 1300, 120), Vector3(5390, 2880, 74),
        Vector3(2280, 3420, 48), Vector3(3210, 750, 67)
    ]
    for location in locations:
        asteroids.append({"pos": Vector2(location.x, location.y), "radius": location.z})

func setup_targets() -> void:
    # Two mobile enemies: an arc-aware broadside cruiser and a nimble
    # forward-firing frigate. Both obey inertia and their own turn limits.
    targets = [
        {"pos": Vector2(3300, 1970), "angle": -1.4, "velocity": Vector2.ZERO,
            "turn_velocity": 0.0, "hp": 34.0, "max_hp": 34.0,
            "shields": 15.0, "max_shields": 15.0, "shield_delay": 0.0,
            "flash": 0.0, "reload": 1.8, "name": "HOSTILE CRUISER", "kind": "cruiser",
            "speed": 83.0, "turn_rate": 0.50, "accel": 37.0, "reload_time": 1.65,
            "range": CRUISER_WEAPON_RANGE, "damage": 2.1, "radius": 49.0,
            "destroyed": false},
        {"pos": Vector2(2060, 2640), "angle": -0.6, "velocity": Vector2.ZERO,
            "turn_velocity": 0.0, "hp": 18.0, "max_hp": 18.0,
            "shields": 7.0, "max_shields": 7.0, "shield_delay": 0.0,
            "flash": 0.0, "reload": 2.1, "name": "HOSTILE FRIGATE", "kind": "frigate",
            "speed": 142.0, "turn_rate": 1.15, "accel": 66.0, "reload_time": 0.85,
            "range": FRIGATE_WEAPON_RANGE, "damage": 1.0, "radius": 29.0,
            "destroyed": false, "missile_reload": 5.8}
    ]

func reset_test() -> void:
    ship_pos = Vector2(2500.0, 2100.0)
    camera_pos = ship_pos
    view_zoom = INITIAL_ZOOM
    ship_angle = PI / 2.0
    velocity = Vector2.ZERO
    angular_velocity = 0.0
    charge = 0.0
    beam_charging = false
    beam_recovery = 0.0
    beam_path.clear()
    beam_hit_targets.clear()
    beam_absorption_timer = 0.0
    beam_scars.clear()
    smoke.clear()
    smoke_tick = 0.0
    port_cooldown = 0.0
    starboard_cooldown = 0.0
    shots.clear()
    impacts.clear()
    debris.clear()
    missiles.clear()
    missile_blasts.clear()
    missile_cooldown = 0.0
    missile_boom_audio = 0.0
    ion_trails.clear()
    trail_tick = 0.0
    player_shield_flash = 0.0
    setup_targets()
    player_hull = PLAYER_MAX_HULL
    player_shields = PLAYER_MAX_SHIELDS
    player_shield_delay = 0.0
    port_order = false
    starboard_order = false
    port_target = -1
    starboard_target = -1
    port_ammo = AMMO_CAPACITY
    starboard_ammo = AMMO_CAPACITY
    encounter_finished = false
    player_destroyed = false
    sound_message = ""
    sound_message_timer = 0.0

func _physics_process(delta: float) -> void:
    time_passed += delta
    sound_bus.advance(delta)
    if Input.is_action_just_pressed("fc_reset"):
        reset_test()
    if Input.is_action_just_pressed("fc_arcs"):
        show_arcs = not show_arcs
    if Input.is_action_just_pressed("fc_zoom_out"):
        view_zoom = maxf(0.38, view_zoom - 0.07)
    if Input.is_action_just_pressed("fc_zoom_in"):
        view_zoom = minf(0.78, view_zoom + 0.07)

    beam_recovery = maxf(0.0, beam_recovery - delta)
    missile_cooldown = maxf(0.0, missile_cooldown - delta)
    missile_boom_audio = maxf(0.0, missile_boom_audio - delta)
    port_cooldown = maxf(0.0, port_cooldown - delta)
    starboard_cooldown = maxf(0.0, starboard_cooldown - delta)
    port_flash = maxf(0.0, port_flash - delta)
    starboard_flash = maxf(0.0, starboard_flash - delta)

    sound_message_timer = maxf(0.0, sound_message_timer - delta)
    port_ammo = minf(AMMO_CAPACITY, port_ammo + AMMO_RECHARGE * delta)
    starboard_ammo = minf(AMMO_CAPACITY, starboard_ammo + AMMO_RECHARGE * delta)
    if Input.is_action_just_pressed("fc_cease"):
        port_order = false
        starboard_order = false
        port_target = -1
        starboard_target = -1
        announce("ALL BATTERIES - CEASE FIRE")
    if Input.is_action_just_pressed("fc_port"):
        port_order = not port_order
        port_target = -1
        announce("PORT BATTERIES - " + ("OPEN FIRE" if port_order else "CEASE FIRE"))
    if Input.is_action_just_pressed("fc_starboard"):
        starboard_order = not starboard_order
        starboard_target = -1
        announce("STARBOARD BATTERIES - " + ("OPEN FIRE" if starboard_order else "CEASE FIRE"))
    if Input.is_action_just_pressed("fc_missile") and not encounter_finished and missile_cooldown <= 0.0:
        launch_missiles(MISSILES_PER_SALVO)

    # One press arms a five-second firing order. The second press cancels.
    if Input.is_action_just_pressed("fc_beam") and not encounter_finished:
        if beam_charging:
            beam_charging = false
            charge = 0.0
            beam_recovery = maxf(beam_recovery, 1.7)
            announce("SPINAL BEAM - CHARGE ABORTED")
        elif beam_recovery <= 0.0 and beam_path.is_empty():
            beam_charging = true
            charge = 0.0
            announce("SPINAL BEAM - CHARGING")
    if beam_charging and not encounter_finished:
        charge = minf(CHARGE_SECONDS, charge + delta)
        if charge >= CHARGE_SECONDS:
            beam_charging = false
            fire_beam(1.0)
            charge = 0.0
            announce("SPINAL BEAM - FIRE")

    if not player_destroyed:
        update_ship(delta)
    camera_pos = camera_pos.lerp(ship_pos, 1.0 - exp(-2.5 * delta))
    var half_view := VIEW_SIZE * (0.5 / view_zoom)
    camera_pos.x = clampf(camera_pos.x, FIELD.position.x + half_view.x, FIELD.end.x - half_view.x)
    camera_pos.y = clampf(camera_pos.y, FIELD.position.y + half_view.y, FIELD.end.y - half_view.y)
    update_environment_transform()

    if not encounter_finished:
        advance_enemies(delta)
        process_battery_order(-1.0)
        process_battery_order(1.0)

    advance_shots(delta)
    advance_missiles(delta)
    advance_beam(delta)
    update_beam_damage_effects(delta)
    recharge_shields(delta)
    update_ion_trails(delta)
    check_encounter_result()
    for i in range(impacts.size() - 1, -1, -1):
        impacts[i]["life"] = float(impacts[i]["life"]) - delta
        if float(impacts[i]["life"]) <= 0.0:
            impacts.remove_at(i)
    for i in range(debris.size() - 1, -1, -1):
        debris[i]["pos"] = Vector2(debris[i]["pos"]) + Vector2(debris[i]["vel"]) * delta
        debris[i]["life"] = float(debris[i]["life"]) - delta
        if float(debris[i]["life"]) <= 0.0:
            debris.remove_at(i)
    for i in range(missile_blasts.size() - 1, -1, -1):
        missile_blasts[i]["life"] = float(missile_blasts[i]["life"]) - delta
        if float(missile_blasts[i]["life"]) <= 0.0:
            missile_blasts.remove_at(i)
    queue_redraw()

func update_ship(delta: float) -> void:
    var turn_input := Input.get_axis("fc_turn_left", "fc_turn_right")
    var progress := charge / CHARGE_SECONDS
    var desired_turn := turn_input * TURN_SPEED * (1.0 - 0.47 * progress)
    angular_velocity = move_toward(angular_velocity, desired_turn, TURN_ACCEL * delta)
    ship_angle += angular_velocity * delta

    var throttle := Input.get_action_strength("fc_thrust")
    var reverse_input := Input.get_action_strength("fc_brake")
    thrusting = throttle > 0.05
    braking = reverse_input > 0.05
    var forward := Vector2.UP.rotated(ship_angle)
    var available_power := 1.0 - progress
    # Opposite stick direction drives actual stern-first movement, not
    # passive braking. A stationary ship can accelerate in reverse.
    velocity += forward * THRUST * throttle * available_power * delta
    velocity -= forward * REVERSE_THRUST * reverse_input * available_power * delta
    velocity += gravity_at(ship_pos) * delta
    if progress > 0.0:
        velocity = velocity.move_toward(Vector2.ZERO, (26.0 + 83.0 * progress) * delta)
        if progress >= 0.999:
            velocity = Vector2.ZERO
    velocity = velocity.limit_length(MAX_SPEED)
    # Limit reverse-speed component while retaining sideways inertia.
    var back_speed := -velocity.dot(forward)
    if back_speed > MAX_REVERSE_SPEED:
        velocity += forward * (back_speed - MAX_REVERSE_SPEED)
    ship_pos += velocity * delta
    confine_ship()

func gravity_at(pos: Vector2) -> Vector2:
    var direction: Vector2 = GRAVITY_CENTER - pos
    var distance := direction.length()
    if distance < 8.0 or distance >= GRAVITY_RADIUS:
        return Vector2.ZERO
    var strength := 62.0 * pow(1.0 - distance / GRAVITY_RADIUS, 1.6)
    return direction / distance * strength

func confine_ship() -> void:
    var margin := 72.0
    var clamped := Vector2(
        clampf(ship_pos.x, FIELD.position.x + margin, FIELD.end.x - margin),
        clampf(ship_pos.y, FIELD.position.y + margin, FIELD.end.y - margin))
    if clamped.x != ship_pos.x:
        velocity.x = 0.0
    if clamped.y != ship_pos.y:
        velocity.y = 0.0
    ship_pos = clamped
    for rock in asteroids:
        var centre: Vector2 = rock["pos"]
        var minimum := float(rock["radius"]) + 42.0
        var displacement := ship_pos - centre
        if displacement.length_squared() < minimum * minimum:
            var outward := displacement.normalized() if displacement.length() > 0.1 else Vector2.UP
            var impact_speed := maxf(0.0, -velocity.dot(outward))
            ship_pos = centre + outward * minimum
            velocity = velocity.slide(outward) * 0.65
            if impact_speed > ASTEROID_SAFE_IMPACT:
                # Kinetic impact bypasses shields entirely.
                var harm := clampf((impact_speed - ASTEROID_SAFE_IMPACT) * 0.115, 0.5, 10.0)
                damage_player_hull_direct(harm, ship_pos - outward * 33.0)

func damage_player_hull_direct(amount: float, at: Vector2) -> void:
    if player_destroyed:
        return
    player_hull = maxf(0.0, player_hull - amount)
    impacts.append({"pos": at, "life": 0.32, "color": PORT_COLOR})
    create_explosion(at, 5)
    if player_hull <= 0.0:
        player_destroyed = true
        encounter_finished = true
        beam_charging = false
        charge = 0.0
        announce("FLAGSHIP CRUSHED - PRESS R TO RETRY")
        create_explosion(ship_pos, 22)
        sound_bus.play("explosion")

func update_ion_trails(delta: float) -> void:
    # World-space emitters reflect actual travel, including drifting,
    # strafing inertia and reversing. Bounded lifetime prevents buildup.
    for i in range(ion_trails.size() - 1, -1, -1):
        ion_trails[i]["life"] = float(ion_trails[i]["life"]) - delta
        if float(ion_trails[i]["life"]) <= 0.0:
            ion_trails.remove_at(i)
    trail_tick -= delta
    if trail_tick > 0.0:
        return
    trail_tick = TRAIL_INTERVAL
    if not player_destroyed:
        emit_ion(ship_pos, velocity, 1.0)
    for enemy in targets:
        if not bool(enemy["destroyed"]):
            emit_ion(enemy["pos"], enemy["velocity"], 0.73 if enemy["kind"] == "frigate" else 1.0)

func emit_ion(pos: Vector2, actual_velocity: Vector2, strength: float) -> void:
    var speed := actual_velocity.length()
    if speed < 9.0:
        return
    var rearward := actual_velocity / speed
    var speed_factor := clampf(speed / 140.0, 0.0, 1.0)
    var lifetime := lerpf(0.46, 1.24, speed_factor)
    ion_trails.append({
        "pos": pos - rearward * (25.0 * strength),
        "vel": actual_velocity * 0.22,
        "life": lifetime, "max_life": lifetime, "speed": speed,
        "radius": lerpf(2.5, 5.0, speed_factor) * strength
    })

func draw_ion_trails() -> void:
    for particle in ion_trails:
        var ratio := clampf(float(particle["life"]) / float(particle["max_life"]), 0.0, 1.0)
        var pos: Vector2 = particle["pos"]
        var vel: Vector2 = particle["vel"]
        var streak := minf(float(particle["speed"]) * 0.27, 30.0)
        draw_line(pos, pos - vel.normalized() * streak,
            Color(0.24, 0.65, 1.0, 0.36 * ratio), 5.2 * ratio, true)
        draw_line(pos, pos - vel.normalized() * streak * 0.75,
            Color(0.67, 0.93, 1.0, 0.48 * ratio), 2.2 * ratio, true)
        draw_circle(pos, float(particle["radius"]) * ratio, Color(0.57, 0.88, 1.0, 0.54 * ratio))

func announce(message: String) -> void:
    sound_message = message
    sound_message_timer = 2.0

func arc_valid(source: Vector2, direction: Vector2, focus: Vector2, max_angle: float, max_range: float) -> bool:
    var displacement: Vector2 = focus - source
    if displacement.length_squared() > max_range * max_range:
        return false
    if displacement.length_squared() < 0.1:
        return true
    return absf(wrapf(displacement.angle() - direction.angle(), -PI, PI)) <= max_angle

func line_clear(source: Vector2, destination: Vector2) -> bool:
    for rock in asteroids:
        var centre: Vector2 = rock["pos"]
        var near := Geometry2D.get_closest_point_to_segment(centre, source, destination)
        if near.distance_squared_to(centre) <= pow(float(rock["radius"]) + 5.0, 2.0):
            return false
    return true

func choose_target(side: float, previous: int) -> int:
    var direction := Vector2(side, 0.0).rotated(ship_angle)
    # Retain a current lock through a slightly wider tracking cone.
    if previous >= 0 and previous < targets.size():
        var existing: Dictionary = targets[previous]
        if not bool(existing["destroyed"]) and arc_valid(ship_pos, direction, existing["pos"], TRACKING_HALF_ARC, BATTERY_RANGE * 1.08) and line_clear(ship_pos, existing["pos"]):
            return previous
    var best := -1
    var best_distance := INF
    for j in range(targets.size()):
        if bool(targets[j]["destroyed"]):
            continue
        var spot: Vector2 = targets[j]["pos"]
        var distance := ship_pos.distance_squared_to(spot)
        if distance < best_distance and arc_valid(ship_pos, direction, spot, BATTERY_HALF_ARC, BATTERY_RANGE) and line_clear(ship_pos, spot):
            best_distance = distance
            best = j
    return best

func choose_hostile_missile(side: float) -> int:
    # Rudimentary close-in point defence: active batteries interrupt their
    # ship target while a hostile missile enters their arc and line of sight.
    var axis := Vector2(side, 0.0).rotated(ship_angle)
    var chosen := -1
    var nearest := INF
    for j in range(missiles.size()):
        var m: Dictionary = missiles[j]
        if not bool(m["hostile"]):
            continue
        var position: Vector2 = m["pos"]
        var square_distance := ship_pos.distance_squared_to(position)
        if square_distance < nearest and arc_valid(ship_pos, axis, position, BATTERY_HALF_ARC, 610.0) and line_clear(ship_pos, position):
            nearest = square_distance
            chosen = j
    return chosen

func process_battery_order(side: float) -> void:
    var ordered: bool = port_order if side < 0.0 else starboard_order
    if not ordered:
        return
    var previous: int = port_target if side < 0.0 else starboard_target
    var next_target := choose_target(side, previous)
    if side < 0.0:
        port_target = next_target
    else:
        starboard_target = next_target
    var cooldown: float = port_cooldown if side < 0.0 else starboard_cooldown
    var ammo: float = port_ammo if side < 0.0 else starboard_ammo
    if cooldown > 0.0 or ammo < 2.0:
        return
    fire_broadside(side, next_target, choose_hostile_missile(side))
    if side < 0.0:
        port_cooldown = BROADSIDE_INTERVAL
        port_ammo -= 2.0
        port_flash = 0.12
    else:
        starboard_cooldown = BROADSIDE_INTERVAL
        starboard_ammo -= 2.0
        starboard_flash = 0.12

func fire_broadside(side: float, selected: int = -1, missile_target: int = -1) -> void:
    var outward := Vector2(side, 0.0).rotated(ship_angle)
    var aim := outward
    var focus := Vector2.ZERO
    var focus_velocity := Vector2.ZERO
    var has_focus := false
    if missile_target >= 0 and missile_target < missiles.size():
        var missile: Dictionary = missiles[missile_target]
        if bool(missile["hostile"]):
            focus = missile["pos"]
            focus_velocity = missile["vel"]
            has_focus = true
    elif selected >= 0 and selected < targets.size() and not bool(targets[selected]["destroyed"]):
        focus = targets[selected]["pos"]
        focus_velocity = targets[selected]["velocity"]
        has_focus = true
    if has_focus and arc_valid(ship_pos, outward, focus, BATTERY_HALF_ARC, BATTERY_RANGE) and line_clear(ship_pos, focus):
        var requested := focus - ship_pos
        if requested.length_squared() > 0.1:
            var prediction := requested.length() / SHELL_SPEED
            aim = (requested + focus_velocity * prediction).normalized()
            var offset := wrapf(aim.angle() - outward.angle(), -PI, PI)
            aim = outward.rotated(clampf(offset, -BATTERY_HALF_ARC, BATTERY_HALF_ARC))
    for station in [-21.0, 21.0]:
        var muzzle := ship_pos + Vector2(side * 45.0, station).rotated(ship_angle)
        var direction := aim.rotated((station / 21.0) * 0.014)
        shots.append({
            "pos": muzzle, "previous": muzzle, "vel": direction * SHELL_SPEED,
            "life": 2.7, "side": side, "hostile": false, "damage": 1.45
        })
    sound_bus.play("pulse")

func advance_enemies(delta: float) -> void:
    for j in range(targets.size()):
        var enemy: Dictionary = targets[j]
        if bool(enemy["destroyed"]):
            continue
        var centre: Vector2 = enemy["pos"]
        var to_flagship := ship_pos - centre
        var distance := to_flagship.length()
        if distance < 1.0:
            to_flagship = Vector2.UP
            distance = 1.0
        var bearing := to_flagship.angle()
        var is_cruiser: bool = enemy["kind"] == "cruiser"
        var preferred := 580.0 if is_cruiser else 390.0
        var heading := bearing + PI * 0.5
        var moving_forward := false

        if distance > preferred + 110.0:
            heading = bearing + PI * 0.5  # nose faces player (UP local axis)
            moving_forward = true
        elif distance < preferred - 130.0:
            heading = bearing - PI * 0.5  # nose faces away
            moving_forward = true
        elif is_cruiser:
            # Make port guns face player; drift along the firing line.
            heading = bearing - PI
        else:
            # A frigate keeps bringing its forward battery around.
            heading = bearing + PI * 0.5 + sin(time_passed * 0.49 + float(j)) * 0.22
            moving_forward = true

        # Avoid solid rocks and the anomaly with intentional steering.
        for rock in asteroids:
            var separation: Vector2 = centre - Vector2(rock["pos"])
            if separation.length() < float(rock["radius"]) + 170.0:
                heading = separation.angle() + PI * 0.5
                moving_forward = true
                break
        var well_delta: Vector2 = centre - GRAVITY_CENTER
        if well_delta.length() < GRAVITY_RADIUS * 0.62:
            heading = well_delta.angle() + PI * 0.5
            moving_forward = true

        var turn_rate: float = enemy["turn_rate"]
        var target_rotation := wrapf(heading - float(enemy["angle"]), -PI, PI)
        var desired_turn := clampf(target_rotation * 1.15, -turn_rate, turn_rate)
        var turn_velocity: float = move_toward(float(enemy["turn_velocity"]), desired_turn, turn_rate * 0.95 * delta)
        enemy["turn_velocity"] = turn_velocity
        enemy["angle"] = float(enemy["angle"]) + turn_velocity * delta

        var vel: Vector2 = enemy["velocity"]
        var heading_error := absf(wrapf(heading - float(enemy["angle"]), -PI, PI))
        if heading_error < 1.0:
            var impulse: float = 1.0 if moving_forward else 0.43
            vel += Vector2.UP.rotated(float(enemy["angle"])) * float(enemy["accel"]) * impulse * delta
        if not moving_forward:
            vel = vel.move_toward(Vector2.ZERO, 15.0 * delta)
        vel += gravity_at(centre) * delta
        vel = vel.limit_length(float(enemy["speed"]))
        var future := centre + vel * delta
        if not FIELD.grow(-65.0).has_point(future):
            vel = -vel * 0.25
            future = centre + vel * delta
        for rock in asteroids:
            var from_rock := future - Vector2(rock["pos"])
            var safe_radius := float(rock["radius"]) + float(enemy["radius"])
            if from_rock.length_squared() < safe_radius * safe_radius:
                var outward := from_rock.normalized() if from_rock.length() > 0.1 else Vector2.RIGHT
                var kinetic_impact := maxf(0.0, -vel.dot(outward))
                future = Vector2(rock["pos"]) + outward * safe_radius
                vel = vel.slide(outward) * 0.65
                if kinetic_impact > ASTEROID_SAFE_IMPACT:
                    var collision_harm := clampf((kinetic_impact - ASTEROID_SAFE_IMPACT) * 0.11, 0.5, 12.0)
                    enemy["hp"] = maxf(0.0, float(enemy["hp"]) - collision_harm)
                    enemy["flash"] = 0.3
                    impacts.append({"pos": future - outward * float(enemy["radius"]), "life": 0.32, "color": PORT_COLOR})
                    if float(enemy["hp"]) <= 0.0 and not bool(enemy["destroyed"]):
                        enemy["destroyed"] = true
                        create_explosion(future, 15)
                        sound_bus.play("explosion")
        # Ships are solid to one another and cannot overlap the flagship.
        var from_player := future - ship_pos
        var min_player := float(enemy["radius"]) + SHIP_RADIUS
        if from_player.length_squared() < min_player * min_player:
            var out := from_player.normalized() if from_player.length() > 0.1 else Vector2.RIGHT
            future = ship_pos + out * min_player
            vel = vel.slide(out) * 0.65
        enemy["pos"] = future
        enemy["velocity"] = vel
        enemy["reload"] = maxf(0.0, float(enemy["reload"]) - delta)
        if enemy["kind"] == "frigate":
            enemy["missile_reload"] = maxf(0.0, float(enemy["missile_reload"]) - delta)
        targets[j] = enemy
        if not bool(enemy["destroyed"]) and float(enemy["reload"]) <= 0.0:
            fire_enemy(j)
        if not bool(enemy["destroyed"]) and enemy["kind"] == "frigate" and float(enemy["missile_reload"]) <= 0.0 and not player_destroyed:
            # A small hostile salvo exists so the player can practice
            # physically shooting missiles out of the sky.
            launch_missiles(2, j)
            enemy["missile_reload"] = FRIGATE_MISSILE_INTERVAL
            targets[j] = enemy

func fire_enemy(j: int) -> void:
    if player_destroyed:
        return
    var enemy: Dictionary = targets[j]
    var centre: Vector2 = enemy["pos"]
    var diff := ship_pos - centre
    var distance := diff.length()
    var ship_heading: float = enemy["angle"]
    var is_cruiser: bool = enemy["kind"] == "cruiser"
    var aim := diff.normalized()
    if is_cruiser:
        var left := Vector2.LEFT.rotated(ship_heading)
        var right := Vector2.RIGHT.rotated(ship_heading)
        var side := -1.0 if left.dot(aim) > right.dot(aim) else 1.0
        var outward := Vector2(side, 0).rotated(ship_heading)
        if not arc_valid(centre, outward, ship_pos, BATTERY_HALF_ARC, float(enemy["range"])):
            return
        if not line_clear(centre, ship_pos):
            return
        var lead := (ship_pos + velocity * (distance / SHELL_SPEED) - centre).normalized()
        var error_angle := wrapf(lead.angle() - outward.angle(), -PI, PI)
        aim = outward.rotated(clampf(error_angle, -BATTERY_HALF_ARC, BATTERY_HALF_ARC))
        for station in [-18.0, 18.0]:
            var muzzle := centre + Vector2(side * 39.0, station).rotated(ship_heading)
            spawn_enemy_shell(muzzle, aim, float(enemy["damage"]), 0.03)
    else:
        var nose := Vector2.UP.rotated(ship_heading)
        if not arc_valid(centre, nose, ship_pos, deg_to_rad(30.0), float(enemy["range"])):
            return
        if not line_clear(centre, ship_pos):
            return
        var lead := (ship_pos + velocity * (distance / (SHELL_SPEED + 100.0)) - centre).normalized()
        var offset := wrapf(lead.angle() - nose.angle(), -PI, PI)
        aim = nose.rotated(clampf(offset, -deg_to_rad(30.0), deg_to_rad(30.0)))
        spawn_enemy_shell(centre + nose * 31.0, aim, float(enemy["damage"]), 0.02)
    enemy["reload"] = float(enemy["reload_time"])
    sound_bus.play("pulse")

func spawn_enemy_shell(origin: Vector2, aim: Vector2, damage: float, dispersion: float) -> void:
    shots.append({
        "pos": origin, "previous": origin,
        "vel": aim.rotated(randf_range(-dispersion, dispersion)) * (SHELL_SPEED + 70.0),
        "life": 2.2, "side": 0.0, "hostile": true, "damage": damage
    })

# Individual lightweight projectiles: the salvo count is data-driven so the
# exact same logic can support larger upgraded missile swarms later.
func launch_missiles(count: int, enemy_index: int = -1) -> void:
    # Both factions use the same physics, cold-launch and interception rules.
    # The hostile frigate's small salvos make point-defence testable now.
    var hostile := enemy_index >= 0
    var amount := clampi(count, 1, 96)
    var origin_ship: Vector2 = targets[enemy_index]["pos"] if hostile else ship_pos
    var origin_angle: float = float(targets[enemy_index]["angle"]) if hostile else ship_angle
    var carrier_velocity: Vector2 = targets[enemy_index]["velocity"] if hostile else velocity
    var stern := Vector2.DOWN.rotated(origin_angle)
    var wing := Vector2.RIGHT.rotated(origin_angle)
    for n in range(amount):
        var slot := float(n) - (float(amount) - 1.0) * 0.5
        var spread := clampf(slot * 13.0, -92.0, 92.0)
        var origin := origin_ship + stern * (42.0 + absf(slot) * 3.0 if hostile else 52.0 + absf(slot) * 3.0) + wing * spread
        var ejection := stern * (60.0 + float(n % 3) * 7.0) + wing * slot * 12.0
        missiles.append({
            "pos": origin, "previous": origin,
            "vel": carrier_velocity * 0.73 + ejection,
            "age": 0.0, "life": MISSILE_FUEL_LIFE,
            "ignited": false, "target": -1,
            "hostile": hostile,
            "last_distance": INF,
            "trail": [], "trail_clock": 0.0
        })
    if not hostile:
        missile_cooldown = MISSILE_RELOAD
        announce("AFT MISSILE SALVO - %d COLD LAUNCHED" % amount)
        sound_bus.play("missile")

func nearest_missile_target(pos: Vector2) -> int:
    var best := -1
    var best_sq := INF
    for j in range(targets.size()):
        var enemy: Dictionary = targets[j]
        if bool(enemy["destroyed"]):
            continue
        var sq := pos.distance_squared_to(enemy["pos"])
        if sq < best_sq:
            best_sq = sq
            best = j
    return best

func missile_steering(pos: Vector2, current_velocity: Vector2, desired: Vector2, hostile: bool = false) -> Vector2:
    # Short-range anticipatory avoidance. Steer tangentially round asteroids,
    # rather than simply pushing away (which can trap homing missiles).
    var speed := maxf(current_velocity.length(), 50.0)
    var direction := current_velocity.normalized() if current_velocity.length_squared() > 1.0 else desired
    var look_ahead := 115.0 + minf(speed * 0.38, 100.0)
    var look_end := pos + direction * look_ahead
    var adjusted := desired
    var nearest_threat := INF
    for rock in asteroids:
        var centre: Vector2 = rock["pos"]
        var clearance := float(rock["radius"]) + 38.0
        var nearest := Geometry2D.get_closest_point_to_segment(centre, pos, look_end)
        var separation := centre.distance_to(nearest)
        if separation < clearance and separation < nearest_threat:
            nearest_threat = separation
            var away := (pos - centre).normalized()
            if away.length_squared() < 0.01:
                away = Vector2.UP
            var tangent := Vector2(-away.y, away.x)
            if tangent.dot(desired) < 0.0:
                tangent = -tangent
            adjusted = (away * 1.35 + tangent * 0.95).normalized()
    # Player and future friendly vessels are protected from friendly missiles.
    # Ignore the launch hull for the first moment only as the missiles exit.
    var own_radius := SHIP_RADIUS + 40.0
    var near_player := Geometry2D.get_closest_point_to_segment(ship_pos, pos, look_end)
    if not hostile and near_player.distance_to(ship_pos) < own_radius and pos.distance_to(ship_pos) > 66.0:
        var away_player := (pos - ship_pos).normalized()
        if away_player.length_squared() > 0.01:
            adjusted = (away_player * 1.8 + adjusted * 0.5).normalized()
    return adjusted

func advance_missiles(delta: float) -> void:
    for i in range(missiles.size() - 1, -1, -1):
        var m: Dictionary = missiles[i]
        var previous: Vector2 = m["pos"]
        var age := float(m["age"]) + delta
        m["age"] = age
        m["life"] = float(m["life"]) - delta
        var v: Vector2 = m["vel"]
        var hostile: bool = m["hostile"]
        var target_index: int = int(m["target"])
        if not bool(m["ignited"]) and age >= MISSILE_COLD_TIME:
            m["ignited"] = true
            if not hostile:
                target_index = nearest_missile_target(previous)
                m["target"] = target_index
        if bool(m["ignited"]):
            var intercept := Vector2.ZERO
            var has_target := false
            if hostile:
                if not player_destroyed:
                    var to_flagship := ship_pos - previous
                    intercept = (to_flagship + velocity * clampf(to_flagship.length() / MISSILE_MAX_SPEED, 0.0, 1.5)).normalized()
                    has_target = true
            else:
                if target_index < 0 or target_index >= targets.size() or bool(targets[target_index]["destroyed"]):
                    target_index = nearest_missile_target(previous)
                    m["target"] = target_index
                    m["last_distance"] = INF
                if target_index >= 0:
                    var enemy: Dictionary = targets[target_index]
                    var offset: Vector2 = enemy["pos"] - previous
                    intercept = (offset + Vector2(enemy["velocity"]) * clampf(offset.length() / MISSILE_MAX_SPEED, 0.0, 1.5)).normalized()
                    has_target = true
            if has_target:
                var guidance := missile_steering(previous, v, intercept, hostile)
                var speed := v.length()
                var current_heading := v.angle() if speed > 1.0 else guidance.angle()
                var turn := wrapf(guidance.angle() - current_heading, -PI, PI)
                var new_heading := current_heading + clampf(turn, -MISSILE_TURN_RATE * delta, MISSILE_TURN_RATE * delta)
                speed = minf(MISSILE_MAX_SPEED, speed + MISSILE_ACCEL * delta)
                v = Vector2.from_angle(new_heading) * speed
            else:
                v = v.move_toward(Vector2.ZERO, 25.0 * delta)
        else:
            v += gravity_at(previous) * 0.24 * delta
        var next := previous + v * delta
        m["previous"] = previous
        m["pos"] = next
        m["vel"] = v
        m["trail_clock"] = float(m["trail_clock"]) - delta
        if bool(m["ignited"]) and float(m["trail_clock"]) <= 0.0:
            var trail: Array = m["trail"]
            trail.append(next)
            if trail.size() > 17:
                trail.remove_at(0)
            m["trail"] = trail
            m["trail_clock"] = 0.062
        var removed := false
        for rock in asteroids:
            var centre: Vector2 = rock["pos"]
            var near := Geometry2D.get_closest_point_to_segment(centre, previous, next)
            if near.distance_squared_to(centre) < pow(float(rock["radius"]) + 3.0, 2.0):
                missile_detonate(next, -1, false, hostile)
                removed = true
                break
        if not removed and bool(m["ignited"]):
            var valid_target := hostile and not player_destroyed
            if not hostile:
                valid_target = target_index >= 0 and not bool(targets[target_index]["destroyed"])
            if valid_target:
                var target_pos: Vector2 = ship_pos if hostile else targets[target_index]["pos"]
                var radius: float = SHIP_RADIUS if hostile else float(targets[target_index]["radius"])
                var near_target := Geometry2D.get_closest_point_to_segment(target_pos, previous, next)
                var distance := next.distance_to(target_pos)
                if near_target.distance_to(target_pos) <= radius + 5.0:
                    missile_detonate(near_target, target_index, true, hostile)
                    removed = true
                elif age > MISSILE_COLD_TIME + 0.5 and float(m["last_distance"]) < radius + 83.0 and distance > float(m["last_distance"]) + 2.5:
                    missile_detonate(next, -1, false, hostile)
                    removed = true
                m["last_distance"] = distance
        if not removed and (float(m["life"]) <= 0.0 or not FIELD.has_point(next)):
            missile_detonate(next, -1, false, hostile)
            removed = true
        if removed:
            missiles.remove_at(i)
        else:
            missiles[i] = m

func missile_detonate(pos: Vector2, direct_target: int, direct_hit: bool, hostile: bool = false) -> void:
    # The same real detonation is used for missile near-misses, impacts and
    # gunfire interception; it never silently despawns the missile.
    impacts.append({"pos": pos, "life": 0.32, "color": PORT_COLOR if hostile else BEAM_COLOR})
    missile_blasts.append({"pos": pos, "life": 0.48, "max_life": 0.48, "hostile": hostile})
    create_explosion(pos, 9)
    if hostile:
        if not player_destroyed:
            if direct_hit:
                damage_player(MISSILE_DIRECT_DAMAGE, pos)
            else:
                var distance := pos.distance_to(ship_pos)
                if distance < MISSILE_BURST_RADIUS:
                    damage_player(MISSILE_BURST_DAMAGE * (1.0 - 0.55 * distance / MISSILE_BURST_RADIUS), pos)
    elif direct_hit and direct_target >= 0 and not bool(targets[direct_target]["destroyed"]):
        damage_target(direct_target, MISSILE_DIRECT_DAMAGE, pos)
    else:
        # Friendly missile splash only damages enemy ships.
        for j in range(targets.size()):
            var enemy: Dictionary = targets[j]
            if bool(enemy["destroyed"]):
                continue
            var reach := MISSILE_BURST_RADIUS + float(enemy["radius"]) * 0.3
            var distance := pos.distance_to(enemy["pos"])
            if distance < reach:
                damage_target(j, MISSILE_BURST_DAMAGE * (1.0 - 0.55 * distance / reach), pos)
    if missile_boom_audio <= 0.0:
        sound_bus.play("explosion")
        missile_boom_audio = 0.20

func draw_missiles() -> void:
    for m in missiles:
        var pos: Vector2 = m["pos"]
        var v: Vector2 = m["vel"]
        var hostile: bool = m["hostile"]
        var direction := v.normalized() if v.length_squared() > 0.1 else Vector2.DOWN
        var streak := Color(1.0, 0.36, 0.22) if hostile else Color(0.22, 0.70, 1.0)
        if bool(m["ignited"]):
            var trace: Array = m["trail"]
            for k in range(1, trace.size()):
                var fraction := float(k) / float(trace.size())
                draw_line(trace[k - 1], trace[k], Color(streak.r, streak.g, streak.b, 0.12 + 0.55 * fraction), 1.0 + fraction * 2.2, true)
            draw_line(pos - direction * 19.0, pos - direction * 6.0, Color(1.0, 0.58, 0.23, 0.55), 5.0, true)
            draw_line(pos - direction * 15.0, pos - direction * 4.0, Color(1.0, 0.96, 0.92, 0.90), 2.0, true)
        draw_line(pos - direction * 4.0, pos + direction * 6.0, WHITE, 2.8, true)
        draw_circle(pos + direction * 4.0, 2.3, streak)

func draw_missile_blasts() -> void:
    for blast in missile_blasts:
        var pos: Vector2 = blast["pos"]
        var progress := 1.0 - float(blast["life"]) / float(blast["max_life"])
        var opacity := 1.0 - progress
        var flash := Color(1.0, 0.48, 0.21, opacity) if bool(blast["hostile"]) else Color(0.52, 0.86, 1.0, opacity)
        draw_circle(pos, 13.0 + 13.0 * progress, Color(flash.r, flash.g, flash.b, opacity * 0.34))
        draw_circle(pos, maxf(0.0, 7.0 * (1.0 - progress)), Color(1.0, 0.96, 0.77, opacity))
        draw_arc(pos, 9.0 + 34.0 * progress, 0.0, TAU, 28, flash, 3.4 * opacity, true)

func recharge_shields(delta: float) -> void:
    player_shield_delay = maxf(0.0, player_shield_delay - delta)
    player_shield_flash = maxf(0.0, player_shield_flash - delta)
    # Depleted shields stay offline; they can only be brought back by
    # a future explicit repair/restart ability, never passive regeneration.
    if not player_destroyed and player_shields > 0.0 and player_shield_delay <= 0.0:
        player_shields = minf(PLAYER_MAX_SHIELDS, player_shields + SHIELD_REGEN_RATE * delta)
    for enemy in targets:
        if bool(enemy["destroyed"]):
            continue
        enemy["shield_delay"] = maxf(0.0, float(enemy["shield_delay"]) - delta)
        if float(enemy["shields"]) > 0.0 and float(enemy["shield_delay"]) <= 0.0:
            enemy["shields"] = minf(float(enemy["max_shields"]), float(enemy["shields"]) + SHIELD_REGEN_RATE * delta)
        enemy["flash"] = maxf(0.0, float(enemy["flash"]) - delta)

func damage_player(amount: float, at: Vector2) -> void:
    if player_destroyed:
        return
    player_shield_delay = SHIELD_REGEN_DELAY
    var absorbed := minf(player_shields, amount)
    player_shields -= absorbed
    if absorbed > 0.0:
        player_shield_flash = 0.22
    player_hull = maxf(0.0, player_hull - (amount - absorbed))
    impacts.append({"pos": at, "life": 0.32, "color": STARBOARD_COLOR if absorbed > 0.0 else PORT_COLOR})
    if player_hull <= 0.0:
        player_destroyed = true
        encounter_finished = true
        announce("FLAGSHIP LOST - PRESS R TO RETRY")
        create_explosion(ship_pos, 18)
        sound_bus.play("explosion")

func create_explosion(at: Vector2, count: int) -> void:
    for n in range(count):
        var a := TAU * float(n) / float(count)
        var speed := 65.0 + float(n % 6) * 27.0
        debris.append({
            "pos": at + Vector2.from_angle(a) * 10.0,
            "vel": Vector2.from_angle(a) * speed,
            "life": 1.3, "max_life": 1.3,
            "color": PORT_COLOR if n % 3 == 0 else MUTED
        })

func check_encounter_result() -> void:
    if encounter_finished:
        return
    var alive := 0
    for enemy in targets:
        if not bool(enemy["destroyed"]):
            alive += 1
    if alive == 0:
        encounter_finished = true
        announce("BATTLE WON - PRESS R TO RESTART")

func shot_intercepts_missile(shot_start: Vector2, shot_end: Vector2, shot_hostile: bool, delta: float) -> bool:
    # Swept capsule test: shots are small but fast. Check the missile's
    # predicted movement as well as the shell segment to prevent tunnelling.
    # Opposing factions only; our own guns won't destroy our own salvo.
    var radius_squared := MISSILE_INTERCEPT_RADIUS * MISSILE_INTERCEPT_RADIUS
    for i in range(missiles.size() - 1, -1, -1):
        var missile: Dictionary = missiles[i]
        if bool(missile["hostile"]) == shot_hostile:
            continue
        var m_start: Vector2 = missile["pos"]
        var m_end: Vector2 = m_start + Vector2(missile["vel"]) * delta
        var at_start := Geometry2D.get_closest_point_to_segment(m_start, shot_start, shot_end)
        var at_end := Geometry2D.get_closest_point_to_segment(m_end, shot_start, shot_end)
        var at_shot_start := Geometry2D.get_closest_point_to_segment(shot_start, m_start, m_end)
        var at_shot_end := Geometry2D.get_closest_point_to_segment(shot_end, m_start, m_end)
        var missed_squared := minf(
            minf(m_start.distance_squared_to(at_start), m_end.distance_squared_to(at_end)),
            minf(shot_start.distance_squared_to(at_shot_start), shot_end.distance_squared_to(at_shot_end)))
        var crossing: Variant = Geometry2D.segment_intersects_segment(shot_start, shot_end, m_start, m_end)
        if missed_squared > radius_squared and crossing == null:
            continue
        var detonation: Vector2 = at_start
        if crossing != null:
            detonation = Vector2(crossing)
        missile_detonate(detonation, -1, false, bool(missile["hostile"]))
        missiles.remove_at(i)
        return true
    return false

func advance_shots(delta: float) -> void:
    for i in range(shots.size() - 1, -1, -1):
        var bullet: Dictionary = shots[i]
        var old: Vector2 = bullet["pos"]
        bullet["vel"] = Vector2(bullet["vel"]) + gravity_at(old) * 6.0 * delta
        var next: Vector2 = old + Vector2(bullet["vel"]) * delta
        bullet["previous"] = old
        bullet["pos"] = next
        bullet["life"] = float(bullet["life"]) - delta
        var expired := float(bullet["life"]) <= 0.0 or not FIELD.has_point(next)
        if not expired:
            for rock in asteroids:
                var centre: Vector2 = rock["pos"]
                var near_rock := Geometry2D.get_closest_point_to_segment(centre, old, next)
                if near_rock.distance_squared_to(centre) <= pow(float(rock["radius"]), 2.0):
                    impacts.append({"pos": near_rock, "life": 0.32, "color": MUTED})
                    expired = true
                    break
        if not expired and shot_intercepts_missile(old, next, bool(bullet["hostile"]), delta):
            expired = true
        if not expired:
            if bool(bullet["hostile"]):
                if not player_destroyed:
                    var near_ship := Geometry2D.get_closest_point_to_segment(ship_pos, old, next)
                    if near_ship.distance_squared_to(ship_pos) <= SHIP_RADIUS * SHIP_RADIUS:
                        damage_player(float(bullet["damage"]), near_ship)
                        expired = true
            else:
                for j in range(targets.size()):
                    if bool(targets[j]["destroyed"]):
                        continue
                    var target_pos: Vector2 = targets[j]["pos"]
                    var near: Vector2 = Geometry2D.get_closest_point_to_segment(target_pos, old, next)
                    if near.distance_squared_to(target_pos) <= pow(float(targets[j]["radius"]), 2.0):
                        damage_target(j, float(bullet["damage"]), near)
                        expired = true
                        break
        if expired:
            shots.remove_at(i)
        else:
            shots[i] = bullet

func fire_beam(power: float) -> void:
    beam_power = power
    beam_path.clear()
    beam_hit_targets.clear()
    beam_absorption_timer = 0.0
    beam_visible = 0.0
    beam_total = 0.0
    beam_linger = 0.30
    beam_recovery = 1.15

    # A geometrically straight ray. Only world-boundary ricochets may
    # change its direction: there is no sinusoidal bending or steering.
    var direction := Vector2.UP.rotated(ship_angle)
    var cursor := ship_pos + direction * 64.0
    beam_path.append(cursor)
    var remaining := lerpf(340.0, 1150.0, power)
    for rebound in range(3):
        if remaining <= 0.001:
            break
        var x_edge := INF
        var y_edge := INF
        if direction.x > 0.00001:
            x_edge = (FIELD.end.x - cursor.x) / direction.x
        elif direction.x < -0.00001:
            x_edge = (FIELD.position.x - cursor.x) / direction.x
        if direction.y > 0.00001:
            y_edge = (FIELD.end.y - cursor.y) / direction.y
        elif direction.y < -0.00001:
            y_edge = (FIELD.position.y - cursor.y) / direction.y
        var distance_to_wall := minf(x_edge, y_edge)
        var segment_length := minf(remaining, distance_to_wall)
        if segment_length <= 0.001:
            break
        var blocked := false
        # Find the FIRST rock intercept along this exact straight segment.
        for rock in asteroids:
            var centre: Vector2 = rock["pos"]
            var radius: float = float(rock["radius"]) + 4.0
            var difference := cursor - centre
            var projection := difference.dot(direction)
            var discriminant := projection * projection - (difference.length_squared() - radius * radius)
            if discriminant < 0.0:
                continue
            var hit_distance := -projection - sqrt(discriminant)
            if hit_distance >= 0.0 and hit_distance < segment_length:
                segment_length = hit_distance
                blocked = true
        var endpoint := cursor + direction * segment_length
        if segment_length > 0.001:
            beam_path.append(endpoint)
            beam_total += segment_length
            remaining -= segment_length
        if blocked or segment_length < distance_to_wall - 0.001 or rebound >= 2:
            break
        # Mirror reflection at the exact arena edge, not a nearby grid step.
        if absf(x_edge - distance_to_wall) <= 0.001:
            direction.x = -direction.x
        if absf(y_edge - distance_to_wall) <= 0.001:
            direction.y = -direction.y
        cursor = endpoint
    sound_bus.play("missile")

func beam_circle_entry(segment_start: Vector2, segment_end: Vector2, centre: Vector2, radius: float) -> Vector2:
    var vector := segment_end - segment_start
    var length := vector.length()
    if length <= 0.001:
        return segment_start
    var ray := vector / length
    var offset := segment_start - centre
    var projection := offset.dot(ray)
    var discriminant := projection * projection - (offset.length_squared() - radius * radius)
    if discriminant < 0.0:
        return Geometry2D.get_closest_point_to_segment(centre, segment_start, segment_end)
    var entry_distance := clampf(-projection - sqrt(discriminant), 0.0, length)
    return segment_start + ray * entry_distance

func advance_beam(delta: float) -> void:
    if beam_path.size() < 2:
        return
    beam_visible = minf(beam_total, beam_visible + BEAM_EXPAND_SPEED * delta)
    var length_drawn := 0.0
    var stopped_by_shield := false
    for i in range(1, beam_path.size()):
        var start: Vector2 = beam_path[i - 1]
        var finish: Vector2 = beam_path[i]
        var section := start.distance_to(finish)
        if length_drawn >= beam_visible:
            break
        var portion := minf(1.0, (beam_visible - length_drawn) / maxf(section, 0.001))
        finish = start.lerp(finish, portion)
        for j in range(targets.size()):
            if beam_hit_targets.has(j) or bool(targets[j]["destroyed"]):
                continue
            var enemy: Dictionary = targets[j]
            var target_pos: Vector2 = enemy["pos"]
            var near := Geometry2D.get_closest_point_to_segment(target_pos, start, finish)
            var shielded := float(enemy["shields"]) > 0.0
            var radius := float(enemy["radius"]) + (11.0 if shielded else 0.0)
            if near.distance_squared_to(target_pos) <= radius * radius:
                beam_hit_targets[j] = true
                if shielded:
                    # A shield absorbs the entire beam discharge even when
                    # that discharge exhausts its remaining charge.
                    var shield_impact := beam_circle_entry(start, finish, target_pos, radius)
                    damage_shield_from_beam(j, BEAM_SHIELD_DAMAGE, shield_impact)
                    beam_total = length_drawn + start.distance_to(shield_impact)
                    beam_visible = beam_total
                    beam_absorption_point = shield_impact
                    beam_absorption_timer = 0.48
                    beam_linger = 0.42
                    stopped_by_shield = true
                    break
                else:
                    # Exposed hull: draw a cut through the ship, spawn
                    # exit-wound debris, and continue the beam behind it.
                    make_beam_penetration(j, start, finish)
                    damage_target(j, BEAM_HULL_DAMAGE * beam_power, near)
        if stopped_by_shield:
            break
        length_drawn += section
    if beam_visible >= beam_total:
        beam_linger -= delta
        if beam_linger <= 0.0:
            beam_path.clear()

func damage_shield_from_beam(index: int, amount: float, hit: Vector2) -> void:
    var enemy: Dictionary = targets[index]
    if bool(enemy["destroyed"]):
        return
    enemy["shields"] = maxf(0.0, float(enemy["shields"]) - amount)
    enemy["shield_delay"] = SHIELD_REGEN_DELAY
    enemy["flash"] = 0.65
    impacts.append({"pos": hit, "life": 0.32, "color": BEAM_COLOR})
    create_explosion(hit, 6)

func make_beam_penetration(index: int, begin: Vector2, finish: Vector2) -> void:
    var enemy: Dictionary = targets[index]
    var centre: Vector2 = enemy["pos"]
    var heading: float = enemy["angle"]
    var axis := (finish - begin).normalized()
    if axis.length_squared() < 0.1:
        return
    # Intersection chord of an actual circular hull, including off-centre hits.
    var axis_mid := begin + axis * (centre - begin).dot(axis)
    var sideways := centre.distance_to(axis_mid)
    var radius: float = enemy["radius"]
    var chord_half := sqrt(maxf(0.0, radius * radius - sideways * sideways))
    var entry := axis_mid - axis * chord_half
    var exit_wound := axis_mid + axis * chord_half
    beam_scars.append({
        "index": index, "entry_local": (entry - centre).rotated(-heading),
        "exit_local": (exit_wound - centre).rotated(-heading),
        "life": 8.0, "max_life": 8.0
    })
    impacts.append({"pos": entry, "life": 0.32, "color": BEAM_COLOR})
    impacts.append({"pos": exit_wound, "life": 0.32, "color": PORT_COLOR})
    # Entry flashes; most incandescent fragments burst from the exit wound.
    for n in range(12):
        var spray := axis.rotated(randf_range(-0.58, 0.58))
        debris.append({
            "pos": exit_wound, "vel": spray * randf_range(90.0, 320.0),
            "life": randf_range(0.8, 1.6), "max_life": 1.6,
            "color": BEAM_COLOR if n % 3 == 0 else PORT_COLOR
        })

func update_beam_damage_effects(delta: float) -> void:
    beam_absorption_timer = maxf(0.0, beam_absorption_timer - delta)
    for i in range(beam_scars.size() - 1, -1, -1):
        beam_scars[i]["life"] = float(beam_scars[i]["life"]) - delta
        if float(beam_scars[i]["life"]) <= 0.0:
            beam_scars.remove_at(i)
    for i in range(smoke.size() - 1, -1, -1):
        smoke[i]["pos"] = Vector2(smoke[i]["pos"]) + Vector2(smoke[i]["vel"]) * delta
        smoke[i]["life"] = float(smoke[i]["life"]) - delta
        if float(smoke[i]["life"]) <= 0.0:
            smoke.remove_at(i)
    smoke_tick -= delta
    if smoke_tick > 0.0:
        return
    smoke_tick = 0.15
    for scar in beam_scars:
        var j: int = scar["index"]
        if j < 0 or j >= targets.size() or bool(targets[j]["destroyed"]):
            continue
        var enemy: Dictionary = targets[j]
        var emission: Vector2 = Vector2(enemy["pos"]) + Vector2(scar["exit_local"]).rotated(float(enemy["angle"]))
        var drifting: Vector2 = enemy["velocity"]
        smoke.append({
            "pos": emission, "vel": drifting * 0.23 + Vector2(randf_range(-18.0, 18.0), randf_range(-24.0, 9.0)),
            "life": randf_range(0.7, 1.5), "max_life": 1.5, "radius": randf_range(3.0, 7.0)
        })

func draw_smoke() -> void:
    for puff in smoke:
        var opacity := clampf(float(puff["life"]) / float(puff["max_life"]), 0.0, 1.0)
        draw_circle(puff["pos"], float(puff["radius"]) * (2.0 - opacity),
            Color(0.57, 0.65, 0.73, 0.19 * opacity))

func draw_beam_scar_glow() -> void:
    for scar in beam_scars:
        var j: int = scar["index"]
        if j < 0 or j >= targets.size() or bool(targets[j]["destroyed"]):
            continue
        var enemy: Dictionary = targets[j]
        var centre: Vector2 = enemy["pos"]
        var heading: float = enemy["angle"]
        var entry_world: Vector2 = centre + Vector2(scar["entry_local"]).rotated(heading)
        var exit_world: Vector2 = centre + Vector2(scar["exit_local"]).rotated(heading)
        var intensity := clampf(float(scar["life"]) / 8.0, 0.0, 1.0)
        draw_line(entry_world, exit_world, Color(1.0, 0.29, 0.10, 0.48 * intensity), 9.0, true)
        draw_line(entry_world, exit_world, Color(1.0, 0.83, 0.43, 0.75 * intensity), 3.0, true)
        draw_circle(entry_world, 6.0, Color(1.0, 0.91, 0.65, 0.65 * intensity))
        draw_circle(exit_world, 8.0, Color(1.0, 0.47, 0.16, 0.75 * intensity))


func damage_target(index: int, amount: float, at: Vector2) -> void:
    if bool(targets[index]["destroyed"]):
        return
    var enemy: Dictionary = targets[index]
    var absorbed := minf(float(enemy["shields"]), amount)
    enemy["shields"] = float(enemy["shields"]) - absorbed
    enemy["hp"] = maxf(0.0, float(enemy["hp"]) - (amount - absorbed))
    enemy["shield_delay"] = SHIELD_REGEN_DELAY
    enemy["flash"] = 0.20
    impacts.append({"pos": at, "life": 0.32, "color": BEAM_COLOR if absorbed > 0.0 else PORT_COLOR})
    if float(enemy["hp"]) <= 0.0:
        enemy["destroyed"] = true
        create_explosion(enemy["pos"], 14)
        sound_bus.play("explosion")

func update_environment_transform() -> void:
    # Moving/scaling a CanvasItem does not rebuild its cached draw commands.
    camera_offset = VIEW_SIZE * 0.5 - camera_pos * view_zoom
    environment.position = camera_offset
    environment.scale = Vector2.ONE * view_zoom

func _draw() -> void:
    # Only moving objects and UI are redrawn every frame. The background is
    # a show_behind_parent child with independently cached draw commands.
    draw_set_transform(camera_offset, 0.0, Vector2.ONE * view_zoom)
    draw_weapon_arcs()
    draw_ion_trails()
    draw_targets()
    draw_smoke()
    draw_shots()
    draw_missiles()
    draw_missile_blasts()
    draw_ship()
    draw_beam()
    draw_beam_scar_glow()
    draw_impacts()
    draw_debris()
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    draw_hud()

func draw_targets() -> void:
    var font := ThemeDB.fallback_font
    for target in targets:
        if bool(target["destroyed"]):
            continue
        var centre: Vector2 = target["pos"]
        # Skip distant enemies entirely when outside the camera.
        if absf(centre.x - camera_pos.x) > 1500.0 or absf(centre.y - camera_pos.y) > 1100.0:
            continue
        var angle: float = target["angle"]
        var frigate: bool = target["kind"] == "frigate"
        var scale_factor := 0.64 if frigate else 1.0
        var hull_color := Color(0.29, 0.21, 0.26) if frigate else Color(0.39, 0.23, 0.27)
        var edge_color := Color(1.0, 0.67, 0.41) if frigate else Color(0.96, 0.44, 0.41)
        if float(target["flash"]) > 0.0:
            edge_color = Color(1.0, 0.97, 0.78)
        # Silhouette size mirrors role: frigate < cruiser < player flagship.
        var points := PackedVector2Array()
        for local in [
            Vector2(0, -61), Vector2(23, -43), Vector2(30, -10),
            Vector2(39, 23), Vector2(23, 55), Vector2(-23, 55),
            Vector2(-39, 23), Vector2(-30, -10), Vector2(-23, -43)
        ]:
            points.append(centre + (local * scale_factor).rotated(angle))
        draw_colored_polygon(points, hull_color)
        var closed := points.duplicate()
        closed.append(points[0])
        draw_polyline(closed, edge_color, 3.0, true)
        draw_line(centre + (Vector2(0, -46) * scale_factor).rotated(angle),
            centre + (Vector2(0, 40) * scale_factor).rotated(angle), edge_color.darkened(0.25), 3.5, true)
        if frigate:
            draw_line(centre + Vector2(-18, -12).rotated(angle),
                centre + Vector2(18, -12).rotated(angle), edge_color, 4.0, true)
        else:
            for side in [-1.0, 1.0]:
                for y in [-22.0, 20.0]:
                    draw_line(centre + Vector2(side * 27, y).rotated(angle),
                        centre + Vector2(side * 45, y).rotated(angle), edge_color, 4.0, true)
        if float(target["shields"]) > 0.0:
            draw_arc(centre, float(target["radius"]) + 11.0, 0.0, TAU, 36,
                Color(0.28, 0.68, 1.0, 0.22 if float(target["flash"]) <= 0.0 else 0.76), 2.4, true)
        draw_string(font, centre + Vector2(-91, -91), String(target["name"]),
            HORIZONTAL_ALIGNMENT_LEFT, -1, 19, MUTED)
        var hp_ratio := float(target["hp"]) / float(target["max_hp"])
        var shield_ratio := float(target["shields"]) / float(target["max_shields"])
        # Shield health above hull health; colours remain distinct.
        draw_rect(Rect2(centre + Vector2(-56, 65), Vector2(112, 6)), Color(0.08, 0.13, 0.18), true)
        draw_rect(Rect2(centre + Vector2(-56, 65), Vector2(112 * shield_ratio, 6)), STARBOARD_COLOR, true)
        draw_rect(Rect2(centre + Vector2(-56, 76), Vector2(112, 7)), Color(0.08, 0.13, 0.18), true)
        draw_rect(Rect2(centre + Vector2(-56, 76), Vector2(112 * hp_ratio, 7)), edge_color, true)
        if float(target["shields"]) <= 0.0:
            draw_string(font, centre + Vector2(-56, 98), "SHIELDS OFFLINE",
                HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PORT_COLOR)

func draw_weapon_arcs() -> void:
    if not show_arcs:
        return
    for side in [-1.0, 1.0]:
        var bearing := Vector2(side, 0.0).rotated(ship_angle).angle()
        var color := PORT_COLOR if side < 0.0 else STARBOARD_COLOR
        color.a = 0.50
        draw_arc(ship_pos, BATTERY_RANGE, bearing - BATTERY_HALF_ARC,
            bearing + BATTERY_HALF_ARC, 52, color, 3.5, true)
        color.a = 0.20
        draw_arc(ship_pos, BATTERY_RANGE * 1.08, bearing - TRACKING_HALF_ARC,
            bearing + TRACKING_HALF_ARC, 52, color, 2.0, true)
        var idx: int = port_target if side < 0.0 else starboard_target
        if idx >= 0 and idx < targets.size() and not bool(targets[idx]["destroyed"]):
            draw_line(ship_pos, targets[idx]["pos"], Color(color.r, color.g, color.b, 0.25), 1.5, true)
    var beam_angle := Vector2.UP.rotated(ship_angle).angle()
    draw_arc(ship_pos, 1150.0, beam_angle - BOW_HALF_ARC,
        beam_angle + BOW_HALF_ARC, 44, Color(0.45, 0.87, 1.0, 0.28), 2.5, true)
    for enemy in targets:
        if bool(enemy["destroyed"]):
            continue
        var base: Vector2 = enemy["pos"]
        var angle: float = enemy["angle"]
        if enemy["kind"] == "cruiser":
            for side in [-1.0, 1.0]:
                var arc_angle := Vector2(side, 0.0).rotated(angle).angle()
                draw_arc(base, float(enemy["range"]), arc_angle - BATTERY_HALF_ARC,
                    arc_angle + BATTERY_HALF_ARC, 40, Color(0.99, 0.34, 0.30, 0.25), 2.5, true)
        else:
            var bow := Vector2.UP.rotated(angle).angle()
            draw_arc(base, float(enemy["range"]), bow - deg_to_rad(30.0),
                bow + deg_to_rad(30.0), 30, Color(1.0, 0.60, 0.24, 0.28), 2.5, true)

func draw_ship() -> void:
    if player_destroyed:
        return
    draw_set_transform(camera_offset + ship_pos * view_zoom, ship_angle, Vector2.ONE * view_zoom)
    if thrusting and charge < CHARGE_SECONDS:
        var jet := 15.0 + 10.0 * (0.5 + 0.5 * sin(time_passed * 38.0))
        for x in [-17.0, 17.0]:
            draw_line(Vector2(x, 48), Vector2(x, 48 + jet), Color(0.99, 0.51, 0.20), 6.0, true)
            draw_line(Vector2(x, 48), Vector2(x, 48 + jet * 0.70), Color(1.0, 0.92, 0.65), 2.1, true)
    # Forward-facing blue manoeuvring jets make stern-first thrust obvious.
    # They are deliberately visually different from the orange aft engines.
    if braking and charge < CHARGE_SECONDS:
        var reverse_power := Input.get_action_strength("fc_brake") * (1.0 - charge / CHARGE_SECONDS)
        var reverse_pulse := 0.78 + 0.22 * sin(time_passed * 42.0)
        var reverse_jet := (17.0 + 24.0 * reverse_power) * reverse_pulse
        for x in [-24.0, 24.0]:
            var nozzle := Vector2(x, -43)
            draw_line(nozzle, nozzle + Vector2(0, -reverse_jet),
                Color(0.15, 0.62, 1.0, 0.38), 12.0, true)
            draw_line(nozzle, nozzle + Vector2(0, -reverse_jet * 0.78),
                Color(0.43, 0.85, 1.0, 0.95), 5.5, true)
            draw_line(nozzle, nozzle + Vector2(0, -reverse_jet * 0.52),
                Color(0.92, 0.99, 1.0, 0.95), 2.2, true)
            draw_circle(nozzle, 5.0, Color(0.61, 0.92, 1.0, 0.85))

    var hull := PackedVector2Array([
        Vector2(0, -64), Vector2(18, -53), Vector2(29, -33),
        Vector2(37, 29), Vector2(27, 52), Vector2(-27, 52),
        Vector2(-37, 29), Vector2(-29, -33), Vector2(-18, -53)
    ])
    if player_shields > 0.0:
        var shield_alpha := 0.78 if player_shield_flash > 0.0 else 0.14
        draw_arc(Vector2.ZERO, 73.0, 0.0, TAU, 56,
            Color(0.32, 0.76, 1.0, shield_alpha), 3.3 if player_shield_flash > 0.0 else 2.0, true)
    draw_colored_polygon(hull, Color(0.13, 0.24, 0.31))
    draw_polyline(PackedVector2Array([
        hull[0], hull[1], hull[2], hull[3], hull[4],
        hull[5], hull[6], hull[7], hull[8], hull[0]
    ]), Color(0.63, 0.80, 0.89), 2.5, true)
    draw_line(Vector2(0, -55), Vector2(0, 41), Color(0.35, 0.55, 0.65), 3.0, true)
    draw_rect(Rect2(-15, -24, 30, 45), Color(0.19, 0.34, 0.44), true)
    draw_rect(Rect2(-10, -18, 20, 26), Color(0.20, 0.57, 0.70), true)
    for y in [-21.0, 21.0]:
        for side in [-1.0, 1.0]:
            var gun_color := PORT_COLOR if side < 0.0 else STARBOARD_COLOR
            draw_line(Vector2(side * 29, y), Vector2(side * 51, y), gun_color, 6.0, true)
            draw_circle(Vector2(side * 34, y), 6.0, Color(0.12, 0.20, 0.25))
            if (side < 0.0 and port_flash > 0.0) or (side > 0.0 and starboard_flash > 0.0):
                draw_line(Vector2(side * 50, y), Vector2(side * 66, y), gun_color, 4.0, true)
    draw_circle(Vector2(0, -54), 9.0, Color(0.15, 0.33, 0.43))
    var progress := charge / CHARGE_SECONDS
    if progress > 0.0:
        draw_circle(Vector2(0, -59), 4.0 + progress * 12.0, Color(0.24, 0.78, 1.0, 0.23 + 0.25 * progress))
        draw_circle(Vector2(0, -59), 2.5 + progress * 5.0, BEAM_COLOR)
    draw_set_transform(camera_offset, 0.0, Vector2.ONE * view_zoom)

func draw_shots() -> void:
    for bullet in shots:
        var position: Vector2 = bullet["pos"]
        var direction: Vector2 = Vector2(bullet["vel"]).normalized()
        var tint := Color(1.0, 0.28, 0.23) if bool(bullet["hostile"]) else (
            PORT_COLOR if float(bullet["side"]) < 0.0 else STARBOARD_COLOR)
        draw_line(position - direction * 10.0, position + direction * 3.0, tint, 3.0, true)

func draw_beam() -> void:
    if beam_path.size() < 2:
        return
    var accumulated := 0.0
    var head: Vector2 = beam_path[0]
    for i in range(1, beam_path.size()):
        var start := beam_path[i - 1]
        var finish := beam_path[i]
        var section := start.distance_to(finish)
        if accumulated >= beam_visible:
            break
        var part := minf(1.0, (beam_visible - accumulated) / maxf(section, 0.001))
        finish = start.lerp(finish, part)
        draw_line(start, finish, Color(0.11, 0.54, 1.0, 0.24), 15.0, true)
        draw_line(start, finish, Color(0.23, 0.82, 1.0, 0.80), 6.0, true)
        draw_line(start, finish, Color(0.93, 1.0, 1.0), 2.3, true)
        head = finish
        accumulated += section
    draw_circle(head, 8.0, Color(0.20, 0.74, 1.0, 0.32))
    draw_circle(head, 3.7, Color(0.94, 1.0, 1.0))
    if beam_absorption_timer > 0.0:
        var flare := clampf(beam_absorption_timer / 0.48, 0.0, 1.0)
        draw_circle(beam_absorption_point, 16.0 + (1.0 - flare) * 14.0, Color(0.13, 0.68, 1.0, flare * 0.46))
        draw_arc(beam_absorption_point, 22.0 + (1.0 - flare) * 18.0,
            0.0, TAU, 28, Color(0.84, 0.97, 1.0, flare), 3.0, true)

func draw_impacts() -> void:
    for impact in impacts:
        var centre: Vector2 = impact["pos"]
        var life: float = impact["life"]
        var tint: Color = impact["color"]
        tint.a = clampf(life / 0.32, 0.0, 1.0)
        draw_arc(centre, (0.32 - life) * 58.0 + 3.0, 0.0, TAU, 16, tint, 2.0, true)

func draw_debris() -> void:
    for fragment in debris:
        var pos: Vector2 = fragment["pos"]
        var vel: Vector2 = fragment["vel"]
        var color: Color = fragment["color"]
        color.a = float(fragment["life"]) / float(fragment["max_life"])
        draw_line(pos, pos + vel.normalized() * 9.0, color, 3.0, true)

func draw_hud() -> void:
    var font := ThemeDB.fallback_font
    draw_rect(Rect2(0, 0, 1200, 103), Color(0.012, 0.022, 0.043, 0.91), true)
    draw_rect(Rect2(0, 690, 1200, 110), Color(0.012, 0.022, 0.043, 0.91), true)
    draw_string(font, Vector2(25, 30), "FLEET COMMAND / FIRST CONTACT", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, WHITE)
    draw_string(font, Vector2(25, 57), "AUTO-TRACKING BROADSIDES  •  TWO HOSTILE VESSELS  •  ONE HEAVY FLAGSHIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
    var port_status := "ON" if port_order else "OFF"
    var star_status := "ON" if starboard_order else "OFF"
    var port_lock: String = String(targets[port_target]["name"]) if port_target >= 0 else "STRAIGHT FIRE"
    var star_lock: String = String(targets[starboard_target]["name"]) if starboard_target >= 0 else "STRAIGHT FIRE"
    if port_order and choose_hostile_missile(-1.0) >= 0:
        port_lock = "POINT DEFENCE"
    if starboard_order and choose_hostile_missile(1.0) >= 0:
        star_lock = "POINT DEFENCE"
    draw_string(font, Vector2(25, 87), "PORT  %s  [%02d]  %s" % [port_status, int(port_ammo), port_lock],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 14, PORT_COLOR if port_order else MUTED)
    draw_string(font, Vector2(378, 87), "STBD  %s  [%02d]  %s" % [star_status, int(starboard_ammo), star_lock],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 14, STARBOARD_COLOR if starboard_order else MUTED)

    var charge_ratio := charge / CHARGE_SECONDS
    var bar_pos := Vector2(880, 27)
    draw_string(font, bar_pos + Vector2(0, -1), "BOW BEAM", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, BEAM_COLOR)
    draw_rect(Rect2(bar_pos + Vector2(0, 10), Vector2(180, 11)), Color(0.10, 0.19, 0.27), true)
    draw_rect(Rect2(bar_pos + Vector2(0, 10), Vector2(180 * charge_ratio, 11)), BEAM_COLOR, true)
    var beam_status: String = ("%.1f S TO FIRE" % maxf(0.0, CHARGE_SECONDS - charge)) if beam_charging else (
        "RECHARGING" if beam_recovery > 0.0 else "Y / SPACE TO ARM")
    draw_string(font, Vector2(880, 79), beam_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, WHITE)
    var missile_status := "READY  [4]" if missile_cooldown <= 0.0 else "RELOAD %.1fs" % missile_cooldown
    draw_string(font, Vector2(880, 99), "AFT MISSILES  " + missile_status,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PORT_COLOR)
    draw_string(font, Vector2(1093, 29), "%d FPS" % Engine.get_frames_per_second(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
    if sound_message_timer > 0.0:
        draw_string(font, Vector2(355, 130), sound_message, HORIZONTAL_ALIGNMENT_CENTER, 520, 19, WHITE)

    draw_string(font, Vector2(25, 720), "HULL %02d/%02d" % [int(player_hull), int(PLAYER_MAX_HULL)],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 15, PORT_COLOR)
    draw_rect(Rect2(168, 705, 140, 10), Color(0.07, 0.11, 0.17), true)
    draw_rect(Rect2(168, 705, 140 * player_hull / PLAYER_MAX_HULL, 10), PORT_COLOR, true)
    var shield_label := "SHIELDS OFFLINE" if player_shields <= 0.0 else (
        "SHIELDS %02d/%02d" % [int(player_shields), int(PLAYER_MAX_SHIELDS)])
    draw_string(font, Vector2(331, 720), shield_label,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 15, PORT_COLOR if player_shields <= 0.0 else STARBOARD_COLOR)
    draw_rect(Rect2(498, 705, 140, 10), Color(0.07, 0.11, 0.17), true)
    draw_rect(Rect2(498, 705, 140 * player_shields / PLAYER_MAX_SHIELDS, 10), STARBOARD_COLOR, true)
    draw_string(font, Vector2(667, 720), "SPEED %03d  |  ZOOM %.2f" % [roundi(velocity.length()), view_zoom],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
    if braking and not player_destroyed:
        draw_string(font, Vector2(882, 720), "REVERSE THRUST",
            HORIZONTAL_ALIGNMENT_LEFT, -1, 14, STARBOARD_COLOR)
    draw_string(font, Vector2(25, 754), "LEFT STICK: TURN / FORWARD / REVERSE     X: PORT     B: STBD     Y: BEAM ARM/CANCEL     A: 4 MISSILES",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 15, WHITE)
    draw_string(font, Vector2(25, 782), "Keyboard: WASD steer/thrust/reverse   Q/E broadsides   Space beam arm/cancel   F missiles   C cease   V arcs   R reset",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
    if encounter_finished:
        draw_rect(Rect2(280, 303, 640, 126), Color(0.012, 0.026, 0.042, 0.90), true)
        draw_rect(Rect2(280, 303, 640, 126), Color(0.39, 0.72, 0.87), false, 2.0)
        draw_string(font, Vector2(310, 359), "FLAGSHIP DESTROYED" if player_destroyed else "VICTORY - ENEMY FLEET DEFEATED",
            HORIZONTAL_ALIGNMENT_CENTER, 580, 25, WHITE)
        draw_string(font, Vector2(310, 399), "PRESS R TO RESTART", HORIZONTAL_ALIGNMENT_CENTER, 580, 18, MUTED)
    draw_radar()

func draw_radar() -> void:
    var chart := Rect2(1044, 564, 128, 90)
    draw_rect(chart, Color(0.04, 0.08, 0.13, 0.88), true)
    draw_rect(chart, Color(0.32, 0.49, 0.56, 0.8), false, 1.0)
    for rock in asteroids:
        var normalized: Vector2 = Vector2(rock["pos"]) / FIELD.size
        draw_circle(chart.position + normalized * chart.size, 1.1, Color(0.33, 0.41, 0.46))
    draw_circle(chart.position + GRAVITY_CENTER / FIELD.size * chart.size, 2.0, Color(0.55, 0.42, 0.85))
    for target in targets:
        if not bool(target["destroyed"]):
            draw_circle(chart.position + Vector2(target["pos"]) / FIELD.size * chart.size, 2.4, Color(0.98, 0.51, 0.43))
    draw_circle(chart.position + ship_pos / FIELD.size * chart.size, 3.1, Color(0.52, 0.96, 1.0))
    var font := ThemeDB.fallback_font
    draw_string(font, chart.position + Vector2(1, -7), "THEATRE OVERVIEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
