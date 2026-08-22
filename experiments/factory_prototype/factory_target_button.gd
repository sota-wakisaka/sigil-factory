class_name FactoryTargetButton
extends Button

const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")

var glyph_value


func configure_glyph(next_glyph) -> void:
	glyph_value = next_glyph.copy() if next_glyph != null else null
	queue_redraw()


func _draw() -> void:
	if glyph_value == null or not GlyphPainterModel.can_draw(glyph_value):
		return
	var available_radius := minf(size.x, size.y) * 0.34
	var glyph_scale := GlyphPainterModel.fit_scale(
		glyph_value,
		available_radius,
		false,
		0.1,
		3.0
	)
	GlyphPainterModel.draw_glyph(
		self,
		glyph_value,
		size * 0.5,
		glyph_scale,
		1.0 if not disabled else 0.4,
		false,
		0.68
	)
