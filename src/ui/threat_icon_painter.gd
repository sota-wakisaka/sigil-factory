extends RefCounted


static func draw_enemy(canvas: CanvasItem, center: Vector2, kind: StringName, color: Color, scale := 1.0) -> void:
	match shape_id(kind):
		&"triangle":
			var points := PackedVector2Array([
				center + Vector2(0, -9) * scale,
				center + Vector2(9, 7) * scale,
				center + Vector2(-9, 7) * scale,
				center + Vector2(0, -9) * scale,
			])
			canvas.draw_polyline(points, color, 2.0 * scale, true)
		&"square":
			canvas.draw_rect(
				Rect2(center - Vector2(8, 8) * scale, Vector2(16, 16) * scale),
				color,
				false,
				2.0 * scale
			)
		_:
			canvas.draw_arc(center, 8.0 * scale, 0.0, TAU, 20, color, 2.0 * scale, true)


static func shape_id(kind: StringName) -> StringName:
	match kind:
		&"swarm":
			return &"triangle"
		&"brute":
			return &"square"
	return &"circle"
