class_name FactoryLandmarkVisual
extends Control

const INK := Color(0.68, 0.88, 1.0, 1.0)
const DIM_INK := Color(0.24, 0.62, 0.78, 0.72)

var landmark_kind: StringName = &"circle"


func configure(next_kind: StringName) -> void:
	landmark_kind = next_kind
	custom_minimum_size = Vector2(132.0, 112.0) if landmark_kind != &"summoner" else Vector2(188.0, 166.0)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	if landmark_kind == &"summoner":
		_draw_summoner(center)
		return
	var radius := minf(size.x, size.y) * 0.25
	draw_circle(center, radius + 22.0, Color(0.025, 0.09, 0.13, 0.55), true)
	draw_arc(center, radius + 22.0, 0.0, TAU, 64, Color(0.20, 0.62, 0.78, 0.34), 1.0)
	match landmark_kind:
		&"circle":
			draw_arc(center, radius, 0.0, TAU, 64, INK, 2.0, true)
		&"triangle":
			var points := PackedVector2Array()
			for index in 3:
				points.append(center + Vector2.from_angle(-PI * 0.5 + TAU * float(index) / 3.0) * radius)
			points.append(points[0])
			draw_polyline(points, INK, 2.0, true)
		&"square":
			var rect := Rect2(center - Vector2.ONE * radius * 0.72, Vector2.ONE * radius * 1.44)
			draw_rect(rect, INK, false, 2.0, true)


func _draw_summoner(center: Vector2) -> void:
	var radius := minf(size.x, size.y) * 0.36
	draw_circle(center, radius + 18.0, Color(0.02, 0.12, 0.16, 0.72), true)
	for ring_scale in [1.0, 0.68, 0.32]:
		draw_arc(center, radius * ring_scale, 0.0, TAU, 96, INK if ring_scale == 1.0 else DIM_INK, 2.0 if ring_scale == 1.0 else 1.0, true)
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var inner := center + Vector2.from_angle(angle) * radius * 0.72
		var outer := center + Vector2.from_angle(angle) * radius * 1.18
		draw_line(inner, outer, DIM_INK, 1.0, true)
		draw_circle(outer, 2.5, INK, true)
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.43),
		center + Vector2(radius * 0.43, 0.0),
		center + Vector2(0.0, radius * 0.43),
		center + Vector2(-radius * 0.43, 0.0),
		center + Vector2(0.0, -radius * 0.43),
	])
	draw_polyline(diamond, INK, 1.5, true)
