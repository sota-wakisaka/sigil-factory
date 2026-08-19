class_name SigilGhost
extends Control

const MvpContent := preload("res://src/game/mvp_content.gd")
const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")

const PANEL_COLOR := Color(0.035, 0.055, 0.085, 0.96)
const BORDER_COLOR := Color(0.32, 0.56, 0.76, 0.9)

var recipe_id: StringName = &""
var glyph: GlyphModel
var display_name := ""


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
		tooltip_text = "%sシジルの完成形。召喚器へこの構造を送ります" % display_name
		queue_redraw()
		return true
	return false


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_COLOR, true)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 1.5)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(8, size.y * 0.5 + 4),
		"完成見本: %s" % display_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 54.0,
		11,
		Color(0.62, 0.76, 0.88)
	)
	if glyph == null:
		return
	var center := Vector2(size.x - 25.0, size.y * 0.5)
	GlyphPainterModel.draw_glyph(self, glyph, center)
