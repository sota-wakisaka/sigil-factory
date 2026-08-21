class_name SigilPlanButton
extends Button

const MvpContent := preload("res://src/game/mvp_content.gd")
const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")
const GlyphTooltipModel := preload("res://src/ui/glyph_tooltip.gd")

@export var plan_id: StringName
@export var recipe_id: StringName
@export var caption := "術式"
@export var manual_layout := false

var glyph: GlyphModel
var plan_description := ""
var forecast_context := ""
var forecast_mana := -1
var forecast_count := -1


func _ready() -> void:
	toggle_mode = true
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	plan_description = tooltip_text
	_load_recipe()
	queue_redraw()


func _load_recipe() -> bool:
	for recipe in MvpContent.recipes():
		if recipe.id != recipe_id:
			continue
		glyph = recipe.glyph.copy()
		if plan_description == "":
			plan_description = "%sの工場と目標を選択" % caption
		tooltip_text = plan_description
		return true
	glyph = null
	return false


func set_plan_selected(selected: bool) -> void:
	set_pressed_no_signal(selected)
	queue_redraw()


func set_forecast_context(next_context: String, mana := -1, count := -1) -> void:
	forecast_context = next_context
	forecast_mana = mana
	forecast_count = count
	queue_redraw()


func _draw() -> void:
	var accent := Color(0.42, 0.86, 1.0, 1.0) if button_pressed else Color(0.54, 0.66, 0.76, 1.0)
	if button_pressed:
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(0.2, 0.62, 0.86, 0.12), true)
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), accent, false, 2.0)
	if manual_layout:
		_draw_manual_wiring_badge(Vector2(26, 9), accent)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(12, size.y * 0.5 + 5),
		caption,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 58.0,
		13,
		accent
	)
	if glyph != null:
		GlyphPainterModel.draw_glyph(self, glyph, Vector2(size.x - 29.0, size.y * 0.5), glyph_draw_scale(), 1.0, false)
	_draw_forecast_metrics(accent)


func _draw_forecast_metrics(accent: Color) -> void:
	if forecast_mana >= 0:
		var bar := Rect2(Vector2(12, size.y - 5), Vector2(42, 2))
		draw_rect(bar, Color(0.18, 0.25, 0.33, 0.9), true)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(forecast_mana) / 100.0, 0.0, 1.0), bar.size.y)), Color(0.3, 0.67, 0.94, 0.95), true)
	if forecast_count < 0:
		return
	var badge_center := Vector2(size.x - 10, 9)
	draw_circle(badge_center, 8.0, Color(0.025, 0.045, 0.07, 0.98))
	draw_arc(badge_center, 8.0, 0.0, TAU, 18, accent, 1.2, true)
	draw_string(ThemeDB.fallback_font, badge_center + Vector2(-6, 4), str(forecast_count), HORIZONTAL_ALIGNMENT_CENTER, 12, 9, accent)


func mode_badge_kind() -> StringName:
	return &"manual_wiring" if manual_layout else &"template"


func _draw_manual_wiring_badge(center: Vector2, color: Color) -> void:
	var output_center := center + Vector2(-9, 0)
	var input_center := center + Vector2(9, 0)
	draw_circle(output_center, 3.2, color)
	draw_dashed_line(output_center + Vector2(4, 0), input_center - Vector2(4, 0), Color(color, 0.72), 1.3, 3.0)
	draw_circle(input_center, 3.7, Color(0.035, 0.055, 0.085, 0.96))
	draw_arc(input_center, 3.7, 0.0, TAU, 16, color, 1.2, true)


func glyph_draw_scale() -> float:
	return GlyphPainterModel.fit_scale(glyph, 15.0, false, 0.7, 3.0)


func _make_custom_tooltip(_for_text: String):
	var preview := GlyphTooltipModel.new()
	var context := plan_description
	if forecast_context != "":
		context += "\n" + forecast_context
	preview.configure(glyph, "目標候補 // %s" % caption, context)
	return preview
