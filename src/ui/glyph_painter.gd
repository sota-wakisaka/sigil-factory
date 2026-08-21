class_name GlyphPainter
extends RefCounted

const WHITE_GLYPH := Color(0.76, 0.88, 1.0, 0.95)
const BLUE_GLYPH := Color(0.28, 0.8, 1.0, 0.98)
const RED_GLYPH := Color(1.0, 0.4, 0.42, 0.98)
const COMBINE_COLOR := Color(0.55, 0.74, 0.9, 0.72)
const CONNECTION_COLOR := Color(0.42, 0.6, 0.74, 0.42)


static func can_draw(glyph: GlyphModel) -> bool:
	return glyph != null and glyph.structure_validation_errors().is_empty()


static func draw_glyph(
	canvas: CanvasItem,
	glyph: GlyphModel,
	center: Vector2,
	scale: float = 1.0,
	opacity: float = 1.0,
	show_combine_structure: bool = true
) -> bool:
	if canvas == null or not can_draw(glyph) or scale <= 0.0 or opacity <= 0.0:
		return false
	var normalized_opacity := clampf(opacity, 0.0, 1.0)
	var structure := combine_visuals(glyph, scale, show_combine_structure)
	for connection in structure["connections"]:
		canvas.draw_line(
			center + connection["from"],
			center + connection["to"],
			_with_opacity(CONNECTION_COLOR, normalized_opacity),
			connection_stroke_width(scale),
			true
		)
	for circle in structure["circles"]:
		_draw_structure_circle(
			canvas,
			center + circle["center"],
			circle["radius"],
			_with_opacity(COMBINE_COLOR, normalized_opacity * 0.7),
			combine_stroke_width(scale)
		)
	for component in glyph.components:
		_draw_component(
			canvas,
			component,
			center + Vector2(component.position) * 6.0 * scale,
			scale,
			normalized_opacity
		)
	return true


static func combine_visuals(
	glyph: GlyphModel,
	scale: float = 1.0,
	show_combine_structure: bool = true
) -> Dictionary:
	var circles: Array[Dictionary] = []
	var connections: Array[Dictionary] = []
	if not can_draw(glyph) or scale <= 0.0:
		return {"circles": circles, "connections": connections}
	_collect_combine_visuals(glyph, scale, circles, connections, show_combine_structure)
	return {
		"circles": circles,
		"connections": _merge_overlapping_connections(connections, scale),
	}


static func _collect_combine_visuals(
	glyph: GlyphModel,
	scale: float,
	circles: Array[Dictionary],
	connections: Array[Dictionary],
	show_combine_structure: bool
) -> void:
	if glyph.combine_children.is_empty():
		return
	# A new Combine starts at the canonical origin, then follows any Transform
	# applied to the completed group together with its children.
	var glyph_center := Vector2(glyph.combine_origin) * 6.0 * scale
	var radius := _glyph_content_radius(glyph, glyph_center, scale)
	radius += float(_combine_depth(glyph) - 1) * 6.0 * scale
	if show_combine_structure:
		circles.append({"center": glyph_center, "radius": radius})
	var children := glyph.combine_children.duplicate()
	children.sort_custom(_canonical_child_less)
	if glyph.combine_connection_mode == GlyphModel.CONNECTION_PAIRWISE:
		connections.append_array(_pairwise_visible_connections(
			children,
			scale,
			show_combine_structure
		))
	for child_value in children:
		var child: GlyphModel = child_value
		if glyph.combine_connection_mode == GlyphModel.CONNECTION_RADIAL:
			var child_center := _glyph_center_offset(child, scale)
			if glyph_center.distance_to(child_center) >= 2.0 * scale:
				connections.append({
					"from": glyph_center,
					"to": child_center,
					"merge_overlaps": false,
				})
		_collect_combine_visuals(
			child,
			scale,
			circles,
			connections,
			show_combine_structure
		)


static func _pairwise_visible_connections(
	children: Array,
	scale: float,
	clip_combine_structure: bool
) -> Array[Dictionary]:
	var connections: Array[Dictionary] = []
	var centers: Array[Vector2] = []
	var radii: Array[float] = []
	for child_value in children:
		if not child_value is GlyphModel:
			continue
		var child: GlyphModel = child_value
		var child_center := _glyph_center_offset(child, scale)
		centers.append(child_center)
		radii.append(_glyph_connection_radius(child, child_center, scale, clip_combine_structure))
	for first_index in centers.size():
		for second_index in range(first_index + 1, centers.size()):
			connections.append_array(_visible_segment_gaps(
				centers[first_index],
				centers[second_index],
				centers,
				radii,
				scale
			))
	return connections


static func _visible_segment_gaps(
	start: Vector2,
	end: Vector2,
	centers: Array[Vector2],
	radii: Array[float],
	scale: float
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var delta := end - start
	var length_squared := delta.length_squared()
	if length_squared <= 0.000001:
		return result
	var segment_length := sqrt(length_squared)
	var blocked: Array[Vector2] = []
	for index in centers.size():
		var relative := centers[index] - start
		var center_t := relative.dot(delta) / length_squared
		var closest := start + delta * center_t
		var perpendicular_squared := centers[index].distance_squared_to(closest)
		var radius := radii[index]
		if perpendicular_squared >= radius * radius:
			continue
		var half_t := sqrt(maxf(radius * radius - perpendicular_squared, 0.0)) / segment_length
		var blocked_start := maxf(center_t - half_t, 0.0)
		var blocked_end := minf(center_t + half_t, 1.0)
		if blocked_start < blocked_end:
			blocked.append(Vector2(blocked_start, blocked_end))
	blocked.sort_custom(func(first: Vector2, second: Vector2) -> bool: return first.x < second.x)
	var cursor := 0.0
	var minimum_gap := maxf(0.35 * scale, 0.05)
	for interval in blocked:
		if interval.x > cursor:
			var visible_start := start + delta * cursor
			var visible_end := start + delta * interval.x
			if visible_start.distance_to(visible_end) >= minimum_gap:
				result.append({
					"from": visible_start,
					"to": visible_end,
					"merge_overlaps": true,
				})
		cursor = maxf(cursor, interval.y)
	if cursor < 1.0:
		var visible_start := start + delta * cursor
		if visible_start.distance_to(end) >= minimum_gap:
			result.append({
				"from": visible_start,
				"to": end,
				"merge_overlaps": true,
			})
	return result


static func _glyph_connection_radius(
	glyph: GlyphModel,
	center: Vector2,
	scale: float,
	clip_combine_structure: bool = true
) -> float:
	if not glyph.combine_children.is_empty():
		if not clip_combine_structure:
			return _glyph_visible_component_radius(glyph, center, scale)
		return (
			_glyph_content_radius(glyph, center, scale)
			+ float(_combine_depth(glyph) - 1) * 6.0 * scale
			+ combine_stroke_width(scale) * 0.5
		)
	var radius := 0.0
	for component in glyph.components:
		var component_center := Vector2(component.position) * 6.0 * scale
		var component_radius := _component_max_radius(component, scale)
		var visible_radius := component_radius
		match component.primitive_id:
			&"spike":
				# The connector is painted behind the filled triangle. A smaller
				# cut reaches the visible edge without showing through its interior.
				visible_radius = component_radius * 0.55
			&"branch":
				visible_radius = maxf(primitive_stroke_width(scale), 1.5 * scale)
		radius = maxf(radius, center.distance_to(component_center) + visible_radius)
	return radius


static func _glyph_visible_component_radius(
	glyph: GlyphModel,
	center: Vector2,
	scale: float
) -> float:
	var radius := 0.0
	for component in glyph.components:
		var component_center := Vector2(component.position) * 6.0 * scale
		radius = maxf(
			radius,
			center.distance_to(component_center) + _component_max_radius(component, scale)
		)
	return maxf(radius, 0.5 * scale)


static func _merge_overlapping_connections(
	candidates: Array[Dictionary],
	scale: float
) -> Array[Dictionary]:
	var preserved: Array[Dictionary] = []
	var merged: Array[Dictionary] = []
	var epsilon := maxf(0.01 * scale, 0.0001)
	for candidate in candidates:
		if not bool(candidate.get("merge_overlaps", false)):
			preserved.append({"from": candidate["from"], "to": candidate["to"]})
			continue
		var next := _ordered_connection(candidate)
		if next["from"].distance_to(next["to"]) <= epsilon:
			continue
		var index := 0
		while index < merged.size():
			if _connections_overlap_on_same_line(next, merged[index], epsilon):
				next = _merge_connection_pair(next, merged[index])
				merged.remove_at(index)
				index = 0
				continue
			index += 1
		merged.append(next)
	merged.sort_custom(_connection_less)
	preserved.append_array(merged)
	return preserved


static func _connections_overlap_on_same_line(
	first: Dictionary,
	second: Dictionary,
	epsilon: float
) -> bool:
	var first_delta: Vector2 = first["to"] - first["from"]
	var second_delta: Vector2 = second["to"] - second["from"]
	var first_length := first_delta.length()
	var second_length := second_delta.length()
	if first_length <= epsilon or second_length <= epsilon:
		return false
	if absf(_cross(first_delta, second_delta)) > epsilon * first_length * second_length:
		return false
	if absf(_cross(second["from"] - first["from"], first_delta)) > epsilon * first_length:
		return false
	var axis := first_delta / first_length
	var first_min := 0.0
	var first_max := first_length
	var second_a: float = (Vector2(second["from"]) - Vector2(first["from"])).dot(axis)
	var second_b: float = (Vector2(second["to"]) - Vector2(first["from"])).dot(axis)
	var second_min := minf(second_a, second_b)
	var second_max := maxf(second_a, second_b)
	return maxf(first_min, second_min) <= minf(first_max, second_max) + epsilon


static func _merge_connection_pair(first: Dictionary, second: Dictionary) -> Dictionary:
	var origin: Vector2 = first["from"]
	var axis: Vector2 = (first["to"] - origin).normalized()
	var points: Array[Vector2] = [first["from"], first["to"], second["from"], second["to"]]
	points.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return (a - origin).dot(axis) < (b - origin).dot(axis)
	)
	return _ordered_connection({"from": points[0], "to": points[points.size() - 1]})


static func _ordered_connection(value: Dictionary) -> Dictionary:
	var from: Vector2 = value["from"]
	var to: Vector2 = value["to"]
	if _point_less(to, from):
		return {"from": to, "to": from}
	return {"from": from, "to": to}


static func _connection_less(first: Dictionary, second: Dictionary) -> bool:
	if first["from"] != second["from"]:
		return _point_less(first["from"], second["from"])
	return _point_less(first["to"], second["to"])


static func _point_less(first: Vector2, second: Vector2) -> bool:
	return first.x < second.x or (is_equal_approx(first.x, second.x) and first.y < second.y)


static func _cross(first: Vector2, second: Vector2) -> float:
	return first.x * second.y - first.y * second.x


static func _canonical_child_less(first, second) -> bool:
	if not first is GlyphModel or not second is GlyphModel:
		return first is GlyphModel
	var first_glyph: GlyphModel = first
	var second_glyph: GlyphModel = second
	var first_hash := first_glyph.canonical_hash()
	var second_hash := second_glyph.canonical_hash()
	if first_hash != second_hash:
		return first_hash < second_hash
	return first_glyph.canonical_serialization() < second_glyph.canonical_serialization()


static func _glyph_center_offset(glyph: GlyphModel, scale: float) -> Vector2:
	if not glyph.combine_children.is_empty():
		return Vector2(glyph.combine_origin) * 6.0 * scale
	if glyph.components.is_empty():
		return Vector2.ZERO
	var center := Vector2.ZERO
	for component in glyph.components:
		center += Vector2(component.position) * 6.0 * scale
	return center / float(glyph.components.size())


static func _glyph_content_radius(glyph: GlyphModel, center: Vector2, scale: float) -> float:
	var radius := 0.0
	for component in glyph.components:
		var component_center := Vector2(component.position) * 6.0 * scale
		var component_radius := _component_max_radius(component, scale)
		radius = maxf(radius, center.distance_to(component_center) + component_radius)
	return maxf(12.0 * scale, radius + 11.0 * scale)


static func _combine_depth(glyph: GlyphModel) -> int:
	if glyph.combine_children.is_empty():
		return 0
	var child_depth := 0
	for child in glyph.combine_children:
		child_depth = maxi(child_depth, _combine_depth(child))
	return child_depth + 1


static func primitive_stroke_width(scale: float) -> float:
	return maxf(1.0, 2.0 * scale)


static func combine_stroke_width(scale: float) -> float:
	return maxf(0.9, 1.25 * scale)


static func connection_stroke_width(scale: float) -> float:
	return maxf(0.65, 0.8 * scale)


static func _draw_structure_circle(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	color: Color,
	stroke: float
) -> void:
	const SEGMENTS := 32
	for index in SEGMENTS:
		if index % 2 != 0:
			continue
		var from_angle := TAU * float(index) / float(SEGMENTS)
		var to_angle := TAU * float(index + 1) / float(SEGMENTS)
		canvas.draw_arc(center, radius, from_angle, to_angle, 3, color, stroke, true)


static func component_color(color_id: StringName) -> Color:
	match color_id:
		&"blue":
			return BLUE_GLYPH
		&"red":
			return RED_GLYPH
	return WHITE_GLYPH


static func _draw_component(
	canvas: CanvasItem,
	component: GlyphComponentModel,
	center: Vector2,
	scale: float,
	opacity: float
) -> void:
	var color := _with_opacity(component_color(component.color_id), opacity)
	var angle := deg_to_rad(float(component.rotation_degrees))
	var radius := (5.0 + float(maxi(component.scale_step - 1, 0)) * 2.0) * scale
	var radius_x := radius * float(component.scale_x_percent) / 100.0
	var radius_y := radius * float(component.scale_y_percent) / 100.0
	var stroke := primitive_stroke_width(scale)
	match component.primitive_id:
		&"circle":
			_draw_basic_outline(canvas, center, radius_x, radius_y, 0.0, angle, 40, color, stroke)
		&"triangle":
			_draw_basic_outline(canvas, center, radius_x, radius_y, -PI * 0.5, angle, 3, color, stroke)
		&"square":
			_draw_basic_outline(canvas, center, radius_x, radius_y, PI * 0.25, angle, 4, color, stroke)
		&"ring":
			canvas.draw_arc(center, radius, angle + 0.38, angle + TAU - 0.38, 20, color, stroke, true)
		&"spike":
			var direction := Vector2.RIGHT.rotated(angle)
			var normal := Vector2(-direction.y, direction.x)
			canvas.draw_colored_polygon(PackedVector2Array([
				center + direction * (radius + 2.0 * scale),
				center - direction * radius + normal * radius * 0.7,
				center - direction * radius - normal * radius * 0.7,
			]), color)
		&"branch":
			var direction := Vector2.RIGHT.rotated(angle)
			var normal := Vector2(-direction.y, direction.x)
			canvas.draw_line(center - direction * radius, center + direction * radius, color, stroke, true)
			canvas.draw_line(
				center,
				center + direction * 2.0 * scale + normal * radius * 0.7,
				color,
				maxf(1.0, 1.5 * scale),
				true
			)
			canvas.draw_line(
				center,
				center + direction * 2.0 * scale - normal * radius * 0.7,
				color,
				maxf(1.0, 1.5 * scale),
				true
			)
		_:
			canvas.draw_circle(center, radius, color, false, stroke, true)


static func _draw_basic_outline(
	canvas: CanvasItem,
	center: Vector2,
	radius_x: float,
	radius_y: float,
	base_angle: float,
	rotation_angle: float,
	point_count: int,
	color: Color,
	stroke: float
) -> void:
	var points := PackedVector2Array()
	for index in point_count:
		var point_angle := base_angle + TAU * float(index) / float(point_count)
		var local_point := Vector2(
			cos(point_angle) * radius_x,
			sin(point_angle) * radius_y
		)
		points.append(center + local_point.rotated(rotation_angle))
	if not points.is_empty():
		points.append(points[0])
	canvas.draw_polyline(points, color, stroke, true)


static func _component_max_radius(component: GlyphComponentModel, scale: float) -> float:
	var radius := (5.0 + float(maxi(component.scale_step - 1, 0)) * 2.0) * scale
	return radius * float(maxi(component.scale_x_percent, component.scale_y_percent)) / 100.0


static func _with_opacity(color: Color, opacity: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * opacity)
