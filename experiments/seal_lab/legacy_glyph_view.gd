class_name LegacyGlyphView
extends Control

const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")

var glyph = null
var selected := false
var configure_count := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func configure(next_glyph, next_selected: bool = false) -> void:
	configure_count += 1
	glyph = next_glyph.copy() if GlyphPainterModel.can_draw(next_glyph) else null
	selected = next_selected
	queue_redraw()


func set_selected(next_selected: bool) -> void:
	if selected == next_selected:
		return
	selected = next_selected
	queue_redraw()


func draw_scale() -> float:
	if glyph == null:
		return 1.0
	var extent := _glyph_extent(glyph)
	var available_radius := maxf(minf(size.x, size.y) * 0.5 - 14.0, 4.0)
	return clampf(available_radius / maxf(extent, 1.0), 0.18, 6.0)


func _draw() -> void:
	var square := minf(size.x, size.y)
	var rect := Rect2((size - Vector2.ONE * square) * 0.5, Vector2.ONE * square)
	draw_rect(rect, Color(0.018, 0.035, 0.058, 0.97), true)
	draw_rect(
		rect.grow(-1.0),
		Color(0.34, 0.78, 1.0, 0.9 if selected else 0.24),
		false,
		2.0 if selected else 1.0
	)
	if glyph != null:
		GlyphPainterModel.draw_glyph(self, glyph, rect.get_center(), draw_scale())


static func _glyph_extent(value) -> float:
	var extent := 12.0
	for component in value.components:
		var center := Vector2(component.position) * 6.0
		var radius := 5.0 + float(maxi(component.scale_step - 1, 0)) * 2.0
		extent = maxf(extent, maxf(absf(center.x) + radius, absf(center.y) + radius))
	var visuals := GlyphPainterModel.combine_visuals(value, 1.0)
	for circle in visuals["circles"]:
		var center: Vector2 = circle["center"]
		var radius: float = circle["radius"]
		extent = maxf(extent, maxf(absf(center.x) + radius, absf(center.y) + radius))
	for connection in visuals["connections"]:
		for point_key in ["from", "to"]:
			var point: Vector2 = connection[point_key]
			extent = maxf(extent, maxf(absf(point.x), absf(point.y)))
	return extent + 3.0
