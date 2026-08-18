extends Control

const GlyphComponentModel := preload("res://src/domain/glyph_component.gd")
const GlyphModel := preload("res://src/domain/glyph.gd")
const SigilMatcher := preload("res://src/domain/sigil_matcher.gd")

const BACKGROUND_COLOR := Color("070a10")
const GRID_COLOR := Color(0.18, 0.26, 0.36, 0.22)
const CIRCUIT_COLOR := Color(0.46, 0.56, 0.68, 0.72)
const MATCH_COLOR := Color(0.35, 1.0, 0.72, 1.0)
const ERROR_COLOR := Color(1.0, 0.42, 0.48, 1.0)
const GRID_SPACING := 32

@onready var status_label: Label = $Status
@onready var rotate_button: Button = $Controls/RotateButton
@onready var move_button: Button = $Controls/MoveButton
@onready var color_button: Button = $Controls/ColorButton
@onready var reset_button: Button = $Controls/ResetButton

var target_glyph: GlyphModel
var current_glyph: GlyphModel
var match_result: Dictionary = {}


func _ready() -> void:
	rotate_button.pressed.connect(_rotate_current)
	move_button.pressed.connect(_move_current)
	color_button.pressed.connect(_color_current)
	reset_button.pressed.connect(_reset_current)

	target_glyph = GlyphModel.new([
		GlyphComponentModel.new(&"ring", Vector2i.ZERO, 1, 1, &"blue"),
	])
	_reset_current()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	_draw_grid()
	if target_glyph == null or current_glyph == null:
		return
	_draw_glyph(target_glyph, Vector2(size.x * 0.32, size.y * 0.48), true)
	_draw_glyph(current_glyph, Vector2(size.x * 0.68, size.y * 0.48), false)


func _draw_grid() -> void:
	for x in range(0, int(size.x) + GRID_SPACING, GRID_SPACING):
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID_COLOR, 1.0)
	for y in range(0, int(size.y) + GRID_SPACING, GRID_SPACING):
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID_COLOR, 1.0)


func _draw_glyph(glyph: GlyphModel, center: Vector2, is_target: bool) -> void:
	for component in glyph.components:
		var component_center := center + Vector2(component.position) * 34.0
		var component_color := _color_for_id(component.color_id)
		var radius := 76.0 * float(component.scale_step)
		draw_arc(component_center, radius, 0.0, TAU, 96, component_color, 3.0, true)

		var angle := -PI * 0.5 + float(component.rotation_step) * PI * 0.5
		var direction := Vector2.from_angle(angle)
		draw_line(
			component_center,
			component_center + direction * radius,
			component_color,
			3.0,
			true
		)
		draw_circle(component_center, 5.0, component_color)

	var frame_color := CIRCUIT_COLOR
	if not is_target:
		frame_color = MATCH_COLOR if match_result.get("is_match", false) else ERROR_COLOR
	draw_arc(center, 112.0, 0.0, TAU, 96, frame_color, 1.0, true)


func _color_for_id(color_id: StringName) -> Color:
	match color_id:
		&"blue":
			return Color(0.28, 0.72, 1.0, 1.0)
		_:
			return Color(0.88, 0.92, 1.0, 1.0)


func _rotate_current() -> void:
	var component: GlyphComponentModel = current_glyph.components[0]
	component.rotation_step = posmod(component.rotation_step + 1, 4)
	_refresh_match()


func _move_current() -> void:
	var component: GlyphComponentModel = current_glyph.components[0]
	component.position.x += 1
	if component.position.x > 1:
		component.position.x = -1
	_refresh_match()


func _color_current() -> void:
	var component: GlyphComponentModel = current_glyph.components[0]
	component.color_id = &"blue" if component.color_id == &"white" else &"white"
	_refresh_match()


func _reset_current() -> void:
	current_glyph = GlyphModel.new([
		GlyphComponentModel.new(&"ring", Vector2i(-1, 0), 0, 1, &"white"),
	])
	_refresh_match()


func _refresh_match() -> void:
	match_result = SigilMatcher.compare(current_glyph, target_glyph)
	if match_result["is_match"]:
		status_label.text = "完全一致 — 召喚可能"
		status_label.add_theme_color_override("font_color", MATCH_COLOR)
	else:
		status_label.text = " / ".join(match_result["diagnostics"])
		status_label.add_theme_color_override("font_color", ERROR_COLOR)
	queue_redraw()

