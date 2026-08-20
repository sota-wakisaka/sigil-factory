class_name SigilPlanButton
extends Button

const MvpContent := preload("res://src/game/mvp_content.gd")
const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")
const GlyphTooltipModel := preload("res://src/ui/glyph_tooltip.gd")

@export var plan_id: StringName
@export var recipe_id: StringName
@export var caption := "術式"

var glyph: GlyphModel


func _ready() -> void:
	toggle_mode = true
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_load_recipe()
	queue_redraw()


func _load_recipe() -> bool:
	for recipe in MvpContent.recipes():
		if recipe.id != recipe_id:
			continue
		glyph = recipe.glyph.copy()
		tooltip_text = "%sの目標シジルを拡大表示" % caption
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
		GlyphPainterModel.draw_glyph(self, glyph, Vector2(size.x - 29.0, size.y * 0.5), glyph_draw_scale())


func glyph_draw_scale() -> float:
	if glyph != null and not glyph.combine_children.is_empty():
		return 1.55
	return 1.5


func _make_custom_tooltip(_for_text: String):
	var preview := GlyphTooltipModel.new()
	preview.configure(glyph, "目標候補 // %s" % caption, "クリックで工場と目標を選択")
	return preview
