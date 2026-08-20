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
	opacity: float = 1.0
) -> bool:
	if canvas == null or not can_draw(glyph) or scale <= 0.0 or opacity <= 0.0:
		return false
	var normalized_opacity := clampf(opacity, 0.0, 1.0)
	var structure := combine_visuals(glyph, scale)
	for connection in structure["connections"]:
		canvas.draw_line(
			center + connection["from"],
			center + connection["to"],
			_with_opacity(CONNECTION_COLOR, normalized_opacity),
			connection_stroke_width(scale),
			true
		)
	for circle in structure["circles"]:
		canvas.draw_arc(
			center + circle["center"],
			circle["radius"],
			0.0,
			TAU,
			28,
			_with_opacity(COMBINE_COLOR, normalized_opacity),
			combine_stroke_width(scale),
			true
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


static func combine_visuals(glyph: GlyphModel, scale: float = 1.0) -> Dictionary:
	var circles: Array[Dictionary] = []
	var connections: Array[Dictionary] = []
	if not can_draw(glyph) or scale <= 0.0:
		return {"circles": circles, "connections": connections}
	_collect_combine_visuals(glyph, scale, circles, connections)
	return {"circles": circles, "connections": connections}


static func _collect_combine_visuals(
	glyph: GlyphModel,
	scale: float,
	circles: Array[Dictionary],
	connections: Array[Dictionary]
) -> void:
	if glyph.combine_children.is_empty():
		return
	# Combine is anchored to the canonical Glyph origin. This keeps its structure
	# aligned with Rotate, which also transforms every child around (0, 0).
	var glyph_center := Vector2.ZERO
	var radius := _glyph_content_radius(glyph, glyph_center, scale)
	radius += float(_combine_depth(glyph) - 1) * 6.0 * scale
	circles.append({"center": glyph_center, "radius": radius})
	var children := glyph.combine_children.duplicate()
	children.sort_custom(_canonical_child_less)
	for child_index in children.size():
		var child_value = children[child_index]
		var child: GlyphModel = child_value
		var child_center := _glyph_center_offset(child, scale)
		if glyph_center.distance_to(child_center) >= 2.0 * scale:
			connections.append({"from": glyph_center, "to": child_center})
		else:
			var direction := Vector2.UP.rotated(
				float(child_index) * TAU / float(children.size())
			)
			var target_length := minf(
				radius * (0.76 if not child.combine_children.is_empty() else 0.62),
				(17.0 if not child.combine_children.is_empty() else 14.0) * scale
			)
			connections.append({
				"from": glyph_center,
				"to": glyph_center + direction * target_length,
			})
		_collect_combine_visuals(child, scale, circles, connections)


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
		var component_radius := (5.0 + float(maxi(component.scale_step - 1, 0)) * 2.0) * scale
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
	var angle := float(component.rotation_step) * PI * 0.5
	var radius := (5.0 + float(maxi(component.scale_step - 1, 0)) * 2.0) * scale
	var stroke := primitive_stroke_width(scale)
	match component.primitive_id:
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


static func _with_opacity(color: Color, opacity: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * opacity)
