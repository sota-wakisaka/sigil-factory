class_name BattleResultSigilStrip
extends Control

const MvpContent := preload("res://src/game/mvp_content.gd")
const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")
const GlyphTooltipModel := preload("res://src/ui/glyph_tooltip.gd")

const SLOT_SIZE := Vector2(104, 72)

var entries: Array[Dictionary] = []
var tooltip_entry: Dictionary = {}


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_HELP
	queue_redraw()


func configure(produced_by_recipe: Dictionary, damage_by_recipe: Dictionary) -> void:
	entries.clear()
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
	visible = not entries.is_empty()
	custom_minimum_size.y = SLOT_SIZE.y if visible else 0.0
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
	return "battle_result_sigil" if not tooltip_entry.is_empty() else ""


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
