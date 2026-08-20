class_name SealLabView
extends Control

const SealRendererModel := preload("res://src/sigil_v2/seal_renderer.gd")

var plan = null
var lod_size := 80
var presentation: StringName = &"operational"
var state: StringName = &"current"
var animation_progress := 1.0
var grayscale := false
var selected := false
var configure_count := 0
var command_copy_count := 0

var _render_commands: Array = []
var _render_bounds_radius := 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func configure(
	next_plan,
	next_lod_size: int,
	next_presentation: StringName,
	next_state: StringName,
	next_progress: float,
	next_grayscale: bool,
	next_selected: bool = false
) -> void:
	configure_count += 1
	plan = next_plan
	if next_plan != null:
		_render_commands = next_plan.commands
		_render_bounds_radius = next_plan.bounds_radius
		command_copy_count += 1
	else:
		_render_commands = []
		_render_bounds_radius = 1
	lod_size = next_lod_size
	presentation = next_presentation
	state = next_state
	animation_progress = clampf(next_progress, 0.0, 1.0)
	grayscale = next_grayscale
	selected = next_selected
	custom_minimum_size = Vector2(next_lod_size + 12, next_lod_size + 12)
	queue_redraw()


func set_presentation(next_presentation: StringName) -> void:
	if presentation == next_presentation:
		return
	presentation = next_presentation
	queue_redraw()


func set_animation_progress(next_progress: float) -> void:
	var clamped := clampf(next_progress, 0.0, 1.0)
	if is_equal_approx(animation_progress, clamped):
		return
	animation_progress = clamped
	queue_redraw()


func set_grayscale(next_grayscale: bool) -> void:
	if grayscale == next_grayscale:
		return
	grayscale = next_grayscale
	queue_redraw()


func set_selected(next_selected: bool) -> void:
	if selected == next_selected:
		return
	selected = next_selected
	queue_redraw()


func _draw() -> void:
	var square := minf(size.x, size.y)
	var rect := Rect2((size - Vector2.ONE * square) * 0.5, Vector2.ONE * square)
	var panel_color := Color(0.025, 0.045, 0.07, 0.94)
	draw_rect(rect, panel_color, true)
	var border := Color(0.28, 0.72, 1.0, 0.8 if selected else 0.24)
	draw_rect(rect.grow(-1.0), border, false, 2.0 if selected else 1.0)
	SealRendererModel.draw_snapshot(
		self,
		_render_commands,
		_render_bounds_radius,
		rect.grow(-6.0),
		lod_size,
		presentation,
		state,
		animation_progress,
		grayscale
	)
