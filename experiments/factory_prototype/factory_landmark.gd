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
var visual_mode: StringName = &"deposit"


func configure(next_kind: StringName) -> void:
	landmark_kind = next_kind
	if landmark_kind == &"summoner":
		visual_mode = &"summoner"
		custom_minimum_size = Vector2(176.0, 176.0)
	elif landmark_kind == &"relay":
		visual_mode = &"relay"
		custom_minimum_size = Vector2(118.0, 118.0)
	else:
		visual_mode = &"deposit"
		custom_minimum_size = Vector2(142.0, 142.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func configure_target(next_kind: StringName) -> void:
	landmark_kind = next_kind
	visual_mode = &"target"
	custom_minimum_size = Vector2(112.0, 112.0)
	queue_redraw()


func body_radius() -> float:
	var visual_size := size
	if visual_size.x <= 0.0 or visual_size.y <= 0.0:
		visual_size = custom_minimum_size
	if visual_mode == &"summoner":
		return minf(visual_size.x, visual_size.y) * 0.36 + 18.0
	if visual_mode == &"relay":
		return minf(visual_size.x, visual_size.y) * 0.38
	return minf(visual_size.x, visual_size.y) * 0.43


func _draw() -> void:
	var center := size * 0.5
	if visual_mode == &"summoner":
		_draw_summoner(center)
		return
	if visual_mode == &"relay":
		_draw_relay(center)
		return
	if visual_mode == &"target":
		_draw_target(center)
		return
	_draw_material_deposit(center)


func _draw_target(center: Vector2) -> void:
	var frame_radius := minf(size.x, size.y) * 0.43
	draw_circle(center, frame_radius, Color(0.01, 0.055, 0.08, 0.92), true)
	draw_arc(center, frame_radius, 0.0, TAU, 64, Color(0.25, 0.72, 0.90, 0.52), 1.0, true)
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var inner := center + Vector2.from_angle(angle) * frame_radius * 0.86
		var outer := center + Vector2.from_angle(angle) * frame_radius
		draw_line(inner, outer, Color(0.30, 0.78, 0.94, 0.44), 1.0, true)
	_draw_material_shape(center, frame_radius * 0.52, INK, 3.0)


func _draw_material_deposit(center: Vector2) -> void:
	var field_radius := body_radius()
	draw_circle(center, field_radius, Color(0.012, 0.075, 0.105, 0.88), true)
	draw_arc(center, field_radius, 0.0, TAU, 64, Color(0.30, 0.76, 0.92, 0.72), 1.5, true)
	draw_arc(center, field_radius * 0.76, 0.0, TAU, 48, Color(0.18, 0.52, 0.66, 0.32), 1.0, true)
	for index in 12:
		var angle := TAU * float(index) / 12.0
		var inner := center + Vector2.from_angle(angle) * field_radius * 0.88
		var outer := center + Vector2.from_angle(angle) * field_radius
		draw_line(inner, outer, Color(0.30, 0.76, 0.92, 0.42), 1.0, true)
	for index in DEPOSIT_OFFSETS.size():
		var is_center := index == 0
		var radius := 13.0 if is_center else 6.5
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
	var radius := body_radius() - 18.0
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


func _draw_relay(center: Vector2) -> void:
	var radius := body_radius()
	draw_circle(center, radius, Color(0.015, 0.09, 0.12, 0.94), true)
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.36, 0.80, 0.94, 0.88), 1.6, true)
	draw_arc(center, radius * 0.68, 0.0, TAU, 48, Color(0.20, 0.58, 0.72, 0.46), 1.0, true)
	draw_circle(center, 5.0, Color(0.01, 0.04, 0.06, 1.0), true)
	draw_arc(center, 5.0, 0.0, TAU, 20, INK, 1.4, true)
	for index in 4:
		var direction := Vector2.from_angle(TAU * float(index) / 4.0)
		draw_line(center + direction * 9.0, center + direction * 18.0, INK, 1.4, true)
		draw_circle(center + direction * 22.0, 2.8, INK, true)
