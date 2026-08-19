class_name SigilGhost
extends Control

const MvpContent := preload("res://src/game/mvp_content.gd")
const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")
const GlyphTooltipModel := preload("res://src/ui/glyph_tooltip.gd")
const GlyphComparisonTooltipModel := preload("res://src/ui/glyph_comparison_tooltip.gd")

const PANEL_COLOR := Color(0.035, 0.055, 0.085, 0.96)
const BORDER_COLOR := Color(0.32, 0.56, 0.76, 0.9)
const MATCH_COLOR := Color(0.36, 1.0, 0.58, 1.0)
const MISMATCH_COLOR := Color(1.0, 0.38, 0.28, 1.0)

var recipe_id: StringName = &""
var glyph: GlyphModel
var candidate_glyph: GlyphModel
var candidate_state: StringName = &"missing"
var display_name := ""
var tooltip_glyph: GlyphModel
var tooltip_title := ""
var tooltip_context := ""


func _init() -> void:
	custom_minimum_size = Vector2(280, 50)


func _ready() -> void:
	if recipe_id == &"":
		show_recipe(&"open_ring")


func show_recipe(next_recipe_id: StringName) -> bool:
	for recipe in MvpContent.recipes():
		if recipe.id != next_recipe_id:
			continue
		recipe_id = recipe.id
		glyph = recipe.glyph.copy()
		display_name = MvpContent.sigil_name(recipe_id).replace("シジル", "")
		tooltip_text = "%sシジルを拡大表示" % display_name
		tooltip_glyph = glyph
		tooltip_title = "目標シジル // %s" % display_name
		tooltip_context = "CanonicalGlyphの完成形"
		_refresh_candidate_state()
		queue_redraw()
		return true
	return false


func show_candidate(next_candidate: GlyphModel) -> void:
	candidate_glyph = next_candidate.copy() if GlyphPainterModel.can_draw(next_candidate) else null
	_refresh_candidate_state()
	queue_redraw()


func _refresh_candidate_state() -> void:
	if glyph == null or candidate_glyph == null:
		candidate_state = &"missing"
	elif glyph.canonical_serialization() == candidate_glyph.canonical_serialization():
		candidate_state = &"match"
	else:
		candidate_state = &"mismatch"


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_COLOR, true)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 1.5)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(8, size.y * 0.5 + 5),
		display_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		80.0,
		12,
		Color(0.62, 0.76, 0.88)
	)
	if glyph == null:
		return
	var target_center := Vector2(122, size.y * 0.5)
	var candidate_center := Vector2(224, size.y * 0.5)
	GlyphPainterModel.draw_glyph(self, glyph, target_center, glyph_draw_scale())
	draw_line(Vector2(154, size.y * 0.5), Vector2(190, size.y * 0.5), Color(0.36, 0.56, 0.7, 0.75), 1.5, true)
	draw_line(Vector2(190, size.y * 0.5), Vector2(183, size.y * 0.5 - 4), Color(0.36, 0.56, 0.7, 0.75), 1.5, true)
	draw_line(Vector2(190, size.y * 0.5), Vector2(183, size.y * 0.5 + 4), Color(0.36, 0.56, 0.7, 0.75), 1.5, true)
	if candidate_glyph != null:
		GlyphPainterModel.draw_glyph(self, candidate_glyph, candidate_center, candidate_draw_scale())
	else:
		draw_arc(candidate_center, 13.0, 0.0, TAU, 24, Color(0.32, 0.44, 0.54, 0.6), 1.0, true)
	_draw_candidate_marker(candidate_center + Vector2(24, -13))
	if candidate_state == &"match":
		draw_arc(candidate_center, 20.0, 0.0, TAU, 24, Color(MATCH_COLOR, 0.72), 1.5, true)
	elif candidate_state == &"mismatch":
		draw_arc(target_center, 20.0, 0.0, TAU, 24, Color(1.0, 0.74, 0.28, 0.72), 1.5, true)
		draw_arc(candidate_center, 20.0, 0.0, TAU, 24, Color(MISMATCH_COLOR, 0.72), 1.5, true)


func glyph_draw_scale() -> float:
	if glyph != null and glyph.combine_children.is_empty():
		return 1.75
	return 0.95


func candidate_draw_scale() -> float:
	if candidate_glyph != null and candidate_glyph.combine_children.is_empty():
		return 1.75
	return 0.95


func _draw_candidate_marker(center: Vector2) -> void:
	if candidate_state == &"missing":
		return
	var color := MATCH_COLOR if candidate_state == &"match" else MISMATCH_COLOR
	draw_circle(center, 6.0, color)
	if candidate_state == &"match":
		draw_line(center + Vector2(-3, 0), center + Vector2(-1, 2), Color.WHITE, 1.5, true)
		draw_line(center + Vector2(-1, 2), center + Vector2(3, -3), Color.WHITE, 1.5, true)
	else:
		draw_line(center + Vector2(-3, -3), center + Vector2(3, 3), Color.WHITE, 1.5, true)
		draw_line(center + Vector2(-3, 3), center + Vector2(3, -3), Color.WHITE, 1.5, true)


func _get_tooltip(at_position: Vector2) -> String:
	if candidate_glyph != null and at_position.x >= 180.0:
		tooltip_glyph = candidate_glyph
		tooltip_title = "工場出力候補"
		tooltip_context = "実仕掛品または32秒予測"
		return "candidate"
	tooltip_glyph = glyph
	tooltip_title = "目標シジル // %s" % display_name
	tooltip_context = "CanonicalGlyphの完成形"
	return "target"


func _make_custom_tooltip(_for_text: String):
	if candidate_glyph != null:
		var comparison := GlyphComparisonTooltipModel.new()
		comparison.configure(glyph, candidate_glyph, display_name)
		return comparison
	var preview := GlyphTooltipModel.new()
	preview.configure(
		tooltip_glyph,
		tooltip_title,
		tooltip_context
	)
	return preview
