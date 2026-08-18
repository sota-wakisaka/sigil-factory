class_name FactoryBoard
extends Control

signal summon_produced(unit_id: StringName)

const MvpContent := preload("res://src/game/mvp_content.gd")
const FactoryNodeModel := preload("res://src/factory/factory_node.gd")

const PANEL_COLOR := Color(0.035, 0.055, 0.085, 0.96)
const NODE_COLOR := Color(0.08, 0.12, 0.18, 1.0)
const NODE_BORDER := Color(0.38, 0.62, 0.82, 0.9)
const LINE_COLOR := Color(0.24, 0.48, 0.68, 0.75)
const GLYPH_COLOR := Color(0.35, 0.86, 1.0, 1.0)

var plan_id: StringName = MvpContent.PLAN_SCOUT
var simulation: FactorySimulation
var node_positions: Dictionary = {}
var observed_event_count := 0
var editing := false
var pending_plan_id: StringName
var preview_simulation: FactorySimulation
var preview_node_positions: Dictionary = {}


func _ready() -> void:
	configure(plan_id)


func configure(next_plan_id: StringName) -> void:
	plan_id = next_plan_id
	simulation = MvpContent.build_factory(plan_id)
	node_positions = MvpContent.layout_for_plan(plan_id)
	observed_event_count = 0
	editing = false
	preview_simulation = null
	queue_redraw()


func begin_edit() -> void:
	editing = true
	pending_plan_id = plan_id
	preview_simulation = MvpContent.build_factory(pending_plan_id)
	preview_node_positions = MvpContent.layout_for_plan(pending_plan_id)
	queue_redraw()


func preview_plan(next_plan_id: StringName) -> void:
	if not editing:
		return
	pending_plan_id = next_plan_id
	preview_simulation = MvpContent.build_factory(pending_plan_id)
	preview_node_positions = MvpContent.layout_for_plan(pending_plan_id)
	queue_redraw()


func commit_edit() -> void:
	if not editing:
		return
	plan_id = pending_plan_id
	simulation = preview_simulation
	node_positions = preview_node_positions
	observed_event_count = 0
	editing = false
	preview_simulation = null
	queue_redraw()


func cancel_edit() -> void:
	if not editing:
		return
	editing = false
	preview_simulation = null
	preview_node_positions.clear()
	queue_redraw()


func work_in_progress_count() -> int:
	if simulation == null:
		return 0
	var count := 0
	for node in simulation.nodes.values():
		for glyph in node.input_buffers:
			count += int(glyph != null)
		count += int(node.output_buffer != null)
		count += int(node.processing_glyph != null)
	for line in simulation.lines.values():
		count += int(line.payload != null)
	return count


func advance_tick() -> void:
	if simulation == null:
		return
	simulation.tick()
	while observed_event_count < simulation.summon_events.size():
		var event := simulation.summon_events[observed_event_count]
		observed_event_count += 1
		summon_produced.emit(event["unit_id"])
	queue_redraw()


func _draw() -> void:
	draw_style_box(_panel_style(), Rect2(Vector2.ZERO, size))
	var display_simulation := preview_simulation if editing else simulation
	var display_positions := preview_node_positions if editing else node_positions
	if display_simulation == null:
		return
	_draw_lines(display_simulation, display_positions)
	_draw_nodes(display_simulation, display_positions)
	if editing:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.18, 0.62, 0.9, 0.055), true)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(18, 28),
			"PREVIEW // 未確定",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color(0.46, 0.82, 1.0)
		)


func _draw_lines(display_simulation: FactorySimulation, display_positions: Dictionary) -> void:
	for line_id in display_simulation.lines:
		var line: FactoryLineModel = display_simulation.lines[line_id]
		var start := _scaled_position(display_positions.get(line.from_node_id, Vector2.ZERO))
		var finish := _scaled_position(display_positions.get(line.to_node_id, Vector2.ZERO))
		draw_line(start, finish, LINE_COLOR, 4.0, true)
		if line.payload != null:
			var progress := 1.0 - float(line.remaining_ticks) / float(line.travel_ticks)
			draw_circle(start.lerp(finish, progress), 7.0, GLYPH_COLOR)


func _draw_nodes(display_simulation: FactorySimulation, display_positions: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	for node_id in display_simulation.nodes:
		var node: FactoryNodeModel = display_simulation.nodes[node_id]
		var center := _scaled_position(display_positions.get(node_id, Vector2.ZERO))
		var rect := Rect2(center - Vector2(48, 30), Vector2(96, 60))
		draw_rect(rect, NODE_COLOR, true)
		draw_rect(rect, NODE_BORDER, false, 2.0)
		var label := MvpContent.node_name(node.kind)
		draw_string(
			font,
			center + Vector2(-font.get_string_size(label).x * 0.5, 5),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			15,
			Color(0.82, 0.9, 1.0)
		)
		if node.output_buffer != null or node.processing_glyph != null:
			draw_circle(center + Vector2(0, 22), 4.0, GLYPH_COLOR)


func _scaled_position(reference_position: Vector2) -> Vector2:
	return Vector2(
		reference_position.x / 820.0 * size.x,
		reference_position.y / 395.0 * size.y
	)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = Color(0.18, 0.32, 0.46, 0.8)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
