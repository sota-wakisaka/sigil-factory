class_name FactoryPaletteButton
extends Button

const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")
const GlyphComponentModel := preload("res://src/domain/glyph_component.gd")

@export var equipment_kind: StringName
@export var caption := "設備"
@export var mana_cost := 0

var preview_glyph: GlyphModel


func _ready() -> void:
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if equipment_kind in [&"ring_source", &"spike_source"]:
		var primitive_id := &"ring" if equipment_kind == &"ring_source" else &"spike"
		preview_glyph = GlyphModel.new([GlyphComponentModel.new(primitive_id)])
	queue_redraw()


func _draw() -> void:
	var icon_center := Vector2(size.x * 0.5, 16)
	if preview_glyph != null:
		GlyphPainterModel.draw_glyph(self, preview_glyph, icon_center, 1.28)
	else:
		_draw_equipment_icon(icon_center)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(0, size.y - 6),
		caption,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		10,
		Color(0.66, 0.76, 0.84, 1.0)
	)
	if mana_cost > 0:
		_draw_mana_cost()
	if disabled:
		_draw_unavailable_overlay()


func _draw_mana_cost() -> void:
	draw_string(
		ThemeDB.fallback_font,
		Vector2(4, 10),
		"◆%d" % mana_cost,
		HORIZONTAL_ALIGNMENT_LEFT,
		28.0,
		8,
		Color(0.32, 0.68, 0.96, 0.88)
	)


func _draw_unavailable_overlay() -> void:
	var center := Vector2(size.x - 11.0, 10.0)
	draw_circle(center, 7.0, Color(0.055, 0.07, 0.09, 0.96))
	draw_arc(center, 7.0, 0.0, TAU, 18, Color(0.88, 0.38, 0.34, 0.92), 1.2, true)
	draw_line(center + Vector2(-4, 4), center + Vector2(4, -4), Color(0.96, 0.45, 0.4), 1.6, true)


func _draw_equipment_icon(center: Vector2) -> void:
	var color := Color(0.42, 0.78, 0.98, 0.94)
	match equipment_kind:
		&"rotator":
			draw_arc(center, 8.0, -0.6, 4.5, 20, color, 2.0, true)
			draw_line(center + Vector2(-8, -3), center + Vector2(-3, -8), color, 2.0, true)
		&"colorizer":
			draw_circle(center, 7.0, GlyphPainterModel.BLUE_GLYPH)
			draw_arc(center, 10.0, 0.0, TAU, 24, color, 1.3, true)
		&"combiner":
			draw_arc(center + Vector2(-5, 0), 7.0, 0.0, TAU, 20, color, 1.8, true)
			draw_arc(center + Vector2(5, 0), 7.0, 0.0, TAU, 20, color, 1.8, true)
			draw_line(center + Vector2(-1, 0), center + Vector2(1, 0), color, 2.0, true)
		&"summoner":
			draw_arc(center, 10.0, 0.0, TAU, 24, color, 2.0, true)
			draw_arc(center, 6.0, 0.0, TAU, 20, Color(color, 0.55), 1.2, true)
		&"delete":
			draw_line(center + Vector2(-7, -7), center + Vector2(7, 7), Color(1.0, 0.42, 0.38), 2.5, true)
			draw_line(center + Vector2(-7, 7), center + Vector2(7, -7), Color(1.0, 0.42, 0.38), 2.5, true)
		&"undo":
			draw_arc(center + Vector2(2, 0), 8.0, -1.7, 2.8, 20, color, 2.0, true)
			draw_line(center + Vector2(-8, -1), center + Vector2(-3, -7), color, 2.0, true)
			draw_line(center + Vector2(-8, -1), center + Vector2(-1, 2), color, 2.0, true)
