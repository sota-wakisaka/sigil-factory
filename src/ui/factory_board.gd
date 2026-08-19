class_name FactoryBoard
extends Control

signal summon_produced(unit_id: StringName)
signal selection_changed
signal factory_changed

const MvpContent := preload("res://src/game/mvp_content.gd")
const FactoryNodeModel := preload("res://src/factory/factory_node.gd")
const FactoryLineModel := preload("res://src/factory/factory_line.gd")

const PANEL_COLOR := Color(0.035, 0.055, 0.085, 0.96)
const NODE_COLOR := Color(0.08, 0.12, 0.18, 1.0)
const NODE_BORDER := Color(0.38, 0.62, 0.82, 0.9)
const LINE_COLOR := Color(0.24, 0.48, 0.68, 0.75)
const GLYPH_COLOR := Color(0.35, 0.86, 1.0, 1.0)
const SELECTED_COLOR := Color(1.0, 0.78, 0.3, 1.0)
const NODE_HALF_SIZE := Vector2(48, 30)
const REFERENCE_SIZE := Vector2(820, 395)
const PORT_RADIUS := 7.0
const PRODUCTION_PREVIEW_TICKS := 160

var plan_id: StringName = MvpContent.PLAN_SCOUT
var simulation: FactorySimulation
var node_positions: Dictionary = {}
var observed_event_count := 0
var editing := false
var pending_plan_id: StringName
var preview_simulation: FactorySimulation
var preview_node_positions: Dictionary = {}
var interaction_enabled := false
var selected_node_id: StringName = &""
var dragging_node := false
var drag_offset := Vector2.ZERO
var connecting_from_node_id: StringName = &""
var connection_cursor := Vector2.ZERO
var connection_serial := 1
var node_serial := 1
var connection_message := ""
var undo_history: Array[Dictionary] = []
var cached_production_preview := ""
var run_upgrades: Array[StringName] = []


func _ready() -> void:
	configure(plan_id)


func configure(next_plan_id: StringName) -> void:
	plan_id = next_plan_id
	simulation = MvpContent.build_factory(plan_id)
	_apply_run_upgrades(simulation)
	node_positions = MvpContent.layout_for_plan(plan_id)
	observed_event_count = 0
	editing = false
	preview_simulation = null
	selected_node_id = &""
	dragging_node = false
	connecting_from_node_id = &""
	connection_message = ""
	undo_history.clear()
	_refresh_production_preview()
	selection_changed.emit()
	queue_redraw()


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	if not enabled:
		dragging_node = false
		selected_node_id = &""
		connecting_from_node_id = &""
	selection_changed.emit()
	queue_redraw()


func move_node(node_id: StringName, local_position: Vector2) -> bool:
	var positions := _display_positions()
	if not interaction_enabled or not positions.has(node_id):
		return false
	var margin := NODE_HALF_SIZE + Vector2(8, 8)
	var clamped_local := Vector2(
		clampf(local_position.x, margin.x, size.x - margin.x),
		clampf(local_position.y, margin.y, size.y - margin.y)
	)
	positions[node_id] = _reference_position(clamped_local)
	queue_redraw()
	return true


func node_local_position(node_id: StringName) -> Vector2:
	return _scaled_position(_display_positions().get(node_id, Vector2.ZERO))


func add_node_from_palette(template_id: StringName) -> StringName:
	if not interaction_enabled:
		return &""
	var kind := FactoryNodeModel.NodeKind.SOURCE
	var config := {}
	var prefix := "node"
	match template_id:
		&"ring_source":
			prefix = "ring_source"
			config = {"primitive_id": "ring", "interval_ticks": 18}
		&"spike_source":
			prefix = "spike_source"
			config = {"primitive_id": "spike", "interval_ticks": 54}
		&"rotator":
			prefix = "rotator"
			kind = FactoryNodeModel.NodeKind.ROTATOR
			config = {"steps": 1, "processing_ticks": 2}
		&"colorizer":
			prefix = "colorizer"
			kind = FactoryNodeModel.NodeKind.COLORIZER
			config = {"color_id": "blue", "processing_ticks": 2}
		&"combiner":
			prefix = "combiner"
			kind = FactoryNodeModel.NodeKind.COMBINER
			config = {"processing_ticks": 3}
		&"summoner":
			prefix = "summoner"
			kind = FactoryNodeModel.NodeKind.SUMMONER
		_:
			return &""
	var display_simulation := _display_simulation()
	_push_undo_snapshot()
	var node_id := StringName("%s_user_%d" % [prefix, node_serial])
	while display_simulation.nodes.has(node_id):
		node_serial += 1
		node_id = StringName("%s_user_%d" % [prefix, node_serial])
	node_serial += 1
	var new_node := FactoryNodeModel.new(node_id, kind, config)
	_apply_node_upgrades(new_node)
	display_simulation.add_node(new_node)
	var column := posmod(node_serial - 2, 3)
	var row := posmod((node_serial - 2) / 3, 2)
	_display_positions()[node_id] = Vector2(250 + column * 150, 135 + row * 125)
	selected_node_id = node_id
	connection_message = "%sを追加しました" % MvpContent.node_name(kind)
	_refresh_production_preview()
	selection_changed.emit()
	queue_redraw()
	return node_id


func remove_factory_node(node_id: StringName) -> bool:
	if not interaction_enabled or node_id == &"":
		return false
	var display_simulation := _display_simulation()
	_push_undo_snapshot()
	var discarded_now := display_simulation.discard_all_work_in_progress() if editing else 0
	if not display_simulation.remove_node(node_id):
		var snapshot: Dictionary = undo_history.pop_back()
		if editing:
			preview_simulation = snapshot["simulation"]
		else:
			simulation = snapshot["simulation"]
		return false
	_display_positions().erase(node_id)
	if selected_node_id == node_id:
		selected_node_id = &""
	if connecting_from_node_id == node_id:
		connecting_from_node_id = &""
	connection_message = (
		"設備を削除しました（仕掛品%d個を廃棄予定）" % discarded_now
		if discarded_now > 0
		else "設備を削除しました"
	)
	_refresh_production_preview()
	selection_changed.emit()
	queue_redraw()
	return true


func remove_selected_node() -> bool:
	return remove_factory_node(selected_node_id)


func undo() -> bool:
	if not interaction_enabled or undo_history.is_empty():
		return false
	var snapshot: Dictionary = undo_history.pop_back()
	if editing:
		preview_simulation = snapshot["simulation"]
		preview_node_positions = snapshot["positions"]
	else:
		simulation = snapshot["simulation"]
		node_positions = snapshot["positions"]
	selected_node_id = &""
	connecting_from_node_id = &""
	connection_message = "元に戻しました"
	_refresh_production_preview()
	selection_changed.emit()
	queue_redraw()
	return true


func validation_result() -> Dictionary:
	var result := _display_simulation().validate_graph()
	result["message"] = _validation_message(result["errors"])
	return result


func set_run_upgrades(upgrades: Array[StringName]) -> void:
	run_upgrades = upgrades.duplicate()


func is_guided_connection_pending() -> bool:
	var display_simulation := _display_simulation()
	return (
		plan_id == MvpContent.PLAN_EMPTY
		and display_simulation != null
		and display_simulation.lines.is_empty()
		and display_simulation.nodes.has(&"ring_source")
		and display_simulation.nodes.has(&"summoner")
	)


func selected_node_details() -> Dictionary:
	var display_simulation := _display_simulation()
	if selected_node_id == &"" or display_simulation == null or not display_simulation.nodes.has(selected_node_id):
		return {"selected": false, "title": "設備を選択", "options": PackedStringArray(), "selected_index": -1}
	var node: FactoryNodeModel = display_simulation.nodes[selected_node_id]
	var options := PackedStringArray()
	var selected_index := -1
	match node.kind:
		FactoryNodeModel.NodeKind.SOURCE:
			options = PackedStringArray(["環素材", "棘素材"])
			selected_index = 1 if String(node.config.get("primitive_id", "ring")) == "spike" else 0
		FactoryNodeModel.NodeKind.ROTATOR:
			options = PackedStringArray(["90°", "180°", "270°"])
			selected_index = clampi(int(node.config.get("steps", 1)) - 1, 0, 2)
		FactoryNodeModel.NodeKind.COLORIZER:
			options = PackedStringArray(["青", "赤", "白"])
			var color_id := String(node.config.get("color_id", "blue"))
			selected_index = ["blue", "red", "white"].find(color_id)
	return {
		"selected": true,
		"title": _node_label(node),
		"options": options,
		"selected_index": selected_index,
	}


func configure_selected_node(option_index: int) -> bool:
	var display_simulation := _display_simulation()
	if not interaction_enabled or selected_node_id == &"" or not display_simulation.nodes.has(selected_node_id):
		return false
	var node: FactoryNodeModel = display_simulation.nodes[selected_node_id]
	var config_changed := false
	match node.kind:
		FactoryNodeModel.NodeKind.SOURCE:
			if option_index < 0 or option_index > 1:
				return false
			config_changed = String(node.config.get("primitive_id", "ring")) != ("spike" if option_index == 1 else "ring")
		FactoryNodeModel.NodeKind.ROTATOR:
			if option_index < 0 or option_index > 2:
				return false
			config_changed = int(node.config.get("steps", 1)) != option_index + 1
		FactoryNodeModel.NodeKind.COLORIZER:
			if option_index < 0 or option_index > 2:
				return false
			config_changed = String(node.config.get("color_id", "blue")) != ["blue", "red", "white"][option_index]
		_:
			return false
	if not config_changed:
		return false
	_push_undo_snapshot()
	var discarded_now := display_simulation.discard_all_work_in_progress() if editing else 0
	match node.kind:
		FactoryNodeModel.NodeKind.SOURCE:
			node.config["primitive_id"] = "spike" if option_index == 1 else "ring"
			node.config["interval_ticks"] = 54 if option_index == 1 else 18
			_apply_node_upgrades(node)
		FactoryNodeModel.NodeKind.ROTATOR:
			node.config["steps"] = option_index + 1
		FactoryNodeModel.NodeKind.COLORIZER:
			node.config["color_id"] = ["blue", "red", "white"][option_index]
	connection_message = (
		"設備設定を変更しました（仕掛品%d個を廃棄予定）" % discarded_now
		if discarded_now > 0
		else "設備設定を変更しました"
	)
	_refresh_production_preview()
	selection_changed.emit()
	queue_redraw()
	return true


func production_preview(ticks: int = PRODUCTION_PREVIEW_TICKS) -> Dictionary:
	var counts := {&"scout": 0, &"sentinel": 0, &"golem": 0}
	var display_simulation := _display_simulation()
	if display_simulation == null:
		return {"ok": false, "counts": counts, "discarded": 0}
	var validation := display_simulation.validate_graph()
	if not validation["ok"]:
		return {"ok": false, "counts": counts, "discarded": 0}
	var preview := display_simulation.duplicate_state()
	var event_start := preview.summon_events.size()
	var discarded_start := preview.discarded_glyphs
	for _tick in maxi(ticks, 0):
		preview.tick()
	for event_index in range(event_start, preview.summon_events.size()):
		var unit_id: StringName = preview.summon_events[event_index]["unit_id"]
		counts[unit_id] = int(counts.get(unit_id, 0)) + 1
	return {
		"ok": true,
		"counts": counts,
		"discarded": preview.discarded_glyphs - discarded_start,
	}


func connect_nodes_interactive(from_node_id: StringName, to_node_id: StringName, to_port: int) -> Dictionary:
	if not interaction_enabled:
		return {"ok": false, "error": "locked"}
	var display_simulation := _display_simulation()
	if display_simulation == null or from_node_id == to_node_id:
		return {"ok": false, "error": "self_connection"}
	_push_undo_snapshot()
	var removed_line: FactoryLineModel
	for line in display_simulation.lines.values():
		if line.to_node_id == to_node_id and line.to_port == to_port:
			removed_line = line
			display_simulation.disconnect_line(line.id)
			break
	var line_id := StringName("user_line_%d" % connection_serial)
	connection_serial += 1
	var result := display_simulation.connect_nodes(
		FactoryLineModel.new(line_id, from_node_id, to_node_id, to_port, 2)
	)
	if result["ok"]:
		_apply_line_upgrades(display_simulation.lines[line_id])
	if not result["ok"] and removed_line != null:
		display_simulation.connect_nodes(removed_line)
	if not result["ok"]:
		undo_history.pop_back()
	var discarded_now := 0
	if result["ok"] and editing:
		discarded_now = display_simulation.discard_all_work_in_progress()
		if removed_line != null and removed_line.payload != null:
			display_simulation.discarded_glyphs += 1
			discarded_now += 1
	connection_message = _connection_result_text(result)
	if discarded_now > 0:
		connection_message += "（仕掛品%d個を廃棄予定）" % discarded_now
	_refresh_production_preview()
	queue_redraw()
	return result


func disconnect_input(to_node_id: StringName, to_port: int) -> bool:
	if not interaction_enabled:
		return false
	var display_simulation := _display_simulation()
	for line in display_simulation.lines.values():
		if line.to_node_id == to_node_id and line.to_port == to_port:
			_push_undo_snapshot()
			var discarded_now := display_simulation.discard_all_work_in_progress() if editing else 0
			display_simulation.disconnect_line(line.id)
			connection_message = (
				"接続を解除しました（仕掛品%d個を廃棄予定）" % discarded_now
				if discarded_now > 0
				else "接続を解除しました"
			)
			_refresh_production_preview()
			queue_redraw()
			return true
	return false


func _gui_input(event: InputEvent) -> void:
	if not interaction_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var input_port := _input_port_at(event.position)
			if not input_port.is_empty() and connecting_from_node_id != &"":
				connect_nodes_interactive(connecting_from_node_id, input_port["node_id"], input_port["port"])
				connecting_from_node_id = &""
				accept_event()
				return
			var output_node_id := _output_port_at(event.position)
			if output_node_id != &"":
				connecting_from_node_id = output_node_id
				connection_cursor = event.position
				connection_message = "入力ポートを選択してください"
				accept_event()
				queue_redraw()
				return
			selected_node_id = _node_at(event.position)
			selection_changed.emit()
			dragging_node = selected_node_id != &""
			if dragging_node:
				_push_undo_snapshot()
				drag_offset = node_local_position(selected_node_id) - event.position
				accept_event()
		else:
			dragging_node = false
		queue_redraw()
	elif event is InputEventMouseMotion and dragging_node:
		move_node(selected_node_id, event.position + drag_offset)
		accept_event()
	elif event is InputEventMouseMotion and connecting_from_node_id != &"":
		connection_cursor = event.position
		queue_redraw()
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var input_port := _input_port_at(event.position)
		if not input_port.is_empty():
			disconnect_input(input_port["node_id"], input_port["port"])
			accept_event()


func begin_edit() -> void:
	editing = true
	pending_plan_id = plan_id
	preview_simulation = simulation.duplicate_state()
	preview_node_positions = node_positions.duplicate(true)
	selected_node_id = &""
	connecting_from_node_id = &""
	undo_history.clear()
	_refresh_production_preview()
	selection_changed.emit()
	queue_redraw()


func preview_plan(next_plan_id: StringName) -> void:
	if not editing:
		return
	var discarded_before_edit := simulation.discarded_glyphs
	var discarded_work_in_progress := work_in_progress_count()
	var committed_tick := simulation.tick_index
	pending_plan_id = next_plan_id
	preview_simulation = MvpContent.build_factory(pending_plan_id)
	_apply_run_upgrades(preview_simulation)
	preview_simulation.discarded_glyphs = discarded_before_edit + discarded_work_in_progress
	preview_simulation.tick_index = committed_tick
	preview_node_positions = MvpContent.layout_for_plan(pending_plan_id)
	selected_node_id = &""
	undo_history.clear()
	_refresh_production_preview()
	selection_changed.emit()
	queue_redraw()


func commit_edit() -> void:
	if not editing:
		return
	plan_id = pending_plan_id
	simulation = preview_simulation
	node_positions = preview_node_positions
	observed_event_count = simulation.summon_events.size()
	editing = false
	preview_simulation = null
	undo_history.clear()
	_refresh_production_preview()
	selection_changed.emit()
	queue_redraw()


func cancel_edit() -> void:
	if not editing:
		return
	editing = false
	preview_simulation = null
	preview_node_positions.clear()
	undo_history.clear()
	_refresh_production_preview()
	selection_changed.emit()
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


func pending_discard_count() -> int:
	if not editing or preview_simulation == null or simulation == null:
		return 0
	return maxi(preview_simulation.discarded_glyphs - simulation.discarded_glyphs, 0)


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
	if is_guided_connection_pending():
		draw_dashed_line(
			_output_port_position(&"ring_source"),
			_input_port_position(&"summoner", 0),
			Color(1.0, 0.74, 0.24, 0.65),
			3.0,
			8.0
		)
	if connecting_from_node_id != &"":
		draw_line(_output_port_position(connecting_from_node_id), connection_cursor, SELECTED_COLOR, 3.0, true)
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
	if interaction_enabled:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(18, size.y - 12),
			"ドラッグ: 配置  /  ●出力→○入力: 接続  /  右クリック: 解除",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color(0.52, 0.65, 0.76)
		)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(18, size.y - 31),
			"シジル工程 // 斥候: 環  |  衛兵: 環→回転→青  |  巨像: 環+棘→合成→青",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			Color(0.66, 0.72, 0.84)
		)
		if connection_message != "":
			draw_string(
				ThemeDB.fallback_font,
				Vector2(18, 22),
				connection_message,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				12,
				SELECTED_COLOR
			)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(18, 43),
			cached_production_preview,
			HORIZONTAL_ALIGNMENT_RIGHT,
			size.x - 36.0,
			12,
			Color(0.54, 0.86, 0.7)
		)


func _draw_lines(display_simulation: FactorySimulation, display_positions: Dictionary) -> void:
	for line_id in display_simulation.lines:
		var line: FactoryLineModel = display_simulation.lines[line_id]
		var start := _scaled_position(display_positions.get(line.from_node_id, Vector2.ZERO)) + Vector2(NODE_HALF_SIZE.x, 0)
		var finish := _input_port_position(line.to_node_id, line.to_port)
		draw_line(start, finish, LINE_COLOR, 4.0, true)
		if line.payload != null:
			var progress := 1.0 - float(line.remaining_ticks) / float(line.travel_ticks)
			draw_circle(start.lerp(finish, progress), 7.0, GLYPH_COLOR)


func _draw_nodes(display_simulation: FactorySimulation, display_positions: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	for node_id in display_simulation.nodes:
		var node: FactoryNodeModel = display_simulation.nodes[node_id]
		var center := _scaled_position(display_positions.get(node_id, Vector2.ZERO))
		var rect := Rect2(center - NODE_HALF_SIZE, NODE_HALF_SIZE * 2.0)
		draw_rect(rect, NODE_COLOR, true)
		var border_color := SELECTED_COLOR if node_id == selected_node_id else NODE_BORDER
		draw_rect(rect, border_color, false, 3.0 if node_id == selected_node_id else 2.0)
		var label := _node_label(node)
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
		_draw_ports(node, center)


func _draw_ports(node: FactoryNodeModel, center: Vector2) -> void:
	if node.kind != FactoryNodeModel.NodeKind.SUMMONER:
		var output_color := LINE_COLOR
		if is_guided_connection_pending() and node.id == &"ring_source":
			output_color = SELECTED_COLOR
		draw_circle(center + Vector2(NODE_HALF_SIZE.x, 0), PORT_RADIUS, output_color)
	for port in node.required_input_count():
		var position := _input_port_position(node.id, port)
		var input_color := LINE_COLOR
		if is_guided_connection_pending() and node.id == &"summoner":
			input_color = SELECTED_COLOR
		draw_circle(position, PORT_RADIUS, PANEL_COLOR)
		draw_arc(position, PORT_RADIUS, 0.0, TAU, 20, input_color, 2.0)


func _node_label(node: FactoryNodeModel) -> String:
	match node.kind:
		FactoryNodeModel.NodeKind.SOURCE:
			var primitive := String(node.config.get("primitive_id", "ring"))
			return "棘素材" if primitive == "spike" else "環素材"
		FactoryNodeModel.NodeKind.ROTATOR:
			return "回転 +90°"
		FactoryNodeModel.NodeKind.TRANSLATOR:
			return "位置移動"
		FactoryNodeModel.NodeKind.COLORIZER:
			return "青着色"
		FactoryNodeModel.NodeKind.COMBINER:
			return "グリフ合成"
		FactoryNodeModel.NodeKind.SUMMONER:
			return "召喚器"
	return MvpContent.node_name(node.kind)


func _scaled_position(reference_position: Vector2) -> Vector2:
	return Vector2(
		reference_position.x / REFERENCE_SIZE.x * size.x,
		reference_position.y / REFERENCE_SIZE.y * size.y
	)


func _reference_position(local_position: Vector2) -> Vector2:
	return Vector2(
		local_position.x / size.x * REFERENCE_SIZE.x,
		local_position.y / size.y * REFERENCE_SIZE.y
	)


func _display_positions() -> Dictionary:
	return preview_node_positions if editing else node_positions


func _display_simulation() -> FactorySimulation:
	return preview_simulation if editing else simulation


func _node_at(local_position: Vector2) -> StringName:
	var display_simulation := _display_simulation()
	if display_simulation == null:
		return &""
	var ids := display_simulation.nodes.keys()
	ids.reverse()
	for node_id in ids:
		var center := node_local_position(node_id)
		if Rect2(center - NODE_HALF_SIZE, NODE_HALF_SIZE * 2.0).has_point(local_position):
			return node_id
	return &""


func _output_port_position(node_id: StringName) -> Vector2:
	return node_local_position(node_id) + Vector2(NODE_HALF_SIZE.x, 0)


func _input_port_position(node_id: StringName, port: int) -> Vector2:
	var node: FactoryNodeModel = _display_simulation().nodes[node_id]
	var y_offset := 0.0
	if node.required_input_count() == 2:
		y_offset = -13.0 if port == 0 else 13.0
	return node_local_position(node_id) + Vector2(-NODE_HALF_SIZE.x, y_offset)


func _output_port_at(local_position: Vector2) -> StringName:
	var display_simulation := _display_simulation()
	if display_simulation == null:
		return &""
	for node_id in display_simulation.nodes:
		var node: FactoryNodeModel = display_simulation.nodes[node_id]
		if node.kind == FactoryNodeModel.NodeKind.SUMMONER:
			continue
		if local_position.distance_to(_output_port_position(node_id)) <= PORT_RADIUS + 4.0:
			return node_id
	return &""


func _input_port_at(local_position: Vector2) -> Dictionary:
	var display_simulation := _display_simulation()
	if display_simulation == null:
		return {}
	for node_id in display_simulation.nodes:
		var node: FactoryNodeModel = display_simulation.nodes[node_id]
		for port in node.required_input_count():
			if local_position.distance_to(_input_port_position(node_id, port)) <= PORT_RADIUS + 4.0:
				return {"node_id": node_id, "port": port}
	return {}


func _connection_result_text(result: Dictionary) -> String:
	if result["ok"]:
		return "接続しました"
	match result["error"]:
		"cycle":
			return "接続できません: 回路が循環します"
		"invalid_port":
			return "接続できません: 入力ポートがありません"
		"occupied_port":
			return "接続できません: 入力はすでに接続されています"
		"occupied_output":
			return "接続できません: 出力はすでに接続されています。分岐器はMVP対象外です"
		"self_connection":
			return "接続できません: 同じ設備には接続できません"
		_:
			return "接続できません: %s" % result["error"]


func _validation_message(errors: Array) -> String:
	if errors.is_empty():
		return "工場は稼働可能です"
	var error := String(errors[0])
	if error == "missing_source":
		return "素材源がありません"
	if error == "missing_summoner":
		return "召喚器がありません"
	if error.begins_with("missing_input:"):
		return "入力が未接続の設備があります"
	if error.begins_with("missing_output:"):
		return "出力が未接続の設備があります"
	return "工場の配線を確認してください"


func _push_undo_snapshot() -> void:
	var display_simulation := _display_simulation()
	if display_simulation == null:
		return
	undo_history.append({
		"simulation": display_simulation.duplicate_state(),
		"positions": _display_positions().duplicate(true),
	})


func _refresh_production_preview() -> void:
	var result := production_preview()
	if not result["ok"]:
		cached_production_preview = "32秒予測 // 配線未完成"
		factory_changed.emit()
		return
	var counts: Dictionary = result["counts"]
	cached_production_preview = "32秒予測 // 斥候 %d  衛兵 %d  巨像 %d  不一致 %d" % [
		counts[&"scout"],
		counts[&"sentinel"],
		counts[&"golem"],
		result["discarded"],
	]
	factory_changed.emit()


func _apply_run_upgrades(target_simulation: FactorySimulation) -> void:
	for node in target_simulation.nodes.values():
		_apply_node_upgrades(node)
	for line in target_simulation.lines.values():
		_apply_line_upgrades(line)


func _apply_node_upgrades(node: FactoryNodeModel) -> void:
	for upgrade_id in run_upgrades:
		if upgrade_id == &"ring_speed" and node.kind == FactoryNodeModel.NodeKind.SOURCE and String(node.config.get("primitive_id", "")) == "ring":
			node.config["interval_ticks"] = maxi(int(round(float(node.config.get("interval_ticks", 18)) * 0.8)), 1)
		elif upgrade_id == &"processing_speed" and node.kind not in [FactoryNodeModel.NodeKind.SOURCE, FactoryNodeModel.NodeKind.SUMMONER]:
			node.config["processing_ticks"] = maxi(int(node.config.get("processing_ticks", 1)) - 1, 1)


func _apply_line_upgrades(line: FactoryLineModel) -> void:
	for upgrade_id in run_upgrades:
		if upgrade_id == &"line_speed":
			line.travel_ticks = maxi(line.travel_ticks - 1, 1)


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
