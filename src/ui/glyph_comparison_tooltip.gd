class_name GlyphComparisonTooltip
extends Control

const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")

const PANEL_COLOR := Color(0.018, 0.028, 0.045, 0.985)
const BORDER_COLOR := Color(0.42, 0.7, 0.9, 0.96)
const MATCH_COLOR := Color(0.36, 1.0, 0.58, 1.0)
const MISMATCH_COLOR := Color(1.0, 0.38, 0.28, 1.0)
const TARGET_COLOR := Color(1.0, 0.74, 0.28, 0.95)
const TOOLTIP_SIZE := Vector2(520, 250)

var target_glyph: GlyphModel
var candidate_glyph: GlyphModel
var display_name := ""
var comparison_state: StringName = &"missing"


func _init() -> void:
	custom_minimum_size = TOOLTIP_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(target: GlyphModel, candidate: GlyphModel, next_display_name: String) -> void:
	target_glyph = target.copy() if GlyphPainterModel.can_draw(target) else null
	candidate_glyph = candidate.copy() if GlyphPainterModel.can_draw(candidate) else null
	display_name = next_display_name
	comparison_state = _comparison_state()
	queue_redraw()


func _comparison_state() -> StringName:
	if target_glyph == null or candidate_glyph == null:
		return &"missing"
	return &"match" if target_glyph.canonical_serialization() == candidate_glyph.canonical_serialization() else &"mismatch"


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_COLOR, true)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(20, 30), display_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 40.0, 17, Color(0.82, 0.92, 1.0))
	var target_center := Vector2(142, 142)
	var candidate_center := Vector2(378, 142)
	_draw_preview_backing(target_center, TARGET_COLOR)
	_draw_preview_backing(candidate_center, MATCH_COLOR if comparison_state == &"match" else MISMATCH_COLOR)
	if target_glyph != null:
		GlyphPainterModel.draw_glyph(self, target_glyph, target_center, _preview_scale(target_glyph))
	if candidate_glyph != null:
		GlyphPainterModel.draw_glyph(self, candidate_glyph, candidate_center, _preview_scale(candidate_glyph))
	draw_line(Vector2(228, 142), Vector2(292, 142), Color(0.4, 0.62, 0.76, 0.8), 2.0, true)
	draw_line(Vector2(292, 142), Vector2(282, 136), Color(0.4, 0.62, 0.76, 0.8), 2.0, true)
	draw_line(Vector2(292, 142), Vector2(282, 148), Color(0.4, 0.62, 0.76, 0.8), 2.0, true)
	_draw_state_badge(Vector2(260, 205))
	draw_string(ThemeDB.fallback_font, Vector2(112, 226), "目標", HORIZONTAL_ALIGNMENT_CENTER, 60.0, 12, TARGET_COLOR)
	draw_string(ThemeDB.fallback_font, Vector2(338, 226), "工場出力", HORIZONTAL_ALIGNMENT_CENTER, 80.0, 12, Color(0.68, 0.8, 0.9))


func _draw_preview_backing(center: Vector2, color: Color) -> void:
	draw_circle(center, 72.0, Color(0.035, 0.06, 0.085, 0.96))
	draw_arc(center, 72.0, 0.0, TAU, 40, Color(color, 0.72), 2.0, true)


func _preview_scale(value: GlyphModel) -> float:
	return 3.6 if not value.combine_children.is_empty() else 6.0


func _draw_state_badge(center: Vector2) -> void:
	if comparison_state == &"missing":
		return
	var color := MATCH_COLOR if comparison_state == &"match" else MISMATCH_COLOR
	draw_circle(center, 13.0, color)
	if comparison_state == &"match":
		draw_line(center + Vector2(-6, 0), center + Vector2(-2, 5), Color.WHITE, 2.3, true)
		draw_line(center + Vector2(-2, 5), center + Vector2(7, -6), Color.WHITE, 2.3, true)
	else:
		draw_line(center + Vector2(-6, -6), center + Vector2(6, 6), Color.WHITE, 2.3, true)
		draw_line(center + Vector2(-6, 6), center + Vector2(6, -6), Color.WHITE, 2.3, true)
