class_name FactoryPaletteButton
extends Button

const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")
const GlyphComponentModel := preload("res://src/domain/glyph_component.gd")
const GlyphTooltipModel := preload("res://src/ui/glyph_tooltip.gd")
const MeaningGlyphsModel := preload("res://src/domain/meaning_glyphs.gd")

@export var equipment_kind: StringName
@export var caption := "設備"
@export var mana_cost := 0

var preview_glyph: GlyphModel
var goal_relevant := false
var goal_state: StringName = &"irrelevant"
var availability_reason: StringName = &""
var base_tooltip := ""


func _ready() -> void:
	text = ""
	base_tooltip = tooltip_text
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if equipment_kind in [&"ring_source", &"spike_source"]:
		var primitive_id := &"ring" if equipment_kind == &"ring_source" else &"spike"
		preview_glyph = GlyphModel.new([GlyphComponentModel.new(primitive_id)])
	elif equipment_kind == &"meaning_source":
		preview_glyph = MeaningGlyphsModel.glyph(MeaningGlyphsModel.EYE)
	queue_redraw()


func _draw() -> void:
	var icon_center := Vector2(size.x * 0.5, 27)
	if preview_glyph != null:
		GlyphPainterModel.draw_glyph(self, preview_glyph, icon_center, GlyphPainterModel.fit_scale(preview_glyph, 12.0, false, 0.7, 3.0), 1.0, false)
	else:
		_draw_equipment_icon(icon_center)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(0, size.y - 10),
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
	if goal_state != &"irrelevant":
		_draw_goal_marker()


func _make_custom_tooltip(_for_text: String):
	if preview_glyph == null:
		return null
	var context := "一定周期 // ◆%d" % mana_cost
	var title := "素材 // %s" % caption
	if equipment_kind == &"meaning_source":
		var registered := PackedStringArray()
		for glyph_id in MeaningGlyphsModel.IDS:
			registered.append(MeaningGlyphsModel.label(glyph_id))
		context = "登録済み: %s\n選択後に切替 // ◆%d" % ["・".join(registered), mana_cost]
		title = "印源 // 登録済み意味Glyph"
	var unavailable_reason := _availability_reason_text(availability_reason)
	if unavailable_reason != "":
		context = "%s\n%s" % [unavailable_reason, context]
	var goal_reason := _goal_state_text()
	if goal_reason != "":
		context = "%s\n%s" % [goal_reason, context]
	var preview := GlyphTooltipModel.new()
	preview.configure(
		preview_glyph,
		title,
		context
	)
	return preview


func set_goal_relevant(relevant: bool) -> void:
	set_goal_state(&"missing" if relevant else &"irrelevant")


func set_goal_state(next_state: StringName) -> void:
	goal_state = (
		next_state
		if next_state in [&"irrelevant", &"present", &"partial", &"missing", &"blocked"]
		else &"irrelevant"
	)
	goal_relevant = goal_state != &"irrelevant"
	_refresh_tooltip_text()
	queue_redraw()


func goal_marker_style() -> StringName:
	return goal_state


func set_availability(available: bool, reason: StringName = &"") -> void:
	disabled = not available
	availability_reason = &"" if available else reason
	_refresh_tooltip_text()
	queue_redraw()


func _refresh_tooltip_text() -> void:
	var lines := PackedStringArray()
	var reason_text := _availability_reason_text(availability_reason)
	if reason_text != "":
		lines.append(reason_text)
	var goal_text := _goal_state_text()
	if goal_text != "":
		lines.append(goal_text)
	if base_tooltip != "":
		lines.append(base_tooltip)
	tooltip_text = "\n".join(lines)


func _goal_state_text() -> String:
	return {
		&"present": "目標に関係 // 盤上に存在",
		&"partial": "目標に関係 // 一部が盤上に存在",
		&"missing": "目標に関係 // 盤上に不在",
		&"blocked": "目標に関係 // 現在は追加不可",
	}.get(goal_state, "")


func _availability_reason_text(reason: StringName) -> String:
	return {
		&"locked": "現在は工場を編集できません",
		&"mana": "必要な魔力が不足しています",
		&"summoner_limit": "召喚器は1基までです",
		&"selection": "設備を選択すると削除できます",
		&"undo_empty": "戻せる編集がありません",
		&"unknown": "この設備は現在使用できません",
	}.get(reason, "")


func _draw_goal_marker() -> void:
	var start := Vector2(8, size.y - 2)
	var finish := Vector2(size.x - 8, size.y - 2)
	var center := start.lerp(finish, 0.5)
	match goal_state:
		&"present":
			var present_color := Color(0.3, 0.64, 0.8, 0.72)
			draw_line(start, finish, present_color, 1.4, true)
			draw_circle(center, 2.6, present_color)
		&"partial":
			var partial_color := Color(0.32, 0.76, 0.94, 0.9)
			draw_line(start, center, partial_color, 1.4, true)
			draw_dashed_line(center, finish, partial_color, 1.5, 4.0)
			_draw_goal_diamond(center, partial_color)
		&"missing":
			var missing_color := Color(0.32, 0.82, 1.0, 0.98)
			draw_dashed_line(start, finish, missing_color, 1.8, 4.0)
			_draw_goal_diamond(center, missing_color)
		&"blocked":
			var blocked_color := Color(0.95, 0.66, 0.3, 0.9)
			draw_dashed_line(start, finish, blocked_color, 1.5, 4.0)
			_draw_goal_diamond(center, blocked_color)
			draw_line(center + Vector2(-3.5, 3.5), center + Vector2(3.5, -3.5), blocked_color, 1.3, true)


func _draw_goal_diamond(center: Vector2, color: Color) -> void:
	var diamond := PackedVector2Array([
		center + Vector2(0, -4),
		center + Vector2(4, 0),
		center + Vector2(0, 4),
		center + Vector2(-4, 0),
		center + Vector2(0, -4),
	])
	draw_polyline(diamond, color, 1.4, true)


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
	match availability_reason:
		&"mana":
			var points := PackedVector2Array([
				center + Vector2(0, -6), center + Vector2(5, 0),
				center + Vector2(0, 6), center + Vector2(-5, 0), center + Vector2(0, -6),
			])
			draw_polyline(points, Color(0.32, 0.68, 0.96, 0.95), 1.4, true)
		&"summoner_limit":
			draw_arc(center, 6.0, 0.0, TAU, 18, Color(0.36, 1.0, 0.58, 0.86), 1.2, true)
			draw_line(center + Vector2(0, -3), center + Vector2(0, 3), Color(0.7, 1.0, 0.82), 1.5, true)
		&"selection":
			draw_arc(center, 4.0, 0.0, TAU, 16, Color(0.56, 0.66, 0.75, 0.9), 1.2, true)
			for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				draw_line(center + direction * 5.0, center + direction * 7.0, Color(0.56, 0.66, 0.75, 0.9), 1.0, true)
		&"undo_empty":
			draw_arc(center + Vector2(1, 0), 5.0, -1.7, 2.8, 14, Color(0.56, 0.66, 0.75, 0.9), 1.2, true)
			draw_line(center + Vector2(-5, -1), center + Vector2(-1, -5), Color(0.56, 0.66, 0.75, 0.9), 1.2, true)
		_:
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
