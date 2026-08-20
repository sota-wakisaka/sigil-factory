class_name FactoryBoard
extends Control

signal summon_produced(unit_id: StringName)
signal selection_changed
signal factory_changed

const MvpContent := preload("res://src/game/mvp_content.gd")
const FactoryNodeModel := preload("res://src/factory/factory_node.gd")
const FactoryLineModel := preload("res://src/factory/factory_line.gd")
const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")
const GlyphTooltipModel := preload("res://src/ui/glyph_tooltip.gd")
const GlyphComponentModel := preload("res://src/domain/glyph_component.gd")

const PANEL_COLOR := Color(0.035, 0.055, 0.085, 0.96)
const NODE_COLOR := Color(0.08, 0.12, 0.18, 1.0)
const NODE_BORDER := Color(0.38, 0.62, 0.82, 0.9)
const LINE_COLOR := Color(0.24, 0.48, 0.68, 0.75)
const GLYPH_COLOR := Color(0.35, 0.86, 1.0, 1.0)
const SELECTED_COLOR := Color(1.0, 0.78, 0.3, 1.0)
const WARNING_COLOR := Color(1.0, 0.38, 0.28, 1.0)
const WAITING_COLOR := Color(1.0, 0.72, 0.24, 1.0)
const MATCH_COLOR := Color(0.36, 1.0, 0.58, 1.0)
const NODE_HALF_SIZE := Vector2(48, 30)
const REFERENCE_SIZE := Vector2(820, 395)
const PORT_RADIUS := 7.0
const FACTORY_LINE_WIDTH := 2.0
const TRANSPORT_GLYPH_HALO_RADIUS := 13.0
const PRODUCTION_PREVIEW_TICKS := 160
const FLOW_WARNING_HOLD_TICKS := 5

var plan_id: StringName = MvpContent.PLAN_SCOUT
var simulation: FactorySimulation
var node_positions: Dictionary = {}
var observed_event_count := 0
var observed_failure_count := 0
var editing := false
var pending_plan_id: StringName
var preview_simulation: FactorySimulation
var preview_node_positions: Dictionary = {}
var interaction_enabled := false
var selected_node_id: StringName = &""
var hovered_node_id: StringName = &""
var hovered_output_node_id: StringName = &""
var hovered_input_node_id: StringName = &""
var hovered_input_port := -1
var dragging_node := false
var drag_snapshot_pending := false
var drag_offset := Vector2.ZERO
var connecting_from_node_id: StringName = &""
var connection_cursor := Vector2.ZERO
var connection_serial := 1
var node_serial := 1
var connection_message := ""
var flow_warning_message := ""
var flow_warning_hold_ticks := 0
var undo_history: Array[Dictionary] = []
var cached_production_preview := ""
var cached_production_counts: Dictionary = {}
var cached_production_discarded := 0
var cached_production_valid := false
var cached_node_output_glyphs: Dictionary = {}
var tooltip_glyph: GlyphModel
var tooltip_title := ""
var tooltip_context := ""
var run_upgrades: Array[StringName] = []
var last_corrupt_discard_count := 0


func _ready() -> void:
	mouse_exited.connect(_clear_node_hover)
	configure(plan_id)


func configure(next_plan_id: StringName) -> void:
	plan_id = next_plan_id
	simulation = MvpContent.build_factory(plan_id)
	_apply_run_upgrades(simulation)
	node_positions = MvpContent.layout_for_plan(plan_id)
	observed_event_count = 0
	observed_failure_count = 0
	editing = false
	preview_simulation = null
	selected_node_id = &""
	hovered_node_id = &""
	hovered_output_node_id = &""
	hovered_input_node_id = &""
	hovered_input_port = -1
	dragging_node = false
	drag_snapshot_pending = false
	connecting_from_node_id = &""
	connection_message = ""
	flow_warning_message = ""
	flow_warning_hold_ticks = 0
	undo_history.clear()
	_refresh_production_preview()
	selection_changed.emit()
	queue_redraw()


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	if not enabled:
		dragging_node = false
		drag_snapshot_pending = false
		selected_node_id = &""
		hovered_node_id = &""
		hovered_output_node_id = &""
		hovered_input_node_id = &""
		hovered_input_port = -1
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
	if kind == FactoryNodeModel.NodeKind.SUMMONER and _summoner_count(display_simulation) >= 1:
		connection_message = "召喚器を追加できません: 現MVPは1基までです"
		queue_redraw()
		return &""
	var node_cost := MvpContent.node_mana_cost(kind)
	if mana_used(display_simulation) + node_cost > MvpContent.FACTORY_MANA_MAX:
		connection_message = "設備を追加できません: 魔力不足（必要%d / 空き%d）" % [
			node_cost,
			mana_available(display_simulation),
		]
		queue_redraw()
		return &""
	_push_undo_snapshot()
	var node_id := StringName("%s_user_%d" % [prefix, node_serial])
	while display_simulation.nodes.has(node_id):
		node_serial += 1
		node_id = StringName("%s_user_%d" % [prefix, node_serial])
	node_serial += 1
	var new_node := FactoryNodeModel.new(node_id, kind, config)
	_apply_node_upgrades(new_node)
	var registration := display_simulation.node_registration_result(new_node)
	if not registration["ok"]:
		undo_history.pop_back()
		connection_message = "設備を追加できません: 設備データが不正です（%s）" % ", ".join(registration["errors"])
		queue_redraw()
		return &""
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
		"設備を削除しました（%s）" % pending_discard_notice()
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
	if mana_used(_display_simulation()) > MvpContent.FACTORY_MANA_MAX:
		result["ok"] = false
		result["errors"].append("mana_exceeded")
	result["message"] = _validation_message(result["errors"])
	return result


func mana_used(source_simulation: FactorySimulation = null) -> int:
	var target_simulation := source_simulation if source_simulation != null else _display_simulation()
	if target_simulation == null:
		return 0
	var total := 0
	for node in target_simulation.nodes.values():
		total += MvpContent.node_mana_cost(node.kind)
	return total


func mana_available(source_simulation: FactorySimulation = null) -> int:
	return maxi(MvpContent.FACTORY_MANA_MAX - mana_used(source_simulation), 0)


func mana_fill_ratio(source_simulation: FactorySimulation = null) -> float:
	return clampf(float(mana_used(source_simulation)) / float(MvpContent.FACTORY_MANA_MAX), 0.0, 1.0)


func palette_availability(template_id: StringName) -> Dictionary:
	if not interaction_enabled:
		return {"available": false, "reason": &"locked"}
	var kind := FactoryNodeModel.NodeKind.SOURCE
	match template_id:
		&"ring_source", &"spike_source":
			kind = FactoryNodeModel.NodeKind.SOURCE
		&"rotator":
			kind = FactoryNodeModel.NodeKind.ROTATOR
		&"colorizer":
			kind = FactoryNodeModel.NodeKind.COLORIZER
		&"combiner":
			kind = FactoryNodeModel.NodeKind.COMBINER
		&"summoner":
			kind = FactoryNodeModel.NodeKind.SUMMONER
		_:
			return {"available": false, "reason": &"unknown"}
	var display_simulation := _display_simulation()
	if kind == FactoryNodeModel.NodeKind.SUMMONER and _summoner_count(display_simulation) >= 1:
		return {"available": false, "reason": &"summoner_limit"}
	if mana_used(display_simulation) + MvpContent.node_mana_cost(kind) > MvpContent.FACTORY_MANA_MAX:
		return {"available": false, "reason": &"mana"}
	return {"available": true, "reason": &""}


func can_undo() -> bool:
	return interaction_enabled and not undo_history.is_empty()


func mana_status_text() -> String:
	return "魔力 %d/%d // 空き%d" % [
		mana_used(),
		MvpContent.FACTORY_MANA_MAX,
		mana_available(),
	]


func _summoner_count(source_simulation: FactorySimulation) -> int:
	var count := 0
	for node in source_simulation.nodes.values():
		count += int(node.kind == FactoryNodeModel.NodeKind.SUMMONER)
	return count


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
		return {"selected": false, "kind": -1, "title": "設備を選択", "options": PackedStringArray(), "selected_index": -1}
	var node: FactoryNodeModel = display_simulation.nodes[selected_node_id]
	var options := PackedStringArray()
	var selected_index := -1
	match node.kind:
		FactoryNodeModel.NodeKind.SOURCE:
			options = PackedStringArray(["環", "棘"])
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
		"kind": node.kind,
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
		"設備設定を変更しました（%s）" % pending_discard_notice()
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
		return {"ok": false, "counts": counts, "discarded": 0, "first_failure": {}, "node_outputs": {}, "errors": []}
	var validation := display_simulation.validate_graph()
	if not validation["ok"]:
		return {
			"ok": false,
			"counts": counts,
			"discarded": 0,
			"first_failure": {},
			"node_outputs": {},
			"errors": validation["errors"].duplicate(),
		}
	var duplication := display_simulation.duplicate_state_result()
	if not duplication["ok"]:
		return {
			"ok": false,
			"counts": counts,
			"discarded": 0,
			"first_failure": {},
			"node_outputs": {},
			"errors": duplication["errors"].duplicate(),
		}
	var preview: FactorySimulation = duplication["state"]
	var event_start := preview.summon_events.size()
	var failure_start := preview.summon_failure_events.size()
	var discarded_start := preview.discarded_glyphs
	var node_outputs: Dictionary = {}
	for _tick in maxi(ticks, 0):
		preview.tick()
		_capture_preview_node_outputs(preview, node_outputs)
	for event_index in range(event_start, preview.summon_events.size()):
		var unit_id: StringName = preview.summon_events[event_index]["unit_id"]
		counts[unit_id] = int(counts.get(unit_id, 0)) + 1
	var first_failure: Dictionary = {}
	if preview.summon_failure_events.size() > failure_start:
		first_failure = preview.summon_failure_events[failure_start].duplicate(true)
	return {
		"ok": true,
		"counts": counts,
		"discarded": preview.discarded_glyphs - discarded_start,
		"first_failure": first_failure,
		"node_outputs": node_outputs,
		"errors": [],
	}


func _capture_preview_node_outputs(preview: FactorySimulation, outputs: Dictionary) -> void:
	for node_id in preview.nodes:
		if outputs.has(node_id):
			continue
		var node: FactoryNodeModel = preview.nodes[node_id]
		if node.output_buffer != null and node.output_buffer.structure_validation_errors().is_empty():
			outputs[node_id] = node.output_buffer.copy()
	for line in preview.lines.values():
		if outputs.has(line.from_node_id) or line.payload == null:
			continue
		if line.payload.structure_validation_errors().is_empty():
			outputs[line.from_node_id] = line.payload.copy()


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
		connection_message += "（%s）" % pending_discard_notice()
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
				"接続を解除しました（%s）" % pending_discard_notice()
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
	if event is InputEventMouseMotion:
		_update_pointer_hover(event.position)
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
				drag_snapshot_pending = true
				drag_offset = node_local_position(selected_node_id) - event.position
				accept_event()
		else:
			dragging_node = false
			drag_snapshot_pending = false
		queue_redraw()
	elif event is InputEventMouseMotion and dragging_node:
		if drag_snapshot_pending:
			_push_undo_snapshot()
			drag_snapshot_pending = false
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


func _clear_node_hover() -> void:
	if hovered_node_id == &"" and hovered_output_node_id == &"" and hovered_input_node_id == &"":
		return
	hovered_node_id = &""
	hovered_output_node_id = &""
	hovered_input_node_id = &""
	hovered_input_port = -1
	queue_redraw()


func _update_pointer_hover(at_position: Vector2) -> void:
	var next_node := _node_at(at_position)
	var next_output := _output_port_at(at_position)
	var input := _input_port_at(at_position)
	var next_input_node: StringName = input.get("node_id", &"")
	var next_input_port := int(input.get("port", -1))
	if (
		next_node == hovered_node_id
		and next_output == hovered_output_node_id
		and next_input_node == hovered_input_node_id
		and next_input_port == hovered_input_port
	):
		return
	hovered_node_id = next_node
	hovered_output_node_id = next_output
	hovered_input_node_id = next_input_node
	hovered_input_port = next_input_port
	queue_redraw()


func hovered_port_kind() -> StringName:
	if hovered_output_node_id != &"":
		return &"output"
	if hovered_input_node_id != &"":
		return &"input"
	return &"none"


func _get_cursor_shape(at_position: Vector2) -> CursorShape:
	return cursor_shape_at(at_position)


func cursor_shape_at(at_position: Vector2) -> CursorShape:
	if not interaction_enabled:
		return Control.CURSOR_ARROW
	if _output_port_at(at_position) != &"" or not _input_port_at(at_position).is_empty():
		return Control.CURSOR_POINTING_HAND
	if _node_at(at_position) != &"":
		return Control.CURSOR_DRAG
	return Control.CURSOR_ARROW


func begin_edit() -> void:
	last_corrupt_discard_count = 0
	var runtime_errors := simulation.work_in_progress_validation_errors()
	if not runtime_errors.is_empty():
		last_corrupt_discard_count = simulation.discard_invalid_work_in_progress()
		connection_message = "破損仕掛品 %d個を廃棄して編集状態へ復旧しました" % last_corrupt_discard_count
	var duplication := simulation.duplicate_state_result()
	if not duplication["ok"]:
		connection_message = "工場状態を複製できません // %s" % _validation_message(duplication["errors"])
		return
	editing = true
	pending_plan_id = plan_id
	preview_simulation = duplication["state"]
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
	observed_failure_count = simulation.summon_failure_events.size()
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
	return _work_in_progress_entries(simulation).size()


func work_in_progress_summary() -> String:
	var counts := {}
	for entry in _work_in_progress_entries(simulation):
		var glyph: GlyphModel = entry["glyph"]
		var label := _glyph_type_label(glyph)
		counts[label] = int(counts.get(label, 0)) + 1
	var labels := counts.keys()
	labels.sort()
	var parts := PackedStringArray()
	for label in labels:
		parts.append("%s×%d" % [label, counts[label]])
	return "、".join(parts)


func work_in_progress_impact_summary() -> String:
	var impacts := PackedStringArray()
	for entry in _work_in_progress_entries(simulation):
		var location := String(entry["location"])
		if not impacts.has(location):
			impacts.append(location)
	impacts.sort()
	return "、".join(impacts)


func pending_discard_count() -> int:
	if not editing or preview_simulation == null or simulation == null:
		return 0
	return maxi(preview_simulation.discarded_glyphs - simulation.discarded_glyphs, 0)


func pending_discard_notice() -> String:
	var count := pending_discard_count()
	if count <= 0:
		return ""
	var summary := work_in_progress_summary()
	var notice := (
		"仕掛品%d個を廃棄予定" % count
		if summary == ""
		else "仕掛品%d個（%s）を廃棄予定" % [count, summary]
	)
	var impact_summary := work_in_progress_impact_summary()
	if impact_summary != "":
		notice += " // 影響: " + impact_summary
	return notice


func _work_in_progress_entries(source_simulation: FactorySimulation) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if source_simulation == null:
		return entries
	var node_ids := source_simulation.nodes.keys()
	node_ids.sort()
	for node_id in node_ids:
		var node: FactoryNodeModel = source_simulation.nodes[node_id]
		var node_label := _node_label(node)
		for port in node.input_buffers.size():
			var glyph = node.input_buffers[port]
			if glyph != null:
				entries.append({"glyph": glyph, "location": "%s・入力%d" % [node_label, port + 1]})
		if node.output_buffer != null:
			entries.append({"glyph": node.output_buffer, "location": "%s・出力" % node_label})
		if node.processing_glyph != null:
			entries.append({"glyph": node.processing_glyph, "location": "%s・処理中" % node_label})
	var line_ids := source_simulation.lines.keys()
	line_ids.sort()
	for line_id in line_ids:
		var line: FactoryLineModel = source_simulation.lines[line_id]
		if line.payload != null:
			var from_node: FactoryNodeModel = source_simulation.nodes[line.from_node_id]
			var to_node: FactoryNodeModel = source_simulation.nodes[line.to_node_id]
			entries.append({
				"glyph": line.payload,
				"location": "%s→%s" % [_node_label(from_node), _node_label(to_node)],
			})
	return entries


func _glyph_type_label(glyph: GlyphModel) -> String:
	var component_labels := PackedStringArray()
	for component in glyph.components:
		var attributes := PackedStringArray([_primitive_name(component.primitive_id)])
		if component.color_id != &"white":
			attributes.append(_color_name(component.color_id))
		if component.rotation_step != 0:
			attributes.append("%d°" % (component.rotation_step * 90))
		if component.scale_step != 1:
			attributes.append("倍率%d" % component.scale_step)
		if component.position != Vector2i.ZERO:
			attributes.append("位置%d,%d" % [component.position.x, component.position.y])
		component_labels.append("・".join(attributes))
	component_labels.sort()
	return "+".join(component_labels)


func _primitive_name(primitive_id: StringName) -> String:
	return {&"ring": "環", &"spike": "棘", &"branch": "枝"}.get(primitive_id, String(primitive_id))


func _color_name(color_id: StringName) -> String:
	return {&"blue": "青", &"red": "赤", &"white": "白"}.get(color_id, String(color_id))


func advance_tick() -> void:
	if simulation == null:
		return
	simulation.tick()
	while observed_event_count < simulation.summon_events.size():
		var event := simulation.summon_events[observed_event_count]
		observed_event_count += 1
		connection_message = "召喚成功 // %s" % MvpContent.sigil_name(event["recipe_id"])
		summon_produced.emit(event["unit_id"])
	while observed_failure_count < simulation.summon_failure_events.size():
		var event := simulation.summon_failure_events[observed_failure_count]
		observed_failure_count += 1
		connection_message = _summon_failure_message(event)
	_refresh_flow_warning()
	queue_redraw()


func _summon_failure_message(event: Dictionary) -> String:
	var diagnostics: PackedStringArray = event.get("diagnostics", PackedStringArray())
	var reason := "原因不明" if diagnostics.is_empty() else " / ".join(diagnostics)
	var recipe_id: StringName = event.get("closest_recipe_id", &"")
	if recipe_id == &"":
		return "召喚失敗 // %s" % reason
	return "召喚失敗 // %sとの差分: %s" % [MvpContent.sigil_name(recipe_id), reason]


func _refresh_flow_warning() -> void:
	var warnings := PackedStringArray()
	for diagnostic in simulation.flow_diagnostics():
		var node_id: StringName = diagnostic.get("node_id", &"")
		var node_label := String(node_id)
		if simulation.nodes.has(node_id):
			node_label = _node_label(simulation.nodes[node_id])
		match diagnostic["code"]:
			&"buffer_full":
				warnings.append("入力満杯: %s" % node_label)
			&"output_blocked":
				warnings.append("出力閉塞: %s" % node_label)
			&"material_shortage":
				warnings.append("素材不足: %s" % node_label)
	if not warnings.is_empty():
		flow_warning_message = "工場警告 // " + " / ".join(warnings)
		flow_warning_hold_ticks = FLOW_WARNING_HOLD_TICKS
	elif flow_warning_hold_ticks > 0:
		flow_warning_hold_ticks -= 1
		if flow_warning_hold_ticks == 0:
			flow_warning_message = ""
	else:
		flow_warning_message = ""


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
		_draw_edit_summary()
	if interaction_enabled:
		_draw_interaction_legend()
		if cached_production_valid:
			_draw_production_summary()
		else:
			_draw_production_error_badge()
		_draw_mana_meter()
	if connection_message != "":
		_draw_connection_feedback_badge()
	if not interaction_enabled and flow_warning_message != "":
		_draw_flow_warning_badge()


func _draw_lines(display_simulation: FactorySimulation, display_positions: Dictionary) -> void:
	for line_id in display_simulation.lines:
		var line: FactoryLineModel = display_simulation.lines[line_id]
		var start := _scaled_position(display_positions.get(line.from_node_id, Vector2.ZERO)) + Vector2(NODE_HALF_SIZE.x, 0)
		var finish := _input_port_position(line.to_node_id, line.to_port)
		var line_color := WARNING_COLOR if display_simulation.line_flow_state(line_id) == &"buffer_full" else LINE_COLOR
		var goal_state := line_goal_match_state(line_id)
		if display_simulation.line_flow_state(line_id) != &"buffer_full":
			if goal_state == &"match":
				line_color = Color(MATCH_COLOR, 0.76)
			elif goal_state == &"mismatch":
				line_color = Color(WARNING_COLOR, 0.76)
		draw_line(start, finish, line_color, FACTORY_LINE_WIDTH, true)
		_draw_flow_arrow(start, finish, line_color)
		if display_simulation.line_flow_state(line_id) == &"buffer_full":
			_draw_line_blocked_marker(start.lerp(finish, 0.58))
		if goal_state in [&"match", &"mismatch"]:
			_draw_recipe_match_marker(start.lerp(finish, 0.76), goal_state, 7.0)
		if line.payload != null:
			var progress := 1.0 - float(line.remaining_ticks) / float(line.travel_ticks)
			var glyph_center := start.lerp(finish, progress)
			_draw_transport_glyph(line.payload, glyph_center)
			_draw_recipe_match_marker(glyph_center, line_recipe_match_state(line_id), 11.0)


func _draw_flow_arrow(start: Vector2, finish: Vector2, color: Color) -> void:
	var direction := start.direction_to(finish)
	if direction == Vector2.ZERO:
		return
	var center := start.lerp(finish, 0.5)
	var tip := center + direction * 8.0
	var wing_origin := center - direction * 5.0
	var normal := Vector2(-direction.y, direction.x) * 6.0
	draw_line(tip, wing_origin + normal, color, 1.5, true)
	draw_line(tip, wing_origin - normal, color, 1.5, true)


func _draw_transport_glyph(glyph: GlyphModel, center: Vector2) -> void:
	if not GlyphPainterModel.can_draw(glyph):
		return
	draw_circle(center, TRANSPORT_GLYPH_HALO_RADIUS, Color(0.012, 0.024, 0.038, 0.94))
	draw_arc(center, TRANSPORT_GLYPH_HALO_RADIUS, 0.0, TAU, 24, Color(0.22, 0.42, 0.56, 0.42), 1.0, true)
	_draw_mini_glyph(glyph, center, transport_glyph_draw_scale(glyph))


func transport_glyph_draw_scale(glyph: GlyphModel) -> float:
	if glyph != null and not glyph.combine_children.is_empty():
		return 0.85
	return 1.5


func _draw_nodes(display_simulation: FactorySimulation, display_positions: Dictionary) -> void:
	for node_id in display_simulation.nodes:
		var node: FactoryNodeModel = display_simulation.nodes[node_id]
		var center := _scaled_position(display_positions.get(node_id, Vector2.ZERO))
		var node_state := display_simulation.node_flow_state(node_id)
		var border_color := NODE_BORDER
		if node_state == &"output_blocked":
			border_color = WARNING_COLOR
		elif node_state == &"material_shortage":
			border_color = WAITING_COLOR
		if node_id == selected_node_id:
			border_color = SELECTED_COLOR
		elif node_id == hovered_node_id:
			border_color = Color(0.56, 0.86, 1.0)
		_draw_node_frame(node, center, border_color, node_id == selected_node_id or node_id == hovered_node_id)
		_draw_node_warning_marker(node_state, center)
		_draw_node_activity_progress(node, center, display_simulation.tick_index > 0)
		var visible_glyph := _visible_node_active_glyph(node)
		if visible_glyph != null:
			_draw_mini_glyph(visible_glyph, center + Vector2(0, 3), node_glyph_draw_scale(visible_glyph))
		elif cached_node_output_glyphs.has(node_id):
			var predicted_glyph: GlyphModel = cached_node_output_glyphs[node_id]
			_draw_mini_glyph(
				predicted_glyph,
				center + Vector2(0, 3),
				node_glyph_draw_scale(predicted_glyph),
				0.82
			)
		else:
			var source_glyph := source_glyph_for_node(node_id)
			if source_glyph != null:
				_draw_mini_glyph(source_glyph, center + Vector2(0, 3), 1.55)
		_draw_node_input_glyphs(node, center)
		_draw_ports(node, center)


func persistent_node_label_count() -> int:
	return 0


func warning_marker_symbol(flow_state: StringName) -> StringName:
	match flow_state:
		&"output_blocked": return &"cross"
		&"material_shortage": return &"half_empty"
		&"buffer_full": return &"stop"
	return &""


func _draw_node_warning_marker(flow_state: StringName, center: Vector2) -> void:
	var symbol := warning_marker_symbol(flow_state)
	if symbol == &"":
		return
	var badge_center := center + Vector2(34, -20)
	var color := WARNING_COLOR if symbol == &"cross" else WAITING_COLOR
	draw_circle(badge_center, 8.0, Color(0.025, 0.045, 0.068, 0.96))
	draw_arc(badge_center, 8.0, 0.0, TAU, 20, color, 1.6, true)
	if symbol == &"cross":
		draw_line(badge_center + Vector2(-4, -4), badge_center + Vector2(4, 4), color, 1.6, true)
		draw_line(badge_center + Vector2(-4, 4), badge_center + Vector2(4, -4), color, 1.6, true)
	else:
		draw_arc(badge_center + Vector2(-2.5, 0), 3.0, 0.0, TAU, 14, color, 1.3, true)
		draw_arc(badge_center + Vector2(3.5, 0), 3.0, 0.0, TAU, 14, Color(color, 0.28), 1.3, true)


func _draw_line_blocked_marker(center: Vector2) -> void:
	draw_circle(center, 8.0, Color(0.025, 0.045, 0.068, 0.96))
	draw_line(center + Vector2(-3, -5), center + Vector2(-3, 5), WARNING_COLOR, 2.0, true)
	draw_line(center + Vector2(3, -5), center + Vector2(3, 5), WARNING_COLOR, 2.0, true)


func flow_warning_badge_at(at_position: Vector2) -> bool:
	return not interaction_enabled and flow_warning_message != "" and at_position.distance_to(Vector2(28, size.y - 18)) <= 18.0


func _draw_flow_warning_badge() -> void:
	var center := Vector2(28, size.y - 18)
	var points := PackedVector2Array([
		center + Vector2(0, -12), center + Vector2(11, 9), center + Vector2(-11, 9),
	])
	draw_colored_polygon(points, Color(WARNING_COLOR, 0.9))
	draw_line(center + Vector2(0, -5), center + Vector2(0, 3), Color.WHITE, 2.0, true)
	draw_circle(center + Vector2(0, 6), 1.5, Color.WHITE)
	var warning_count := maxi(simulation.flow_diagnostics().size(), 1)
	draw_string(ThemeDB.fallback_font, center + Vector2(13, 5), str(warning_count), HORIZONTAL_ALIGNMENT_LEFT, 22.0, 11, WARNING_COLOR)


func connection_feedback_kind() -> StringName:
	if connection_message == "":
		return &"none"
	if "失敗" in connection_message or "できません" in connection_message or "破損" in connection_message:
		return &"error"
	if "選択してください" in connection_message:
		return &"pending"
	return &"success"


func _connection_feedback_center() -> Vector2:
	return Vector2(28, 76 if editing else 27)


func connection_feedback_badge_at(at_position: Vector2) -> bool:
	return connection_message != "" and at_position.distance_to(_connection_feedback_center()) <= 16.0


func _draw_connection_feedback_badge() -> void:
	var center := _connection_feedback_center()
	var kind := connection_feedback_kind()
	var color := WARNING_COLOR if kind == &"error" else (WAITING_COLOR if kind == &"pending" else MATCH_COLOR)
	draw_circle(center, 10.0, Color(0.025, 0.045, 0.068, 0.96))
	draw_arc(center, 10.0, 0.0, TAU, 24, color, 1.8, true)
	if kind == &"error":
		draw_line(center + Vector2(-4, -4), center + Vector2(4, 4), color, 1.8, true)
		draw_line(center + Vector2(-4, 4), center + Vector2(4, -4), color, 1.8, true)
	elif kind == &"pending":
		draw_circle(center + Vector2(-4, 0), 3.0, color)
		draw_arc(center + Vector2(5, 0), 4.0, 0.0, TAU, 16, color, 1.4, true)
		draw_line(center, center + Vector2(2, 0), color, 1.4, true)
	else:
		draw_line(center + Vector2(-5, 0), center + Vector2(-1, 4), color, 2.0, true)
		draw_line(center + Vector2(-1, 4), center + Vector2(6, -5), color, 2.0, true)


func _draw_production_summary() -> void:
	var clock_center := Vector2(size.x - 278.0, 28.0)
	draw_arc(clock_center, 9.0, 0.0, TAU, 20, Color(0.4, 0.62, 0.76, 0.78), 1.5, true)
	draw_line(clock_center, clock_center + Vector2(0, -5), Color(0.58, 0.78, 0.92), 1.5, true)
	draw_line(clock_center, clock_center + Vector2(4, 2), Color(0.58, 0.78, 0.92), 1.5, true)
	var recipe_by_unit := {}
	for recipe in MvpContent.recipes():
		recipe_by_unit[recipe.unit_id] = recipe.glyph
	var unit_order: Array[StringName] = [&"scout", &"sentinel", &"golem"]
	for index in unit_order.size():
		var unit_id := unit_order[index]
		var center := production_summary_center(index)
		var glyph: GlyphModel = recipe_by_unit.get(unit_id)
		var is_goal := production_summary_is_goal(unit_id)
		draw_circle(center, 18.0, Color(0.025, 0.055, 0.085, 0.94))
		draw_arc(
			center,
			18.0,
			0.0,
			TAU,
			28,
			MATCH_COLOR if is_goal else Color(0.3, 0.56, 0.74, 0.68),
			2.2 if is_goal else 1.0,
			true
		)
		if GlyphPainterModel.can_draw(glyph):
			var scale := 1.3 if glyph.combine_children.is_empty() else 1.15
			GlyphPainterModel.draw_glyph(self, glyph, center, scale)
		var count_center := center + Vector2(14, 12)
		draw_circle(count_center, 8.5, Color(0.02, 0.12, 0.09, 0.96))
		draw_arc(count_center, 8.5, 0.0, TAU, 20, Color(0.38, 0.9, 0.68), 1.0, true)
		draw_string(
			ThemeDB.fallback_font,
			count_center + Vector2(-8, 4),
			str(cached_production_counts.get(unit_id, 0)),
			HORIZONTAL_ALIGNMENT_CENTER,
			16.0,
			12,
			Color(0.54, 0.86, 0.7)
		)
	if cached_production_discarded > 0:
		var warning_center := Vector2(size.x - 18.0, 28.0)
		draw_circle(warning_center, 9.0, WARNING_COLOR)
		draw_line(warning_center + Vector2(-4, -4), warning_center + Vector2(4, 4), Color.WHITE, 1.8, true)
		draw_line(warning_center + Vector2(-4, 4), warning_center + Vector2(4, -4), Color.WHITE, 1.8, true)
		draw_string(
			ThemeDB.fallback_font,
			warning_center + Vector2(-30, 4),
			str(cached_production_discarded),
			HORIZONTAL_ALIGNMENT_RIGHT,
			18.0,
			10,
			WARNING_COLOR
		)


func interaction_legend_count() -> int:
	return 3


func _draw_production_error_badge() -> void:
	var center := Vector2(size.x - 18.0, 27.0)
	draw_circle(center, 10.0, WARNING_COLOR)
	draw_line(center + Vector2(-4, -4), center + Vector2(4, 4), Color.WHITE, 1.8, true)
	draw_line(center + Vector2(-4, 4), center + Vector2(4, -4), Color.WHITE, 1.8, true)


func work_in_progress_visual_summary() -> Array[Dictionary]:
	var grouped := {}
	for entry in _work_in_progress_entries(simulation):
		var glyph: GlyphModel = entry["glyph"]
		if not GlyphPainterModel.can_draw(glyph):
			continue
		var key := glyph.canonical_serialization()
		if not grouped.has(key):
			grouped[key] = {"glyph": glyph.copy(), "count": 0}
		grouped[key]["count"] += 1
	var keys := grouped.keys()
	keys.sort()
	var result: Array[Dictionary] = []
	for key in keys:
		result.append(grouped[key])
	return result


func _draw_edit_summary() -> void:
	var pause_center := Vector2(28, 28)
	draw_circle(pause_center, 13.0, Color(0.04, 0.09, 0.14, 0.95))
	draw_arc(pause_center, 13.0, 0.0, TAU, 24, Color(0.42, 0.78, 1.0, 0.9), 1.5, true)
	draw_line(pause_center + Vector2(-4, -6), pause_center + Vector2(-4, 6), Color(0.62, 0.86, 1.0), 2.5, true)
	draw_line(pause_center + Vector2(4, -6), pause_center + Vector2(4, 6), Color(0.62, 0.86, 1.0), 2.5, true)
	var groups := work_in_progress_visual_summary()
	for index in mini(groups.size(), 6):
		var entry: Dictionary = groups[index]
		var glyph: GlyphModel = entry["glyph"]
		var center := Vector2(72.0 + index * 58.0, 28.0)
		draw_circle(center, 16.0, Color(0.025, 0.055, 0.085, 0.92))
		GlyphPainterModel.draw_glyph(self, glyph, center, 0.78 if not glyph.combine_children.is_empty() else 1.3)
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(12, 12),
			str(entry["count"]),
			HORIZONTAL_ALIGNMENT_CENTER,
			18.0,
			10,
			Color(0.76, 0.9, 1.0)
		)
	var discard_count := pending_discard_count()
	if discard_count > 0:
		var center := pending_discard_badge_center()
		draw_circle(center, 10.0, WARNING_COLOR)
		draw_line(center + Vector2(-4, -4), center + Vector2(4, 4), Color.WHITE, 1.8, true)
		draw_line(center + Vector2(-4, 4), center + Vector2(4, -4), Color.WHITE, 1.8, true)
		draw_string(ThemeDB.fallback_font, center + Vector2(13, 4), str(discard_count), HORIZONTAL_ALIGNMENT_LEFT, 24.0, 11, WARNING_COLOR)


func production_error_at(at_position: Vector2) -> bool:
	return interaction_enabled and not cached_production_valid and at_position.distance_to(Vector2(size.x - 18.0, 27.0)) <= 16.0


func production_discard_badge_at(at_position: Vector2) -> bool:
	return (
		interaction_enabled
		and cached_production_valid
		and cached_production_discarded > 0
		and at_position.distance_to(Vector2(size.x - 18.0, 28.0)) <= 18.0
	)


func work_in_progress_summary_index_at(at_position: Vector2) -> int:
	if not editing:
		return -1
	var groups := work_in_progress_visual_summary()
	for index in mini(groups.size(), 6):
		if at_position.distance_to(Vector2(72.0 + index * 58.0, 28.0)) <= 22.0:
			return index
	return -1


func pending_discard_badge_center() -> Vector2:
	return Vector2(78.0 + mini(work_in_progress_visual_summary().size(), 6) * 58.0, 28.0)


func pending_discard_badge_at(at_position: Vector2) -> bool:
	return editing and pending_discard_count() > 0 and at_position.distance_to(pending_discard_badge_center()) <= 20.0


func _draw_interaction_legend() -> void:
	var y := size.y - 18.0
	var icon_color := Color(0.4, 0.68, 0.86, 0.82)
	var muted := Color(0.16, 0.28, 0.38, 0.7)
	for index in interaction_legend_count():
		var rect := Rect2(Vector2(18.0 + index * 78.0, y - 15.0), Vector2(66.0, 28.0))
		draw_rect(rect, Color(0.025, 0.045, 0.068, 0.84), true)
		draw_rect(rect, muted, false, 1.0)
	var move_center := Vector2(51.0, y - 1.0)
	draw_rect(Rect2(move_center - Vector2(8, 5), Vector2(16, 10)), Color(0.08, 0.13, 0.19), true)
	draw_rect(Rect2(move_center - Vector2(8, 5), Vector2(16, 10)), icon_color, false, 1.2)
	var move_directions: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	for direction in move_directions:
		var tip: Vector2 = move_center + direction * 11.0
		draw_line(move_center + direction * 7.0, tip, icon_color, 1.4, true)
		var normal := Vector2(-direction.y, direction.x)
		draw_line(tip, tip - direction * 3.0 + normal * 2.0, icon_color, 1.2, true)
		draw_line(tip, tip - direction * 3.0 - normal * 2.0, icon_color, 1.2, true)
	var link_left := Vector2(110.0, y - 1.0)
	var link_right := Vector2(143.0, y - 1.0)
	draw_circle(link_left, 5.0, icon_color)
	draw_arc(link_right, 6.0, 0.0, TAU, 18, icon_color, 1.5, true)
	draw_line(link_left + Vector2(6, 0), link_right - Vector2(7, 0), icon_color, 1.5, true)
	draw_line(link_right - Vector2(7, 0), link_right - Vector2(11, -3), icon_color, 1.2, true)
	draw_line(link_right - Vector2(7, 0), link_right - Vector2(11, 3), icon_color, 1.2, true)
	var cut_left := Vector2(188.0, y - 1.0)
	var cut_right := Vector2(221.0, y - 1.0)
	draw_arc(cut_left, 5.0, 0.0, TAU, 18, icon_color, 1.5, true)
	draw_arc(cut_right, 5.0, 0.0, TAU, 18, icon_color, 1.5, true)
	draw_dashed_line(cut_left + Vector2(6, 0), cut_right - Vector2(6, 0), Color(0.92, 0.4, 0.34), 1.4, 3.0)
	var cut_center := cut_left.lerp(cut_right, 0.5)
	draw_line(cut_center + Vector2(-4, -4), cut_center + Vector2(4, 4), Color(0.96, 0.42, 0.36), 1.5, true)
	draw_line(cut_center + Vector2(-4, 4), cut_center + Vector2(4, -4), Color(0.96, 0.42, 0.36), 1.5, true)


func _draw_mana_meter() -> void:
	var meter_rect := Rect2(Vector2(size.x - 276.0, 50.0), Vector2(244.0, 10.0))
	var used_ratio := mana_fill_ratio()
	var fill_color := WARNING_COLOR if mana_available() < 15 else Color(0.28, 0.66, 0.95)
	draw_rect(meter_rect, Color(0.06, 0.1, 0.15, 0.96), true)
	draw_rect(Rect2(meter_rect.position, Vector2(meter_rect.size.x * used_ratio, meter_rect.size.y)), fill_color, true)
	draw_rect(meter_rect, Color(0.38, 0.58, 0.72, 0.72), false, 1.0)
	draw_string(
		ThemeDB.fallback_font,
		meter_rect.position + Vector2(-46, 9),
		"◆",
		HORIZONTAL_ALIGNMENT_CENTER,
		36.0,
		12,
		fill_color
	)
	draw_string(
		ThemeDB.fallback_font,
		meter_rect.position + Vector2(meter_rect.size.x - 52.0, 9),
		"%d/%d" % [mana_used(), MvpContent.FACTORY_MANA_MAX],
		HORIZONTAL_ALIGNMENT_CENTER,
		52.0,
		10,
		Color(0.84, 0.92, 1.0)
	)
func node_frame_kind(node_id: StringName) -> StringName:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.nodes.has(node_id):
		return &"missing"
	match display_simulation.nodes[node_id].kind:
		FactoryNodeModel.NodeKind.SOURCE:
			return &"source_hex"
		FactoryNodeModel.NodeKind.COMBINER:
			return &"combine_hex"
		FactoryNodeModel.NodeKind.SUMMONER:
			return &"summon_circle"
		_:
			return &"processor_chamfer"


func _draw_node_frame(node: FactoryNodeModel, center: Vector2, border_color: Color, selected: bool) -> void:
	var stroke := 3.0 if selected else 2.0
	if node.kind == FactoryNodeModel.NodeKind.SUMMONER:
		draw_circle(center, 40.0, NODE_COLOR)
		draw_arc(center, 40.0, 0.0, TAU, 36, border_color, stroke, true)
		draw_arc(center, 31.0, 0.0, TAU, 32, Color(border_color, 0.35), 1.0, true)
		return
	var points := PackedVector2Array()
	if node.kind == FactoryNodeModel.NodeKind.SOURCE:
		points = PackedVector2Array([
			center + Vector2(-38, -30), center + Vector2(38, -30), center + Vector2(48, 0),
			center + Vector2(38, 30), center + Vector2(-38, 30), center + Vector2(-48, 0),
		])
	elif node.kind == FactoryNodeModel.NodeKind.COMBINER:
		points = PackedVector2Array([
			center + Vector2(-32, -30), center + Vector2(32, -30), center + Vector2(48, 0),
			center + Vector2(32, 30), center + Vector2(-32, 30), center + Vector2(-48, 0),
		])
	else:
		points = PackedVector2Array([
			center + Vector2(-38, -30), center + Vector2(38, -30), center + Vector2(48, -20),
			center + Vector2(48, 20), center + Vector2(38, 30), center + Vector2(-38, 30),
			center + Vector2(-48, 20), center + Vector2(-48, -20),
		])
	draw_colored_polygon(points, NODE_COLOR)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, border_color, stroke, true)
	_draw_node_role_mark(node, center)


func _draw_node_role_mark(node: FactoryNodeModel, center: Vector2) -> void:
	var mark_center := center + Vector2(-34, -16)
	match node.kind:
		FactoryNodeModel.NodeKind.ROTATOR:
			draw_arc(mark_center, 6.0, -0.7, 4.4, 16, Color(0.5, 0.76, 0.94, 0.78), 1.5, true)
			draw_line(mark_center + Vector2(-6, -2), mark_center + Vector2(-2, -6), Color(0.5, 0.76, 0.94, 0.78), 1.5, true)
		FactoryNodeModel.NodeKind.COLORIZER:
			var color_id := StringName(node.config.get("color_id", "white"))
			draw_circle(mark_center, 4.5, GlyphPainterModel.component_color(color_id))
		FactoryNodeModel.NodeKind.COMBINER:
			draw_arc(mark_center + Vector2(-3, 0), 5.0, 0.0, TAU, 16, Color(0.5, 0.76, 0.94, 0.7), 1.3, true)
			draw_arc(mark_center + Vector2(4, 0), 5.0, 0.0, TAU, 16, Color(0.5, 0.76, 0.94, 0.7), 1.3, true)


func node_activity_progress(node_id: StringName) -> float:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.nodes.has(node_id):
		return -1.0
	return _node_activity_progress(display_simulation.nodes[node_id])


func _node_activity_progress(node: FactoryNodeModel) -> float:
	if node.kind == FactoryNodeModel.NodeKind.SUMMONER:
		return -1.0
	if node.output_buffer != null:
		return 1.0
	if node.kind == FactoryNodeModel.NodeKind.SOURCE:
		var interval := maxi(int(node.config.get("interval_ticks", 1)), 1)
		return clampf(float(node.source_timer) / float(interval), 0.0, 1.0)
	if node.processing_glyph == null:
		return -1.0
	var processing_ticks := maxi(int(node.config.get("processing_ticks", 1)), 1)
	return clampf(
		1.0 - float(node.remaining_processing_ticks) / float(processing_ticks),
		0.0,
		1.0
	)


func _draw_node_activity_progress(
	node: FactoryNodeModel,
	center: Vector2,
	show_empty: bool
) -> void:
	var progress := _node_activity_progress(node)
	if progress < 0.0 or (progress == 0.0 and not show_empty):
		return
	var start := center + Vector2(-34.0, -22.0)
	var finish := center + Vector2(34.0, -22.0)
	draw_line(start, finish, Color(0.02, 0.035, 0.055, 0.95), 3.0, true)
	if progress > 0.0:
		draw_line(start, start.lerp(finish, progress), GLYPH_COLOR, 3.0, true)


func visible_glyph_for_node(node_id: StringName) -> GlyphModel:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.nodes.has(node_id):
		return null
	return _visible_node_glyph(display_simulation.nodes[node_id])


func predicted_output_glyph_for_node(node_id: StringName) -> GlyphModel:
	return cached_node_output_glyphs.get(node_id)


func final_summoner_candidate_glyph() -> GlyphModel:
	var display_simulation := _display_simulation()
	if display_simulation == null:
		return null
	var summoner_ids: Array = []
	for node_id in display_simulation.nodes:
		if display_simulation.nodes[node_id].kind == FactoryNodeModel.NodeKind.SUMMONER:
			summoner_ids.append(node_id)
	summoner_ids.sort()
	for summoner_id in summoner_ids:
		var summoner: FactoryNodeModel = display_simulation.nodes[summoner_id]
		for input_glyph in summoner.input_buffers:
			if GlyphPainterModel.can_draw(input_glyph):
				return input_glyph.copy()
		var line_ids := display_simulation.lines.keys()
		line_ids.sort()
		for line_id in line_ids:
			var line: FactoryLineModel = display_simulation.lines[line_id]
			if line.to_node_id != summoner_id:
				continue
			if GlyphPainterModel.can_draw(line.payload):
				return line.payload.copy()
			if cached_node_output_glyphs.has(line.from_node_id):
				var predicted = cached_node_output_glyphs[line.from_node_id]
				if GlyphPainterModel.can_draw(predicted):
					return predicted.copy()
	return null


func source_glyph_for_node(node_id: StringName) -> GlyphModel:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.nodes.has(node_id):
		return null
	var node: FactoryNodeModel = display_simulation.nodes[node_id]
	if node.kind != FactoryNodeModel.NodeKind.SOURCE:
		return null
	var primitive_id := StringName(node.config.get("primitive_id", ""))
	if primitive_id == &"":
		return null
	return GlyphModel.new([GlyphComponentModel.new(primitive_id)])


func _get_tooltip(at_position: Vector2) -> String:
	tooltip_glyph = null
	tooltip_title = ""
	tooltip_context = ""
	if connection_feedback_badge_at(at_position):
		return connection_message
	if flow_warning_badge_at(at_position):
		return flow_warning_message
	if pending_discard_badge_at(at_position):
		return pending_discard_notice()
	var work_index := work_in_progress_summary_index_at(at_position)
	if work_index >= 0:
		var work_entry: Dictionary = work_in_progress_visual_summary()[work_index]
		_set_glyph_tooltip(
			work_entry["glyph"],
			"時間停止 // 仕掛品",
			"工場内 %d個" % work_entry["count"]
		)
		return "glyph_preview"
	if production_error_at(at_position):
		return cached_production_preview
	if production_discard_badge_at(at_position):
		return "32秒予測 // 不一致Glyph %d個を廃棄" % cached_production_discarded
	var summary_unit := production_summary_unit_at(at_position)
	if summary_unit != &"":
		for recipe in MvpContent.recipes():
			if recipe.unit_id != summary_unit:
				continue
			_set_glyph_tooltip(
				recipe.glyph,
				"32秒予測 // %s" % String(MvpContent.sigil_name(recipe.id)).trim_suffix("シジル"),
				"生産見込み %d体" % cached_production_counts.get(summary_unit, 0)
			)
			return "glyph_preview"
	var display_simulation := _display_simulation()
	if display_simulation == null:
		return ""
	var node_id := _node_at(at_position)
	if node_id != &"":
		var node: FactoryNodeModel = display_simulation.nodes[node_id]
		var visible_glyph := _visible_node_glyph(node)
		if visible_glyph != null:
			_set_glyph_tooltip(visible_glyph, _node_label(node), "設備内の現在Glyph")
		elif cached_node_output_glyphs.has(node_id):
			_set_glyph_tooltip(cached_node_output_glyphs[node_id], _node_label(node), "32秒予測の出力Glyph")
		else:
			var source_glyph := source_glyph_for_node(node_id)
			if source_glyph != null:
				_set_glyph_tooltip(source_glyph, _node_label(node), "素材Primitive")
		return "glyph_preview" if tooltip_glyph != null else ""
	for line_id in display_simulation.lines:
		var line: FactoryLineModel = display_simulation.lines[line_id]
		if line.payload == null or not GlyphPainterModel.can_draw(line.payload):
			continue
		var start := _scaled_position(_display_positions().get(line.from_node_id, Vector2.ZERO)) + Vector2(NODE_HALF_SIZE.x, 0)
		var finish := _input_port_position(line.to_node_id, line.to_port)
		var closest := Geometry2D.get_closest_point_to_segment(at_position, start, finish)
		if at_position.distance_to(closest) > 14.0:
			continue
		var from_label := _node_label(display_simulation.nodes[line.from_node_id])
		var to_label := _node_label(display_simulation.nodes[line.to_node_id])
		_set_glyph_tooltip(line.payload, "%s → %s" % [from_label, to_label], "輸送中Glyph")
		return "glyph_preview"
	return ""


func production_summary_unit_at(at_position: Vector2) -> StringName:
	if not interaction_enabled or not cached_production_valid:
		return &""
	var unit_order: Array[StringName] = [&"scout", &"sentinel", &"golem"]
	for index in unit_order.size():
		var center := production_summary_center(index)
		if at_position.distance_to(center) <= 28.0:
			return unit_order[index]
	return &""


func production_summary_center(index: int) -> Vector2:
	return Vector2(size.x - 220.0 + index * 72.0, 28.0)


func production_summary_is_goal(unit_id: StringName) -> bool:
	var target_recipe_id := MvpContent.recipe_id_for_plan(plan_id)
	for recipe in MvpContent.recipes():
		if recipe.id == target_recipe_id:
			return recipe.unit_id == unit_id
	return false


func _set_glyph_tooltip(next_glyph: GlyphModel, next_title: String, next_context: String) -> void:
	if not GlyphPainterModel.can_draw(next_glyph):
		return
	tooltip_glyph = next_glyph.copy()
	tooltip_title = next_title
	tooltip_context = next_context


func _make_custom_tooltip(for_text: String):
	if for_text != "glyph_preview":
		var label := Label.new()
		label.text = for_text
		label.custom_minimum_size = Vector2(360, 42)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.64))
		return label
	var preview := GlyphTooltipModel.new()
	preview.configure(tooltip_glyph, tooltip_title, tooltip_context)
	return preview


func node_glyph_draw_scale(glyph: GlyphModel) -> float:
	if glyph != null and not glyph.combine_children.is_empty():
		return 0.9
	return 1.55


func visible_glyph_for_line(line_id: StringName) -> GlyphModel:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.lines.has(line_id):
		return null
	var glyph: GlyphModel = display_simulation.lines[line_id].payload
	if glyph == null or not glyph.structure_validation_errors().is_empty():
		return null
	return glyph


func line_recipe_match_state(line_id: StringName) -> StringName:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.lines.has(line_id):
		return &"missing"
	var line: FactoryLineModel = display_simulation.lines[line_id]
	if not display_simulation.nodes.has(line.to_node_id):
		return &"invalid"
	var target: FactoryNodeModel = display_simulation.nodes[line.to_node_id]
	if target.kind != FactoryNodeModel.NodeKind.SUMMONER:
		return &"not_applicable"
	if line.payload == null:
		return &"empty"
	return _recipe_match_state_for_glyph(display_simulation, line.payload)


func line_goal_match_state(line_id: StringName) -> StringName:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.lines.has(line_id):
		return &"missing"
	var line: FactoryLineModel = display_simulation.lines[line_id]
	if not display_simulation.nodes.has(line.to_node_id):
		return &"invalid"
	if display_simulation.nodes[line.to_node_id].kind != FactoryNodeModel.NodeKind.SUMMONER:
		return &"not_applicable"
	var glyph: GlyphModel = line.payload
	if not GlyphPainterModel.can_draw(glyph):
		glyph = cached_node_output_glyphs.get(line.from_node_id)
	if not GlyphPainterModel.can_draw(glyph):
		return &"empty"
	var target_recipe_id := MvpContent.recipe_id_for_plan(plan_id)
	for recipe in MvpContent.recipes():
		if recipe.id != target_recipe_id:
			continue
		return (
			&"match"
			if recipe.glyph.canonical_serialization() == glyph.canonical_serialization()
			else &"mismatch"
		)
	return &"invalid"


func input_recipe_match_state(node_id: StringName, port: int) -> StringName:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.nodes.has(node_id):
		return &"missing"
	var node: FactoryNodeModel = display_simulation.nodes[node_id]
	if node.kind != FactoryNodeModel.NodeKind.SUMMONER:
		return &"not_applicable"
	if port < 0 or port >= node.input_buffers.size():
		return &"invalid"
	if node.input_buffers[port] == null:
		return &"empty"
	return _recipe_match_state_for_glyph(display_simulation, node.input_buffers[port])


func _recipe_match_state_for_glyph(
	display_simulation: FactorySimulation,
	glyph_value
) -> StringName:
	if not glyph_value is GlyphModel:
		return &"invalid"
	var result := display_simulation.recipe_match_result(glyph_value)
	if not result["ok"]:
		return &"invalid"
	return &"match" if result["is_match"] else &"mismatch"


func recipe_match_marker_symbol(match_state: StringName) -> StringName:
	if match_state == &"match":
		return &"check"
	if match_state == &"mismatch":
		return &"cross"
	return &""


func visible_input_glyph_for_node(node_id: StringName, port: int) -> GlyphModel:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.nodes.has(node_id):
		return null
	var node: FactoryNodeModel = display_simulation.nodes[node_id]
	if port < 0 or port >= node.input_buffers.size():
		return null
	var glyph_value = node.input_buffers[port]
	if not glyph_value is GlyphModel:
		return null
	var glyph: GlyphModel = glyph_value
	if not glyph.structure_validation_errors().is_empty():
		return null
	return glyph


func _visible_node_glyph(node: FactoryNodeModel) -> GlyphModel:
	var glyph := _visible_node_active_glyph(node)
	if glyph == null:
		for input_glyph in node.input_buffers:
			if input_glyph is GlyphModel:
				glyph = input_glyph
				break
	if glyph == null or not glyph.structure_validation_errors().is_empty():
		return null
	return glyph


func _visible_node_active_glyph(node: FactoryNodeModel) -> GlyphModel:
	var glyph: GlyphModel = node.output_buffer
	if glyph == null:
		glyph = node.processing_glyph
	if glyph == null or not glyph.structure_validation_errors().is_empty():
		return null
	return glyph


func _draw_node_input_glyphs(node: FactoryNodeModel, center: Vector2) -> void:
	for port in node.input_buffers.size():
		var glyph_value = node.input_buffers[port]
		if not glyph_value is GlyphModel:
			continue
		var glyph: GlyphModel = glyph_value
		if not glyph.structure_validation_errors().is_empty():
			continue
		var y_offset := 0.0
		if node.required_input_count() == 2:
			y_offset = -13.0 if port == 0 else 13.0
		var glyph_center := center + Vector2(-NODE_HALF_SIZE.x + 14.0, y_offset)
		_draw_mini_glyph(glyph, glyph_center, 0.85)
		if node.kind == FactoryNodeModel.NodeKind.SUMMONER:
			_draw_recipe_match_marker(glyph_center, input_recipe_match_state(node.id, port), 9.0)


func _draw_recipe_match_marker(
	center: Vector2,
	match_state: StringName,
	radius: float
) -> void:
	var symbol := recipe_match_marker_symbol(match_state)
	if symbol == &"":
		return
	var color := MATCH_COLOR if symbol == &"check" else WARNING_COLOR
	draw_arc(center, radius, 0.0, TAU, 24, color, 2.0, true)
	var badge_center := center + Vector2(radius * 0.72, -radius * 0.72)
	draw_circle(badge_center, 4.5, color)
	if symbol == &"check":
		draw_line(badge_center + Vector2(-2.2, 0.0), badge_center + Vector2(-0.5, 1.8), Color.WHITE, 1.4, true)
		draw_line(badge_center + Vector2(-0.5, 1.8), badge_center + Vector2(2.5, -2.0), Color.WHITE, 1.4, true)
	else:
		draw_line(badge_center + Vector2(-2.0, -2.0), badge_center + Vector2(2.0, 2.0), Color.WHITE, 1.4, true)
		draw_line(badge_center + Vector2(-2.0, 2.0), badge_center + Vector2(2.0, -2.0), Color.WHITE, 1.4, true)


func _draw_mini_glyph(
	glyph: GlyphModel,
	center: Vector2,
	scale: float,
	opacity: float = 1.0
) -> void:
	GlyphPainterModel.draw_glyph(self, glyph, center, scale, opacity)


func _draw_ports(node: FactoryNodeModel, center: Vector2) -> void:
	if node.kind != FactoryNodeModel.NodeKind.SUMMONER:
		var output_color := LINE_COLOR
		if is_guided_connection_pending() and node.id == &"ring_source":
			output_color = SELECTED_COLOR
		var output_position := center + Vector2(NODE_HALF_SIZE.x, 0)
		draw_circle(output_position, PORT_RADIUS, output_color)
		if node.id == hovered_output_node_id:
			draw_arc(output_position, PORT_RADIUS + 5.0, 0.0, TAU, 24, Color(GLYPH_COLOR, 0.5), 2.2, true)
	for port in node.required_input_count():
		var position := _input_port_position(node.id, port)
		var input_color := LINE_COLOR
		if is_guided_connection_pending() and node.id == &"summoner":
			input_color = SELECTED_COLOR
		if connecting_from_node_id != &"":
			if input_port_connectable(node.id, port):
				input_color = MATCH_COLOR
				draw_arc(position, PORT_RADIUS + 5.0, 0.0, TAU, 24, Color(MATCH_COLOR, 0.32), 2.0, true)
			else:
				input_color = Color(LINE_COLOR, 0.2)
		if node.id == hovered_input_node_id and port == hovered_input_port:
			var hover_color := GLYPH_COLOR
			if connecting_from_node_id != &"":
				hover_color = MATCH_COLOR if input_port_connectable(node.id, port) else WARNING_COLOR
			draw_arc(position, PORT_RADIUS + 5.0, 0.0, TAU, 24, Color(hover_color, 0.52), 2.2, true)
		draw_circle(position, PORT_RADIUS, PANEL_COLOR)
		draw_arc(position, PORT_RADIUS, 0.0, TAU, 20, input_color, 2.0)


func input_port_connectable(to_node_id: StringName, to_port: int) -> bool:
	var display_simulation := _display_simulation()
	if (
		connecting_from_node_id == &""
		or display_simulation == null
		or not display_simulation.nodes.has(connecting_from_node_id)
		or not display_simulation.nodes.has(to_node_id)
		or connecting_from_node_id == to_node_id
	):
		return false
	var target: FactoryNodeModel = display_simulation.nodes[to_node_id]
	if to_port < 0 or to_port >= target.required_input_count():
		return false
	for line in display_simulation.lines.values():
		if line.from_node_id != connecting_from_node_id:
			continue
		if line.to_node_id != to_node_id or line.to_port != to_port:
			return false
	return not _path_reaches_node(to_node_id, connecting_from_node_id, {})


func _path_reaches_node(current_id: StringName, sought_id: StringName, visited: Dictionary) -> bool:
	if current_id == sought_id:
		return true
	if visited.has(current_id):
		return false
	visited[current_id] = true
	var display_simulation := _display_simulation()
	for line in display_simulation.lines.values():
		if line.from_node_id == current_id and _path_reaches_node(line.to_node_id, sought_id, visited):
			return true
	return false


func _node_label(node: FactoryNodeModel) -> String:
	match node.kind:
		FactoryNodeModel.NodeKind.SOURCE:
			var primitive := String(node.config.get("primitive_id", "ring"))
			return "棘素材" if primitive == "spike" else "環素材"
		FactoryNodeModel.NodeKind.ROTATOR:
			var steps := clampi(int(node.config.get("steps", 1)), 1, 3)
			return "回転 +%d°" % (steps * 90)
		FactoryNodeModel.NodeKind.TRANSLATOR:
			return "位置移動"
		FactoryNodeModel.NodeKind.COLORIZER:
			return "%s着色" % _color_name(StringName(node.config.get("color_id", "blue")))
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
	var x_offset := -40.0 if node.kind == FactoryNodeModel.NodeKind.SUMMONER else -NODE_HALF_SIZE.x
	return node_local_position(node_id) + Vector2(x_offset, y_offset)


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
		"invalid_payload":
			return "接続できません: ライン上の仕掛品データが破損しています"
		"missing_line", "missing_line_id":
			return "接続できません: ラインデータにIDがありません"
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
	if error == "mana_exceeded":
		return "工場魔力が上限を超えています"
	if error == "multiple_summoners":
		return "召喚器は現MVPでは1基だけ配置できます"
	if error == "cycle":
		return "配線が循環しています。循環するラインを解除してください"
	if error.begins_with("missing_from_node:") or error.begins_with("missing_to_node:"):
		return "接続先が存在しないラインがあります。壊れたラインを解除してください"
	if error.begins_with("invalid_port:"):
		return "存在しない入力ポートへのラインがあります。接続をやり直してください"
	if error.begins_with("occupied_input:"):
		return "1つの入力に複数ラインが接続されています"
	if error.begins_with("occupied_output:"):
		return "通常設備の出力が分岐しています。余分なラインを解除してください"
	if error.begins_with("missing_source_primitive:"):
		return "素材源「%s」の素材設定がありません" % error.get_slice(":", 1)
	if error.begins_with("invalid_source_interval:"):
		return "素材源「%s」の生成間隔が不正です" % error.get_slice(":", 1)
	if error.begins_with("invalid_processing_ticks:"):
		return "設備「%s」の処理時間が不正です" % error.get_slice(":", 1)
	if error.begins_with("invalid_rotation_steps:"):
		return "回転器「%s」の回転設定は90°・180°・270°から選んでください" % error.get_slice(":", 1)
	if error.begins_with("invalid_translation_offset:"):
		return "移動器「%s」の移動設定が不正です" % error.get_slice(":", 1)
	if error.begins_with("missing_color_id:"):
		return "着色器「%s」の色設定がありません" % error.get_slice(":", 1)
	if error.begins_with("missing_node_id:") or error.begins_with("node_key_mismatch:") or error.begins_with("invalid_node_kind:"):
		return "設備データのIDまたは種類が破損しています"
	if error.begins_with("missing_line_id:") or error.begins_with("line_key_mismatch:"):
		return "ラインデータのIDが破損しています"
	if error.begins_with("invalid_glyph:"):
		return "工場内の仕掛品データが破損しています。仕掛品を廃棄して再構築してください"
	if error.begins_with("invalid_recipe:"):
		return "取得済みシジルデータが破損しています。ランデータを再読み込みしてください"
	return "工場の配線を確認してください"


func _push_undo_snapshot() -> void:
	var display_simulation := _display_simulation()
	if display_simulation == null:
		return
	var duplication := display_simulation.duplicate_state_result()
	if not duplication["ok"]:
		connection_message = "工場状態を保存できません // %s" % _validation_message(duplication["errors"])
		return
	undo_history.append({
		"simulation": duplication["state"],
		"positions": _display_positions().duplicate(true),
	})


func _refresh_production_preview() -> void:
	var result := production_preview()
	if not result["ok"]:
		cached_production_valid = false
		cached_production_counts.clear()
		cached_production_discarded = 0
		cached_node_output_glyphs.clear()
		cached_production_preview = "32秒予測 // %s" % _validation_message(result.get("errors", []))
		factory_changed.emit()
		return
	var counts: Dictionary = result["counts"]
	var first_failure: Dictionary = result["first_failure"]
	cached_production_valid = true
	cached_production_counts = counts.duplicate()
	cached_production_discarded = result["discarded"]
	cached_node_output_glyphs = result["node_outputs"].duplicate()
	if first_failure.is_empty():
		cached_production_preview = "32秒予測 // 斥候 %d  衛兵 %d  巨像 %d  不一致 0" % [
			counts[&"scout"],
			counts[&"sentinel"],
			counts[&"golem"],
		]
	else:
		cached_production_preview = "32秒 // 斥%d 衛%d 巨%d 不%d // %s" % [
			counts[&"scout"],
			counts[&"sentinel"],
			counts[&"golem"],
			result["discarded"],
			_preview_failure_summary(first_failure),
		]
	factory_changed.emit()


func _preview_failure_summary(event: Dictionary) -> String:
	var diagnostics: PackedStringArray = event.get("diagnostics", PackedStringArray())
	var reason := "原因不明" if diagnostics.is_empty() else _localize_preview_diagnostic(diagnostics[0])
	var recipe_id: StringName = event.get("closest_recipe_id", &"")
	if recipe_id == &"":
		return reason
	return "%s: %s" % [String(MvpContent.sigil_name(recipe_id)).trim_suffix("シジル"), reason]


func _localize_preview_diagnostic(diagnostic: String) -> String:
	for prefix in ["部品不足: ", "余分な部品: "]:
		if diagnostic.begins_with(prefix):
			var primitive_id := StringName(diagnostic.trim_prefix(prefix))
			return "%s %s" % [prefix.trim_suffix(": "), _primitive_name(primitive_id)]
	return diagnostic


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
