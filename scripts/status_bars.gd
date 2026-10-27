extends RefCounted

# World-space mini-bars appear only after either pool is damaged.
static func draw_for(actor: CanvasItem, hull: float, max_hull: float, shields: float, max_shields: float, y: float = -26.0, center: Vector2 = Vector2.ZERO) -> void:
	if hull >= max_hull - 0.001 and shields >= max_shields - 0.001:
		return
	var width := 32.0
	var left := center.x - width / 2.0
	y += center.y
	var hp_ratio := clampf(hull / maxf(max_hull, 0.001), 0.0, 1.0)
	var shield_ratio := clampf(shields / maxf(max_shields, 0.001), 0.0, 1.0)
	actor.draw_rect(Rect2(left - 1.0, y - 1.0, width + 2.0, 11.0), Color(0.02, 0.05, 0.08, 0.82), true)
	actor.draw_rect(Rect2(left, y, width, 3.0), Color(0.17, 0.21, 0.22), true)
	actor.draw_rect(Rect2(left, y, width * hp_ratio, 3.0), Color(0.43, 0.95, 0.47), true)
	actor.draw_rect(Rect2(left, y + 5.0, width, 3.0), Color(0.11, 0.18, 0.23), true)
	if max_shields > 0.0:
		actor.draw_rect(Rect2(left, y + 5.0, width * shield_ratio, 3.0), Color(0.28, 0.69, 1.0), true)
