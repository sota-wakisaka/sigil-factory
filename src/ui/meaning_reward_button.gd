class_name MeaningRewardButton
extends Button

const MeaningGlyphsModel := preload("res://src/domain/meaning_glyphs.gd")
const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")

@export var reward_id: StringName
@export var glyph_id: StringName
@export var caption := "強化"
@export var effect_caption := ""

var glyph: GlyphModel


func _ready() -> void:
	toggle_mode = true
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	glyph = MeaningGlyphsModel.glyph(glyph_id)
	tooltip_text = "%s // %s" % [caption, effect_caption]
	queue_redraw()


func set_reward_selected(selected: bool) -> void:
	set_pressed_no_signal(selected)
	queue_redraw()


func _draw() -> void:
	var accent := Color(0.42, 0.86, 1.0, 1.0) if button_pressed else Color(0.55, 0.66, 0.76, 1.0)
	var panel := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	draw_rect(panel, Color(0.04, 0.065, 0.1, 0.96), true)
	draw_rect(panel, accent, false, 2.0 if button_pressed else 1.0)
	if glyph != null:
		GlyphPainterModel.draw_glyph(self, glyph, Vector2(48, size.y * 0.5), 1.35, 1.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(83, size.y * 0.5 - 3),
		caption,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 93,
		16,
		accent
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(83, size.y * 0.5 + 19),
		effect_caption,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 93,
		11,
		Color(0.68, 0.76, 0.84)
	)
