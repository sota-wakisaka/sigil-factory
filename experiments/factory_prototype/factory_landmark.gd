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
var rotation_angle_degrees := 45
var scale_x_percent := 100
var scale_y_percent := 100
var move_offset := Vector2i.UP
var combine_connection_mode: StringName = &"simple"


func configure(next_kind: StringName) -> void:
	landmark_kind = next_kind
	if landmark_kind == &"summoner":
		visual_mode = &"summoner"
		custom_minimum_size = Vector2(176.0, 176.0)
	elif landmark_kind == &"relay":
		visual_mode = &"relay"
		custom_minimum_size = Vector2(118.0, 118.0)
	elif landmark_kind == &"rotation":
		visual_mode = &"rotation"
		custom_minimum_size = Vector2(118.0, 118.0)
	elif landmark_kind == &"scale":
		visual_mode = &"scale"
		custom_minimum_size = Vector2(118.0, 118.0)
	elif landmark_kind == &"move":
		visual_mode = &"move"
		custom_minimum_size = Vector2(118.0, 118.0)
	elif landmark_kind == &"combine":
		visual_mode = &"combine"
		custom_minimum_size = Vector2(134.0, 134.0)
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


func configure_rotation(next_degrees: int) -> void:
	landmark_kind = &"rotation"
	visual_mode = &"rotation"
	rotation_angle_degrees = posmod(next_degrees, 360)
	custom_minimum_size = Vector2(118.0, 118.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func configure_scale(next_x_percent: int, next_y_percent: int) -> void:
	landmark_kind = &"scale"
	visual_mode = &"scale"
	scale_x_percent = next_x_percent
	scale_y_percent = next_y_percent
	custom_minimum_size = Vector2(118.0, 118.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func configure_move(next_offset: Vector2i) -> void:
	landmark_kind = &"move"
	visual_mode = &"move"
	move_offset = next_offset
	custom_minimum_size = Vector2(118.0, 118.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func configure_combine(next_connection_mode: StringName) -> void:
	landmark_kind = &"combine"
	visual_mode = &"combine"
	combine_connection_mode = next_connection_mode
	custom_minimum_size = Vector2(134.0, 134.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func body_radius() -> float:
	var visual_size := size
	if visual_size.x <= 0.0 or visual_size.y <= 0.0:
		visual_size = custom_minimum_size
	if visual_mode == &"summoner":
		return minf(visual_size.x, visual_size.y) * 0.36 + 18.0
	if visual_mode in [&"relay", &"rotation", &"scale", &"move", &"combine"]:
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
	if visual_mode == &"rotation":
		_draw_rotation(center)
		return
	if visual_mode == &"scale":
		_draw_scale(center)
		return
	if visual_mode == &"move":
		_draw_move(center)
		return
	if visual_mode == &"combine":
		_draw_combine(center)
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
		&"diamond":
			var diamond := PackedVector2Array([
				center + Vector2(0.0, -radius),
				center + Vector2(radius, 0.0),
				center + Vector2(0.0, radius),
				center + Vector2(-radius, 0.0),
				center + Vector2(0.0, -radius),
			])
			draw_polyline(diamond, color, width, true)


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


func _draw_rotation(center: Vector2) -> void:
	var radius := body_radius()
	draw_circle(center, radius, Color(0.015, 0.075, 0.11, 0.96), true)
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.42, 0.82, 1.0, 0.92), 1.6, true)
	for index in 8:
		var tick_angle := -PI * 0.5 + TAU * float(index) / 8.0
		var direction := Vector2.from_angle(tick_angle)
		draw_line(
			center + direction * radius * 0.72,
			center + direction * radius * 0.86,
			Color(DIM_INK, 0.72),
			1.0,
			true
		)
	var angle := deg_to_rad(float(rotation_angle_degrees) - 90.0)
	var hand := Vector2.from_angle(angle)
	var tangent := Vector2(-hand.y, hand.x)
	var tip := center + hand * radius * 0.58
	draw_line(center, tip, INK, 2.0, true)
	draw_colored_polygon(PackedVector2Array([
		tip + hand * 4.0,
		tip - hand * 4.0 + tangent * 4.0,
		tip - hand * 4.0 - tangent * 4.0,
	]), INK)
	draw_circle(center, 4.0, Color(0.01, 0.04, 0.06, 1.0), true)
	draw_arc(center, 4.0, 0.0, TAU, 20, INK, 1.2, true)


func _draw_scale(center: Vector2) -> void:
	var radius := body_radius()
	draw_circle(center, radius, Color(0.015, 0.075, 0.11, 0.96), true)
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.42, 0.82, 1.0, 0.92), 1.6, true)
	var reference_half := Vector2.ONE * radius * 0.38
	var reference_rect := Rect2(center - reference_half, reference_half * 2.0)
	draw_dashed_line(reference_rect.position, Vector2(reference_rect.end.x, reference_rect.position.y), DIM_INK, 1.0, 4.0)
	draw_dashed_line(Vector2(reference_rect.end.x, reference_rect.position.y), reference_rect.end, DIM_INK, 1.0, 4.0)
	draw_dashed_line(reference_rect.end, Vector2(reference_rect.position.x, reference_rect.end.y), DIM_INK, 1.0, 4.0)
	draw_dashed_line(Vector2(reference_rect.position.x, reference_rect.end.y), reference_rect.position, DIM_INK, 1.0, 4.0)
	var max_percent := maxf(float(maxi(scale_x_percent, scale_y_percent)), 100.0)
	var shape_half := Vector2(
		radius * 0.54 * float(scale_x_percent) / max_percent,
		radius * 0.54 * float(scale_y_percent) / max_percent
	)
	shape_half.x = maxf(shape_half.x, 4.0)
	shape_half.y = maxf(shape_half.y, 4.0)
	draw_rect(Rect2(center - shape_half, shape_half * 2.0), INK, false, 2.0, true)
	draw_circle(center, 2.5, INK, true)


func _draw_move(center: Vector2) -> void:
	var radius := body_radius()
	draw_circle(center, radius, Color(0.015, 0.075, 0.11, 0.96), true)
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.42, 0.82, 1.0, 0.92), 1.6, true)
	var distance := maxi(absi(move_offset.x), absi(move_offset.y))
	var direction := Vector2(move_offset).normalized()
	if direction.is_zero_approx():
		direction = Vector2.UP
	var tangent := Vector2(-direction.y, direction.x)
	var shaft_start := center - direction * radius * 0.30
	var shaft_end := center + direction * (radius * (0.34 + 0.045 * float(distance)))
	draw_line(shaft_start, shaft_end, INK, 2.2, true)
	draw_colored_polygon(PackedVector2Array([
		shaft_end + direction * 5.0,
		shaft_end - direction * 5.0 + tangent * 4.5,
		shaft_end - direction * 5.0 - tangent * 4.5,
	]), INK)
	for step in distance:
		var marker := center - direction * radius * 0.18 + direction * float(step) * 5.0
		draw_circle(marker, 1.6, Color(DIM_INK, 0.92), true)


func _draw_combine(center: Vector2) -> void:
	var radius := body_radius()
	draw_circle(center, radius, Color(0.015, 0.075, 0.11, 0.96), true)
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.42, 0.82, 1.0, 0.92), 1.6, true)
	var child_centers := [
		center + Vector2(-17.0, -12.0),
		center + Vector2(17.0, -12.0),
		center + Vector2(0.0, 18.0),
	]
	if combine_connection_mode == &"radial":
		for child_center in child_centers:
			draw_line(center, child_center, Color(DIM_INK, 0.88), 1.6, true)
	elif combine_connection_mode == &"pairwise":
		for index in child_centers.size():
			draw_line(
				child_centers[index],
				child_centers[(index + 1) % child_centers.size()],
				Color(DIM_INK, 0.88),
				1.6,
				true
			)
	for child_center in child_centers:
		draw_circle(child_center, 4.0, Color(0.01, 0.04, 0.06, 1.0), true)
		draw_arc(child_center, 4.0, 0.0, TAU, 20, INK, 1.4, true)
	if combine_connection_mode == &"radial":
		draw_circle(center, 3.2, INK, true)
