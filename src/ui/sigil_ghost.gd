class_name SigilGhost
extends Control

const MvpContent := preload("res://src/game/mvp_content.gd")
const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")
const GlyphTooltipModel := preload("res://src/ui/glyph_tooltip.gd")
const GlyphComparisonTooltipModel := preload("res://src/ui/glyph_comparison_tooltip.gd")

const PANEL_COLOR := Color(0.035, 0.055, 0.085, 0.96)
const BORDER_COLOR := Color(0.32, 0.56, 0.76, 0.9)
const MATCH_COLOR := Color(0.36, 1.0, 0.58, 1.0)
const OWNED_OTHER_COLOR := Color(0.42, 0.82, 1.0, 1.0)
const MISMATCH_COLOR := Color(1.0, 0.38, 0.28, 1.0)

var recipe_id: StringName = &""
var glyph: GlyphModel
var candidate_glyph: GlyphModel
var candidate_state: StringName = &"missing"
var candidate_recipe_id: StringName = &""
var candidate_unit_id: StringName = &""
var candidate_origin: StringName = &"missing"
var candidate_forecast_state: StringName = &"valid"
var candidate_forecast_context := ""
var display_name := ""
var tooltip_glyph: GlyphModel
var tooltip_title := ""
var tooltip_context := ""
var hovered_slot: StringName = &""


func _init() -> void:
	custom_minimum_size = Vector2(320, 80)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_HELP


func _ready() -> void:
	mouse_exited.connect(_clear_hover_slot)
	if recipe_id == &"":
		show_recipe(&"watchful_eye")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var next_slot := hover_slot_at(event.position)
		if next_slot != hovered_slot:
			hovered_slot = next_slot
			queue_redraw()


func _clear_hover_slot() -> void:
	if hovered_slot == &"":
		return
	hovered_slot = &""
	queue_redraw()


func hover_slot_at(at_position: Vector2) -> StringName:
	if glyph == null or not Rect2(Vector2.ZERO, comparison_slot_size()).has_point(at_position):
		return &""
	if candidate_slot_rect().has_point(at_position):
		return &"candidate"
	return &"target" if target_slot_rect().has_point(at_position) else &""


func target_slot_rect() -> Rect2:
	var slot_size := comparison_slot_size()
	return Rect2(Vector2.ZERO, Vector2(minf(slot_size.x, 200.0), slot_size.y))


func candidate_slot_rect() -> Rect2:
	var slot_size := comparison_slot_size()
	return Rect2(Vector2(200.0, 0), Vector2(maxf(slot_size.x - 200.0, 0.0), slot_size.y))


func comparison_slot_size() -> Vector2:
	return Vector2(
		size.x if size.x > 0.0 else custom_minimum_size.x,
		size.y if size.y > 0.0 else custom_minimum_size.y
	)


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


func show_candidate(
	next_candidate: GlyphModel,
	next_origin: StringName = &"actual",
	next_forecast_state: StringName = &"valid",
	next_forecast_context: String = ""
) -> void:
	candidate_glyph = next_candidate.copy() if GlyphPainterModel.can_draw(next_candidate) else null
	candidate_origin = (
		next_origin
		if next_origin == &"hypothetical" or (candidate_glyph != null and next_origin in [&"actual", &"predicted"])
		else &"missing"
	)
	candidate_forecast_state = (
		next_forecast_state
		if candidate_origin == &"hypothetical" and next_forecast_state in [&"glyph", &"no_output", &"invalid"]
		else &"valid"
	)
	candidate_forecast_context = next_forecast_context if candidate_origin == &"hypothetical" else ""
	_refresh_candidate_state()
	queue_redraw()


func _refresh_candidate_state() -> void:
	candidate_recipe_id = &""
	candidate_unit_id = &""
	if glyph == null or candidate_glyph == null:
		candidate_state = &"missing"
	elif glyph.canonical_serialization() == candidate_glyph.canonical_serialization():
		candidate_state = &"match"
	else:
		candidate_state = &"mismatch"
		var candidate_serialization := candidate_glyph.canonical_serialization()
		for recipe in MvpContent.recipes():
			if recipe.glyph.canonical_serialization() == candidate_serialization:
				candidate_state = &"owned_other"
				candidate_recipe_id = recipe.id
				candidate_unit_id = recipe.unit_id
				break


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_COLOR, true)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 1.5)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(8, size.y * 0.5 + 5),
		persistent_label(),
		HORIZONTAL_ALIGNMENT_LEFT,
		80.0,
		12,
		Color(0.62, 0.76, 0.88)
	)
	if glyph == null:
		return
	var target_center := Vector2(132, size.y * 0.5)
	var candidate_center := Vector2(266, size.y * 0.5)
	GlyphPainterModel.draw_glyph(self, glyph, target_center, glyph_draw_scale(), 1.0, false)
	draw_line(Vector2(174, size.y * 0.5), Vector2(224, size.y * 0.5), Color(0.36, 0.56, 0.7, 0.75), 1.5, true)
	draw_line(Vector2(224, size.y * 0.5), Vector2(216, size.y * 0.5 - 5), Color(0.36, 0.56, 0.7, 0.75), 1.5, true)
	draw_line(Vector2(224, size.y * 0.5), Vector2(216, size.y * 0.5 + 5), Color(0.36, 0.56, 0.7, 0.75), 1.5, true)
	if candidate_glyph != null:
		var candidate_opacity: float = {
			&"actual": 1.0,
			&"predicted": 0.7,
			&"hypothetical": 0.52,
		}.get(candidate_origin, 1.0)
		GlyphPainterModel.draw_glyph(
			self,
			candidate_glyph,
			candidate_center,
			candidate_draw_scale(),
			candidate_opacity,
			false
		)
	else:
		var empty_color := MISMATCH_COLOR if candidate_forecast_state == &"invalid" else Color(0.32, 0.62, 0.78, 0.76)
		draw_arc(candidate_center, 13.0, 0.0, TAU, 24, empty_color, 1.0, true)
		if candidate_origin == &"hypothetical" and candidate_forecast_state == &"invalid":
			draw_line(candidate_center + Vector2(-4, -4), candidate_center + Vector2(4, 4), empty_color, 1.5, true)
			draw_line(candidate_center + Vector2(-4, 4), candidate_center + Vector2(4, -4), empty_color, 1.5, true)
	if candidate_origin == &"hypothetical":
		_draw_hypothetical_ring(candidate_center)
	elif candidate_state == &"match":
		_draw_candidate_marker(candidate_center + Vector2(30, -22))
		_draw_candidate_state_ring(candidate_center, Color(MATCH_COLOR, 0.72))
	elif candidate_state == &"owned_other":
		_draw_candidate_marker(candidate_center + Vector2(30, -22))
		_draw_candidate_state_ring(candidate_center, Color(OWNED_OTHER_COLOR, 0.72))
	elif candidate_state == &"mismatch":
		_draw_candidate_marker(candidate_center + Vector2(30, -22))
		draw_arc(target_center, 29.0, 0.0, TAU, 28, Color(1.0, 0.74, 0.28, 0.72), 1.5, true)
		_draw_candidate_state_ring(candidate_center, Color(MISMATCH_COLOR, 0.72))
	if hovered_slot == &"target":
		draw_arc(target_center, 34.0, 0.0, TAU, 32, Color(1.0, 0.78, 0.3, 0.9), 1.5, true)
	elif hovered_slot == &"candidate":
		draw_arc(candidate_center, 34.0, 0.0, TAU, 32, Color(0.42, 0.82, 1.0, 0.9), 1.5, true)


func _draw_candidate_state_ring(center: Vector2, color: Color) -> void:
	if candidate_origin == &"actual":
		draw_arc(center, 29.0, 0.0, TAU, 28, color, 1.5, true)
		return
	for segment in 12:
		var start_angle := float(segment) * TAU / 12.0
		draw_arc(center, 29.0, start_angle, start_angle + TAU / 24.0, 3, color, 1.5, true)


func _draw_hypothetical_ring(center: Vector2) -> void:
	var color := Color(0.42, 0.82, 1.0, 0.8)
	for segment in 16:
		var start_angle := float(segment) * TAU / 16.0
		draw_arc(center, 29.0, start_angle, start_angle + TAU / 64.0, 3, color, 1.5, true)
	var marker_center := center + Vector2(30, -22)
	var diamond := PackedVector2Array([
		marker_center + Vector2(0, -4),
		marker_center + Vector2(4, 0),
		marker_center + Vector2(0, 4),
		marker_center + Vector2(-4, 0),
		marker_center + Vector2(0, -4),
	])
	draw_polyline(diamond, color, 1.4, true)


func candidate_ring_style() -> StringName:
	if candidate_origin == &"hypothetical":
		return &"dotted"
	return &"dashed" if candidate_origin == &"predicted" else &"solid"


func persistent_label() -> String:
	return "目標"


func glyph_draw_scale() -> float:
	return GlyphPainterModel.fit_scale(glyph, 22.0, false, 0.7, 4.0)


func candidate_draw_scale() -> float:
	return GlyphPainterModel.fit_scale(candidate_glyph, 22.0, false, 0.7, 4.0)


func _draw_candidate_marker(center: Vector2) -> void:
	if candidate_state == &"missing":
		return
	var color: Color = {
		&"match": MATCH_COLOR,
		&"owned_other": OWNED_OTHER_COLOR,
	}.get(candidate_state, MISMATCH_COLOR)
	if candidate_state == &"owned_other":
		var diamond := PackedVector2Array([
			center + Vector2(0, -6),
			center + Vector2(6, 0),
			center + Vector2(0, 6),
			center + Vector2(-6, 0),
		])
		draw_colored_polygon(diamond, color)
		draw_circle(center, 2.0, PANEL_COLOR)
		return
	draw_circle(center, 6.0, color)
	if candidate_state == &"match":
		draw_line(center + Vector2(-3, 0), center + Vector2(-1, 2), Color.WHITE, 1.5, true)
		draw_line(center + Vector2(-1, 2), center + Vector2(3, -3), Color.WHITE, 1.5, true)
	else:
		draw_line(center + Vector2(-3, -3), center + Vector2(3, 3), Color.WHITE, 1.5, true)
		draw_line(center + Vector2(-3, 3), center + Vector2(3, -3), Color.WHITE, 1.5, true)


func _get_tooltip(at_position: Vector2) -> String:
	var slot := hover_slot_at(at_position)
	if slot == &"candidate":
		if candidate_glyph == null:
			if candidate_origin == &"hypothetical":
				return (
					"設定候補 // 予測できません"
					if candidate_forecast_state == &"invalid"
					else "設定候補 // 32秒内に出力なし"
				)
			return "工場出力 // 候補なし"
		tooltip_glyph = candidate_glyph
		tooltip_title = "工場出力候補"
		tooltip_context = candidate_context()
		return "candidate"
	if slot != &"target":
		return ""
	tooltip_glyph = glyph
	tooltip_title = "目標シジル // %s" % display_name
	tooltip_context = "CanonicalGlyphの完成形"
	return "target"


func _make_custom_tooltip(for_text: String):
	if for_text.begins_with("設定候補 //") or for_text == "工場出力 // 候補なし":
		return null
	if for_text == "candidate" and candidate_glyph != null:
		var comparison := GlyphComparisonTooltipModel.new()
		comparison.configure(
			glyph,
			candidate_glyph,
			display_name,
			candidate_context()
		)
		return comparison
	if tooltip_glyph == null:
		return null
	var preview := GlyphTooltipModel.new()
	preview.configure(
		tooltip_glyph,
		tooltip_title,
		tooltip_context
	)
	return preview


func candidate_context() -> String:
	var origin_context: String = {
		&"actual": "実仕掛品",
		&"predicted": "32秒予測",
		&"hypothetical": "設定候補 // 未確定",
	}.get(candidate_origin, "候補なし")
	if candidate_forecast_context != "":
		origin_context += " // " + candidate_forecast_context
	match candidate_state:
		&"owned_other":
			return "%s // 取得済み: %s → %s" % [
				origin_context,
				String(MvpContent.sigil_name(candidate_recipe_id)).trim_suffix("シジル"),
				MvpContent.unit_name(candidate_unit_id),
			]
		&"mismatch":
			return "%s // 未登録" % origin_context
	return origin_context
