class_name RunUpgradeStrip
extends Control

const MeaningGlyphsModel := preload("res://src/domain/meaning_glyphs.gd")
const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")
const GlyphTooltipModel := preload("res://src/ui/glyph_tooltip.gd")

const MAX_LEVEL := 3
const SLOT_SIZE := Vector2(64, 52)
const ENTRIES := [
	{&"id": &"ring_speed", &"glyph_id": &"target", &"label": "集束", &"effect": "素材生成 -20%"},
	{&"id": &"processing_speed", &"glyph_id": &"cross", &"label": "交差", &"effect": "加工 -1 tick"},
	{&"id": &"line_speed", &"glyph_id": &"eye", &"label": "先見", &"effect": "輸送 -1 tick"},
]

var levels: Dictionary = {}
var tooltip_entry: Dictionary = {}


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_HELP
	queue_redraw()


func configure(upgrades: Array[StringName]) -> void:
	levels.clear()
	for entry in ENTRIES:
		var level := mini(upgrades.count(entry[&"id"]), MAX_LEVEL)
		if level > 0:
			levels[entry[&"id"]] = level
	visible = not levels.is_empty()
	custom_minimum_size.y = SLOT_SIZE.y if visible else 0.0
	queue_redraw()


func acquired_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in ENTRIES:
		if levels.has(entry[&"id"]):
			result.append(entry)
	return result


func slot_rect(index: int) -> Rect2:
	var entries := acquired_entries()
	if index < 0 or index >= entries.size():
		return Rect2()
	var total_width := SLOT_SIZE.x * float(entries.size())
	return Rect2(Vector2((size.x - total_width) * 0.5 + SLOT_SIZE.x * index, 0), SLOT_SIZE)


func entry_at(at_position: Vector2) -> Dictionary:
	var entries := acquired_entries()
	for index in entries.size():
		if slot_rect(index).has_point(at_position):
			return entries[index]
	return {}


func _draw() -> void:
	var entries := acquired_entries()
	for index in entries.size():
		var entry := entries[index]
		var rect := slot_rect(index)
		var glyph := MeaningGlyphsModel.glyph(entry[&"glyph_id"])
		var center := rect.position + Vector2(rect.size.x * 0.5, 22.0)
		GlyphPainterModel.draw_glyph(self, glyph, center, GlyphPainterModel.fit_scale(glyph, 15.0, false, 0.7, 3.0), 0.92, false)
		var level := int(levels[entry[&"id"]])
		for pip_index in MAX_LEVEL:
			var pip_center := rect.position + Vector2(24.0 + float(pip_index) * 8.0, 45.0)
			if pip_index < level:
				draw_circle(pip_center, 2.5, Color(0.42, 0.86, 1.0, 0.95))
			else:
				draw_arc(pip_center, 2.5, 0.0, TAU, 12, Color(0.42, 0.62, 0.76, 0.42), 1.0, true)


func _get_tooltip(at_position: Vector2) -> String:
	tooltip_entry = entry_at(at_position)
	return "run_upgrade" if not tooltip_entry.is_empty() else ""


func _make_custom_tooltip(for_text: String):
	if for_text != "run_upgrade" or tooltip_entry.is_empty():
		return null
	var preview := GlyphTooltipModel.new()
	var level := int(levels.get(tooltip_entry[&"id"], 0))
	preview.configure(
		MeaningGlyphsModel.glyph(tooltip_entry[&"glyph_id"]),
		"所持強化 // %s" % tooltip_entry[&"label"],
		"%s // %d/%d" % [tooltip_entry[&"effect"], level, MAX_LEVEL]
	)
	return preview
