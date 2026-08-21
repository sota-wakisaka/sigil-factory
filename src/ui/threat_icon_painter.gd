extends RefCounted


static func draw_enemy(canvas: CanvasItem, center: Vector2, kind: StringName, color: Color, scale := 1.0) -> void:
	match kind:
		&"swarm":
			for offset in [Vector2(-5, 3), Vector2(0, -5), Vector2(5, 3)]:
				canvas.draw_circle(center + offset * scale, 3.0 * scale, color)
		&"brute":
			var points := PackedVector2Array([
				center + Vector2(-8, -7) * scale, center + Vector2(8, -7) * scale,
				center + Vector2(6, 6) * scale, center + Vector2(0, 10) * scale,
				center + Vector2(-6, 6) * scale,
			])
			canvas.draw_polyline(points, color, 2.0 * scale, true)
			canvas.draw_line(points[points.size() - 1], points[0], color, 2.0 * scale, true)
		_:
			var points := PackedVector2Array([
				center + Vector2(0, -9) * scale, center + Vector2(9, 7) * scale,
				center + Vector2(-9, 7) * scale, center + Vector2(0, -9) * scale,
			])
			canvas.draw_polyline(points, color, 2.0 * scale, true)
