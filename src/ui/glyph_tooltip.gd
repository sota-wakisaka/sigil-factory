class_name GlyphTooltip
extends Control

const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")

const PANEL_COLOR := Color(0.018, 0.028, 0.045, 0.985)
const BORDER_COLOR := Color(0.42, 0.7, 0.9, 0.96)
const TITLE_COLOR := Color(0.82, 0.92, 1.0, 1.0)
const TEXT_COLOR := Color(0.62, 0.74, 0.84, 1.0)
const ACCENT_COLOR := Color(0.42, 0.86, 1.0, 1.0)
const TOOLTIP_SIZE := Vector2(340, 214)

var glyph: GlyphModel
var title := "グリフ"
var context := "実形状を拡大表示"


func _init() -> void:
	custom_minimum_size = TOOLTIP_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(next_glyph: GlyphModel, next_title: String, next_context: String) -> void:
	glyph = next_glyph.copy() if GlyphPainterModel.can_draw(next_glyph) else null
	title = next_title
	context = next_context
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_COLOR, true)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 2.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(18, 28),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 36.0,
		17,
		TITLE_COLOR
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(18, 49),
		context,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 36.0,
		12,
		TEXT_COLOR
	)
	if glyph == null:
		draw_string(ThemeDB.fallback_font, Vector2(18, 102), "表示できるGlyphがありません", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT_COLOR)
		return
	var glyph_center := Vector2(92, 124)
	draw_circle(glyph_center, 66.0, Color(0.04, 0.075, 0.11, 0.9))
	draw_arc(glyph_center, 66.0, 0.0, TAU, 40, Color(0.2, 0.38, 0.52, 0.72), 1.0, true)
	GlyphPainterModel.draw_glyph(self, glyph, glyph_center, _preview_scale())
	var detail_lines := _detail_lines()
	for index in detail_lines.size():
		draw_string(
			ThemeDB.fallback_font,
			Vector2(176, 82 + index * 22),
			detail_lines[index],
			HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 192.0,
			13,
			ACCENT_COLOR if index == 0 else TEXT_COLOR
		)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(176, 191),
		"同じ形を召喚器へ",
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 192.0,
		12,
		TITLE_COLOR
	)


func _preview_scale() -> float:
	return 3.5 if not glyph.combine_children.is_empty() else 5.6


func _detail_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("構成 %d Primitive" % glyph.components.size())
	lines.append("合成 %s" % ("あり" if not glyph.combine_children.is_empty() else "なし"))
	for component in glyph.components:
		var parts := PackedStringArray([
			_primitive_name(component.primitive_id),
			_color_name(component.color_id),
			"%d°" % (component.rotation_step * 90),
		])
		lines.append("・".join(parts))
	return lines


func _primitive_name(primitive_id: StringName) -> String:
	return {&"ring": "環", &"spike": "棘", &"branch": "枝"}.get(primitive_id, String(primitive_id))


func _color_name(color_id: StringName) -> String:
	return {&"blue": "青", &"red": "赤", &"white": "白"}.get(color_id, String(color_id))
