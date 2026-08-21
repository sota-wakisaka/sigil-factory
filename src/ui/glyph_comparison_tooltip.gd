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
var candidate_label := "工場出力"
var comparison_state: StringName = &"missing"


func _init() -> void:
	custom_minimum_size = TOOLTIP_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(
	target: GlyphModel,
	candidate: GlyphModel,
	next_display_name: String,
	next_candidate_label: String = "工場出力"
) -> void:
	target_glyph = target.copy() if GlyphPainterModel.can_draw(target) else null
	candidate_glyph = candidate.copy() if GlyphPainterModel.can_draw(candidate) else null
	display_name = next_display_name
	candidate_label = next_candidate_label
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
		GlyphPainterModel.draw_glyph(self, target_glyph, target_center, _preview_scale(target_glyph), 1.0, false)
	if candidate_glyph != null:
		GlyphPainterModel.draw_glyph(self, candidate_glyph, candidate_center, _preview_scale(candidate_glyph), 1.0, false)
	draw_line(Vector2(228, 142), Vector2(292, 142), Color(0.4, 0.62, 0.76, 0.8), 2.0, true)
	draw_line(Vector2(292, 142), Vector2(282, 136), Color(0.4, 0.62, 0.76, 0.8), 2.0, true)
	draw_line(Vector2(292, 142), Vector2(282, 148), Color(0.4, 0.62, 0.76, 0.8), 2.0, true)
	_draw_state_badge(Vector2(260, 205))
	if comparison_state == &"mismatch":
		_draw_difference_badges()
	draw_string(ThemeDB.fallback_font, Vector2(112, 226), "目標", HORIZONTAL_ALIGNMENT_CENTER, 60.0, 12, TARGET_COLOR)
	draw_string(ThemeDB.fallback_font, Vector2(328, 226), candidate_label, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 12, Color(0.68, 0.8, 0.9))


func _draw_preview_backing(center: Vector2, color: Color) -> void:
	draw_circle(center, 72.0, Color(0.035, 0.06, 0.085, 0.96))
	draw_arc(center, 72.0, 0.0, TAU, 40, Color(color, 0.72), 2.0, true)


func _preview_scale(value: GlyphModel) -> float:
	return GlyphPainterModel.fit_scale(value, 60.0, false, 1.0, 7.0)


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


func difference_categories() -> Array[StringName]:
	var result: Array[StringName] = []
	if target_glyph == null or candidate_glyph == null:
		return result
	if _component_signature(target_glyph, &"primitive") != _component_signature(candidate_glyph, &"primitive"):
		result.append(&"primitive")
	if _component_signature(target_glyph, &"rotation") != _component_signature(candidate_glyph, &"rotation"):
		result.append(&"rotation")
	if _component_signature(target_glyph, &"color") != _component_signature(candidate_glyph, &"color"):
		result.append(&"color")
	if _component_signature(target_glyph, &"geometry") != _component_signature(candidate_glyph, &"geometry"):
		result.append(&"geometry")
	if (
		(not target_glyph.combine_children.is_empty() or not candidate_glyph.combine_children.is_empty())
		and _combine_signature(target_glyph) != _combine_signature(candidate_glyph)
	):
		result.append(&"combine")
	return result


func _component_signature(value: GlyphModel, category: StringName) -> PackedStringArray:
	var signature := PackedStringArray()
	for component in value.components:
		match category:
			&"primitive": signature.append(String(component.primitive_id))
			&"rotation": signature.append("%s:%d" % [component.primitive_id, component.rotation_degrees])
			&"color": signature.append("%s:%s" % [component.primitive_id, component.color_id])
			&"geometry": signature.append("%s:%s,%s:%d" % [
				component.primitive_id,
				GlyphComponentModel.coordinate_key(component.position.x),
				GlyphComponentModel.coordinate_key(component.position.y),
				component.scale_step,
			])
	signature.sort()
	return signature


func _combine_signature(value: GlyphModel) -> String:
	if value.combine_children.is_empty():
		return "L(%s)" % value.canonical_serialization()
	var children := PackedStringArray()
	for child in value.combine_children:
		children.append(_combine_signature(child))
	children.sort()
	return "C[%s](%s)" % [value.combine_connection_mode, ",".join(children)]


func _draw_difference_badges() -> void:
	var categories := difference_categories()
	var spacing := 31.0
	var start_x := 260.0 - float(categories.size() - 1) * spacing * 0.5
	for index in categories.size():
		_draw_difference_icon(Vector2(start_x + index * spacing, 55), categories[index])


func _draw_difference_icon(center: Vector2, category: StringName) -> void:
	draw_circle(center, 11.0, Color(0.09, 0.035, 0.035, 0.96))
	draw_arc(center, 11.0, 0.0, TAU, 20, Color(MISMATCH_COLOR, 0.84), 1.3, true)
	match category:
		&"primitive":
			draw_arc(center + Vector2(-2, 0), 5.0, 0.5, TAU - 0.5, 16, MISMATCH_COLOR, 1.7, true)
			draw_line(center + Vector2(2, -5), center + Vector2(7, 0), MISMATCH_COLOR, 1.7, true)
		&"rotation":
			draw_arc(center, 6.0, -0.8, 4.1, 16, MISMATCH_COLOR, 1.7, true)
			draw_line(center + Vector2(-6, -2), center + Vector2(-2, -6), MISMATCH_COLOR, 1.7, true)
		&"color":
			draw_circle(center + Vector2(-3, 0), 3.2, GlyphPainterModel.BLUE_GLYPH)
			draw_circle(center + Vector2(4, 0), 3.2, Color(1.0, 0.38, 0.3))
		&"geometry":
			draw_line(center + Vector2(-7, 0), center + Vector2(7, 0), MISMATCH_COLOR, 1.4, true)
			draw_line(center + Vector2(0, -7), center + Vector2(0, 7), MISMATCH_COLOR, 1.4, true)
			draw_circle(center, 3.0, Color(0.09, 0.035, 0.035), true)
		&"combine":
			draw_arc(center + Vector2(-3.5, 0), 4.5, 0.0, TAU, 16, MISMATCH_COLOR, 1.5, true)
			draw_arc(center + Vector2(3.5, 0), 4.5, 0.0, TAU, 16, MISMATCH_COLOR, 1.5, true)
