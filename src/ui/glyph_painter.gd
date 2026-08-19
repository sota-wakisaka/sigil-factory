class_name GlyphPainter
extends RefCounted

const WHITE_GLYPH := Color(0.76, 0.88, 1.0, 0.95)
const BLUE_GLYPH := Color(0.28, 0.8, 1.0, 0.98)
const RED_GLYPH := Color(1.0, 0.4, 0.42, 0.98)
const COMBINE_COLOR := Color(0.55, 0.74, 0.9, 0.72)


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
	if not glyph.combine_children.is_empty():
		canvas.draw_arc(
			center,
			16.0 * scale,
			0.0,
			TAU,
			28,
			_with_opacity(COMBINE_COLOR, normalized_opacity),
			maxf(1.0, 1.4 * scale),
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
	var stroke := maxf(1.0, 2.0 * scale)
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
