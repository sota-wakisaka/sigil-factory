class_name BattleResultSigilStrip
extends Control

const MvpContent := preload("res://src/game/mvp_content.gd")
const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")
const GlyphTooltipModel := preload("res://src/ui/glyph_tooltip.gd")

const SLOT_SIZE := Vector2(104, 72)
const METRIC_SLOT_SIZE := Vector2(82, 34)
const METRIC_KEYS: Array[StringName] = [&"time", &"kills", &"pauses", &"rebuilds", &"discarded"]

var entries: Array[Dictionary] = []
var metrics: Dictionary = {}
var tooltip_entry: Dictionary = {}


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_HELP
	queue_redraw()


func configure(produced_by_recipe: Dictionary, damage_by_recipe: Dictionary, next_metrics: Dictionary = {}) -> void:
	entries.clear()
	metrics = next_metrics.duplicate(true)
	for recipe in MvpContent.recipes():
		var produced := int(produced_by_recipe.get(recipe.id, 0))
		var damage := float(damage_by_recipe.get(recipe.id, 0.0))
		if produced <= 0 and damage <= 0.0:
			continue
		entries.append({
			&"recipe_id": recipe.id,
			&"glyph": recipe.glyph.copy(),
			&"produced": produced,
			&"damage": damage,
		})
	visible = not entries.is_empty() or not metrics.is_empty()
	custom_minimum_size.y = SLOT_SIZE.y + (METRIC_SLOT_SIZE.y if not metrics.is_empty() else 0.0) if visible else 0.0
	tooltip_entry.clear()
	queue_redraw()


func slot_rect(index: int) -> Rect2:
	if index < 0 or index >= entries.size():
		return Rect2()
	var total_width := SLOT_SIZE.x * float(entries.size())
	return Rect2(Vector2((size.x - total_width) * 0.5 + SLOT_SIZE.x * index, 0.0), SLOT_SIZE)


func entry_at(at_position: Vector2) -> Dictionary:
	for index in entries.size():
		if slot_rect(index).has_point(at_position):
			return entries[index]
	return {}


func metric_rect(index: int) -> Rect2:
	if index < 0 or index >= METRIC_KEYS.size() or metrics.is_empty():
		return Rect2()
	var total_width := METRIC_SLOT_SIZE.x * float(METRIC_KEYS.size())
	return Rect2(
		Vector2((size.x - total_width) * 0.5 + METRIC_SLOT_SIZE.x * index, SLOT_SIZE.y),
		METRIC_SLOT_SIZE
	)


func metric_key_at(at_position: Vector2) -> StringName:
	for index in METRIC_KEYS.size():
		if metric_rect(index).has_point(at_position):
			return METRIC_KEYS[index]
	return &""


func _draw() -> void:
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var rect := slot_rect(index)
		var center := rect.position + Vector2(33.0, 30.0)
		GlyphPainterModel.draw_glyph(
			self,
			entry[&"glyph"],
			center,
			GlyphPainterModel.fit_scale(entry[&"glyph"], 20.0, false, 0.7, 3.2),
			0.95,
			false
		)
		_draw_production_mark(rect.position + Vector2(66.0, 24.0), int(entry[&"produced"]))
		_draw_damage_mark(rect.position + Vector2(66.0, 50.0), roundi(float(entry[&"damage"])))
	_draw_metrics()


func _draw_metrics() -> void:
	for index in METRIC_KEYS.size():
		var key := METRIC_KEYS[index]
		if not metrics.has(key):
			continue
		var rect := metric_rect(index)
		var icon_center := rect.position + Vector2(18.0, 17.0)
		var color := Color(0.52, 0.72, 0.86, 0.88)
		_draw_metric_icon(key, icon_center, color)
		draw_string(
			ThemeDB.fallback_font,
			rect.position + Vector2(31.0, 22.0),
			str(metrics[key]),
			HORIZONTAL_ALIGNMENT_LEFT,
			45.0,
			12,
			Color(0.76, 0.84, 0.92)
		)


func _draw_metric_icon(key: StringName, center: Vector2, color: Color) -> void:
	match key:
		&"time":
			draw_arc(center, 7.0, 0.0, TAU, 18, color, 1.4, true)
			draw_line(center, center + Vector2(0, -4), color, 1.4, true)
			draw_line(center, center + Vector2(3, 2), color, 1.4, true)
		&"kills":
			draw_arc(center, 6.0, 0.0, TAU, 18, color, 1.3, true)
			draw_line(center + Vector2(-4, 4), center + Vector2(4, -4), color, 1.7, true)
		&"pauses":
			draw_arc(center, 7.0, 0.0, TAU, 18, color, 1.2, true)
			draw_line(center + Vector2(-2.5, -4), center + Vector2(-2.5, 4), color, 1.8, true)
			draw_line(center + Vector2(2.5, -4), center + Vector2(2.5, 4), color, 1.8, true)
		&"rebuilds":
			var diamond := PackedVector2Array([
				center + Vector2(0, -7), center + Vector2(7, 0),
				center + Vector2(0, 7), center + Vector2(-7, 0), center + Vector2(0, -7),
			])
			draw_polyline(diamond, color, 1.4, true)
		_:
			draw_line(center + Vector2(-5, -5), center + Vector2(5, 5), color, 1.6, true)
			draw_line(center + Vector2(-5, 5), center + Vector2(5, -5), color, 1.6, true)
			draw_circle(center + Vector2(0, 7), 1.8, color)


func _draw_production_mark(center: Vector2, count: int) -> void:
	draw_circle(center + Vector2(-11.0, -3.0), 2.0, Color(0.42, 0.86, 1.0, 0.95))
	draw_circle(center + Vector2(-11.0, 3.0), 2.0, Color(0.42, 0.86, 1.0, 0.95))
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-4.0, 5.0),
		str(count),
		HORIZONTAL_ALIGNMENT_LEFT,
		28.0,
		13,
		Color(0.76, 0.86, 0.96)
	)


func _draw_damage_mark(center: Vector2, damage: int) -> void:
	var color := Color(1.0, 0.62, 0.5, 0.92)
	draw_line(center + Vector2(-14.0, 5.0), center + Vector2(-7.0, -5.0), color, 1.5, true)
	draw_line(center + Vector2(-11.0, -1.0), center + Vector2(-5.0, 1.0), color, 1.5, true)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-2.0, 5.0),
		str(damage),
		HORIZONTAL_ALIGNMENT_LEFT,
		34.0,
		12,
		color
	)


func _get_tooltip(at_position: Vector2) -> String:
	tooltip_entry = entry_at(at_position)
	if not tooltip_entry.is_empty():
		return "battle_result_sigil"
	var metric_key := metric_key_at(at_position)
	match metric_key:
		&"time":
			return "戦闘時間 // %s" % metrics.get(metric_key, "--:--")
		&"kills":
			return "敵撃破 // %s体" % metrics.get(metric_key, 0)
		&"pauses":
			return "時間停止 // %s回" % metrics.get(metric_key, 0)
		&"rebuilds":
			return "工場再構成 // %s回" % metrics.get(metric_key, 0)
		&"discarded":
			return "廃棄・不一致 // %s" % metrics.get(metric_key, 0)
	return ""


func _make_custom_tooltip(for_text: String):
	if for_text != "battle_result_sigil" or tooltip_entry.is_empty():
		return null
	var recipe_id := StringName(tooltip_entry[&"recipe_id"])
	var preview := GlyphTooltipModel.new()
	preview.configure(
		tooltip_entry[&"glyph"],
		"戦果 // %s" % String(MvpContent.sigil_name(recipe_id)).trim_suffix("シジル"),
		"召喚 %d体 // 与ダメージ %.0f\n%s" % [
			int(tooltip_entry[&"produced"]),
			float(tooltip_entry[&"damage"]),
			MvpContent.recipe_combat_trait(recipe_id),
		]
	)
	return preview
