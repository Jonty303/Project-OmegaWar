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
const CHARGE_SECONDS := 2.4
const BROADSIDE_INTERVAL := 0.56
const SHELL_SPEED := 390.0
const BEAM_EXPAND_SPEED := 1450.0
const BATTERY_RANGE := 800.0
const BATTERY_HALF_ARC := deg_to_rad(60.0)
const TRACKING_HALF_ARC := deg_to_rad(75.0)
const BOW_HALF_ARC := deg_to_rad(10.0)
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
var beam_held := false
var beam_recovery := 0.0
var beam_path: PackedVector2Array = PackedVector2Array()
var beam_visible := 0.0
var beam_total := 0.0
var beam_linger := 0.0
var beam_power := 0.0
var beam_hit_targets: Dictionary = {}
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
var encounter_finished := false
var player_destroyed := false
var show_arcs := false
var sound_message := ""
var sound_message_timer := 0.0
var shots: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
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
    key_action("fc_arcs", KEY_V)
    key_action("fc_zoom_out", KEY_MINUS)
    key_action("fc_zoom_in", KEY_EQUAL)
    # Left-stick axes handle all piloting. Face buttons exclusively issue
    # weapon orders: X port, B starboard, Y charge beam, A cease fire.
    pad_button("fc_port", JOY_BUTTON_X)
    pad_button("fc_starboard", JOY_BUTTON_B)
    pad_button("fc_beam", JOY_BUTTON_Y)
    pad_button("fc_cease", JOY_BUTTON_A)
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
            "destroyed": false}
    ]

func reset_test() -> void:
    ship_pos = Vector2(2500.0, 2100.0)
    camera_pos = ship_pos
    view_zoom = INITIAL_ZOOM
    ship_angle = PI / 2.0
    velocity = Vector2.ZERO
    angular_velocity = 0.0
    charge = 0.0
    beam_held = false
    beam_recovery = 0.0
    beam_path.clear()
    port_cooldown = 0.0
    starboard_cooldown = 0.0
    shots.clear()
    impacts.clear()
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

    var holding_beam := Input.is_action_pressed("fc_beam")
    if not encounter_finished and holding_beam and beam_recovery <= 0.0 and beam_path.is_empty():
        charge = minf(CHARGE_SECONDS, charge + delta)
        beam_held = true
    elif not holding_beam and beam_held:
        if charge >= 0.28 and not encounter_finished:
            fire_beam(charge / CHARGE_SECONDS)
        charge = 0.0
        beam_held = false

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
    advance_beam(delta)
    recharge_shields(delta)
    check_encounter_result()
    for i in range(impacts.size() - 1, -1, -1):
        impacts[i]["life"] = float(impacts[i]["life"]) - delta
        if float(impacts[i]["life"]) <= 0.0:
            impacts.remove_at(i)
    queue_redraw()

func update_ship(delta: float) -> void:
    var turn_input := Input.get_axis("fc_turn_left", "fc_turn_right")
    var progress := charge / CHARGE_SECONDS
    var desired_turn := turn_input * TURN_SPEED * (1.0 - 0.47 * progress)
    angular_velocity = move_toward(angular_velocity, desired_turn, TURN_ACCEL * delta)
    ship_angle += angular_velocity * delta

    var throttle := Input.get_action_strength("fc_thrust")
    thrusting = throttle > 0.05
    var brake_input := Input.get_action_strength("fc_brake")
    braking = brake_input > 0.05
    if thrusting:
        velocity += Vector2.UP.rotated(ship_angle) * THRUST * throttle * (1.0 - progress) * delta
    velocity += gravity_at(ship_pos) * delta
    if braking:
        velocity = velocity.move_toward(Vector2.ZERO, BRAKE * brake_input * delta)
    # A charging spinal beam diverts propulsion power. At full charge,
    # the hull comes to a complete halt until the player releases it.
    if progress > 0.0:
        velocity = velocity.move_toward(Vector2.ZERO, (32.0 + 92.0 * progress) * delta)
        if progress >= 0.999:
            velocity = Vector2.ZERO
    velocity = velocity.limit_length(MAX_SPEED)
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
            ship_pos = centre + outward * minimum
            velocity = velocity.slide(outward) * 0.75

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
    fire_broadside(side, next_target)
    if side < 0.0:
        port_cooldown = BROADSIDE_INTERVAL
        port_ammo -= 2.0
        port_flash = 0.12
    else:
        starboard_cooldown = BROADSIDE_INTERVAL
        starboard_ammo -= 2.0
        starboard_flash = 0.12

func fire_broadside(side: float, selected: int = -1) -> void:
    var outward := Vector2(side, 0.0).rotated(ship_angle)
    var aim := outward
    if selected >= 0 and selected < targets.size():
        var requested: Vector2 = Vector2(targets[selected]["pos"]) - ship_pos
        if requested.length_squared() > 0.1 and arc_valid(ship_pos, outward, targets[selected]["pos"], BATTERY_HALF_ARC, BATTERY_RANGE) and line_clear(ship_pos, targets[selected]["pos"]):
            # Simple predictive lead on moving ships.
            var prediction := requested.length() / SHELL_SPEED
            aim = (requested + Vector2(targets[selected]["velocity"]) * prediction).normalized()
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
                future = Vector2(rock["pos"]) + outward * safe_radius
                vel = vel.slide(outward) * 0.65
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
        if float(enemy["reload"]) <= 0.0:
            fire_enemy(j)
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

func recharge_shields(delta: float) -> void:
    player_shield_delay = maxf(0.0, player_shield_delay - delta)
    if not player_destroyed and player_shield_delay <= 0.0:
        player_shields = minf(PLAYER_MAX_SHIELDS, player_shields + 1.5 * delta)
    for enemy in targets:
        if bool(enemy["destroyed"]):
            continue
        enemy["shield_delay"] = maxf(0.0, float(enemy["shield_delay"]) - delta)
        if float(enemy["shield_delay"]) <= 0.0:
            enemy["shields"] = minf(float(enemy["max_shields"]), float(enemy["shields"]) + 0.9 * delta)
        enemy["flash"] = maxf(0.0, float(enemy["flash"]) - delta)

func damage_player(amount: float, at: Vector2) -> void:
    if player_destroyed:
        return
    player_shield_delay = 4.0
    var absorbed := minf(player_shields, amount)
    player_shields -= absorbed
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
        var offset := Vector2.from_angle(a) * float((n % 4) + 1) * 9.0
        impacts.append({"pos": at + offset, "life": 0.32, "color": PORT_COLOR})

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
    beam_visible = 0.0
    beam_total = 0.0
    beam_linger = 0.30
    beam_recovery = 1.15

    var direction := Vector2.UP.rotated(ship_angle)
    var cursor := ship_pos + direction * 64.0
    beam_path.append(cursor)
    var requested_range := lerpf(340.0, 1150.0, power)
    var travelled := 0.0
    var rebounds := 0
    while travelled < requested_range:
        # A subtly wandering, growing beam rather than an instant straight ray.
        var waviness := sin(travelled * 0.027 + time_passed * 4.0) * 0.045
        var step_vector := direction.rotated(waviness) * 10.0
        var proposed := cursor + step_vector
        if not FIELD.has_point(proposed):
            if rebounds >= 2:
                break
            if proposed.x <= FIELD.position.x or proposed.x >= FIELD.end.x:
                direction.x = -direction.x
            if proposed.y <= FIELD.position.y or proposed.y >= FIELD.end.y:
                direction.y = -direction.y
            rebounds += 1
            proposed = cursor + direction * 10.0
            if not FIELD.has_point(proposed):
                break
        var absorbed := false
        for rock in asteroids:
            if proposed.distance_squared_to(Vector2(rock["pos"])) <= pow(float(rock["radius"]) + 4.0, 2.0):
                absorbed = true
                break
        if absorbed:
            break
        cursor = proposed
        beam_path.append(cursor)
        travelled += 10.0
    beam_total = travelled
    sound_bus.play("missile")

func advance_beam(delta: float) -> void:
    if beam_path.size() < 2:
        return
    beam_visible = minf(beam_total, beam_visible + BEAM_EXPAND_SPEED * delta)
    var length_drawn := 0.0
    for i in range(1, beam_path.size()):
        var start := beam_path[i - 1]
        var finish := beam_path[i]
        var section := start.distance_to(finish)
        if length_drawn >= beam_visible:
            break
        var portion := minf(1.0, (beam_visible - length_drawn) / maxf(section, 0.001))
        finish = start.lerp(finish, portion)
        for j in range(targets.size()):
            if beam_hit_targets.has(j) or float(targets[j]["hp"]) <= 0.0:
                continue
            var target_pos: Vector2 = targets[j]["pos"]
            var near := Geometry2D.get_closest_point_to_segment(target_pos, start, finish)
            if near.distance_squared_to(target_pos) <= 55.0 * 55.0:
                damage_target(j, 3.0 + 10.0 * beam_power, near)
                beam_hit_targets[j] = true
        length_drawn += section
    if beam_visible >= beam_total:
        beam_linger -= delta
        if beam_linger <= 0.0:
            beam_path.clear()

func damage_target(index: int, amount: float, at: Vector2) -> void:
    if bool(targets[index]["destroyed"]):
        return
    var enemy: Dictionary = targets[index]
    var absorbed := minf(float(enemy["shields"]), amount)
    enemy["shields"] = float(enemy["shields"]) - absorbed
    enemy["hp"] = maxf(0.0, float(enemy["hp"]) - (amount - absorbed))
    enemy["shield_delay"] = 4.0
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
    draw_targets()
    draw_shots()
    draw_ship()
    draw_beam()
    draw_impacts()
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
        draw_rect(Rect2(centre + Vector2(-56, 65), Vector2(112, 7)), Color(0.08, 0.13, 0.18), true)
        draw_rect(Rect2(centre + Vector2(-56, 65), Vector2(112 * hp_ratio, 7)), edge_color, true)
        draw_rect(Rect2(centre + Vector2(-56, 76), Vector2(112, 5)), Color(0.08, 0.13, 0.18), true)
        draw_rect(Rect2(centre + Vector2(-56, 76), Vector2(112 * shield_ratio, 5)), STARBOARD_COLOR, true)

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
    if braking:
        draw_line(Vector2(-25, -35), Vector2(-25, -46), Color(0.47, 0.79, 1.0), 3.0, true)
        draw_line(Vector2(25, -35), Vector2(25, -46), Color(0.47, 0.79, 1.0), 3.0, true)

    var hull := PackedVector2Array([
        Vector2(0, -64), Vector2(18, -53), Vector2(29, -33),
        Vector2(37, 29), Vector2(27, 52), Vector2(-27, 52),
        Vector2(-37, 29), Vector2(-29, -33), Vector2(-18, -53)
    ])
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

func draw_impacts() -> void:
    for impact in impacts:
        var centre: Vector2 = impact["pos"]
        var life: float = impact["life"]
        var tint: Color = impact["color"]
        tint.a = clampf(life / 0.32, 0.0, 1.0)
        draw_arc(centre, (0.32 - life) * 58.0 + 3.0, 0.0, TAU, 16, tint, 2.0, true)

func draw_hud() -> void:
    var font := ThemeDB.fallback_font
    draw_rect(Rect2(0, 0, 1200, 103), Color(0.012, 0.022, 0.043, 0.91), true)
    draw_rect(Rect2(0, 690, 1200, 110), Color(0.012, 0.022, 0.043, 0.91), true)
    draw_string(font, Vector2(25, 30), "FLEET COMMAND / FIRST CONTACT", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, WHITE)
    draw_string(font, Vector2(25, 57), "AUTO-TRACKING BROADSIDES  •  TWO HOSTILE VESSELS  •  ONE HEAVY FLAGSHIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
    var port_status := "ON" if port_order else "OFF"
    var star_status := "ON" if starboard_order else "OFF"
    var port_lock := targets[port_target]["name"] if port_target >= 0 else "STRAIGHT FIRE"
    var star_lock := targets[starboard_target]["name"] if starboard_target >= 0 else "STRAIGHT FIRE"
    draw_string(font, Vector2(25, 87), "PORT  %s  [%02d]  %s" % [port_status, int(port_ammo), port_lock],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 14, PORT_COLOR if port_order else MUTED)
    draw_string(font, Vector2(378, 87), "STBD  %s  [%02d]  %s" % [star_status, int(starboard_ammo), star_lock],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 14, STARBOARD_COLOR if starboard_order else MUTED)

    var charge_ratio := charge / CHARGE_SECONDS
    var bar_pos := Vector2(880, 27)
    draw_string(font, bar_pos + Vector2(0, -1), "BOW BEAM", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, BEAM_COLOR)
    draw_rect(Rect2(bar_pos + Vector2(0, 10), Vector2(180, 11)), Color(0.10, 0.19, 0.27), true)
    draw_rect(Rect2(bar_pos + Vector2(0, 10), Vector2(180 * charge_ratio, 11)), BEAM_COLOR, true)
    var beam_status := "RELEASE" if charge > 0.0 else ("RECHARGING" if beam_recovery > 0.0 else "HOLD Y / SPACE")
    if charge_ratio >= 0.999:
        beam_status = "READY - STOPPED"
    draw_string(font, Vector2(880, 79), beam_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, WHITE)
    draw_string(font, Vector2(1093, 29), "%d FPS" % Engine.get_frames_per_second(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
    if sound_message_timer > 0.0:
        draw_string(font, Vector2(355, 130), sound_message, HORIZONTAL_ALIGNMENT_CENTER, 520, 19, WHITE)

    draw_string(font, Vector2(25, 720), "HULL %02d/%02d" % [int(player_hull), int(PLAYER_MAX_HULL)],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 15, PORT_COLOR)
    draw_rect(Rect2(168, 705, 140, 10), Color(0.07, 0.11, 0.17), true)
    draw_rect(Rect2(168, 705, 140 * player_hull / PLAYER_MAX_HULL, 10), PORT_COLOR, true)
    draw_string(font, Vector2(331, 720), "SHIELDS %02d/%02d" % [int(player_shields), int(PLAYER_MAX_SHIELDS)],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 15, STARBOARD_COLOR)
    draw_rect(Rect2(498, 705, 140, 10), Color(0.07, 0.11, 0.17), true)
    draw_rect(Rect2(498, 705, 140 * player_shields / PLAYER_MAX_SHIELDS, 10), STARBOARD_COLOR, true)
    draw_string(font, Vector2(667, 720), "SPEED %03d  |  ZOOM %.2f" % [roundi(velocity.length()), view_zoom],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
    draw_string(font, Vector2(25, 754), "LEFT STICK: STEER / THRUST / BRAKE     X: PORT     B: STARBOARD     Y: CHARGE BEAM     A: CEASE FIRE",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 15, WHITE)
    draw_string(font, Vector2(25, 782), "Keyboard: WASD move   Q/E toggle batteries   Space beam   C cease   V show arcs   -/= zoom   R restart",
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
