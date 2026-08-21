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
	preview.configure(glyph, "目標候補 // %s" % caption, plan_description)
	return preview
