class_name FactoryLandmarkVisual
extends Control

const INK := Color(0.68, 0.88, 1.0, 1.0)
const DIM_INK := Color(0.24, 0.62, 0.78, 0.72)
const DEPOSIT_OFFSETS := [
	Vector2(0.0, 0.0),
	Vector2(-43.0, -24.0),
	Vector2(43.0, -22.0),
	Vector2(-38.0, 28.0),
	Vector2(39.0, 29.0),
	Vector2(0.0, -39.0),
	Vector2(1.0, 40.0),
]

var landmark_kind: StringName = &"circle"


func configure(next_kind: StringName) -> void:
	landmark_kind = next_kind
	custom_minimum_size = Vector2(152.0, 120.0) if landmark_kind != &"summoner" else Vector2(188.0, 166.0)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	if landmark_kind == &"summoner":
		_draw_summoner(center)
		return
	_draw_material_deposit(center)


func _draw_material_deposit(center: Vector2) -> void:
	var field_points := PackedVector2Array([
		center + Vector2(-61.0, -20.0),
		center + Vector2(-24.0, -51.0),
		center + Vector2(29.0, -48.0),
		center + Vector2(63.0, -14.0),
		center + Vector2(55.0, 35.0),
		center + Vector2(7.0, 53.0),
		center + Vector2(-50.0, 39.0),
	])
	draw_colored_polygon(field_points, Color(0.02, 0.10, 0.14, 0.58))
	draw_polyline(field_points + PackedVector2Array([field_points[0]]), Color(0.20, 0.62, 0.78, 0.26), 1.0, true)
	for index in DEPOSIT_OFFSETS.size():
		var is_center := index == 0
		var radius := 12.0 if is_center else 7.0
		var color := INK if is_center else Color(DIM_INK, 0.68)
		_draw_material_shape(center + DEPOSIT_OFFSETS[index], radius, color, 2.0 if is_center else 1.25)


func _draw_material_shape(center: Vector2, radius: float, color: Color, width: float) -> void:
	match landmark_kind:
		&"circle":
			draw_arc(center, radius, 0.0, TAU, 32, color, width, true)
		&"triangle":
			var points := PackedVector2Array()
			for index in 3:
				points.append(center + Vector2.from_angle(-PI * 0.5 + TAU * float(index) / 3.0) * radius)
			points.append(points[0])
			draw_polyline(points, color, width, true)
		&"square":
			var rect := Rect2(center - Vector2.ONE * radius * 0.72, Vector2.ONE * radius * 1.44)
			draw_rect(rect, color, false, width, true)


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
