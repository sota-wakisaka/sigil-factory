class_name SigilGhost
extends Control

const MvpContent := preload("res://src/game/mvp_content.gd")

const PANEL_COLOR := Color(0.035, 0.055, 0.085, 0.96)
const BORDER_COLOR := Color(0.32, 0.56, 0.76, 0.9)
const WHITE_GLYPH := Color(0.76, 0.88, 1.0, 0.88)
const BLUE_GLYPH := Color(0.28, 0.8, 1.0, 0.95)
const RED_GLYPH := Color(1.0, 0.4, 0.42, 0.95)

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
	if not glyph.combine_children.is_empty():
		draw_arc(center, 16.0, 0.0, TAU, 28, Color(0.55, 0.74, 0.9, 0.65), 1.3, true)
	for component in glyph.components:
		_draw_component(component, center + Vector2(component.position) * 6.0)


func _draw_component(component: GlyphComponentModel, center: Vector2) -> void:
	var color := _component_color(component.color_id)
	var angle := float(component.rotation_step) * PI * 0.5
	var radius := 5.0 + float(maxi(component.scale_step - 1, 0)) * 2.0
	match component.primitive_id:
		&"ring":
			draw_arc(center, radius, angle + 0.38, angle + TAU - 0.38, 20, color, 2.0, true)
		&"spike":
			var direction := Vector2.RIGHT.rotated(angle)
			var normal := Vector2(-direction.y, direction.x)
			var points := PackedVector2Array([
				center + direction * (radius + 2.0),
				center - direction * radius + normal * radius * 0.7,
				center - direction * radius - normal * radius * 0.7,
			])
			draw_colored_polygon(points, color)
		&"branch":
			var direction := Vector2.RIGHT.rotated(angle)
			var normal := Vector2(-direction.y, direction.x)
			draw_line(center - direction * radius, center + direction * radius, color, 2.0, true)
			draw_line(center, center + direction * 2.0 + normal * radius * 0.7, color, 1.5, true)
			draw_line(center, center + direction * 2.0 - normal * radius * 0.7, color, 1.5, true)
		_:
			draw_circle(center, radius, color, false, 2.0, true)


func _component_color(color_id: StringName) -> Color:
	match color_id:
		&"blue":
			return BLUE_GLYPH
		&"red":
			return RED_GLYPH
	return WHITE_GLYPH
