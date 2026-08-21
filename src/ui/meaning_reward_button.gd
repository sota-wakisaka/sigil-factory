class_name MeaningRewardButton
extends Button

const MeaningGlyphsModel := preload("res://src/domain/meaning_glyphs.gd")
const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")
const MAX_LEVEL := 3

@export var reward_id: StringName
@export var glyph_id: StringName
@export var caption := "強化"
@export var effect_caption := ""

var glyph: GlyphModel
var level := 0
var forecast_context := ""


func _ready() -> void:
	toggle_mode = true
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	glyph = MeaningGlyphsModel.glyph(glyph_id)
	_refresh_tooltip()
	queue_redraw()


func set_reward_selected(selected: bool) -> void:
	set_pressed_no_signal(selected and not disabled)
	queue_redraw()


func set_level(next_level: int) -> void:
	level = clampi(next_level, 0, MAX_LEVEL)
	disabled = level >= MAX_LEVEL
	if disabled:
		set_pressed_no_signal(false)
	_refresh_tooltip()
	queue_redraw()


func set_forecast_context(next_context: String) -> void:
	forecast_context = next_context
	_refresh_tooltip()


func _refresh_tooltip() -> void:
	tooltip_text = "%s // %s // %d/%d" % [caption, effect_caption, level, MAX_LEVEL]
	if forecast_context != "":
		tooltip_text += "\n" + forecast_context


func _draw() -> void:
	var accent := Color(0.42, 0.86, 1.0, 1.0) if button_pressed else Color(0.55, 0.66, 0.76, 1.0)
	var panel := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	draw_rect(panel, Color(0.04, 0.065, 0.1, 0.96), true)
	draw_rect(panel, accent, false, 2.0 if button_pressed else 1.0)
	if glyph != null:
		GlyphPainterModel.draw_glyph(self, glyph, Vector2(48, size.y * 0.5), GlyphPainterModel.fit_scale(glyph, 22.0, false, 0.7, 4.0), 1.0, false)
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
	for index in MAX_LEVEL:
		var pip_center := Vector2(size.x - 15.0 - float((MAX_LEVEL - 1 - index) * 10), 14.0)
		if index < level:
			draw_circle(pip_center, 3.0, accent)
		else:
			draw_arc(pip_center, 3.0, 0.0, TAU, 12, Color(accent, 0.48), 1.0, true)
