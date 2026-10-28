extends Node2D
## Isolated Fleet Command handling / gunnery range.
## The classic Omega War scripts and scene remain unchanged on this branch.

const SoundBus = preload("res://scripts/sound_bus.gd")
const Environment = preload("res://scripts/fleet_environment.gd")
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
var shots: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
var targets: Array[Dictionary] = []
var asteroids: Array[Dictionary] = []
var environment := Environment.new()
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
    key_action("fc_zoom_out", KEY_MINUS)
    key_action("fc_zoom_in", KEY_EQUAL)
    pad_button("fc_thrust", JOY_BUTTON_A)
    pad_button("fc_brake", JOY_BUTTON_B)
    pad_button("fc_port", JOY_BUTTON_X)
    pad_button("fc_starboard", JOY_BUTTON_Y)
    pad_button("fc_turn_left", JOY_BUTTON_DPAD_LEFT)
    pad_button("fc_turn_right", JOY_BUTTON_DPAD_RIGHT)
    pad_axis("fc_turn_left", JOY_AXIS_LEFT_X, -1.0)
    pad_axis("fc_turn_right", JOY_AXIS_LEFT_X, 1.0)
    pad_axis("fc_thrust", JOY_AXIS_LEFT_Y, -1.0)
    pad_axis("fc_brake", JOY_AXIS_LEFT_Y, 1.0)
    pad_axis("fc_beam", JOY_AXIS_TRIGGER_RIGHT, 1.0)

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
    # Other capital-sized hulls in the starting view, deliberately inert
    # until real fleet AI is introduced. Full HP/respawn gunnery targets.
    targets = [
        {"pos": Vector2(3350, 2100), "angle": -0.9, "hp": 42.0, "max_hp": 42.0, "respawn": 0.0, "flash": 0.0, "name": "TARGET CRUISER ALPHA"},
        {"pos": Vector2(2450, 1650), "angle": 0.27, "hp": 36.0, "max_hp": 36.0, "respawn": 0.0, "flash": 0.0, "name": "TARGET CRUISER BETA"},
        {"pos": Vector2(2490, 2550), "angle": -0.32, "hp": 36.0, "max_hp": 36.0, "respawn": 0.0, "flash": 0.0, "name": "TARGET CRUISER GAMMA"}
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

func _physics_process(delta: float) -> void:
    time_passed += delta
    sound_bus.advance(delta)
    if Input.is_action_just_pressed("fc_reset"):
        reset_test()
    if Input.is_action_just_pressed("fc_zoom_out"):
        view_zoom = maxf(0.38, view_zoom - 0.07)
    if Input.is_action_just_pressed("fc_zoom_in"):
        view_zoom = minf(0.78, view_zoom + 0.07)

    beam_recovery = maxf(0.0, beam_recovery - delta)
    port_cooldown = maxf(0.0, port_cooldown - delta)
    starboard_cooldown = maxf(0.0, starboard_cooldown - delta)
    port_flash = maxf(0.0, port_flash - delta)
    starboard_flash = maxf(0.0, starboard_flash - delta)

    var holding_beam := Input.is_action_pressed("fc_beam")
    if holding_beam and beam_recovery <= 0.0 and beam_path.is_empty():
        charge = minf(CHARGE_SECONDS, charge + delta)
        beam_held = true
    elif not holding_beam and beam_held:
        if charge >= 0.28:
            fire_beam(charge / CHARGE_SECONDS)
        charge = 0.0
        beam_held = false

    update_ship(delta)
    camera_pos = camera_pos.lerp(ship_pos, 1.0 - exp(-2.5 * delta))
    var half_view := VIEW_SIZE * (0.5 / view_zoom)
    camera_pos.x = clampf(camera_pos.x, FIELD.position.x + half_view.x, FIELD.end.x - half_view.x)
    camera_pos.y = clampf(camera_pos.y, FIELD.position.y + half_view.y, FIELD.end.y - half_view.y)
    update_environment_transform()
    if Input.is_action_pressed("fc_port") and port_cooldown <= 0.0:
        fire_broadside(-1.0)
        port_cooldown = BROADSIDE_INTERVAL
        port_flash = 0.12
    if Input.is_action_pressed("fc_starboard") and starboard_cooldown <= 0.0:
        fire_broadside(1.0)
        starboard_cooldown = BROADSIDE_INTERVAL
        starboard_flash = 0.12

    advance_shots(delta)
    advance_beam(delta)
    advance_targets(delta)
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

func fire_broadside(side: float) -> void:
    var outward := Vector2(side, 0.0).rotated(ship_angle)
    for station in [-21.0, 21.0]:
        var muzzle := ship_pos + Vector2(side * 48.0, station).rotated(ship_angle)
        var direction := outward.rotated((station / 21.0) * 0.025 * side)
        shots.append({
            "pos": muzzle, "previous": muzzle, "vel": direction * SHELL_SPEED,
            "life": 2.0, "side": side
        })
    sound_bus.play("pulse")

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
            for j in range(targets.size()):
                if float(targets[j]["hp"]) <= 0.0:
                    continue
                var target_pos: Vector2 = targets[j]["pos"]
                var near: Vector2 = Geometry2D.get_closest_point_to_segment(target_pos, old, next)
                if near.distance_squared_to(target_pos) <= 50.0 * 50.0:
                    damage_target(j, 1.0, near)
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

func damage_target(index: int, damage: float, at: Vector2) -> void:
    targets[index]["hp"] = maxf(0.0, float(targets[index]["hp"]) - damage)
    targets[index]["flash"] = 0.20
    impacts.append({"pos": at, "life": 0.32, "color": BEAM_COLOR if damage > 1.5 else PORT_COLOR})
    if float(targets[index]["hp"]) <= 0.0:
        targets[index]["respawn"] = 3.0
        sound_bus.play("explosion")

func advance_targets(delta: float) -> void:
    for target in targets:
        target["flash"] = maxf(0.0, float(target["flash"]) - delta)
        if float(target["hp"]) <= 0.0:
            target["respawn"] = maxf(0.0, float(target["respawn"]) - delta)
            if float(target["respawn"]) <= 0.0:
                target["hp"] = target["max_hp"]

func update_environment_transform() -> void:
    # Moving/scaling a CanvasItem does not rebuild its cached draw commands.
    camera_offset = VIEW_SIZE * 0.5 - camera_pos * view_zoom
    environment.position = camera_offset
    environment.scale = Vector2.ONE * view_zoom

func _draw() -> void:
    # Only moving objects and UI are redrawn every frame. The background is
    # a show_behind_parent child with independently cached draw commands.
    draw_set_transform(camera_offset, 0.0, Vector2.ONE * view_zoom)
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
        var centre: Vector2 = target["pos"]
        var angle: float = target["angle"]
        var alive := float(target["hp"]) > 0.0
        var hull_color := Color(0.44, 0.21, 0.24) if alive else Color(0.16, 0.19, 0.23)
        var edge_color := Color(0.93, 0.54, 0.51) if alive else Color(0.32, 0.36, 0.40)
        if float(target["flash"]) > 0.0:
            edge_color = Color(1.0, 0.96, 0.76)
        # Capital-ship silhouette at the same world scale as the flagship.
        var points := PackedVector2Array()
        for local in [
            Vector2(0, -61), Vector2(23, -43), Vector2(30, -10),
            Vector2(39, 23), Vector2(23, 55), Vector2(-23, 55),
            Vector2(-39, 23), Vector2(-30, -10), Vector2(-23, -43)
        ]:
            points.append(centre + local.rotated(angle))
        draw_colored_polygon(points, hull_color)
        var closed := points.duplicate()
        closed.append(points[0])
        draw_polyline(closed, edge_color, 3.5, true)
        draw_line(centre + Vector2(0, -46).rotated(angle),
            centre + Vector2(0, 40).rotated(angle), edge_color.darkened(0.25), 4.0, true)
        for side in [-1.0, 1.0]:
            for y in [-22.0, 20.0]:
                draw_line(centre + Vector2(side * 27, y).rotated(angle),
                    centre + Vector2(side * 45, y).rotated(angle), edge_color, 4.0, true)
        draw_string(font, centre + Vector2(-91, -91), String(target["name"]),
            HORIZONTAL_ALIGNMENT_LEFT, -1, 20, MUTED)
        var ratio := float(target["hp"]) / float(target["max_hp"])
        draw_rect(Rect2(centre + Vector2(-60, 69), Vector2(120, 7)), Color(0.08, 0.13, 0.18), true)
        draw_rect(Rect2(centre + Vector2(-60, 69), Vector2(120 * ratio, 7)), edge_color, true)

func draw_ship() -> void:
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
        var tint := PORT_COLOR if float(bullet["side"]) < 0.0 else STARBOARD_COLOR
        draw_line(position - direction * 8.0, position + direction * 3.0, tint, 3.0, true)

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
    draw_string(font, Vector2(32, 36), "FLEET COMMAND  /  OPEN-THEATRE SCALE TEST", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, WHITE)
    draw_string(font, Vector2(32, 62), "6,000 x 4,200 THEATRE   •   3 INERT CAPITAL TARGETS   •   ASTEROIDS + GRAVITY   •   NO AFT GUNS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
    var charge_ratio := charge / CHARGE_SECONDS
    var bar_pos := Vector2(815, 31)
    draw_string(font, bar_pos + Vector2(0, -1), "BOW BEAM CHARGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, BEAM_COLOR)
    draw_rect(Rect2(bar_pos + Vector2(0, 12), Vector2(245, 15)), Color(0.10, 0.19, 0.27), true)
    draw_rect(Rect2(bar_pos + Vector2(0, 12), Vector2(245 * charge_ratio, 15)), BEAM_COLOR, true)
    var beam_status := "RELEASE TO FIRE" if charge > 0.0 else ("RECHARGING" if beam_recovery > 0.0 else "HOLD SPACE")
    if charge_ratio >= 0.999:
        beam_status = "FULL - SHIP STOPPED"
    draw_string(font, Vector2(815, 83), beam_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, WHITE)
    var velocity_text := "SPEED  %03d / %03d   TURN  %02d deg/s" % [roundi(velocity.length()), roundi(MAX_SPEED), roundi(absf(rad_to_deg(angular_velocity)))]
    draw_string(font, Vector2(32, 713), "CAMERA %.2fx   •   THEATRE 6000 x 4200   •   POSITION %d / %d" % [view_zoom, roundi(ship_pos.x), roundi(ship_pos.y)], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
    draw_string(font, Vector2(32, 738), velocity_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, WHITE)
    draw_string(font, Vector2(32, 768), "W/S thrust/brake  •  A/D turn  •  Q/E broadsides  •  HOLD/RELEASE SPACE beam  •  - / = zoom  •  R reset", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTED)
    draw_string(font, Vector2(32, 790), "Gamepad: left stick steer / thrust, A thrust, B brake, X/Y broadsides, RT beam. Cruiser targets respawn.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
    draw_string(font, Vector2(1095, 36), "%d FPS" % Engine.get_frames_per_second(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
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
        if float(target["hp"]) > 0.0:
            draw_circle(chart.position + Vector2(target["pos"]) / FIELD.size * chart.size, 2.4, Color(0.98, 0.51, 0.43))
    draw_circle(chart.position + ship_pos / FIELD.size * chart.size, 3.1, Color(0.52, 0.96, 1.0))
    var font := ThemeDB.fallback_font
    draw_string(font, chart.position + Vector2(1, -7), "THEATRE OVERVIEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
