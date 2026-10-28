extends Node2D
## Stationary Fleet Command scenery drawn into a cached CanvasItem.
## Moving the parent Node2D for camera tracking does NOT rerun _draw.
## The active flagship, weapons and HUD are drawn separately each frame.

const STAR_COUNT := 850

var battlefield := Rect2(0.0, 0.0, 6000.0, 4200.0)
var well_pos := Vector2(4490.0, 2310.0)
var well_radius := 520.0
var stars := PackedVector2Array()

func configure(bounds: Rect2, gravity_position: Vector2, gravity_radius: float, rocks: Array[Dictionary]) -> void:
    battlefield = bounds
    well_pos = gravity_position
    well_radius = gravity_radius
    # Rocks are now destructible/dynamic and rendered by Fleet Command.
    stars.clear()
    var rng := RandomNumberGenerator.new()
    rng.seed = 48672
    for i in range(STAR_COUNT):
        stars.append(Vector2(
            rng.randf_range(battlefield.position.x + 8.0, battlefield.end.x - 8.0),
            rng.randf_range(battlefield.position.y + 8.0, battlefield.end.y - 8.0)))
    queue_redraw()

func _draw() -> void:
    # Godot caches these drawing commands. Only the transform changes while flying.
    draw_rect(battlefield, Color(0.015, 0.025, 0.048), true)
    for x in range(0, int(battlefield.size.x) + 1, 400):
        draw_line(Vector2(x, 0), Vector2(x, battlefield.end.y),
            Color(0.10, 0.17, 0.23, 0.22), 1.0)
    for y in range(0, int(battlefield.size.y) + 1, 400):
        draw_line(Vector2(0, y), Vector2(battlefield.end.x, y),
            Color(0.10, 0.17, 0.23, 0.22), 1.0)
    for i in range(stars.size()):
        var brightness := 0.15 + float(i % 5) * 0.045
        draw_circle(stars[i], 1.2 if i % 4 else 2.1,
            Color(brightness, brightness + 0.07, brightness + 0.15))
    draw_rect(battlefield, Color(0.24, 0.38, 0.45, 0.48), false, 7.0)
    draw_gravity_well()

func draw_gravity_well() -> void:
    for r in [520.0, 365.0, 240.0, 125.0, 66.0]:
        draw_arc(well_pos, r, 0.0, TAU, 90,
            Color(0.35, 0.32, 0.72, 0.13 if r >= 240.0 else 0.28), 2.8, true)
    draw_circle(well_pos, 32.0, Color(0.005, 0.007, 0.018))
    draw_arc(well_pos, 35.0, 0.0, TAU, 42, Color(0.54, 0.41, 0.92, 0.60), 4.0, true)
