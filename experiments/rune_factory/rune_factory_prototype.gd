class_name RuneFactoryPrototype
extends Control

const RunePacketModel := preload("res://src/rune/rune_packet.gd")
const RunePacketViewModel := preload("res://experiments/rune_factory/rune_packet_view.gd")
const RuneFactoryNodeVisualModel := preload("res://experiments/rune_factory/rune_factory_node_visual.gd")
const DirectionalOverlayModel := preload("res://experiments/factory_prototype/factory_directional_overlay.gd")

const MENU_SCENE := "res://src/main_menu.tscn"
const PLAYFIELD_SIZE := Vector2(9000.0, 6000.0)
const SUMMONER_POSITION := Vector2(4500.0, 3000.0)
const SUMMONER_INPUT_COUNT := 3
const MERGE_INPUT_COUNT := 8
const PORT_HIT_RADIUS := 13.0
const LINE_HIT_RADIUS := 10.0
const PORT_RADIUS := 5.5
const CONVEYOR_SPEED := 520.0
const PACKET_INTERVAL := 1.5
const FLOW_LIMIT := 20
const BUILTIN_PORT_COLOR := Color.TRANSPARENT
const SHIFT_DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const SHIFT_LABELS := ["↑", "→", "↓", "←"]

const TARGET_ORDER: Array[StringName] = [
	&"red_seed", &"blue_seed", &"green_seed", &"red_twins", &"tricolor",
]
const TARGET_DEFINITIONS := {
	&"red_seed": {
		"label": "赤の一字",
		"monster": "緋小鬼",
		"role": "近接・量産",
		"runes": [0],
	},
	&"blue_seed": {
		"label": "青の一字",
		"monster": "蒼羽虫",
		"role": "遠隔・軽量",
		"runes": [10],
	},
	&"green_seed": {
		"label": "緑の一字",
		"monster": "翠甲仔",
		"role": "防壁・低速",
		"runes": [21],
	},
	&"red_twins": {
		"label": "赤の双字",
		"monster": "双角インプ",
		"role": "同字合成・突撃",
		"runes": [0, 0],
	},
	&"tricolor": {
		"label": "三彩句",
		"monster": "三相キメラ",
		"role": "複合・汎用",
		"runes": [1, 11, 23],
	},
}

var factory_graph: GraphEdit
var graph_area: Control
var connection_overlay
var flow_overlay
var port_overlay
var nodes: Dictionary = {}
var source_node_ids: Array[StringName] = []
var processor_node_ids: Array[StringName] = []
var summoner_node: GraphNode
var connection_created_at: Dictionary = {}
var connecting_from_node: StringName = &""
var connecting_from_port := 0
var pointer_position := Vector2.ZERO
var placement_kind: StringName = &""
var placement_serials := {&"relay": 0, &"shift": 0, &"attune": 0, &"extract": 0, &"merge": 0}
var toolbar_buttons: Dictionary = {}
var status_label: Label
var target_panel: PanelContainer
var rune_reference_view: RunePacketView
var target_view: RunePacketView
var current_view: RunePacketView
var target_title: Label
var target_monster: Label
var target_state: Label
var target_buttons: Dictionary = {}
var setting_preview_panel: PanelContainer
var setting_preview_label: Label
var setting_preview_detail: Label
var setting_preview_view: RunePacketView
var input_targets: Array[StringName] = [&"red_seed", &"blue_seed", &"green_seed"]
var selected_input_index := 0
var summoned_counts: Dictionary = {}
var last_arrival_cycles := [-1, -1, -1]
var flow_time_override := -1.0
var node_menu: PopupMenu
var node_menu_node_id: StringName = &""
var node_menu_preview_id := -1
var line_menu: PopupMenu
var line_menu_connection: Dictionary = {}


func _ready() -> void:
	_build_ui()
	_place_sources_and_summoner()
	_refresh_all()
	call_deferred("_center_initial_view")


func _process(_delta: float) -> void:
	_process_summoning(flow_time_seconds())
	if connection_overlay != null:
		connection_overlay.queue_redraw()
	if flow_overlay != null:
		flow_overlay.queue_redraw()
	if port_overlay != null:
		port_overlay.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.004, 0.012, 0.020, 1.0), true)


func return_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func flow_time_seconds() -> float:
	return flow_time_override if flow_time_override >= 0.0 else float(Time.get_ticks_msec()) / 1000.0


func target_packet(target_id: StringName) -> RunePacket:
	if not TARGET_DEFINITIONS.has(target_id):
		return null
	return RunePacketModel.from_rune_ids(TARGET_DEFINITIONS[target_id]["runes"])


func selected_target_id() -> StringName:
	return input_targets[selected_input_index]


func select_input(input_index: int) -> bool:
	if input_index < 0 or input_index >= SUMMONER_INPUT_COUNT:
		return false
	selected_input_index = input_index
	_refresh_target_panel()
	return true


func select_target(target_id: StringName) -> bool:
	if not TARGET_DEFINITIONS.has(target_id):
		return false
	input_targets[selected_input_index] = target_id
	_refresh_target_panel()
	return true


func source_count() -> int:
	return source_node_ids.size()


func source_distance_tiers() -> Dictionary:
	var result := {&"near": 0, &"middle": 0, &"far": 0}
	for id in source_node_ids:
		var node := _node(id)
		if node == null:
			continue
		var distance := _node_world_center(node).distance_to(SUMMONER_POSITION)
		if distance < 1300.0:
			result[&"near"] += 1
		elif distance < 2200.0:
			result[&"middle"] += 1
		else:
			result[&"far"] += 1
	return result


func place_processor(kind: StringName, world_center: Vector2) -> GraphNode:
	if kind not in placement_serials:
		return null
	placement_serials[kind] = int(placement_serials[kind]) + 1
	var id := StringName("%s_%02d" % [String(kind), int(placement_serials[kind])])
	var config := _default_config(kind)
	var node := _make_factory_node(id, kind, world_center, false, config)
	processor_node_ids.append(id)
	nodes[id] = node
	factory_graph.add_child(node)
	node.selected = true
	_refresh_all()
	return node


func set_shift_direction(node_id: StringName, direction: Vector2i) -> bool:
	var node := _node(node_id)
	if node == null or _kind(node_id) != &"shift" or direction not in SHIFT_DIRECTIONS:
		return false
	if Vector2i(node.get_meta("direction", Vector2i.RIGHT)) == direction:
		return false
	node.set_meta("direction", direction)
	_reset_downstream_transport(node_id)
	_refresh_all()
	return true


func set_attune_delta(node_id: StringName, delta: int) -> bool:
	var node := _node(node_id)
	if node == null or _kind(node_id) != &"attune" or delta not in [-1, 1]:
		return false
	if int(node.get_meta("delta", 1)) == delta:
		return false
	node.set_meta("delta", delta)
	_reset_downstream_transport(node_id)
	_refresh_all()
	return true


func set_extract_selector(node_id: StringName, selector_kind: StringName, selector_value: int) -> bool:
	var node := _node(node_id)
	if node == null or _kind(node_id) != &"extract":
		return false
	if selector_kind == &"attribute":
		if selector_value < 0 or selector_value >= RunePacketModel.ATTRIBUTE_COUNT:
			return false
	elif selector_kind == &"position":
		if selector_value < 0 or selector_value >= RunePacketModel.RUNES_PER_ATTRIBUTE:
			return false
	else:
		return false
	if (
		StringName(node.get_meta("selector_kind", &"attribute")) == selector_kind
		and int(node.get_meta("selector_value", 0)) == selector_value
	):
		return false
	node.set_meta("selector_kind", selector_kind)
	node.set_meta("selector_value", selector_value)
	_reset_downstream_transport(node_id)
	_refresh_all()
	return true


func output_packet(node_id: StringName, output_port: int = 0) -> RunePacket:
	return _output_packet(node_id, output_port, {})


func _output_packet(node_id: StringName, output_port: int, visited: Dictionary) -> RunePacket:
	if visited.has(node_id):
		return null
	var node := _node(node_id)
	if node == null:
		return null
	visited[node_id] = true
	var kind := _kind(node_id)
	if kind == &"source":
		var source_packet = node.get_meta("source_packet")
		return source_packet.copy() if source_packet is RunePacket else null
	if kind == &"merge":
		var input_connections := _connections_to(node_id)
		if input_connections.size() < 2:
			return null
		var result := RunePacketModel.empty()
		for connection in input_connections:
			var input_packet := _output_packet(
				StringName(connection["from_node"]),
				int(connection["from_port"]),
				visited.duplicate()
			)
			if input_packet == null:
				return null
			result = result.merged(input_packet)
			if result == null:
				return null
		return result if not result.is_empty() else null
	var input_connection := _connection_to(node_id, 0)
	if input_connection.is_empty():
		return null
	var input_packet := _output_packet(
		StringName(input_connection["from_node"]),
		int(input_connection["from_port"]),
		visited
	)
	if input_packet == null:
		return null
	match kind:
		&"relay":
			return input_packet.copy()
		&"shift":
			var shifted := input_packet.shifted(Vector2i(node.get_meta("direction", Vector2i.RIGHT)))
			return shifted if shifted != null and not shifted.is_empty() else null
		&"attune":
			return input_packet.attuned(int(node.get_meta("delta", 1)))
		&"extract":
			var split := input_packet.extracted(
				StringName(node.get_meta("selector_kind", &"attribute")),
				int(node.get_meta("selector_value", 0))
			)
			if not bool(split.get("ok", false)):
				return null
			var selected: RunePacket = split["selected"] if output_port == 0 else split["remainder"]
			return selected if selected != null and not selected.is_empty() else null
	return null


func connect_nodes(from_node_id: StringName, from_port: int, to_node_id: StringName, to_port: int) -> bool:
	if (
		factory_graph == null
		or from_node_id == to_node_id
		or not _valid_output(from_node_id, from_port)
		or not _valid_input(to_node_id, to_port)
		or _would_create_cycle(from_node_id, to_node_id)
	):
		return false
	if factory_graph.is_node_connected(from_node_id, from_port, to_node_id, to_port):
		return false
	disconnect_input(to_node_id, to_port)
	var error := factory_graph.connect_node(from_node_id, from_port, to_node_id, to_port)
	if error != OK:
		return false
	connection_created_at[_connection_key(from_node_id, from_port, to_node_id, to_port)] = flow_time_seconds()
	connecting_from_node = &""
	_refresh_all()
	return true


func disconnect_input(to_node_id: StringName, to_port: int) -> bool:
	var removed := false
	for connection in factory_graph.get_connection_list():
		if StringName(connection["to_node"]) != to_node_id or int(connection["to_port"]) != to_port:
			continue
		connection_created_at.erase(_connection_key_from(connection))
		factory_graph.disconnect_node(
			StringName(connection["from_node"]), int(connection["from_port"]),
			to_node_id, to_port
		)
		removed = true
	if removed:
		_refresh_all()
	return removed


func remove_processor(node_id: StringName) -> bool:
	if node_id not in processor_node_ids:
		return false
	var node := _node(node_id)
	if node == null:
		return false
	var affected := []
	for connection in factory_graph.get_connection_list():
		if StringName(connection["from_node"]) == node_id or StringName(connection["to_node"]) == node_id:
			affected.append(connection)
	for connection in affected:
		connection_created_at.erase(_connection_key_from(connection))
		factory_graph.disconnect_node(
			StringName(connection["from_node"]), int(connection["from_port"]),
			StringName(connection["to_node"]), int(connection["to_port"])
		)
	processor_node_ids.erase(node_id)
	nodes.erase(node_id)
	node.queue_free()
	_refresh_all()
	return true


func connected_packet(input_index: int = -1) -> RunePacket:
	var resolved := selected_input_index if input_index < 0 else input_index
	if summoner_node == null or resolved < 0 or resolved >= SUMMONER_INPUT_COUNT:
		return null
	var connection := _connection_to(StringName(summoner_node.name), resolved)
	if connection.is_empty():
		return null
	return output_packet(StringName(connection["from_node"]), int(connection["from_port"]))


func summon_state(input_index: int = -1) -> StringName:
	var resolved := selected_input_index if input_index < 0 else input_index
	var packet := connected_packet(resolved)
	if packet == null:
		return &"idle"
	if arrival_cycle(resolved, flow_time_seconds()) < 0:
		return &"transporting"
	return &"matched" if packet.matches(target_packet(input_targets[resolved])) else &"mismatch"


func arrival_cycle(input_index: int, time_seconds: float) -> int:
	if summoner_node == null:
		return -1
	var connection := _connection_to(StringName(summoner_node.name), input_index)
	if connection.is_empty():
		return -1
	var start := _connection_flow_start(connection, {})
	if is_inf(start):
		return -1
	var arrival := start + _connection_world_length(connection) / CONVEYOR_SPEED
	if time_seconds < arrival:
		return -1
	return floori((time_seconds - arrival) / PACKET_INTERVAL)


func summoned_count(target_id: StringName) -> int:
	return int(summoned_counts.get(target_id, 0))


func draw_directional_overlay(canvas: Control, layer: StringName) -> void:
	if factory_graph == null:
		return
	if layer == &"connections":
		_draw_connections(canvas)
	elif layer == &"flow":
		_draw_flow(canvas)
	elif layer == &"ports":
		_draw_ports(canvas)


func _draw_connections(canvas: Control) -> void:
	for connection in factory_graph.get_connection_list():
		var start := _port_position(StringName(connection["from_node"]), int(connection["from_port"]), true, canvas)
		var finish := _port_position(StringName(connection["to_node"]), int(connection["to_port"]), false, canvas)
		canvas.draw_line(start, finish, Color(0.13, 0.61, 0.82, 0.56), 6.0, true)
		canvas.draw_line(start, finish, Color(0.36, 0.84, 1.0, 0.94), 2.1, true)
	if connecting_from_node != &"":
		var start := _port_position(connecting_from_node, connecting_from_port, true, canvas)
		canvas.draw_dashed_line(start, pointer_position, Color(0.52, 0.90, 1.0, 0.88), 2.0, 9.0)


func _draw_flow(canvas: Control) -> void:
	var now := flow_time_seconds()
	for connection in factory_graph.get_connection_list():
		var packet := output_packet(StringName(connection["from_node"]), int(connection["from_port"]))
		if packet == null:
			continue
		var start_time := _connection_flow_start(connection, {})
		if is_inf(start_time) or now < start_time:
			continue
		var line_length := _connection_world_length(connection)
		if line_length <= 0.0:
			continue
		var emitted := floori((now - start_time) / PACKET_INTERVAL)
		var start := _port_position(StringName(connection["from_node"]), int(connection["from_port"]), true, canvas)
		var finish := _port_position(StringName(connection["to_node"]), int(connection["to_port"]), false, canvas)
		for packet_offset in mini(emitted + 1, FLOW_LIMIT):
			var sequence := emitted - packet_offset
			var elapsed := now - (start_time + float(sequence) * PACKET_INTERVAL)
			var progress := elapsed * CONVEYOR_SPEED / line_length
			if progress < 0.0 or progress > 1.0:
				continue
			_draw_flow_packet(canvas, start.lerp(finish, progress), packet)


func _draw_flow_packet(canvas: Control, center: Vector2, packet: RunePacket) -> void:
	var ids := packet.rune_ids_expanded()
	if ids.is_empty():
		return
	var primary_id := ids[0]
	var color := RunePacketModel.attribute_color(RunePacketModel.attribute_for_id(primary_id))
	canvas.draw_circle(center, 9.0, Color(0.005, 0.025, 0.038, 0.96), true)
	canvas.draw_circle(center, 9.0, Color(color, 0.92), false, 1.5)
	canvas.draw_string(
		ThemeDB.fallback_font, center + Vector2(-7.0, 4.0),
		RunePacketModel.rune_symbol(primary_id), HORIZONTAL_ALIGNMENT_CENTER, 14.0, 10,
		Color(0.90, 0.97, 1.0)
	)
	if ids.size() > 1:
		canvas.draw_circle(center + Vector2(7.0, -7.0), 4.2, color, true)
		canvas.draw_string(
			ThemeDB.fallback_font, center + Vector2(3.0, -4.0), str(ids.size()),
			HORIZONTAL_ALIGNMENT_CENTER, 8.0, 7, Color(0.01, 0.03, 0.04)
		)


func _draw_ports(canvas: Control) -> void:
	for id in nodes:
		for output_port in _output_count(id):
			var point := _port_position(id, output_port, true, canvas)
			canvas.draw_colored_polygon(PackedVector2Array([
				point + Vector2(0.0, -PORT_RADIUS),
				point + Vector2(PORT_RADIUS, 0.0),
				point + Vector2(0.0, PORT_RADIUS),
				point + Vector2(-PORT_RADIUS, 0.0),
			]), Color(0.34, 0.84, 1.0, 0.98))
		for input_port in _input_count(id):
			var point := _port_position(id, input_port, false, canvas)
			canvas.draw_circle(point, PORT_RADIUS, Color(0.008, 0.028, 0.040, 1.0), true)
			canvas.draw_circle(point, PORT_RADIUS, Color(0.42, 0.88, 1.0, 0.96), false, 1.7)


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 7)
	toolbar.custom_minimum_size.y = 42.0
	page.add_child(toolbar)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "← メニュー"
	back.custom_minimum_size = Vector2(104.0, 34.0)
	back.pressed.connect(return_to_menu)
	toolbar.add_child(back)
	for definition in [
		{&"kind": &"relay", &"text": "＋ 中継", &"tip": "内容を変えずに搬送"},
		{&"kind": &"shift", &"text": "＋ 移動", &"tip": "集合全体を3×3盤上で移動 // 中央・盤外は消滅"},
		{&"kind": &"attune", &"text": "＋ 属性", &"tip": "位置を保ったまま赤・青・緑を循環"},
		{&"kind": &"extract", &"text": "＋ 抽出", &"tip": "属性または位置で選別 // 2出力"},
		{&"kind": &"merge", &"text": "＋ 合成", &"tip": "2〜8入力を最大8文字へ合成 // 同字可"},
	]:
		var button := Button.new()
		button.text = definition[&"text"]
		button.tooltip_text = definition[&"tip"]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(78.0, 34.0)
		button.pressed.connect(_toggle_placement.bind(definition[&"kind"]))
		toolbar_buttons[definition[&"kind"]] = button
		toolbar.add_child(button)
	var title := Label.new()
	title.text = "RUNE FACTORY"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0))
	toolbar.add_child(title)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.46, 0.70, 0.80))
	toolbar.add_child(status_label)
	graph_area = Control.new()
	graph_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(graph_area)
	factory_graph = GraphEdit.new()
	factory_graph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	factory_graph.show_arrange_button = false
	factory_graph.minimap_enabled = true
	factory_graph.zoom = 0.28
	factory_graph.connection_lines_thickness = 0.0
	factory_graph.add_theme_constant_override("connection_hover_thickness", 0)
	factory_graph.gui_input.connect(_on_graph_input)
	graph_area.add_child(factory_graph)
	connection_overlay = DirectionalOverlayModel.new()
	connection_overlay.z_index = -10
	connection_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	connection_overlay.configure(self, &"connections")
	factory_graph.add_child(connection_overlay)
	flow_overlay = DirectionalOverlayModel.new()
	flow_overlay.z_index = 10
	flow_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flow_overlay.configure(self, &"flow")
	factory_graph.add_child(flow_overlay)
	port_overlay = DirectionalOverlayModel.new()
	port_overlay.z_index = 20
	port_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	port_overlay.configure(self, &"ports")
	factory_graph.add_child(port_overlay)
	target_panel = _build_target_panel()
	graph_area.add_child(target_panel)
	setting_preview_panel = _build_setting_preview_panel()
	graph_area.add_child(setting_preview_panel)
	var footer := Label.new()
	footer.text = "出力◆→入力○を順にクリック // 右クリック: 個別メニュー // ホイール: ズーム // 24素材は固定"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.40, 0.60, 0.68))
	page.add_child(footer)
	_build_context_menus()


func _build_target_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.z_index = 50
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -382.0
	panel.offset_top = 12.0
	panel.offset_right = -12.0
	panel.offset_bottom = 455.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.04, 0.058, 0.97)
	style.border_color = Color(0.20, 0.53, 0.68, 0.88)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var header := Label.new()
	header.text = "24ルーン // 赤・青・緑 × 8位置"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.72, 0.91, 1.0))
	column.add_child(header)
	rune_reference_view = RunePacketViewModel.new()
	rune_reference_view.show_empty_slots = true
	rune_reference_view.show_catalog = true
	rune_reference_view.configure(RunePacketModel.empty(), RunePacketViewModel.DisplayMode.WHEELS)
	column.add_child(rune_reference_view)
	target_title = Label.new()
	target_title.add_theme_font_size_override("font_size", 14)
	column.add_child(target_title)
	target_view = RunePacketViewModel.new()
	target_view.show_empty_slots = true
	target_view.configure(RunePacketModel.empty(), RunePacketViewModel.DisplayMode.STRIP)
	column.add_child(target_view)
	target_monster = Label.new()
	target_monster.add_theme_font_size_override("font_size", 12)
	target_monster.add_theme_color_override("font_color", Color(0.52, 0.76, 0.86))
	column.add_child(target_monster)
	var selector := HBoxContainer.new()
	selector.add_theme_constant_override("separation", 5)
	column.add_child(selector)
	var group := ButtonGroup.new()
	for target_id in TARGET_ORDER:
		var button := Button.new()
		button.text = String(TARGET_DEFINITIONS[target_id]["label"])
		button.tooltip_text = "%s // %s" % [TARGET_DEFINITIONS[target_id]["monster"], TARGET_DEFINITIONS[target_id]["role"]]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(65.0, 34.0)
		button.pressed.connect(select_target.bind(target_id))
		target_buttons[target_id] = button
		selector.add_child(button)
	var current_label := Label.new()
	current_label.text = "接続中"
	current_label.add_theme_font_size_override("font_size", 11)
	column.add_child(current_label)
	current_view = RunePacketViewModel.new()
	current_view.show_empty_slots = true
	current_view.configure(RunePacketModel.empty(), RunePacketViewModel.DisplayMode.STRIP)
	column.add_child(current_view)
	target_state = Label.new()
	target_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_state.add_theme_font_size_override("font_size", 12)
	column.add_child(target_state)
	return panel


func _build_setting_preview_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.z_index = 51
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -760.0
	panel.offset_top = 12.0
	panel.offset_right = -392.0
	panel.offset_bottom = 188.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.032, 0.048, 0.97)
	style.border_color = Color(0.34, 0.82, 1.0, 0.92)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	margin.add_child(column)
	setting_preview_label = Label.new()
	setting_preview_label.text = "未確定プレビュー"
	setting_preview_label.add_theme_font_size_override("font_size", 12)
	setting_preview_label.add_theme_color_override("font_color", Color(0.72, 0.92, 1.0))
	column.add_child(setting_preview_label)
	setting_preview_view = RunePacketViewModel.new()
	setting_preview_view.show_empty_slots = true
	setting_preview_view.configure(RunePacketModel.empty(), RunePacketViewModel.DisplayMode.WHEELS)
	column.add_child(setting_preview_view)
	setting_preview_detail = Label.new()
	setting_preview_detail.add_theme_font_size_override("font_size", 11)
	setting_preview_detail.add_theme_color_override("font_color", Color(0.55, 0.75, 0.84))
	column.add_child(setting_preview_detail)
	return panel


func _place_sources_and_summoner() -> void:
	var ordered_ids: Array[int] = [0, 8, 16, 1, 9, 17, 2, 10]
	for id in RunePacketModel.RUNE_TYPE_COUNT:
		if id not in ordered_ids:
			ordered_ids.append(id)
	for order_index in ordered_ids.size():
		var rune_id := ordered_ids[order_index]
		var radius := 950.0 if order_index < 2 else (1700.0 if order_index < 8 else 2550.0)
		var tier_index := order_index if order_index < 2 else (order_index - 2 if order_index < 8 else order_index - 8)
		var tier_count := 2 if order_index < 2 else (6 if order_index < 8 else 16)
		var angle := -PI * 0.5 + TAU * float(tier_index) / float(tier_count)
		var center := SUMMONER_POSITION + Vector2.from_angle(angle) * radius
		var attribute_index := RunePacketModel.attribute_for_id(rune_id)
		var position_index := RunePacketModel.position_for_id(rune_id)
		var id_name := StringName("source_%s_%d" % [String(RunePacketModel.ATTRIBUTES[attribute_index]), position_index + 1])
		var packet := RunePacketModel.singleton(attribute_index, position_index)
		var node := _make_factory_node(id_name, &"source", center, true, {"source_packet": packet})
		source_node_ids.append(id_name)
		nodes[id_name] = node
		factory_graph.add_child(node)
	summoner_node = _make_factory_node(&"summoner_center", &"summoner", SUMMONER_POSITION, true, {})
	nodes[StringName(summoner_node.name)] = summoner_node
	factory_graph.add_child(summoner_node)


func _make_factory_node(
	node_id: StringName,
	kind: StringName,
	world_center: Vector2,
	fixed: bool,
	config: Dictionary
) -> GraphNode:
	var node := GraphNode.new()
	node.name = String(node_id)
	node.title = ""
	node.draggable = not fixed
	node.resizable = false
	node.set_meta("rune_kind", kind)
	node.set_meta("fixed_landmark", fixed)
	for key in config:
		node.set_meta(StringName(key), config[key])
	var row_count := maxi(_input_count_for_kind(kind), _output_count_for_kind(kind))
	for row_index in row_count:
		var row := Control.new()
		row.custom_minimum_size = Vector2.ONE
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(row)
		node.set_slot(
			row_index,
			row_index < _input_count_for_kind(kind), row_index, BUILTIN_PORT_COLOR,
			row_index < _output_count_for_kind(kind), row_index, BUILTIN_PORT_COLOR
		)
	var visual := RuneFactoryNodeVisualModel.new()
	visual.configure(kind, config.get("source_packet", null), config)
	node.add_child(visual)
	_configure_round_node(node, visual.custom_minimum_size)
	node.position_offset = world_center - visual.custom_minimum_size * 0.5
	node.tooltip_text = _node_tooltip(node_id)
	if not fixed:
		node.gui_input.connect(_on_node_input.bind(node))
	return node


func _configure_round_node(node: GraphNode, minimum_size: Vector2) -> void:
	node.custom_minimum_size = minimum_size
	var empty := StyleBoxEmpty.new()
	for style_name in ["panel", "panel_selected", "titlebar", "titlebar_selected", "slot"]:
		node.add_theme_stylebox_override(style_name, empty)
	node.add_theme_color_override("title_color", Color.TRANSPARENT)
	node.add_theme_color_override("close_color", Color.TRANSPARENT)
	node.add_theme_color_override("resizer_color", Color.TRANSPARENT)


func _default_config(kind: StringName) -> Dictionary:
	match kind:
		&"shift":
			return {"direction": Vector2i.RIGHT}
		&"attune":
			return {"delta": 1}
		&"extract":
			return {"selector_kind": &"attribute", "selector_value": 0}
	return {}


func _refresh_all() -> void:
	for id in nodes:
		var node := _node(id)
		var visual := _visual(node)
		if visual == null:
			continue
		var config := _node_config(id)
		visual.configure(_kind(id), output_packet(id), config)
		node.tooltip_text = _node_tooltip(id)
	status_label.text = "素材 %d // 中継 %d // 移動 %d // 属性 %d // 抽出 %d // 合成 %d" % [
		source_node_ids.size(), _processor_count(&"relay"), _processor_count(&"shift"),
		_processor_count(&"attune"), _processor_count(&"extract"), _processor_count(&"merge")
	]
	_refresh_target_panel()


func _refresh_target_panel() -> void:
	if target_view == null:
		return
	var target_id := selected_target_id()
	var definition: Dictionary = TARGET_DEFINITIONS[target_id]
	target_title.text = "INPUT %d // %s" % [selected_input_index + 1, definition["label"]]
	target_monster.text = "%s // %s" % [definition["monster"], definition["role"]]
	target_view.configure(target_packet(target_id), RunePacketViewModel.DisplayMode.STRIP)
	var current := connected_packet(selected_input_index)
	current_view.configure(current if current != null else RunePacketModel.empty(), RunePacketViewModel.DisplayMode.STRIP)
	for id in target_buttons:
		target_buttons[id].set_pressed_no_signal(id == target_id)
	match summon_state(selected_input_index):
		&"idle":
			target_state.text = "未接続"
			target_state.add_theme_color_override("font_color", Color(0.48, 0.62, 0.70))
		&"transporting":
			target_state.text = "輸送中"
			target_state.add_theme_color_override("font_color", Color(0.46, 0.82, 1.0))
		&"matched":
			target_state.text = "召喚中 // ×%d" % summoned_count(target_id)
			target_state.add_theme_color_override("font_color", Color(0.42, 0.92, 0.66))
		_:
			target_state.text = "不一致"
			target_state.add_theme_color_override("font_color", Color(1.0, 0.48, 0.44))


func _process_summoning(now: float) -> void:
	var changed := false
	for input_index in SUMMONER_INPUT_COUNT:
		var cycle := arrival_cycle(input_index, now)
		if cycle <= last_arrival_cycles[input_index]:
			continue
		var packet := connected_packet(input_index)
		var target_id := input_targets[input_index]
		if packet != null and packet.matches(target_packet(target_id)):
			var additions := cycle - maxi(last_arrival_cycles[input_index], -1)
			summoned_counts[target_id] = int(summoned_counts.get(target_id, 0)) + additions
		last_arrival_cycles[input_index] = cycle
		changed = true
	if changed:
		_refresh_target_panel()


func _toggle_placement(kind: StringName) -> void:
	var button: Button = toolbar_buttons[kind]
	placement_kind = kind if button.button_pressed else &""
	for other_kind in toolbar_buttons:
		if other_kind != kind:
			toolbar_buttons[other_kind].set_pressed_no_signal(false)
	connecting_from_node = &""


func _on_graph_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer_position = event.position
		return
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	pointer_position = mouse.position
	if not mouse.pressed:
		return
	if mouse.button_index == MOUSE_BUTTON_LEFT:
		var output := _output_at(mouse.position)
		var input := _input_at(mouse.position)
		if not input.is_empty():
			if StringName(input["node_id"]) == StringName(summoner_node.name):
				select_input(int(input["port"]))
			if connecting_from_node != &"":
				connect_nodes(connecting_from_node, connecting_from_port, StringName(input["node_id"]), int(input["port"]))
			factory_graph.accept_event()
			return
		if not output.is_empty():
			connecting_from_node = StringName(output["node_id"])
			connecting_from_port = int(output["port"])
			factory_graph.accept_event()
			return
		if placement_kind != &"" and _node_at(mouse.position) == &"":
			place_processor(placement_kind, _graph_to_world(mouse.position))
			placement_kind = &""
			for button in toolbar_buttons.values():
				button.set_pressed_no_signal(false)
			factory_graph.accept_event()
			return
		connecting_from_node = &""
	elif mouse.button_index == MOUSE_BUTTON_RIGHT:
		connecting_from_node = &""
		var connection := _connection_at(mouse.position)
		if not connection.is_empty():
			_open_line_menu(connection, mouse.global_position)
			factory_graph.accept_event()
			return
		var node_id := _node_at(mouse.position)
		if node_id in processor_node_ids:
			_open_node_menu(node_id, mouse.global_position)
			factory_graph.accept_event()


func _on_node_input(event: InputEvent, node: GraphNode) -> void:
	if not event is InputEventMouse:
		return
	var graph_event := event.duplicate() as InputEventMouse
	graph_event.position = _convert_point(node, event.position, factory_graph)
	_on_graph_input(graph_event)
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT:
			_open_node_menu(StringName(node.name), mouse.global_position)
			node.accept_event()


func _build_context_menus() -> void:
	node_menu = PopupMenu.new()
	node_menu.id_pressed.connect(_on_node_menu_pressed)
	node_menu.id_focused.connect(_preview_node_menu_item)
	node_menu.window_input.connect(_on_node_menu_window_input)
	node_menu.popup_hide.connect(_clear_node_setting_preview)
	add_child(node_menu)
	line_menu = PopupMenu.new()
	line_menu.add_item("搬送路を削除", 1)
	line_menu.id_pressed.connect(_on_line_menu_pressed)
	add_child(line_menu)


func _open_node_menu(node_id: StringName, global_position: Vector2) -> void:
	node_menu_node_id = node_id
	node_menu.clear()
	match _kind(node_id):
		&"shift":
			for index in SHIFT_DIRECTIONS.size():
				node_menu.add_item("%s へ1マス" % SHIFT_LABELS[index], 100 + index)
		&"attune":
			node_menu.add_item("赤 → 青 → 緑", 200)
			node_menu.add_item("赤 ← 青 ← 緑", 201)
		&"extract":
			for attribute_index in RunePacketModel.ATTRIBUTE_COUNT:
				node_menu.add_item("%s属性を抽出" % RunePacketModel.ATTRIBUTE_LABELS[attribute_index], 300 + attribute_index)
			for position_index in RunePacketModel.RUNES_PER_ATTRIBUTE:
				node_menu.add_item("位置 %d を抽出" % (position_index + 1), 400 + position_index)
	node_menu.add_item("ノードを削除", 999)
	node_menu.position = Vector2i(global_position.round())
	node_menu.popup()


func _on_node_menu_pressed(id: int) -> void:
	if node_menu_node_id == &"":
		return
	if id >= 100 and id < 104:
		set_shift_direction(node_menu_node_id, SHIFT_DIRECTIONS[id - 100])
	elif id == 200:
		set_attune_delta(node_menu_node_id, 1)
	elif id == 201:
		set_attune_delta(node_menu_node_id, -1)
	elif id >= 300 and id < 303:
		set_extract_selector(node_menu_node_id, &"attribute", id - 300)
	elif id >= 400 and id < 408:
		set_extract_selector(node_menu_node_id, &"position", id - 400)
	elif id == 999:
		remove_processor(node_menu_node_id)


func _on_node_menu_window_input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	var index := _popup_item_index_at(node_menu, (event as InputEventMouseMotion).position)
	if index < 0:
		_clear_node_setting_preview()
		return
	_preview_node_menu_item(node_menu.get_item_id(index))


func _popup_item_index_at(popup: PopupMenu, at_position: Vector2) -> int:
	var count := popup.item_count
	if count <= 0 or at_position.x < 0.0 or at_position.x >= float(popup.size.x):
		return -1
	var panel := popup.get_theme_stylebox("panel")
	var top_margin := maxf(panel.get_content_margin(SIDE_TOP), 0.0)
	var bottom_margin := maxf(panel.get_content_margin(SIDE_BOTTOM), 0.0)
	var content_height := float(popup.size.y) - top_margin - bottom_margin
	if content_height <= 0.0 or at_position.y < top_margin or at_position.y >= top_margin + content_height:
		return -1
	var index := int(floor((at_position.y - top_margin) / (content_height / float(count))))
	return index if index >= 0 and index < count else -1


func _preview_node_menu_item(item_id: int) -> void:
	if item_id == node_menu_preview_id or node_menu_node_id == &"":
		return
	if not (
		(item_id >= 100 and item_id < 104)
		or item_id in [200, 201]
		or (item_id >= 300 and item_id < 303)
		or (item_id >= 400 and item_id < 408)
	):
		_clear_node_setting_preview()
		return
	node_menu_preview_id = item_id
	var input_connection := _connection_to(node_menu_node_id, 0)
	var input_packet: RunePacket = null
	if not input_connection.is_empty():
		input_packet = output_packet(
			StringName(input_connection["from_node"]),
			int(input_connection["from_port"])
		)
	setting_preview_panel.visible = true
	if input_packet == null:
		setting_preview_label.text = "未確定プレビュー // 入力待ち"
		setting_preview_detail.text = "接続後に結果と消滅対象を表示します"
		setting_preview_view.configure(RunePacketModel.empty(), RunePacketViewModel.DisplayMode.WHEELS)
		return
	var output: RunePacket = null
	var removed: RunePacket = RunePacketModel.empty()
	var detail := ""
	if item_id >= 100 and item_id < 104:
		var direction: Vector2i = SHIFT_DIRECTIONS[item_id - 100]
		var preview := input_packet.shifted_preview(direction)
		output = preview["output"]
		removed = preview["removed"]
		detail = "%s へ1マス // 出力 %d字 // 消滅 %d字" % [
			SHIFT_LABELS[item_id - 100], output.total_count(), removed.total_count()
		]
	elif item_id in [200, 201]:
		output = input_packet.attuned(1 if item_id == 200 else -1)
		detail = "%s // 位置・個数を保持" % ("赤→青→緑" if item_id == 200 else "赤←青←緑")
	else:
		var selector_kind := &"attribute" if item_id >= 300 and item_id < 303 else &"position"
		var selector_value := item_id - (300 if selector_kind == &"attribute" else 400)
		var split := input_packet.extracted(selector_kind, selector_value)
		output = split["selected"]
		var remainder: RunePacket = split["remainder"]
		detail = "◆0 該当 %d字 // ◆1 残り %d字" % [output.total_count(), remainder.total_count()]
	setting_preview_label.text = "未確定プレビュー // %s" % _node_kind_label(_kind(node_menu_node_id))
	setting_preview_detail.text = detail
	setting_preview_view.configure(output, RunePacketViewModel.DisplayMode.WHEELS, removed)


func _clear_node_setting_preview() -> void:
	node_menu_preview_id = -1
	if setting_preview_panel != null:
		setting_preview_panel.visible = false


func _open_line_menu(connection: Dictionary, global_position: Vector2) -> void:
	line_menu_connection = connection.duplicate()
	line_menu.position = Vector2i(global_position.round())
	line_menu.popup()


func _on_line_menu_pressed(id: int) -> void:
	if id != 1 or line_menu_connection.is_empty():
		return
	disconnect_input(StringName(line_menu_connection["to_node"]), int(line_menu_connection["to_port"]))


func _node_tooltip(node_id: StringName) -> String:
	var node := _node(node_id)
	if node == null:
		return ""
	match _kind(node_id):
		&"source":
			var packet: RunePacket = node.get_meta("source_packet")
			return "%s素材 // 固定 // %s" % [packet.short_label(), RunePacketModel.rune_symbol(packet.rune_ids_expanded()[0])]
		&"summoner":
			return "召喚器 // 入力ポートでターゲット切替"
		&"relay":
			return "中継 // 内容を変更せず搬送 // 右クリック"
		&"shift":
			var direction := Vector2i(node.get_meta("direction", Vector2i.RIGHT))
			return "移動 %s // 中央・盤外・属性境界は消滅 // 右クリック" % SHIFT_LABELS[SHIFT_DIRECTIONS.find(direction)]
		&"attune":
			return "属性変換 // 位置と個数を保持 // 右クリック"
		&"extract":
			return "抽出 // ◆0=該当 / ◆1=残り // 右クリック"
		&"merge":
			return "合成 // 2〜8入力 // 同じルーン可 // 最大8文字"
	return ""


func _node_kind_label(kind: StringName) -> String:
	match kind:
		&"shift":
			return "移動"
		&"attune":
			return "属性変換"
		&"extract":
			return "抽出"
		&"merge":
			return "合成"
		&"relay":
			return "中継"
	return String(kind)


func _node_config(node_id: StringName) -> Dictionary:
	var node := _node(node_id)
	if node == null:
		return {}
	match _kind(node_id):
		&"shift":
			return {"direction": node.get_meta("direction", Vector2i.RIGHT)}
		&"attune":
			return {"delta": int(node.get_meta("delta", 1))}
		&"extract":
			return {
				"selector_kind": node.get_meta("selector_kind", &"attribute"),
				"selector_value": int(node.get_meta("selector_value", 0)),
			}
	return {}


func _processor_count(kind: StringName) -> int:
	var count := 0
	for id in processor_node_ids:
		if _kind(id) == kind:
			count += 1
	return count


func _input_count(node_id: StringName) -> int:
	return _input_count_for_kind(_kind(node_id))


func _output_count(node_id: StringName) -> int:
	return _output_count_for_kind(_kind(node_id))


func _input_count_for_kind(kind: StringName) -> int:
	if kind == &"summoner":
		return SUMMONER_INPUT_COUNT
	if kind == &"merge":
		return MERGE_INPUT_COUNT
	if kind in [&"relay", &"shift", &"attune", &"extract"]:
		return 1
	return 0


func _output_count_for_kind(kind: StringName) -> int:
	if kind == &"extract":
		return 2
	if kind in [&"source", &"relay", &"shift", &"attune", &"merge"]:
		return 1
	return 0


func _valid_input(node_id: StringName, port: int) -> bool:
	return _node(node_id) != null and port >= 0 and port < _input_count(node_id)


func _valid_output(node_id: StringName, port: int) -> bool:
	return _node(node_id) != null and port >= 0 and port < _output_count(node_id)


func _connections_to(node_id: StringName) -> Array:
	var result := []
	for connection in factory_graph.get_connection_list():
		if StringName(connection["to_node"]) == node_id:
			result.append(connection)
	result.sort_custom(func(a, b): return int(a["to_port"]) < int(b["to_port"]))
	return result


func _connection_to(node_id: StringName, port: int) -> Dictionary:
	for connection in factory_graph.get_connection_list():
		if StringName(connection["to_node"]) == node_id and int(connection["to_port"]) == port:
			return connection
	return {}


func _would_create_cycle(from_id: StringName, to_id: StringName) -> bool:
	var pending: Array[StringName] = [to_id]
	var visited := {}
	while not pending.is_empty():
		var current: StringName = pending.pop_back()
		if current == from_id:
			return true
		if visited.has(current):
			continue
		visited[current] = true
		for connection in factory_graph.get_connection_list():
			if StringName(connection["from_node"]) == current:
				pending.append(StringName(connection["to_node"]))
	return false


func _connection_flow_start(connection: Dictionary, visited: Dictionary) -> float:
	var key := _connection_key_from(connection)
	if not connection_created_at.has(key):
		return INF
	var created := float(connection_created_at[key])
	var from_id := StringName(connection["from_node"])
	if _kind(from_id) == &"source":
		return created
	if visited.has(from_id):
		return INF
	visited[from_id] = true
	var upstream := _connections_to(from_id)
	if upstream.is_empty():
		return INF
	var ready := created
	for input_connection in upstream:
		var input_start := _connection_flow_start(input_connection, visited.duplicate())
		if is_inf(input_start):
			return INF
		ready = maxf(ready, input_start + _connection_world_length(input_connection) / CONVEYOR_SPEED)
	return ready


func _reset_downstream_transport(node_id: StringName) -> void:
	var now := flow_time_seconds()
	var pending: Array[StringName] = [node_id]
	var visited := {}
	while not pending.is_empty():
		var current: StringName = pending.pop_back()
		if visited.has(current):
			continue
		visited[current] = true
		for connection in factory_graph.get_connection_list():
			if StringName(connection["from_node"]) != current:
				continue
			connection_created_at[_connection_key_from(connection)] = now
			pending.append(StringName(connection["to_node"]))


func _connection_world_length(connection: Dictionary) -> float:
	var from_node := _node(StringName(connection["from_node"]))
	var to_node := _node(StringName(connection["to_node"]))
	if from_node == null or to_node == null:
		return 0.0
	return _node_world_center(from_node).distance_to(_node_world_center(to_node))


func _connection_key(from_id: StringName, from_port: int, to_id: StringName, to_port: int) -> String:
	return "%s:%d>%s:%d" % [from_id, from_port, to_id, to_port]


func _connection_key_from(connection: Dictionary) -> String:
	return _connection_key(
		StringName(connection["from_node"]), int(connection["from_port"]),
		StringName(connection["to_node"]), int(connection["to_port"])
	)


func _port_position(node_id: StringName, port: int, output: bool, space: Control) -> Vector2:
	var node := _node(node_id)
	if node == null:
		return Vector2.ZERO
	var center := _node_center_in(node, space)
	var direction := Vector2.RIGHT if output else Vector2.LEFT
	var kind := _kind(node_id)
	if kind == &"summoner" and not output:
		direction = Vector2.from_angle(-PI * 0.5 + TAU * float(port) / 3.0)
	elif kind == &"merge" and not output:
		direction = Vector2.from_angle(-PI * 0.5 + TAU * float(port) / 8.0)
	elif kind == &"extract" and output:
		var base := _downstream_direction(node_id, space)
		direction = base.rotated(-0.34 if port == 0 else 0.34)
	elif output:
		direction = _downstream_direction(node_id, space)
	else:
		direction = _upstream_direction(node_id, port, space)
	return _node_boundary_in(node, direction, space)


func _downstream_direction(node_id: StringName, space: Control) -> Vector2:
	var node := _node(node_id)
	var center := _node_center_in(node, space)
	var sum := Vector2.ZERO
	for connection in factory_graph.get_connection_list():
		if StringName(connection["from_node"]) == node_id:
			var target := _node(StringName(connection["to_node"]))
			if target != null:
				sum += center.direction_to(_node_center_in(target, space))
	if not sum.is_zero_approx():
		return sum.normalized()
	return center.direction_to(_node_center_in(summoner_node, space))


func _upstream_direction(node_id: StringName, port: int, space: Control) -> Vector2:
	var node := _node(node_id)
	var center := _node_center_in(node, space)
	var connection := _connection_to(node_id, port)
	if not connection.is_empty():
		var source := _node(StringName(connection["from_node"]))
		if source != null:
			return center.direction_to(_node_center_in(source, space))
	return _node_center_in(summoner_node, space).direction_to(center)


func _node_boundary_in(node: GraphNode, direction: Vector2, space: Control) -> Vector2:
	var visual := _visual(node)
	var local_center := visual.size * 0.5 if visual.size.x > 0.0 else visual.custom_minimum_size * 0.5
	var local_point := local_center + direction.normalized() * visual.body_radius()
	return _convert_point(visual, local_point, space)


func _node_center_in(node: GraphNode, space: Control) -> Vector2:
	var visual := _visual(node)
	var local_center := visual.size * 0.5 if visual.size.x > 0.0 else visual.custom_minimum_size * 0.5
	return _convert_point(visual, local_center, space)


func _node_world_center(node: GraphNode) -> Vector2:
	return node.position_offset + node.size * 0.5


func _convert_point(source: Control, point: Vector2, destination: Control) -> Vector2:
	return destination.get_global_transform().affine_inverse() * (source.get_global_transform() * point)


func _output_at(position: Vector2) -> Dictionary:
	for id in nodes:
		for port in _output_count(id):
			if position.distance_to(_port_position(id, port, true, factory_graph)) <= PORT_HIT_RADIUS:
				return {"node_id": id, "port": port}
	return {}


func _input_at(position: Vector2) -> Dictionary:
	for id in nodes:
		for port in _input_count(id):
			if position.distance_to(_port_position(id, port, false, factory_graph)) <= PORT_HIT_RADIUS:
				return {"node_id": id, "port": port}
	return {}


func _node_at(position: Vector2) -> StringName:
	for id in nodes:
		var node := _node(id)
		if position.distance_to(_node_center_in(node, factory_graph)) <= _visual(node).body_radius() * factory_graph.zoom:
			return id
	return &""


func _connection_at(position: Vector2) -> Dictionary:
	var closest := {}
	var best := INF
	for connection in factory_graph.get_connection_list():
		var start := _port_position(StringName(connection["from_node"]), int(connection["from_port"]), true, factory_graph)
		var finish := _port_position(StringName(connection["to_node"]), int(connection["to_port"]), false, factory_graph)
		var point := Geometry2D.get_closest_point_to_segment(position, start, finish)
		var distance := position.distance_to(point)
		if distance <= LINE_HIT_RADIUS and distance < best:
			best = distance
			closest = connection
	return closest


func _graph_to_world(graph_position: Vector2) -> Vector2:
	return (graph_position + factory_graph.scroll_offset) / maxf(factory_graph.zoom, 0.001)


func _center_initial_view() -> void:
	factory_graph.scroll_offset = SUMMONER_POSITION * factory_graph.zoom - factory_graph.size * 0.5


func _node(node_id: StringName) -> GraphNode:
	return nodes.get(node_id) as GraphNode


func _kind(node_id: StringName) -> StringName:
	var node := _node(node_id)
	return StringName(node.get_meta("rune_kind", &"")) if node != null else &""


func _visual(node: GraphNode) -> RuneFactoryNodeVisual:
	if node == null:
		return null
	for child in node.get_children():
		if child is RuneFactoryNodeVisual:
			return child
	return null
