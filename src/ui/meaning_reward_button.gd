class_name MeaningRewardButton
extends Button

const MeaningGlyphsModel := preload("res://src/domain/meaning_glyphs.gd")
const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")
const GlyphTooltipModel := preload("res://src/ui/glyph_tooltip.gd")
const MAX_LEVEL := 3

@export var reward_id: StringName
@export var glyph_id: StringName
@export var caption := "強化"
@export var effect_caption := ""

var glyph: GlyphModel
var level := 0
var forecast_context := ""
var forecast_glyph: GlyphModel
var forecast_before := -1
var forecast_after := -1
var forecast_timing_changed := false
var forecast_valid := false


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


func set_forecast_visual(state: Dictionary) -> void:
	forecast_valid = bool(state.get("valid", false))
	forecast_glyph = state.get("glyph")
	if forecast_glyph != null:
		forecast_glyph = forecast_glyph.copy()
	forecast_before = int(state.get("before", -1))
	forecast_after = int(state.get("after", -1))
	forecast_timing_changed = bool(state.get("timing_changed", false))
	queue_redraw()


func _refresh_tooltip() -> void:
	tooltip_text = "%s // %s // %d/%d" % [caption, effect_caption, level, MAX_LEVEL]
	if forecast_context != "":
		tooltip_text += "\n" + forecast_context


func _make_custom_tooltip(_for_text: String):
	if glyph == null:
		return null
	var preview := GlyphTooltipModel.new()
	var context := "%s // %d/%d" % [effect_caption, level, MAX_LEVEL]
	if forecast_context != "":
		context += "\n" + forecast_context
	preview.configure(glyph, "報酬 // %s" % caption, context)
	return preview


func _draw() -> void:
	var accent := Color(0.42, 0.86, 1.0, 1.0) if button_pressed else Color(0.55, 0.66, 0.76, 1.0)
	var panel := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	draw_rect(panel, Color(0.04, 0.065, 0.1, 0.96), true)
	draw_rect(panel, accent, false, 2.0 if button_pressed else 1.0)
	if glyph != null:
		GlyphPainterModel.draw_glyph(self, glyph, Vector2(38, size.y * 0.5), GlyphPainterModel.fit_scale(glyph, 20.0, false, 0.7, 4.0), 1.0, false)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(70, size.y * 0.5 - 3),
		caption,
		HORIZONTAL_ALIGNMENT_LEFT,
		90.0,
		16,
		accent
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(70, size.y * 0.5 + 19),
		effect_caption,
		HORIZONTAL_ALIGNMENT_LEFT,
		92.0,
		11,
		Color(0.68, 0.76, 0.84)
	)
	_draw_forecast(accent)
	for index in MAX_LEVEL:
		var pip_center := Vector2(size.x - 15.0 - float((MAX_LEVEL - 1 - index) * 10), 14.0)
		if index < level:
			draw_circle(pip_center, 3.0, accent)
		else:
			draw_arc(pip_center, 3.0, 0.0, TAU, 12, Color(accent, 0.48), 1.0, true)


func _draw_forecast(accent: Color) -> void:
	var divider_x := size.x - 68.0
	draw_line(Vector2(divider_x, 30.0), Vector2(divider_x, size.y - 10.0), Color(accent, 0.2), 1.0)
	if not forecast_valid:
		draw_string(ThemeDB.fallback_font, Vector2(size.x - 53.0, 62.0), "?", HORIZONTAL_ALIGNMENT_CENTER, 36.0, 16, Color(accent, 0.55))
		return
	if forecast_glyph != null:
		GlyphPainterModel.draw_glyph(
			self,
			forecast_glyph,
			Vector2(size.x - 34.0, 48.0),
			GlyphPainterModel.fit_scale(forecast_glyph, 11.0, false, 0.7, 2.5),
			0.82,
			false
		)
	var count_text := "%d›%d" % [forecast_before, forecast_after]
	draw_string(
		ThemeDB.fallback_font,
		Vector2(size.x - 66.0, size.y - 10.0),
		count_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		64.0,
		11,
		Color(0.72, 0.82, 0.92)
	)
	if forecast_timing_changed and forecast_before == forecast_after:
		var clock_center := Vector2(size.x - 58.0, size.y - 15.0)
		draw_arc(clock_center, 4.0, 0.0, TAU, 12, Color(accent, 0.78), 1.0, true)
		draw_line(clock_center, clock_center + Vector2(0.0, -2.5), Color(accent, 0.78), 1.0)
		draw_line(clock_center, clock_center + Vector2(2.0, 1.0), Color(accent, 0.78), 1.0)
