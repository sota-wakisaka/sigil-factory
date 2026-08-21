class_name SigilPreview
extends Control

const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")

var glyph = null
var emphasized := false
var show_structure := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_glyph(next_glyph, next_emphasized: bool = false) -> void:
	glyph = next_glyph.copy() if GlyphPainterModel.can_draw(next_glyph) else null
	emphasized = next_emphasized
	queue_redraw()


func set_show_structure(next_visible: bool) -> void:
	show_structure = next_visible
	queue_redraw()


func draw_scale() -> float:
	if glyph == null:
		return 1.0
	var extent := _glyph_extent(glyph, show_structure)
	var available_radius := maxf(minf(size.x, size.y) * 0.5 - 12.0, 4.0)
	return clampf(available_radius / maxf(extent, 1.0), 0.16, 6.0)


func _draw() -> void:
	var square := minf(size.x, size.y)
	var rect := Rect2((size - Vector2.ONE * square) * 0.5, Vector2.ONE * square)
	draw_rect(rect, Color(0.015, 0.032, 0.054, 0.97), true)
	draw_rect(
		rect.grow(-1.0),
		Color(0.34, 0.78, 1.0, 0.9 if emphasized else 0.25),
		false,
		2.0 if emphasized else 1.0
	)
	if glyph != null:
		GlyphPainterModel.draw_glyph(
			self,
			glyph,
			rect.get_center(),
			draw_scale(),
			1.0,
			show_structure
		)


static func _glyph_extent(value, include_structure: bool = false) -> float:
	var extent := 12.0
	for component in value.components:
		var center := Vector2(component.position) * 6.0
		var radius := 5.0 + float(maxi(component.scale_step - 1, 0)) * 2.0
		radius *= float(maxi(component.scale_x_percent, component.scale_y_percent)) / 100.0
		extent = maxf(extent, maxf(absf(center.x) + radius, absf(center.y) + radius))
	var visuals := GlyphPainterModel.combine_visuals(value, 1.0, include_structure)
	for circle in visuals["circles"]:
		var center: Vector2 = circle["center"]
		var radius: float = circle["radius"]
		extent = maxf(extent, maxf(absf(center.x) + radius, absf(center.y) + radius))
	for connection in visuals["connections"]:
		for point_key in ["from", "to"]:
			var point: Vector2 = connection[point_key]
			extent = maxf(extent, maxf(absf(point.x), absf(point.y)))
	return extent + 3.0
