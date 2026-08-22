class_name FactoryPrototype
extends Control

const FactoryLandmarkVisualModel := preload("res://experiments/factory_prototype/factory_landmark.gd")
const FactoryDirectionalOverlayModel := preload("res://experiments/factory_prototype/factory_directional_overlay.gd")
const FactoryFlowAudioModel := preload("res://experiments/factory_prototype/factory_flow_audio.gd")
const GlyphModelScript := preload("res://src/domain/glyph.gd")
const GlyphComponentModelScript := preload("res://src/domain/glyph_component.gd")
const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")

const MENU_SCENE := "res://src/main_menu.tscn"
const PLAYFIELD_SIZE := Vector2(9000.0, 6000.0)
const SUMMONER_POSITION := Vector2(4400.0, 2895.0)
const SUMMONER_INPUT_COUNT := 3
const SUMMONER_INPUT_START_ANGLE := -PI * 0.5
const PORT_COLOR := Color(0.28, 0.78, 1.0, 1.0)
const PORT_IDLE_COLOR := Color(0.20, 0.55, 0.70, 0.92)
const PORT_HIT_RADIUS := 13.0
const PORT_DRAW_RADIUS := 5.5
const CONNECTION_HIT_RADIUS := 10.0
const BUILTIN_PORT_COLOR := Color(0.0, 0.0, 0.0, 0.0)
const DEFAULT_CONVEYOR_GRADE := 1
const CONVEYOR_SPEED_BY_GRADE := { 1: 520.0 }
const FLOW_GLYPH_SPACING_WORLD_UNITS := 600.0
const FLOW_ARRIVAL_EFFECT_SECONDS := 0.28
const FLOW_MAX_VISIBLE_GLYPHS := 24
const SUMMON_EVENT_HISTORY_LIMIT := 128
const FLOW_TRAIL_SCREEN_LENGTH := 18.0
const FLOW_PATH_START := 0.0
const FLOW_PATH_END := 1.0
const TARGET_ORDER := [&"circle", &"triangle", &"square", &"diamond"]
const TARGET_DEFINITIONS := {
	&"circle": {
		"glyph_label": "○",
		"primitive_id": &"circle",
		"rotation_degrees": 0,
		"monster_id": &"ring_wisp",
		"monster_name": "環霊ウィスプ",
		"role": "軽量・浮遊・群体",
	},
	&"triangle": {
		"glyph_label": "△",
		"primitive_id": &"triangle",
		"rotation_degrees": 0,
		"monster_id": &"stinger",
		"monster_name": "針獣スティンガー",
		"role": "高速・突撃・軽装",
	},
	&"square": {
		"glyph_label": "□",
		"primitive_id": &"square",
		"rotation_degrees": 0,
		"monster_id": &"stone_block",
		"monster_name": "石殻ブロック",
		"role": "低速・防壁・重装",
	},
	&"diamond": {
		"glyph_label": "◇",
		"primitive_id": &"square",
		"rotation_degrees": 45,
		"monster_id": &"razor_kite",
		"monster_name": "斜刃カイト",
		"role": "高速・旋回・切断",
	},
}
const MATERIAL_LAYOUT := [
	# Inner deposits keep all three materials available near the first factory hub.
	{ "id": &"circle_01", "kind": &"circle", "position": Vector2(2900.0, 2895.0) },
	{ "id": &"circle_02", "kind": &"circle", "position": Vector2(5400.0, 2045.0) },
	{ "id": &"triangle_01", "kind": &"triangle", "position": Vector2(5900.0, 2895.0) },
	{ "id": &"triangle_02", "kind": &"triangle", "position": Vector2(3400.0, 3745.0) },
	{ "id": &"square_01", "kind": &"square", "position": Vector2(3400.0, 2045.0) },
	{ "id": &"square_02", "kind": &"square", "position": Vector2(5400.0, 3745.0) },
	# Distant deposits make route length and direction part of later factory planning.
	{ "id": &"circle_03", "kind": &"circle", "position": Vector2(1500.0, 800.0) },
	{ "id": &"circle_04", "kind": &"circle", "position": Vector2(7100.0, 1000.0) },
	{ "id": &"circle_05", "kind": &"circle", "position": Vector2(8000.0, 2700.0) },
	{ "id": &"circle_06", "kind": &"circle", "position": Vector2(6900.0, 4800.0) },
	{ "id": &"circle_07", "kind": &"circle", "position": Vector2(2500.0, 5000.0) },
	{ "id": &"circle_08", "kind": &"circle", "position": Vector2(800.0, 3500.0) },
	{ "id": &"circle_09", "kind": &"circle", "position": Vector2(3000.0, 1400.0) },
	{ "id": &"circle_10", "kind": &"circle", "position": Vector2(6100.0, 3900.0) },
	{ "id": &"triangle_03", "kind": &"triangle", "position": Vector2(2800.0, 700.0) },
	{ "id": &"triangle_04", "kind": &"triangle", "position": Vector2(6000.0, 650.0) },
	{ "id": &"triangle_05", "kind": &"triangle", "position": Vector2(8200.0, 1500.0) },
	{ "id": &"triangle_06", "kind": &"triangle", "position": Vector2(7800.0, 4100.0) },
	{ "id": &"triangle_07", "kind": &"triangle", "position": Vector2(5600.0, 5200.0) },
	{ "id": &"triangle_08", "kind": &"triangle", "position": Vector2(1200.0, 4900.0) },
	{ "id": &"triangle_09", "kind": &"triangle", "position": Vector2(900.0, 2000.0) },
	{ "id": &"triangle_10", "kind": &"triangle", "position": Vector2(2600.0, 3800.0) },
	{ "id": &"square_03", "kind": &"square", "position": Vector2(450.0, 700.0) },
	{ "id": &"square_04", "kind": &"square", "position": Vector2(4400.0, 500.0) },
	{ "id": &"square_05", "kind": &"square", "position": Vector2(7600.0, 650.0) },
	{ "id": &"square_06", "kind": &"square", "position": Vector2(8500.0, 3400.0) },
	{ "id": &"square_07", "kind": &"square", "position": Vector2(7200.0, 5300.0) },
	{ "id": &"square_08", "kind": &"square", "position": Vector2(4000.0, 5350.0) },
	{ "id": &"square_09", "kind": &"square", "position": Vector2(1800.0, 4200.0) },
	{ "id": &"square_10", "kind": &"square", "position": Vector2(1600.0, 1500.0) },
]

var factory_graph: GraphEdit
var summoner_node: GraphNode
var material_nodes: Array[GraphNode] = []
var relay_nodes: Array[GraphNode] = []
var rotation_nodes: Array[GraphNode] = []
var connection_overlay
var flow_overlay
var port_overlay
var graph_menu_panel: PanelContainer
var graph_minimap: Control
var flow_audio
var flow_arrival_cycles: Array[int] = [-1, -1, -1]
var connection_flow_started_at: Dictionary = {}
var summoned_monster_counts: Dictionary = {}
var summon_events: Array[Dictionary] = []
var flow_time_override := -1.0
var status_label: Label
var relay_button: Button
var relay_placement_active := false
var relay_serial := 0
var rotation_button: Button
var rotation_placement_active := false
var rotation_serial := 0
var rotation_settings_popup: PopupPanel
var rotation_settings_title: Label
var rotation_settings_angle: SpinBox
var rotation_settings_node_id: StringName = &""
var rotation_settings_syncing := false
var line_settings_popup: PopupPanel
var line_settings_title: Label
var line_settings_details: Label
var line_settings_delete_button: Button
var line_settings_connection: Dictionary = {}
var target_panel: PanelContainer
var target_preview
var target_header_label: Label
var target_name_label: Label
var target_role_label: Label
var summon_state_label: Label
var target_buttons: Dictionary = {}
var input_target_kinds: Array[StringName] = [&"circle", &"triangle", &"square"]
var selected_input_index := 0
var connecting_material_id: StringName = &""
var hovered_material_id: StringName = &""
var hovered_connection_key := ""
var hovered_input_index := -1
var hovered_input_node_id: StringName = &""
var connection_pointer := Vector2.ZERO
var connection_press_position := Vector2.ZERO
var connection_drag_moved := false
var selected_target_kind: StringName:
	get:
		if selected_input_index < 0 or selected_input_index >= input_target_kinds.size():
			return &"circle"
		return input_target_kinds[selected_input_index]


func _ready() -> void:
	_build_ui()
	_setup_flow_audio()
	_place_landmarks()
	_refresh_summon_state()
	call_deferred("_center_initial_view")


func _process(_delta: float) -> void:
	var now := flow_animation_time_seconds()
	process_transport_at(now)
	_refresh_transport_countdown(now)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.005, 0.014, 0.024, 1.0), true)


func return_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func fixed_landmark_count() -> int:
	return material_nodes.size() + (1 if summoner_node != null else 0)


func material_kind_counts() -> Dictionary:
	var counts := { &"circle": 0, &"triangle": 0, &"square": 0 }
	for node in material_nodes:
		var kind := StringName(node.get_meta("landmark_kind", &""))
		if counts.has(kind):
			counts[kind] = int(counts[kind]) + 1
	return counts


func all_landmarks_locked() -> bool:
	if summoner_node == null or summoner_node.draggable:
		return false
	for node in material_nodes:
		if node.draggable:
			return false
	return true


func begin_relay_placement() -> void:
	_clear_directional_connection_preview()
	cancel_rotation_placement()
	relay_placement_active = true
	if relay_button != null:
		relay_button.button_pressed = true
	status_label.text = "中継ノード // 盤面をクリックして配置 // 右クリックで取消"
	status_label.add_theme_color_override("font_color", Color(0.58, 0.86, 1.0))


func cancel_relay_placement() -> void:
	relay_placement_active = false
	if relay_button != null:
		relay_button.button_pressed = false
	_refresh_summon_state()


func begin_rotation_placement() -> void:
	_clear_directional_connection_preview()
	cancel_relay_placement()
	rotation_placement_active = true
	if rotation_button != null:
		rotation_button.button_pressed = true
	status_label.text = "回転ノード // 盤面をクリックして配置 // 右クリックで取消"
	status_label.add_theme_color_override("font_color", Color(0.58, 0.86, 1.0))


func cancel_rotation_placement() -> void:
	rotation_placement_active = false
	if rotation_button != null:
		rotation_button.button_pressed = false
	_refresh_summon_state()


func place_relay_at(world_center: Vector2) -> GraphNode:
	if factory_graph == null:
		return null
	relay_serial += 1
	var relay_half_size := Vector2.ONE * 59.0
	var safe_center := Vector2(
		clampf(world_center.x, relay_half_size.x, PLAYFIELD_SIZE.x - relay_half_size.x),
		clampf(world_center.y, relay_half_size.y, PLAYFIELD_SIZE.y - relay_half_size.y)
	)
	var relay := _make_relay_node(
		StringName("relay_%02d" % relay_serial),
		safe_center
	)
	relay_nodes.append(relay)
	factory_graph.add_child(relay)
	relay.selected = true
	_refresh_factory_status_label()
	return relay


func place_rotation_at(world_center: Vector2, angle_degrees: int = 45) -> GraphNode:
	if factory_graph == null:
		return null
	rotation_serial += 1
	var node_half_size := Vector2.ONE * 59.0
	var clamped_center := Vector2(
		clampf(world_center.x, node_half_size.x, PLAYFIELD_SIZE.x - node_half_size.x),
		clampf(world_center.y, node_half_size.y, PLAYFIELD_SIZE.y - node_half_size.y)
	)
	var rotation := _make_rotation_node(
		StringName("rotation_%02d" % rotation_serial),
		clamped_center,
		angle_degrees
	)
	rotation_nodes.append(rotation)
	rotation.tooltip_text = _rotation_tooltip(StringName(rotation.name))
	factory_graph.add_child(rotation)
	rotation.selected = true
	_refresh_factory_status_label()
	return rotation


func graph_screen_to_world(screen_position: Vector2) -> Vector2:
	if factory_graph == null:
		return Vector2.ZERO
	var world := (screen_position + factory_graph.scroll_offset) / maxf(factory_graph.zoom, 0.001)
	return Vector2(
		clampf(world.x, 0.0, PLAYFIELD_SIZE.x),
		clampf(world.y, 0.0, PLAYFIELD_SIZE.y)
	)


func select_target(target_kind: StringName) -> bool:
	if not TARGET_DEFINITIONS.has(target_kind):
		return false
	process_transport_at(flow_animation_time_seconds())
	input_target_kinds[selected_input_index] = target_kind
	_refresh_summon_state()
	return true


func select_input(input_index: int) -> bool:
	if input_index < 0 or input_index >= SUMMONER_INPUT_COUNT:
		return false
	selected_input_index = input_index
	_refresh_summon_state()
	return true


func target_kind_for_input(input_index: int) -> StringName:
	if input_index < 0 or input_index >= input_target_kinds.size():
		return &""
	return input_target_kinds[input_index]


func target_glyph_for_input(input_index: int) -> GlyphModel:
	return target_glyph(target_kind_for_input(input_index))


func target_glyph(target_kind: StringName) -> GlyphModel:
	if not TARGET_DEFINITIONS.has(target_kind):
		return null
	var definition: Dictionary = TARGET_DEFINITIONS[target_kind]
	var glyph := primitive_glyph(StringName(definition.get("primitive_id", target_kind)))
	if glyph == null:
		return null
	return glyph.rotated_degrees(int(definition.get("rotation_degrees", 0)))


func target_monster_id(input_index: int = -1) -> StringName:
	var resolved_index := selected_input_index if input_index < 0 else input_index
	var target_kind := target_kind_for_input(resolved_index)
	if not TARGET_DEFINITIONS.has(target_kind):
		return &""
	return StringName(TARGET_DEFINITIONS[target_kind]["monster_id"])


func connected_material_kind(input_index: int = -1) -> StringName:
	return glyph_primitive_kind(connected_glyph(input_index))


func connected_glyph(input_index: int = -1) -> GlyphModel:
	var resolved_index := selected_input_index if input_index < 0 else input_index
	if resolved_index < 0 or resolved_index >= SUMMONER_INPUT_COUNT:
		return null
	if factory_graph == null or summoner_node == null:
		return null
	for connection in factory_graph.get_connection_list():
		if StringName(connection["to_node"]) != StringName(summoner_node.name):
			continue
		if int(connection["to_port"]) != resolved_index:
			continue
		return output_glyph(StringName(connection["from_node"]))
	return null


func primitive_glyph(primitive_id: StringName) -> GlyphModel:
	if primitive_id == &"":
		return null
	return GlyphModelScript.new([
		GlyphComponentModelScript.new(primitive_id),
	])


func glyph_primitive_kind(glyph: GlyphModel) -> StringName:
	if (
		glyph == null
		or not glyph.combine_children.is_empty()
		or glyph.components.size() != 1
		or not glyph.components[0] is GlyphComponentModel
	):
		return &""
	return StringName(glyph.components[0].primitive_id)


func glyph_matches_target(glyph: GlyphModel, input_index: int) -> bool:
	var target_glyph := target_glyph_for_input(input_index)
	return (
		glyph != null
		and target_glyph != null
		and glyph.canonical_serialization() == target_glyph.canonical_serialization()
	)


func output_glyph_kind(node_id: StringName) -> StringName:
	return glyph_primitive_kind(output_glyph(node_id))


func output_glyph(node_id: StringName) -> GlyphModel:
	return _output_glyph(node_id, {})


func rotation_angle(node_id: StringName) -> int:
	var rotation := _rotation_node(node_id)
	return int(rotation.get_meta("rotation_degrees", 45)) if rotation != null else 0


func set_rotation_angle(node_id: StringName, angle_degrees: int) -> bool:
	var rotation := _rotation_node(node_id)
	if rotation == null:
		return false
	var normalized_angle := posmod(angle_degrees, 360)
	if rotation_angle(node_id) == normalized_angle:
		return false
	var now := flow_animation_time_seconds()
	process_transport_at(now)
	rotation.set_meta("rotation_degrees", normalized_angle)
	var visual := _landmark_visual(rotation)
	if visual != null:
		visual.configure_rotation(normalized_angle)
	rotation.tooltip_text = _rotation_tooltip(node_id)
	_restart_outgoing_transport(node_id, now)
	_refresh_summon_state()
	return true


func open_rotation_settings(node_id: StringName, viewport_position: Vector2) -> bool:
	var rotation := _rotation_node(node_id)
	if rotation == null or rotation_settings_popup == null or rotation_settings_angle == null:
		return false
	if line_settings_popup != null:
		line_settings_popup.hide()
	rotation_settings_node_id = node_id
	rotation_settings_title.text = "回転ノード // %s" % String(node_id)
	rotation_settings_syncing = true
	rotation_settings_angle.set_value_no_signal(rotation_angle(node_id))
	rotation_settings_syncing = false
	var popup_size := Vector2i(252, 132)
	var viewport_size := Vector2i(get_viewport_rect().size)
	var popup_position := Vector2i(viewport_position.round()) + Vector2i(10, 8)
	popup_position.x = clampi(popup_position.x, 0, maxi(viewport_size.x - popup_size.x, 0))
	popup_position.y = clampi(popup_position.y, 0, maxi(viewport_size.y - popup_size.y, 0))
	rotation_settings_popup.popup(Rect2i(popup_position, popup_size))
	rotation_settings_angle.get_line_edit().grab_focus()
	rotation_settings_angle.get_line_edit().select_all()
	return true


func open_line_settings(connection: Dictionary, viewport_position: Vector2) -> bool:
	if line_settings_popup == null or factory_graph == null or connection.is_empty():
		return false
	var from_node_id := StringName(connection.get("from_node", &""))
	var from_port := int(connection.get("from_port", 0))
	var to_node_id := StringName(connection.get("to_node", &""))
	var to_port := int(connection.get("to_port", -1))
	if (
		from_node_id == &""
		or to_node_id == &""
		or to_port < 0
		or not factory_graph.is_node_connected(from_node_id, from_port, to_node_id, to_port)
	):
		return false
	if rotation_settings_popup != null:
		rotation_settings_popup.hide()
	line_settings_connection = {
		"from_node": from_node_id,
		"from_port": from_port,
		"to_node": to_node_id,
		"to_port": to_port,
	}
	line_settings_title.text = "搬送路 // %s → %s" % [
		_context_node_label(from_node_id),
		_context_node_label(to_node_id, to_port),
	]
	var line_length := connection_world_length(from_node_id, to_node_id, to_port)
	line_settings_details.text = "距離 %.0f\n初回 %.1fs // 間隔 %.1fs" % [
		line_length,
		flow_travel_duration(line_length),
		flow_packet_interval(),
	]
	var popup_size := Vector2i(292, 174)
	var viewport_size := Vector2i(get_viewport_rect().size)
	var popup_position := Vector2i(viewport_position.round()) + Vector2i(10, 8)
	popup_position.x = clampi(popup_position.x, 0, maxi(viewport_size.x - popup_size.x, 0))
	popup_position.y = clampi(popup_position.y, 0, maxi(viewport_size.y - popup_size.y, 0))
	line_settings_popup.popup(Rect2i(popup_position, popup_size))
	line_settings_delete_button.grab_focus()
	return true


func _connection_to_input(to_node_id: StringName, to_port: int) -> Dictionary:
	if factory_graph == null:
		return {}
	for connection in factory_graph.get_connection_list():
		if (
			StringName(connection["to_node"]) == to_node_id
			and int(connection["to_port"]) == to_port
		):
			return connection.duplicate()
	return {}


func _restart_outgoing_transport(node_id: StringName, time_seconds: float) -> void:
	for connection in factory_graph.get_connection_list():
		if StringName(connection["from_node"]) != node_id:
			continue
		var to_node_id := StringName(connection["to_node"])
		var to_port := int(connection["to_port"])
		connection_flow_started_at[_connection_flow_key(
			node_id,
			int(connection["from_port"]),
			to_node_id,
			to_port
		)] = time_seconds
		_reset_downstream_transport_state(to_node_id, to_port)


func _output_glyph(node_id: StringName, visited: Dictionary) -> GlyphModel:
	if visited.has(node_id):
		return null
	visited[node_id] = true
	var material := _material_node(node_id)
	if material != null:
		return primitive_glyph(StringName(material.get_meta("landmark_kind", &"")))
	var relay := _relay_node(node_id)
	var rotation := _rotation_node(node_id)
	if relay == null and rotation == null:
		return null
	for connection in factory_graph.get_connection_list():
		if StringName(connection["to_node"]) != node_id or int(connection["to_port"]) != 0:
			continue
		var input_glyph := _output_glyph(StringName(connection["from_node"]), visited)
		if input_glyph == null:
			return null
		if rotation != null:
			return input_glyph.rotated_degrees(
				int(rotation.get_meta("rotation_degrees", 45))
			)
		return input_glyph
	return null


func summon_state(input_index: int = -1) -> StringName:
	var resolved_index := selected_input_index if input_index < 0 else input_index
	var glyph := connected_glyph(resolved_index)
	if glyph == null:
		return &"idle"
	if flow_arrival_cycle(resolved_index, flow_animation_time_seconds()) < 0:
		return &"transporting"
	return &"matched" if glyph_matches_target(glyph, resolved_index) else &"mismatch"


func summoning_monsters() -> Array[StringName]:
	var result: Array[StringName] = []
	for input_index in SUMMONER_INPUT_COUNT:
		if summon_state(input_index) == &"matched":
			result.append(target_monster_id(input_index))
	return result


func summoned_monster_count(monster_id: StringName) -> int:
	return int(summoned_monster_counts.get(monster_id, 0))


func summon_event_count() -> int:
	return summon_events.size()


func process_transport_at(time_seconds: float) -> void:
	var state_changed := false
	for input_index in SUMMONER_INPUT_COUNT:
		var glyph := connected_glyph(input_index)
		if glyph == null:
			if flow_arrival_cycles[input_index] != -1:
				state_changed = true
			flow_arrival_cycles[input_index] = -1
			continue
		var arrival_cycle := flow_arrival_cycle(input_index, time_seconds)
		if arrival_cycle < 0:
			continue
		var previous_cycle := flow_arrival_cycles[input_index]
		if arrival_cycle <= previous_cycle:
			continue
		_record_summoner_arrivals(
			input_index,
			previous_cycle + 1,
			arrival_cycle,
			glyph
		)
		flow_arrival_cycles[input_index] = arrival_cycle
		state_changed = true
		if flow_audio != null and glyph_matches_target(glyph, input_index):
			flow_audio.play_arrival(glyph_primitive_kind(target_glyph_for_input(input_index)))
	if state_changed:
		_refresh_summon_state()


func _record_summoner_arrivals(
	input_index: int,
	first_cycle: int,
	last_cycle: int,
	glyph: GlyphModel
) -> void:
	if glyph == null or last_cycle < first_cycle:
		return
	var target_kind := target_kind_for_input(input_index)
	var material_kind := glyph_primitive_kind(glyph)
	var matched := glyph_matches_target(glyph, input_index)
	var canonical_glyph := glyph.canonical_serialization()
	var arrival_count := last_cycle - first_cycle + 1
	var monster_id := target_monster_id(input_index) if matched else StringName()
	if matched:
		summoned_monster_counts[monster_id] = summoned_monster_count(monster_id) + arrival_count
	var retained_first_cycle := maxi(
		first_cycle,
		last_cycle - SUMMON_EVENT_HISTORY_LIMIT + 1
	)
	for arrival_cycle in range(retained_first_cycle, last_cycle + 1):
		summon_events.append({
			"input_index": input_index,
			"arrival_cycle": arrival_cycle,
			"arrival_time": summoner_arrival_time(input_index, arrival_cycle),
			"glyph": glyph.copy(),
			"canonical_glyph": canonical_glyph,
			"glyph_kind": material_kind,
			"target_kind": target_kind,
			"matched": matched,
			"monster_id": monster_id,
		})
	while summon_events.size() > SUMMON_EVENT_HISTORY_LIMIT:
		summon_events.pop_front()


func connect_material_to_summoner(material_node_id: StringName, input_index: int = -1) -> bool:
	var resolved_index := selected_input_index if input_index < 0 else input_index
	if _material_node(material_node_id) == null or summoner_node == null:
		return false
	return connect_output_to_input(
		material_node_id,
		StringName(summoner_node.name),
		resolved_index
	)


func connect_output_to_input(from_node_id: StringName, to_node_id: StringName, to_port: int = 0) -> bool:
	if not _valid_output_node(from_node_id) or not _valid_input_port(to_node_id, to_port):
		return false
	if from_node_id == to_node_id or _would_create_connection_cycle(from_node_id, to_node_id):
		status_label.text = "循環する配線は接続できません"
		status_label.add_theme_color_override("font_color", Color(0.96, 0.62, 0.40))
		return false
	if factory_graph.is_node_connected(from_node_id, 0, to_node_id, to_port):
		_clear_directional_connection_preview()
		return true
	process_transport_at(flow_animation_time_seconds())
	_remove_input_connection(to_node_id, to_port)
	var error := factory_graph.connect_node(from_node_id, 0, to_node_id, to_port, true)
	if error != OK:
		_refresh_summon_state()
		return false
	connection_flow_started_at[_connection_flow_key(from_node_id, 0, to_node_id, to_port)] = (
		flow_animation_time_seconds()
	)
	_reset_downstream_transport_state(to_node_id, to_port)
	_clear_directional_connection_preview()
	_refresh_summon_state()
	if flow_audio != null:
		var matched := (
			summoner_node == null
			or to_node_id != StringName(summoner_node.name)
			or glyph_matches_target(output_glyph(from_node_id), to_port)
		)
		flow_audio.play_connection(matched)
	return true


func disconnect_summoner(input_index: int = -1) -> void:
	var resolved_index := selected_input_index if input_index < 0 else input_index
	if summoner_node == null:
		return
	disconnect_input(StringName(summoner_node.name), resolved_index)


func disconnect_input(to_node_id: StringName, to_port: int = 0) -> void:
	process_transport_at(flow_animation_time_seconds())
	var removed := _remove_input_connection(to_node_id, to_port)
	if removed:
		hovered_connection_key = ""
		_reset_downstream_transport_state(to_node_id, to_port)
		if flow_audio != null:
			flow_audio.play_disconnect()
	_refresh_summon_state()


func _reset_downstream_transport_state(start_node_id: StringName, start_port: int) -> void:
	if summoner_node == null:
		return
	var summoner_id := StringName(summoner_node.name)
	if start_node_id == summoner_id:
		if start_port >= 0 and start_port < flow_arrival_cycles.size():
			flow_arrival_cycles[start_port] = -1
		return
	var pending: Array[StringName] = [start_node_id]
	var visited: Dictionary = {}
	while not pending.is_empty():
		var node_id: StringName = pending.pop_front()
		if visited.has(node_id):
			continue
		visited[node_id] = true
		for connection in factory_graph.get_connection_list():
			if StringName(connection["from_node"]) != node_id:
				continue
			var to_node_id := StringName(connection["to_node"])
			if to_node_id == summoner_id:
				var to_port := int(connection["to_port"])
				if to_port >= 0 and to_port < flow_arrival_cycles.size():
					flow_arrival_cycles[to_port] = -1
				continue
			pending.append(to_node_id)


func _on_connection_request(
	from_node: StringName,
	from_port: int,
	to_node: StringName,
	to_port: int
) -> void:
	if from_port != 0 or not _valid_output_node(from_node) or not _valid_input_port(to_node, to_port):
		summon_state_label.text = "出力ポートから加工入力または召喚器入力へ接続"
		summon_state_label.add_theme_color_override("font_color", Color(0.96, 0.62, 0.40))
		return
	connect_output_to_input(from_node, to_node, to_port)


func _on_disconnection_request(
	from_node: StringName,
	from_port: int,
	to_node: StringName,
	to_port: int
) -> void:
	if factory_graph.is_node_connected(from_node, from_port, to_node, to_port):
		disconnect_input(to_node, to_port)


func _on_factory_graph_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		connection_pointer = event.position
		var target := directional_connection_target_at(event.position)
		hovered_input_node_id = StringName(target.get("node_id", &""))
		hovered_input_index = (
			int(target.get("port", -1))
			if summoner_node != null and hovered_input_node_id == StringName(summoner_node.name)
			else -1
		)
		hovered_material_id = directional_output_at(event.position)
		var hovered_connection := (
			directional_connection_at(event.position)
			if hovered_input_node_id == &"" and hovered_material_id == &""
			else {}
		)
		hovered_connection_key = String(hovered_connection.get("key", ""))
		if relay_placement_active or rotation_placement_active:
			factory_graph.mouse_default_cursor_shape = Control.CURSOR_CROSS
			factory_graph.tooltip_text = (
				"クリックで回転ノードを配置 // 右クリックで取消"
				if rotation_placement_active
				else "クリックで中継ノードを配置 // 右クリックで取消"
			)
		elif hovered_input_node_id != &"":
			factory_graph.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			factory_graph.tooltip_text = (
				"INPUT %d // 左クリックで目標表示 // 右クリックで搬送路メニュー" % (hovered_input_index + 1)
				if hovered_input_index >= 0
				else "加工入力 // 出力から接続 // 右クリックで搬送路メニュー"
			)
		elif hovered_material_id != &"":
			factory_graph.mouse_default_cursor_shape = Control.CURSOR_CROSS
			factory_graph.tooltip_text = _output_tooltip(hovered_material_id)
		elif not hovered_connection.is_empty():
			factory_graph.mouse_default_cursor_shape = Control.CURSOR_HELP
			factory_graph.tooltip_text = _connection_tooltip(hovered_connection)
		else:
			var landmark := directional_landmark_at(event.position)
			factory_graph.mouse_default_cursor_shape = Control.CURSOR_HELP if landmark != &"" else Control.CURSOR_ARROW
			factory_graph.tooltip_text = _landmark_tooltip(landmark)
		if connecting_material_id != &"" and event.position.distance_to(connection_press_position) > 4.0:
			connection_drag_moved = true
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
		if relay_placement_active or rotation_placement_active:
			cancel_relay_placement()
			cancel_rotation_placement()
			factory_graph.accept_event()
			return
		var input_target := directional_connection_target_at(mouse_event.position)
		if not input_target.is_empty():
			var input_node := StringName(input_target["node_id"])
			var input_port := int(input_target["port"])
			if summoner_node != null and input_node == StringName(summoner_node.name):
				select_input(input_port)
			var input_connection := _connection_to_input(input_node, input_port)
			if not input_connection.is_empty():
				open_line_settings(input_connection, mouse_event.global_position)
			factory_graph.accept_event()
			return
		var line_connection := directional_connection_at(mouse_event.position)
		if not line_connection.is_empty():
			open_line_settings(line_connection, mouse_event.global_position)
			factory_graph.accept_event()
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	connection_pointer = mouse_event.position
	if mouse_event.pressed:
		if relay_placement_active or rotation_placement_active:
			var world_position := graph_screen_to_world(mouse_event.position)
			if rotation_placement_active:
				place_rotation_at(world_position)
			else:
				place_relay_at(world_position)
			cancel_relay_placement()
			cancel_rotation_placement()
			factory_graph.accept_event()
			return
		var input_target := directional_connection_target_at(mouse_event.position)
		if not input_target.is_empty():
			var input_node_id := StringName(input_target["node_id"])
			var input_port := int(input_target["port"])
			if summoner_node != null and input_node_id == StringName(summoner_node.name):
				select_input(input_port)
			if connecting_material_id != &"":
				connect_output_to_input(connecting_material_id, input_node_id, input_port)
			factory_graph.accept_event()
			return
		var material_id := directional_output_at(mouse_event.position)
		if material_id != &"":
			connecting_material_id = material_id
			connection_press_position = mouse_event.position
			connection_drag_moved = false
			summon_state_label.text = "接続先の加工入力または召喚器入力を選択"
			summon_state_label.add_theme_color_override("font_color", Color(0.58, 0.86, 1.0))
			factory_graph.accept_event()
			return
		if connecting_material_id != &"":
			_clear_directional_connection_preview()
			_refresh_summon_state()
		return
	if connecting_material_id == &"":
		return
	var release_target := directional_connection_target_at(mouse_event.position)
	if not release_target.is_empty():
		var release_node := StringName(release_target["node_id"])
		var release_port := int(release_target["port"])
		if summoner_node != null and release_node == StringName(summoner_node.name):
			select_input(release_port)
		connect_output_to_input(connecting_material_id, release_node, release_port)
		factory_graph.accept_event()
		return
	if connection_drag_moved:
		_clear_directional_connection_preview()
		_refresh_summon_state()
		factory_graph.accept_event()


func _on_factory_graph_mouse_exited() -> void:
	hovered_material_id = &""
	hovered_input_node_id = &""
	hovered_input_index = -1
	hovered_connection_key = ""
	if factory_graph != null:
		factory_graph.tooltip_text = ""
		factory_graph.mouse_default_cursor_shape = Control.CURSOR_ARROW


func _clear_directional_connection_preview() -> void:
	connecting_material_id = &""
	connection_drag_moved = false


func directional_output_at(graph_position: Vector2) -> StringName:
	for node in material_nodes + relay_nodes + rotation_nodes:
		var node_id := StringName(node.name)
		if graph_position.distance_to(directional_output_position(node_id, factory_graph)) <= PORT_HIT_RADIUS:
			return node_id
	return &""


func directional_connection_target_at(graph_position: Vector2) -> Dictionary:
	for processor in relay_nodes + rotation_nodes:
		var processor_id := StringName(processor.name)
		if graph_position.distance_to(directional_node_input_position(processor_id, 0, factory_graph)) <= PORT_HIT_RADIUS:
			return { "node_id": processor_id, "port": 0 }
	if summoner_node != null:
		for input_index in SUMMONER_INPUT_COUNT:
			if graph_position.distance_to(directional_input_position(input_index, factory_graph)) <= PORT_HIT_RADIUS:
				return { "node_id": StringName(summoner_node.name), "port": input_index }
	return {}


func directional_connection_at(graph_position: Vector2) -> Dictionary:
	if factory_graph == null:
		return {}
	var closest: Dictionary = {}
	var closest_distance := INF
	for connection in factory_graph.get_connection_list():
		var from_node_id := StringName(connection["from_node"])
		var to_node_id := StringName(connection["to_node"])
		var to_port := int(connection["to_port"])
		var start := directional_output_position(from_node_id, factory_graph)
		var finish := directional_node_input_position(to_node_id, to_port, factory_graph)
		var closest_point := Geometry2D.get_closest_point_to_segment(
			graph_position,
			start,
			finish
		)
		var distance := graph_position.distance_to(closest_point)
		if distance > CONNECTION_HIT_RADIUS or distance >= closest_distance:
			continue
		closest_distance = distance
		closest = connection.duplicate()
		closest["key"] = _connection_flow_key(
			from_node_id,
			int(connection["from_port"]),
			to_node_id,
			to_port
		)
		closest["distance_to_line"] = distance
	return closest


func directional_input_at(graph_position: Vector2) -> int:
	for input_index in SUMMONER_INPUT_COUNT:
		if graph_position.distance_to(directional_input_position(input_index, factory_graph)) <= PORT_HIT_RADIUS:
			return input_index
	return -1


func directional_landmark_at(graph_position: Vector2) -> StringName:
	for node in material_nodes + relay_nodes + rotation_nodes:
		if graph_position.distance_to(_node_center_in(node, factory_graph)) <= _landmark_radius_in(node, factory_graph):
			return StringName(node.name)
	if (
		summoner_node != null
		and graph_position.distance_to(_node_center_in(summoner_node, factory_graph))
		<= _landmark_radius_in(summoner_node, factory_graph)
	):
		return StringName(summoner_node.name)
	return &""


func _landmark_tooltip(node_id: StringName) -> String:
	if node_id == &"":
		return ""
	if summoner_node != null and node_id == StringName(summoner_node.name):
		return "召喚器 // 3入力 // 固定 // 入力ポートをクリックして目標表示"
	var material := _material_node(node_id)
	if material != null:
		return "%s資源パッチ // 固定 // 出力を接続" % _kind_label(
			StringName(material.get_meta("landmark_kind", &""))
		)
	if _relay_node(node_id) != null:
		return "中継ノード // グリフを変えずに転送 // ドラッグ移動"
	if _rotation_node(node_id) != null:
		return _rotation_tooltip(node_id)
	return ""


func _output_tooltip(node_id: StringName) -> String:
	var material := _material_node(node_id)
	if material != null:
		return "%s資源パッチ // 固定 // 出力を接続" % _kind_label(
			StringName(material.get_meta("landmark_kind", &""))
		)
	if _relay_node(node_id) != null:
		return "中継出力 // 複数の下流へ分配可能"
	if _rotation_node(node_id) != null:
		return "回転出力 // %d°加工済み // 複数の下流へ分配可能" % rotation_angle(node_id)
	return ""


func _rotation_tooltip(node_id: StringName) -> String:
	return "回転ノード // %d° // 右クリックで設定" % rotation_angle(node_id)


func _context_node_label(node_id: StringName, input_port: int = -1) -> String:
	if summoner_node != null and node_id == StringName(summoner_node.name):
		return "召喚器 INPUT %d" % (input_port + 1)
	var material := _material_node(node_id)
	if material != null:
		return "%s資源" % _shape_symbol(StringName(material.get_meta("landmark_kind", &"")))
	if _relay_node(node_id) != null:
		return "中継"
	if _rotation_node(node_id) != null:
		return "回転 %d°" % rotation_angle(node_id)
	return String(node_id)


func _connection_tooltip(connection: Dictionary) -> String:
	if connection.is_empty():
		return ""
	var from_node_id := StringName(connection.get("from_node", &""))
	var to_node_id := StringName(connection.get("to_node", &""))
	var to_port := int(connection.get("to_port", -1))
	if from_node_id == &"" or to_node_id == &"" or to_port < 0:
		return ""
	var line_length := connection_world_length(from_node_id, to_node_id, to_port)
	return "搬送路 // 距離 %.0f // 初回 %.1fs // 間隔 %.1fs // 右クリックでメニュー" % [
		line_length,
		flow_travel_duration(line_length),
		flow_packet_interval(),
	]


func directional_output_position(node_id: StringName, coordinate_space: Control) -> Vector2:
	var source := _factory_node(node_id)
	if source == null or summoner_node == null or coordinate_space == null:
		return Vector2.ZERO
	var source_center := _node_center_in(source, coordinate_space)
	var direction_sum := Vector2.ZERO
	for connection in factory_graph.get_connection_list():
		if StringName(connection["from_node"]) != node_id:
			continue
		var downstream := _factory_node(StringName(connection["to_node"]))
		if downstream != null:
			direction_sum += source_center.direction_to(_node_center_in(downstream, coordinate_space))
	var direction := direction_sum.normalized()
	if direction.is_zero_approx():
		direction = source_center.direction_to(_node_center_in(summoner_node, coordinate_space))
	return _node_boundary_position(source, direction, coordinate_space)


func directional_input_position(input_index: int, coordinate_space: Control) -> Vector2:
	if (
		input_index < 0
		or input_index >= SUMMONER_INPUT_COUNT
		or summoner_node == null
		or coordinate_space == null
	):
		return Vector2.ZERO
	var direction := _summoner_input_direction(input_index, coordinate_space)
	return _node_boundary_position(summoner_node, direction, coordinate_space)


func directional_node_input_position(node_id: StringName, input_port: int, coordinate_space: Control) -> Vector2:
	if summoner_node != null and node_id == StringName(summoner_node.name):
		return directional_input_position(input_port, coordinate_space)
	var processor := _processing_node(node_id)
	if processor == null or input_port != 0 or coordinate_space == null:
		return Vector2.ZERO
	return _node_boundary_position(
		processor,
		_processing_input_direction(node_id, coordinate_space),
		coordinate_space
	)


func connection_world_length(from_node_id: StringName, to_node_id: StringName, input_port: int) -> float:
	if factory_graph == null:
		return 0.0
	var start := directional_output_position(from_node_id, factory_graph)
	var finish := directional_node_input_position(to_node_id, input_port, factory_graph)
	var safe_zoom := maxf(factory_graph.zoom, 0.001)
	return start.distance_to(finish) / safe_zoom


func directional_port_direction(node_id: StringName, port_kind: StringName, input_index: int = -1) -> Vector2:
	var node: GraphNode = _factory_node(node_id)
	if node == null:
		return Vector2.ZERO
	var point := (
		directional_node_input_position(node_id, input_index, factory_graph)
		if port_kind == &"input"
		else directional_output_position(node_id, factory_graph)
	)
	return _node_center_in(node, factory_graph).direction_to(point)


func draw_directional_overlay(overlay: Control, layer: StringName) -> void:
	if factory_graph == null or summoner_node == null:
		return
	if layer == &"connections":
		_draw_directional_connection_lines(overlay)
		return
	if layer == &"flow":
		_draw_directional_flow_effects(overlay)
		return
	_draw_directional_ports(overlay)


func _draw_directional_connection_lines(overlay: Control) -> void:
	for connection in factory_graph.get_connection_list():
		var from_node_id := StringName(connection["from_node"])
		var to_node_id := StringName(connection["to_node"])
		var input_index := int(connection["to_port"])
		var start := directional_output_position(from_node_id, overlay)
		var finish := directional_node_input_position(to_node_id, input_index, overlay)
		var color := PORT_COLOR
		if summoner_node != null and to_node_id == StringName(summoner_node.name):
			match summon_state(input_index):
				&"matched":
					color = Color(0.34, 0.86, 0.76, 0.96)
				&"mismatch":
					color = Color(0.96, 0.62, 0.34, 0.96)
		var connection_key := _connection_flow_key(
			from_node_id,
			int(connection["from_port"]),
			to_node_id,
			input_index
		)
		if connection_key == hovered_connection_key:
			_draw_connection_curve(
				overlay,
				start,
				finish,
				Color(0.60, 0.90, 1.0, 0.28),
				8.0
			)
		_draw_connection_curve(overlay, start, finish, color, 3.0)
	if connecting_material_id != &"":
		var preview_start: Vector2 = directional_output_position(connecting_material_id, overlay)
		var preview_finish: Vector2 = _convert_control_point(factory_graph, connection_pointer, overlay)
		_draw_connection_curve(overlay, preview_start, preview_finish, Color(0.42, 0.82, 1.0, 0.72), 2.0)


func _draw_directional_flow_effects(overlay: Control) -> void:
	var now := flow_animation_time_seconds()
	for connection in factory_graph.get_connection_list():
		var from_node_id := StringName(connection["from_node"])
		var to_node_id := StringName(connection["to_node"])
		var input_index := int(connection["to_port"])
		var start := directional_output_position(from_node_id, overlay)
		var finish := directional_node_input_position(to_node_id, input_index, overlay)
		var line_length := connection_world_length(from_node_id, to_node_id, input_index)
		var flow_start_time := connection_flow_start_time(
			from_node_id,
			to_node_id,
			input_index
		)
		var color := PORT_COLOR
		if summoner_node != null and to_node_id == StringName(summoner_node.name):
			match summon_state(input_index):
				&"matched":
					color = Color(0.34, 0.86, 0.76, 0.96)
				&"mismatch":
					color = Color(0.96, 0.62, 0.34, 0.96)
		var packets := transport_packets_for_connection(
			from_node_id,
			to_node_id,
			input_index,
			now
		)
		if output_glyph(from_node_id) != null:
			_draw_flowing_glyphs(
				overlay,
				start,
				finish,
				packets,
				color,
				now,
				line_length,
				flow_start_time
			)


func _draw_directional_ports(overlay: Control) -> void:
	for node in material_nodes + relay_nodes + rotation_nodes:
		var node_id := StringName(node.name)
		var position := directional_output_position(node_id, overlay)
		var active := node_id == connecting_material_id or node_id == hovered_material_id
		var direction := _node_center_in(node, overlay).direction_to(position)
		_draw_output_port(overlay, position, direction, PORT_COLOR if active else PORT_IDLE_COLOR, active)
	for processor in relay_nodes + rotation_nodes:
		var processor_id := StringName(processor.name)
		var processor_input := directional_node_input_position(processor_id, 0, overlay)
		var processor_active := hovered_input_node_id == processor_id or connecting_material_id != &""
		_draw_input_port(overlay, processor_input, PORT_COLOR if processor_active else PORT_IDLE_COLOR)
	for input_index in SUMMONER_INPUT_COUNT:
		var position := directional_input_position(input_index, overlay)
		var state := summon_state(input_index)
		var color := PORT_IDLE_COLOR
		if state == &"matched":
			color = Color(0.34, 0.86, 0.76, 1.0)
		elif state == &"mismatch":
			color = Color(0.96, 0.62, 0.34, 1.0)
		elif connecting_material_id != &"":
			color = PORT_COLOR
		_draw_input_port(overlay, position, color)
		var inward := position.direction_to(_node_center_in(summoner_node, overlay))
		_draw_input_target_marker(
			overlay,
			position + inward * 14.0,
			target_kind_for_input(input_index),
			color
		)
		if input_index == hovered_input_index:
			overlay.draw_arc(position, PORT_DRAW_RADIUS + 6.0, 0.0, TAU, 20, Color(0.38, 0.80, 1.0, 0.76), 1.0, true)
		if input_index == selected_input_index:
			overlay.draw_arc(position, PORT_DRAW_RADIUS + 4.0, 0.0, TAU, 20, Color(0.70, 0.92, 1.0, 0.9), 1.2, true)


func _draw_output_port(
	overlay: Control,
	position: Vector2,
	direction: Vector2,
	color: Color,
	active: bool
) -> void:
	var safe_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	var tangent := Vector2(-safe_direction.y, safe_direction.x)
	var radius := PORT_DRAW_RADIUS + (1.5 if active else 0.0)
	var points := PackedVector2Array([
		position + safe_direction * radius,
		position + tangent * radius,
		position - safe_direction * radius,
		position - tangent * radius,
	])
	overlay.draw_colored_polygon(points, color)
	overlay.draw_polyline(points + PackedVector2Array([points[0]]), Color(0.78, 0.94, 1.0, 0.92), 1.0, true)


func _draw_input_port(overlay: Control, position: Vector2, color: Color) -> void:
	overlay.draw_circle(position, PORT_DRAW_RADIUS + 2.0, Color(0.01, 0.05, 0.08, 0.96), true)
	overlay.draw_arc(position, PORT_DRAW_RADIUS, 0.0, TAU, 20, color, 2.0, true)


func _draw_input_target_marker(
	overlay: Control,
	position: Vector2,
	target_kind: StringName,
	color: Color
) -> void:
	var radius := 3.5
	match target_kind:
		&"circle":
			overlay.draw_arc(position, radius, 0.0, TAU, 16, color, 1.1, true)
		&"triangle":
			var points := PackedVector2Array()
			for index in 3:
				points.append(position + Vector2.from_angle(-PI * 0.5 + TAU * float(index) / 3.0) * radius)
			points.append(points[0])
			overlay.draw_polyline(points, color, 1.1, true)
		&"square":
			overlay.draw_rect(Rect2(position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), color, false, 1.1, true)
		&"diamond":
			var points := PackedVector2Array([
				position + Vector2(0.0, -radius * 1.35),
				position + Vector2(radius * 1.35, 0.0),
				position + Vector2(0.0, radius * 1.35),
				position + Vector2(-radius * 1.35, 0.0),
				position + Vector2(0.0, -radius * 1.35),
			])
			overlay.draw_polyline(points, color, 1.1, true)


func _draw_connection_curve(
	overlay: Control,
	start: Vector2,
	finish: Vector2,
	color: Color,
	width: float
) -> void:
	var points := PackedVector2Array()
	for index in 25:
		points.append(connection_curve_point(start, finish, float(index) / 24.0))
	overlay.draw_polyline(points, color, width, true)


func _draw_flowing_glyphs(
	overlay: Control,
	start: Vector2,
	finish: Vector2,
	packets: Array[Dictionary],
	color: Color,
	time_seconds: float,
	line_length: float,
	flow_start_time: float
) -> void:
	var screen_length := maxf(start.distance_to(finish), 1.0)
	var trail_progress := FLOW_TRAIL_SCREEN_LENGTH / screen_length
	for packet in packets:
		var progress := float(packet["progress"])
		var glyph_value = packet.get("glyph")
		if not glyph_value is GlyphModel:
			continue
		var glyph: GlyphModel = glyph_value
		var position := connection_curve_point(start, finish, progress)
		var previous := connection_curve_point(
			start,
			finish,
			maxf(progress - trail_progress, FLOW_PATH_START)
		)
		var direction := previous.direction_to(position)
		overlay.draw_line(previous, position, Color(color, 0.34), 2.0, true)
		for mote_index in 2:
			var mote_progress := maxf(
				progress - trail_progress * 0.45 * float(mote_index + 1),
				FLOW_PATH_START
			)
			var mote := connection_curve_point(start, finish, mote_progress)
			overlay.draw_circle(mote, 1.7 - float(mote_index) * 0.45, Color(color, 0.34), true)
		_draw_transport_glyph(overlay, position, glyph, color, direction)
	var arrival := flow_connection_arrival_progress(
		line_length,
		flow_start_time,
		time_seconds
	)
	if arrival >= 0.0:
		overlay.draw_arc(
			finish,
			7.0 + arrival * 17.0,
			0.0,
			TAU,
			28,
			Color(color, (1.0 - arrival) * 0.72),
			1.8,
			true
		)


func _draw_transport_glyph(
	overlay: Control,
	position: Vector2,
	glyph: GlyphModel,
	state_color: Color,
	_direction: Vector2
) -> void:
	overlay.draw_circle(position, 11.0, Color(state_color, 0.10), true)
	overlay.draw_circle(position, 8.0, Color(0.008, 0.035, 0.055, 0.94), true)
	if glyph == null:
		return
	GlyphPainterModel.draw_glyph(
		overlay,
		glyph,
		position,
		GlyphPainterModel.fit_scale(glyph, 5.6, false, 0.16, 1.15),
		1.0,
		false,
		0.9
	)


func connection_curve_point(start: Vector2, finish: Vector2, progress: float) -> Vector2:
	return start.lerp(finish, clampf(progress, 0.0, 1.0))


func conveyor_speed_for_grade(grade: int = DEFAULT_CONVEYOR_GRADE) -> float:
	return float(
		CONVEYOR_SPEED_BY_GRADE.get(
			grade,
			CONVEYOR_SPEED_BY_GRADE[DEFAULT_CONVEYOR_GRADE]
		)
	)


func flow_packet_interval(grade: int = DEFAULT_CONVEYOR_GRADE) -> float:
	return FLOW_GLYPH_SPACING_WORLD_UNITS / conveyor_speed_for_grade(grade)


func flow_travel_duration(
	line_length: float,
	grade: int = DEFAULT_CONVEYOR_GRADE
) -> float:
	var travel_distance := maxf(line_length, 1.0) * (FLOW_PATH_END - FLOW_PATH_START)
	return travel_distance / conveyor_speed_for_grade(grade)


func flow_packet_slot_count(line_length: float) -> int:
	return clampi(
		ceili(maxf(line_length, 1.0) / FLOW_GLYPH_SPACING_WORLD_UNITS) + 1,
		1,
		FLOW_MAX_VISIBLE_GLYPHS
	)


func flow_packet_elapsed(
	flow_start_time: float,
	packet_index: int,
	time_seconds: float,
	grade: int = DEFAULT_CONVEYOR_GRADE
) -> float:
	if is_inf(flow_start_time) or time_seconds < flow_start_time:
		return -1.0
	var interval := flow_packet_interval(grade)
	var active_duration := time_seconds - flow_start_time
	var emitted_packet_count := floori(active_duration / interval) + 1
	if packet_index < 0 or packet_index >= emitted_packet_count:
		return -1.0
	var newest_packet_age := fposmod(active_duration, interval)
	return newest_packet_age + float(packet_index) * interval


func flow_packet_progress(
	line_length: float,
	flow_start_time: float,
	packet_index: int,
	time_seconds: float,
	grade: int = DEFAULT_CONVEYOR_GRADE
) -> float:
	var elapsed := flow_packet_elapsed(flow_start_time, packet_index, time_seconds, grade)
	if elapsed < 0.0:
		return -1.0
	var travel_duration := flow_travel_duration(line_length, grade)
	if elapsed > travel_duration:
		return -1.0
	var travel_progress := clampf(elapsed / travel_duration, 0.0, 1.0)
	return lerpf(FLOW_PATH_START, FLOW_PATH_END, travel_progress)


func flow_connection_arrival_progress(
	line_length: float,
	flow_start_time: float,
	time_seconds: float,
	grade: int = DEFAULT_CONVEYOR_GRADE
) -> float:
	if is_inf(flow_start_time):
		return -1.0
	var arrival_time := flow_start_time + flow_travel_duration(line_length, grade)
	if time_seconds < arrival_time:
		return -1.0
	var elapsed_since_arrival := fposmod(
		time_seconds - arrival_time,
		flow_packet_interval(grade)
	)
	if elapsed_since_arrival > FLOW_ARRIVAL_EFFECT_SECONDS:
		return -1.0
	return clampf(
		elapsed_since_arrival / FLOW_ARRIVAL_EFFECT_SECONDS,
		0.0,
		1.0
	)


func flow_arrival_cycle(
	input_index: int,
	time_seconds: float,
	line_length: float = -1.0,
	flow_start_time: float = -1.0
) -> int:
	var resolved_length := line_length
	var resolved_start_time := maxf(flow_start_time, 0.0)
	if resolved_length <= 0.0:
		var timing := _summoner_input_transport_timing(input_index)
		resolved_length = float(timing.get("line_length", 0.0))
		resolved_start_time = float(timing.get("flow_start_time", INF))
	if resolved_length <= 0.0 or is_inf(resolved_start_time):
		return -1
	var travel_duration := flow_travel_duration(resolved_length)
	if time_seconds < resolved_start_time + travel_duration:
		return -1
	return floori(
		(time_seconds - resolved_start_time - travel_duration)
		/ flow_packet_interval()
	)


func summoner_arrival_time(input_index: int, arrival_cycle: int) -> float:
	if arrival_cycle < 0:
		return INF
	var timing := _summoner_input_transport_timing(input_index)
	var line_length := float(timing.get("line_length", 0.0))
	var flow_start_time := float(timing.get("flow_start_time", INF))
	if line_length <= 0.0 or is_inf(flow_start_time):
		return INF
	return (
		flow_start_time
		+ flow_travel_duration(line_length)
		+ float(arrival_cycle) * flow_packet_interval()
	)


func transport_seconds_until_first_arrival(
	input_index: int,
	time_seconds: float = -1.0
) -> float:
	var resolved_time := flow_animation_time_seconds() if time_seconds < 0.0 else time_seconds
	var first_arrival := summoner_arrival_time(input_index, 0)
	if is_inf(first_arrival):
		return INF
	return maxf(first_arrival - resolved_time, 0.0)


func transport_packets_for_connection(
	from_node_id: StringName,
	to_node_id: StringName,
	to_port: int,
	time_seconds: float = -1.0
) -> Array[Dictionary]:
	var packets: Array[Dictionary] = []
	if factory_graph == null or not factory_graph.is_node_connected(
		from_node_id,
		0,
		to_node_id,
		to_port
	):
		return packets
	var resolved_time := flow_animation_time_seconds() if time_seconds < 0.0 else time_seconds
	var flow_start_time := connection_flow_start_time(from_node_id, to_node_id, to_port)
	if is_inf(flow_start_time) or resolved_time < flow_start_time:
		return packets
	var line_length := connection_world_length(from_node_id, to_node_id, to_port)
	var interval := flow_packet_interval()
	var emitted_count := floori((resolved_time - flow_start_time) / interval) + 1
	var glyph := output_glyph(from_node_id)
	if glyph == null:
		return packets
	var glyph_kind := glyph_primitive_kind(glyph)
	var canonical_glyph := glyph.canonical_serialization()
	for packet_index in flow_packet_slot_count(line_length):
		var progress := flow_packet_progress(
			line_length,
			flow_start_time,
			packet_index,
			resolved_time
		)
		if progress < 0.0:
			continue
		var sequence_index := emitted_count - packet_index - 1
		if sequence_index < 0:
			continue
		var emitted_at := flow_start_time + float(sequence_index) * interval
		packets.append({
			"packet_id": "%s#%d" % [
				_connection_flow_key(from_node_id, 0, to_node_id, to_port),
				sequence_index,
			],
			"sequence_index": sequence_index,
			"glyph": glyph.copy(),
			"canonical_glyph": canonical_glyph,
			"glyph_kind": glyph_kind,
			"emitted_at": emitted_at,
			"arrival_at": emitted_at + flow_travel_duration(line_length),
			"progress": progress,
		})
	return packets


func _summoner_input_transport_timing(input_index: int) -> Dictionary:
	if factory_graph == null or summoner_node == null:
		return {}
	for connection in factory_graph.get_connection_list():
		if (
			StringName(connection["to_node"]) == StringName(summoner_node.name)
			and int(connection["to_port"]) == input_index
		):
			var from_node_id := StringName(connection["from_node"])
			var to_node_id := StringName(connection["to_node"])
			return {
				"line_length": connection_world_length(
					from_node_id,
					to_node_id,
					input_index
				),
				"flow_start_time": connection_flow_start_time(
					from_node_id,
					to_node_id,
					input_index
				),
			}
	return {}


func connection_flow_start_time(
	from_node_id: StringName,
	to_node_id: StringName,
	to_port: int
) -> float:
	return _connection_flow_start_time_from(from_node_id, to_node_id, to_port, {})


func _connection_flow_start_time_from(
	from_node_id: StringName,
	to_node_id: StringName,
	to_port: int,
	visited: Dictionary
) -> float:
	var key := _connection_flow_key(from_node_id, 0, to_node_id, to_port)
	if not connection_flow_started_at.has(key):
		return INF
	var connection_created_at := float(connection_flow_started_at[key])
	if _material_node(from_node_id) != null:
		return connection_created_at
	return _node_next_output_time(from_node_id, connection_created_at, visited)


func _node_next_output_time(
	node_id: StringName,
	not_before_time: float,
	visited: Dictionary
) -> float:
	if _processing_node(node_id) == null or visited.has(node_id):
		return INF
	visited[node_id] = true
	for connection in factory_graph.get_connection_list():
		if StringName(connection["to_node"]) != node_id:
			continue
		var from_node_id := StringName(connection["from_node"])
		var to_port := int(connection["to_port"])
		var segment_start_time := _connection_flow_start_time_from(
			from_node_id,
			node_id,
			to_port,
			visited
		)
		if is_inf(segment_start_time):
			return INF
		var line_length := connection_world_length(
			from_node_id,
			node_id,
			to_port
		)
		var first_arrival := segment_start_time + flow_travel_duration(line_length)
		if not_before_time <= first_arrival:
			return first_arrival
		var elapsed_intervals := (not_before_time - first_arrival) / flow_packet_interval()
		return first_arrival + float(ceili(elapsed_intervals - 0.000001)) * flow_packet_interval()
	return INF


func _connection_flow_key(
	from_node_id: StringName,
	from_port: int,
	to_node_id: StringName,
	to_port: int
) -> String:
	return "%s:%d>%s:%d" % [from_node_id, from_port, to_node_id, to_port]


func flow_animation_time_seconds() -> float:
	if flow_time_override >= 0.0:
		return flow_time_override
	return float(Time.get_ticks_msec()) / 1000.0


func _summoner_input_direction(input_index: int, _coordinate_space: Control) -> Vector2:
	if input_index < 0 or input_index >= SUMMONER_INPUT_COUNT:
		return Vector2.ZERO
	return Vector2.from_angle(
		SUMMONER_INPUT_START_ANGLE
		+ TAU * float(input_index) / float(SUMMONER_INPUT_COUNT)
	)


func _processing_input_direction(node_id: StringName, coordinate_space: Control) -> Vector2:
	var processor := _processing_node(node_id)
	if processor == null:
		return Vector2.LEFT
	var processor_center := _node_center_in(processor, coordinate_space)
	for connection in factory_graph.get_connection_list():
		if StringName(connection["to_node"]) != node_id or int(connection["to_port"]) != 0:
			continue
		var source := _factory_node(StringName(connection["from_node"]))
		if source != null:
			return processor_center.direction_to(_node_center_in(source, coordinate_space))
	if connecting_material_id != &"":
		var active_source := _factory_node(connecting_material_id)
		if active_source != null and StringName(active_source.name) != node_id:
			return processor_center.direction_to(_node_center_in(active_source, coordinate_space))
	return _node_center_in(summoner_node, coordinate_space).direction_to(processor_center)


func _node_boundary_position(node: GraphNode, direction: Vector2, coordinate_space: Control) -> Vector2:
	var visual := _landmark_visual(node)
	if visual != null:
		var visual_size: Vector2 = visual.size
		if visual_size.x <= 0.0 or visual_size.y <= 0.0:
			visual_size = visual.custom_minimum_size
		var visual_center := visual_size * 0.5
		var safe_visual_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
		var radius := maxf(float(visual.body_radius()), 1.0)
		return _convert_control_point(
			visual,
			visual_center + safe_visual_direction * radius,
			coordinate_space
		)
	var local_size := node.size
	if local_size.x <= 0.0 or local_size.y <= 0.0:
		local_size = node.custom_minimum_size
	var center := local_size * 0.5
	var safe_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	var half_extent := Vector2(maxf(center.x - 5.0, 1.0), maxf(center.y - 5.0, 1.0))
	var x_scale := INF if is_zero_approx(safe_direction.x) else half_extent.x / absf(safe_direction.x)
	var y_scale := INF if is_zero_approx(safe_direction.y) else half_extent.y / absf(safe_direction.y)
	var local_position := center + safe_direction * minf(x_scale, y_scale)
	return _convert_control_point(node, local_position, coordinate_space)


func _node_center_in(node: GraphNode, coordinate_space: Control) -> Vector2:
	var visual := _landmark_visual(node)
	if visual != null:
		var visual_size: Vector2 = visual.size
		if visual_size.x <= 0.0 or visual_size.y <= 0.0:
			visual_size = visual.custom_minimum_size
		return _convert_control_point(visual, visual_size * 0.5, coordinate_space)
	var local_size := node.size
	if local_size.x <= 0.0 or local_size.y <= 0.0:
		local_size = node.custom_minimum_size
	return _convert_control_point(node, local_size * 0.5, coordinate_space)


func _convert_control_point(source: Control, local_point: Vector2, destination: Control) -> Vector2:
	var global_point := source.get_global_transform() * local_point
	return destination.get_global_transform().affine_inverse() * global_point


func _landmark_radius_in(node: GraphNode, coordinate_space: Control) -> float:
	var visual := _landmark_visual(node)
	if visual == null:
		return 0.0
	var visual_size: Vector2 = visual.size
	if visual_size.x <= 0.0 or visual_size.y <= 0.0:
		visual_size = visual.custom_minimum_size
	var center := _convert_control_point(visual, visual_size * 0.5, coordinate_space)
	var edge := _convert_control_point(
		visual,
		visual_size * 0.5 + Vector2.RIGHT * float(visual.body_radius()),
		coordinate_space
	)
	return center.distance_to(edge)


func _landmark_visual(node: GraphNode) -> Control:
	for child in node.get_children():
		if child.get_script() == FactoryLandmarkVisualModel:
			return child
	return null


func _remove_input_connection(to_node_id: StringName, to_port: int) -> bool:
	if factory_graph == null or not _valid_input_port(to_node_id, to_port):
		return false
	var removed := false
	for connection in factory_graph.get_connection_list():
		if StringName(connection["to_node"]) != to_node_id:
			continue
		if int(connection["to_port"]) != to_port:
			continue
		connection_flow_started_at.erase(
			_connection_flow_key(
				StringName(connection["from_node"]),
				int(connection["from_port"]),
				StringName(connection["to_node"]),
				int(connection["to_port"])
			)
		)
		factory_graph.disconnect_node(
			StringName(connection["from_node"]),
			int(connection["from_port"]),
			StringName(connection["to_node"]),
			int(connection["to_port"])
		)
		removed = true
	return removed


func _valid_output_node(node_id: StringName) -> bool:
	return _material_node(node_id) != null or _processing_node(node_id) != null


func _valid_input_port(node_id: StringName, input_port: int) -> bool:
	if summoner_node != null and node_id == StringName(summoner_node.name):
		return input_port >= 0 and input_port < SUMMONER_INPUT_COUNT
	return _processing_node(node_id) != null and input_port == 0


func _would_create_connection_cycle(from_node_id: StringName, to_node_id: StringName) -> bool:
	if _processing_node(from_node_id) == null:
		return false
	var pending: Array[StringName] = [to_node_id]
	var visited: Dictionary = {}
	while not pending.is_empty():
		var current: StringName = pending.pop_back()
		if current == from_node_id:
			return true
		if visited.has(current):
			continue
		visited[current] = true
		for connection in factory_graph.get_connection_list():
			if StringName(connection["from_node"]) == current:
				pending.append(StringName(connection["to_node"]))
	return false


func _material_node(node_id: StringName) -> GraphNode:
	for node in material_nodes:
		if StringName(node.name) == node_id:
			return node
	return null


func _relay_node(node_id: StringName) -> GraphNode:
	for node in relay_nodes:
		if is_instance_valid(node) and StringName(node.name) == node_id:
			return node
	return null


func _rotation_node(node_id: StringName) -> GraphNode:
	for node in rotation_nodes:
		if is_instance_valid(node) and StringName(node.name) == node_id:
			return node
	return null


func _processing_node(node_id: StringName) -> GraphNode:
	var relay := _relay_node(node_id)
	return relay if relay != null else _rotation_node(node_id)


func _factory_node(node_id: StringName) -> GraphNode:
	if summoner_node != null and StringName(summoner_node.name) == node_id:
		return summoner_node
	var material := _material_node(node_id)
	if material != null:
		return material
	return _processing_node(node_id)


func _refresh_summon_state() -> void:
	if summon_state_label == null:
		return
	var target_kind := selected_target_kind
	var definition: Dictionary = TARGET_DEFINITIONS[target_kind]
	target_header_label.text = "召喚目標 // INPUT %d" % (selected_input_index + 1)
	target_preview.configure_target(target_kind)
	target_name_label.text = String(definition["monster_name"])
	target_role_label.text = String(definition["role"])
	for kind in target_buttons:
		var button: Button = target_buttons[kind]
		button.set_pressed_no_signal(StringName(kind) == target_kind)
	var state := summon_state(selected_input_index)
	match state:
		&"matched":
			summon_state_label.text = "召喚中 // %s  ×%d" % [
				definition["monster_name"],
				summoned_monster_count(StringName(definition["monster_id"])),
			]
			summon_state_label.add_theme_color_override("font_color", Color(0.48, 0.92, 0.76))
		&"mismatch":
			var connected := connected_glyph(selected_input_index)
			summon_state_label.text = "不一致 // 接続 %s  /  目標 %s" % [
				glyph_symbol(connected),
				definition["glyph_label"],
			]
			summon_state_label.add_theme_color_override("font_color", Color(0.96, 0.68, 0.38))
		&"transporting":
			_set_transporting_state_text(
				connected_glyph(selected_input_index),
				transport_seconds_until_first_arrival(selected_input_index)
			)
			summon_state_label.add_theme_color_override("font_color", Color(0.48, 0.78, 0.94))
		_:
			summon_state_label.text = "%sを召喚器入力へ接続" % definition["glyph_label"]
			summon_state_label.add_theme_color_override("font_color", Color(0.48, 0.70, 0.82))


func _refresh_transport_countdown(time_seconds: float) -> void:
	if summon_state_label == null or summon_state(selected_input_index) != &"transporting":
		return
	_set_transporting_state_text(
		connected_glyph(selected_input_index),
		transport_seconds_until_first_arrival(selected_input_index, time_seconds)
	)


func _set_transporting_state_text(glyph: GlyphModel, seconds_remaining: float) -> void:
	var eta_text := "--"
	if not is_inf(seconds_remaining):
		eta_text = "%.1fs" % seconds_remaining
	summon_state_label.text = "輸送中 // %s → INPUT %d // %s" % [
		glyph_symbol(glyph),
		selected_input_index + 1,
		eta_text,
	]


func _setup_flow_audio() -> void:
	flow_audio = FactoryFlowAudioModel.new()
	flow_audio.name = "FactoryFlowAudio"
	flow_audio.configure()
	add_child(flow_audio)


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
	toolbar.custom_minimum_size.y = 42.0
	toolbar.add_theme_constant_override("separation", 8)
	page.add_child(toolbar)

	var back := Button.new()
	back.name = "BackButton"
	back.text = "← メニュー"
	back.custom_minimum_size = Vector2(112.0, 34.0)
	back.pressed.connect(return_to_menu)
	toolbar.add_child(back)

	relay_button = Button.new()
	relay_button.name = "AddRelayButton"
	relay_button.text = "＋ 中継"
	relay_button.tooltip_text = "中継ノードを盤面へ配置 // グリフを変えずに転送"
	relay_button.custom_minimum_size = Vector2(92.0, 34.0)
	relay_button.toggle_mode = true
	relay_button.pressed.connect(_on_relay_button_pressed)
	toolbar.add_child(relay_button)

	rotation_button = Button.new()
	rotation_button.name = "AddRotationButton"
	rotation_button.text = "＋ 回転"
	rotation_button.tooltip_text = "回転ノードを盤面へ配置 // ノード右クリックで角度設定"
	rotation_button.custom_minimum_size = Vector2(92.0, 34.0)
	rotation_button.toggle_mode = true
	rotation_button.pressed.connect(_on_rotation_button_pressed)
	toolbar.add_child(rotation_button)

	var title := Label.new()
	title.text = "FACTORY PROTOTYPE // 固定素材地帯"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.76, 0.91, 1.0))
	toolbar.add_child(title)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.44, 0.68, 0.78))
	toolbar.add_child(status_label)
	_refresh_factory_status_label()

	var graph_area := Control.new()
	graph_area.name = "FactoryGraphArea"
	graph_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_area.custom_minimum_size = Vector2(900.0, 620.0)
	page.add_child(graph_area)

	factory_graph = GraphEdit.new()
	factory_graph.name = "FactoryGraph"
	factory_graph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	factory_graph.right_disconnects = false
	factory_graph.connection_lines_curvature = 0.12
	# GraphEdit retains topology and emits connection signals, while the directional
	# overlay is the sole visual line renderer. Native line, hover, and rim passes
	# still target hidden rectangular slots and otherwise appear as displaced shadows.
	factory_graph.connection_lines_thickness = 0.0
	factory_graph.connection_lines_antialiased = false
	factory_graph.add_theme_constant_override("connection_hover_thickness", 0)
	factory_graph.add_theme_color_override("connection_hover_tint_color", Color.TRANSPARENT)
	factory_graph.add_theme_color_override("connection_rim_color", Color.TRANSPARENT)
	factory_graph.add_theme_color_override("connection_valid_target_tint_color", Color.TRANSPARENT)
	factory_graph.show_arrange_button = false
	factory_graph.minimap_enabled = true
	factory_graph.zoom = 0.30
	factory_graph.connection_request.connect(_on_connection_request)
	factory_graph.disconnection_request.connect(_on_disconnection_request)
	factory_graph.gui_input.connect(_on_factory_graph_input)
	factory_graph.mouse_exited.connect(_on_factory_graph_mouse_exited)
	graph_area.add_child(factory_graph)
	_configure_graph_hud_occlusion()

	connection_overlay = FactoryDirectionalOverlayModel.new()
	connection_overlay.name = "DirectionalConnectionOverlay"
	connection_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	connection_overlay.configure(self, &"connections")
	factory_graph.add_child(connection_overlay)

	target_panel = _build_target_panel()
	graph_area.add_child(target_panel)

	var footer := Label.new()
	footer.text = "ドラッグ: 盤面移動  /  ホイール: ズーム  /  ミニマップ: 広域確認  /  資源パッチと召喚器は移動不可"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.40, 0.58, 0.66))
	page.add_child(footer)
	_build_rotation_settings_popup()
	_build_line_settings_popup()


func _build_rotation_settings_popup() -> void:
	rotation_settings_popup = PopupPanel.new()
	rotation_settings_popup.name = "RotationSettingsPopup"
	rotation_settings_popup.popup_hide.connect(_on_rotation_settings_popup_hidden)
	add_child(rotation_settings_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	rotation_settings_popup.add_child(margin)

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(220.0, 94.0)
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	rotation_settings_title = Label.new()
	rotation_settings_title.add_theme_font_size_override("font_size", 14)
	rotation_settings_title.add_theme_color_override("font_color", Color(0.72, 0.91, 1.0))
	column.add_child(rotation_settings_title)

	var angle_row := HBoxContainer.new()
	angle_row.add_theme_constant_override("separation", 10)
	column.add_child(angle_row)
	var angle_label := Label.new()
	angle_label.text = "回転角度"
	angle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	angle_row.add_child(angle_label)
	rotation_settings_angle = SpinBox.new()
	rotation_settings_angle.name = "RotationAngleSpinBox"
	rotation_settings_angle.min_value = 0.0
	rotation_settings_angle.max_value = 359.0
	rotation_settings_angle.step = 1.0
	rotation_settings_angle.allow_greater = false
	rotation_settings_angle.allow_lesser = false
	rotation_settings_angle.suffix = "°"
	rotation_settings_angle.custom_minimum_size = Vector2(112.0, 32.0)
	rotation_settings_angle.value_changed.connect(_on_rotation_settings_angle_changed)
	angle_row.add_child(rotation_settings_angle)

	var hint := Label.new()
	hint.text = "0〜359° // 1°単位"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.44, 0.68, 0.78))
	column.add_child(hint)


func _on_rotation_settings_angle_changed(value: float) -> void:
	if rotation_settings_syncing or rotation_settings_node_id == &"":
		return
	set_rotation_angle(rotation_settings_node_id, roundi(value))


func _on_rotation_settings_popup_hidden() -> void:
	rotation_settings_node_id = &""


func _build_line_settings_popup() -> void:
	line_settings_popup = PopupPanel.new()
	line_settings_popup.name = "LineSettingsPopup"
	line_settings_popup.popup_hide.connect(_on_line_settings_popup_hidden)
	add_child(line_settings_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	line_settings_popup.add_child(margin)

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(260.0, 132.0)
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	line_settings_title = Label.new()
	line_settings_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line_settings_title.add_theme_font_size_override("font_size", 14)
	line_settings_title.add_theme_color_override("font_color", Color(0.72, 0.91, 1.0))
	column.add_child(line_settings_title)

	line_settings_details = Label.new()
	line_settings_details.add_theme_font_size_override("font_size", 12)
	line_settings_details.add_theme_color_override("font_color", Color(0.52, 0.74, 0.84))
	column.add_child(line_settings_details)

	line_settings_delete_button = Button.new()
	line_settings_delete_button.name = "DeleteLineButton"
	line_settings_delete_button.text = "搬送路を削除"
	line_settings_delete_button.custom_minimum_size = Vector2(0.0, 34.0)
	line_settings_delete_button.pressed.connect(_on_line_settings_delete_pressed)
	column.add_child(line_settings_delete_button)


func _on_line_settings_delete_pressed() -> void:
	if line_settings_connection.is_empty():
		return
	var to_node_id := StringName(line_settings_connection.get("to_node", &""))
	var to_port := int(line_settings_connection.get("to_port", -1))
	line_settings_popup.hide()
	if to_node_id != &"" and to_port >= 0:
		disconnect_input(to_node_id, to_port)


func _on_line_settings_popup_hidden() -> void:
	line_settings_connection = {}


func _configure_graph_hud_occlusion() -> void:
	graph_menu_panel = factory_graph.get_menu_hbox().get_parent() as PanelContainer
	graph_minimap = _find_control_by_class(factory_graph, &"GraphEditMinimap")
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.035, 0.045, 1.0)
	panel_style.border_color = Color(0.18, 0.28, 0.34, 1.0)
	panel_style.set_border_width_all(1)
	if graph_menu_panel != null:
		graph_menu_panel.z_index = 30
		graph_menu_panel.add_theme_stylebox_override("panel", panel_style)
	if graph_minimap != null:
		graph_minimap.z_index = 30
		graph_minimap.add_theme_stylebox_override("panel", panel_style.duplicate())


func _find_control_by_class(root_node: Node, target_class: StringName) -> Control:
	for child in root_node.get_children(true):
		if StringName(child.get_class()) == target_class:
			return child as Control
		var nested := _find_control_by_class(child, target_class)
		if nested != null:
			return nested
	return null


func _build_target_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "TargetPanel"
	panel.z_index = 50
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -322.0
	panel.offset_top = 12.0
	panel.offset_right = -12.0
	panel.offset_bottom = 252.0
	panel.add_theme_stylebox_override("panel", _target_panel_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	target_header_label = Label.new()
	target_header_label.add_theme_font_size_override("font_size", 14)
	target_header_label.add_theme_color_override("font_color", Color(0.72, 0.91, 1.0))
	column.add_child(target_header_label)

	var target_row := HBoxContainer.new()
	target_row.add_theme_constant_override("separation", 10)
	column.add_child(target_row)

	target_preview = FactoryLandmarkVisualModel.new()
	target_preview.configure_target(selected_target_kind)
	target_row.add_child(target_preview)

	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	target_row.add_child(identity)

	target_name_label = Label.new()
	target_name_label.add_theme_font_size_override("font_size", 16)
	target_name_label.add_theme_color_override("font_color", Color(0.86, 0.95, 1.0))
	identity.add_child(target_name_label)

	target_role_label = Label.new()
	target_role_label.add_theme_font_size_override("font_size", 12)
	target_role_label.add_theme_color_override("font_color", Color(0.48, 0.70, 0.82))
	identity.add_child(target_role_label)

	var selector := HBoxContainer.new()
	selector.alignment = BoxContainer.ALIGNMENT_CENTER
	selector.add_theme_constant_override("separation", 6)
	column.add_child(selector)
	var target_group := ButtonGroup.new()
	for target_kind in TARGET_ORDER:
		var definition: Dictionary = TARGET_DEFINITIONS[target_kind]
		var button := Button.new()
		button.name = "%sTargetButton" % String(target_kind).capitalize()
		button.text = String(definition["glyph_label"])
		button.tooltip_text = "%s // %s" % [definition["monster_name"], definition["role"]]
		button.custom_minimum_size = Vector2(62.0, 32.0)
		button.toggle_mode = true
		button.button_group = target_group
		button.pressed.connect(select_target.bind(target_kind))
		target_buttons[target_kind] = button
		selector.add_child(button)

	summon_state_label = Label.new()
	summon_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summon_state_label.add_theme_font_size_override("font_size", 12)
	column.add_child(summon_state_label)

	select_input(0)
	return panel


func _place_landmarks() -> void:
	for entry in MATERIAL_LAYOUT:
		var node := _make_material_node(
			StringName(entry["id"]),
			StringName(entry["kind"]),
			Vector2(entry["position"])
		)
		material_nodes.append(node)
		factory_graph.add_child(node)

	summoner_node = _make_summoner_node()
	factory_graph.add_child(summoner_node)

	flow_overlay = FactoryDirectionalOverlayModel.new()
	flow_overlay.name = "DirectionalFlowOverlay"
	flow_overlay.z_index = 10
	flow_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flow_overlay.configure(self, &"flow")
	factory_graph.add_child(flow_overlay)

	port_overlay = FactoryDirectionalOverlayModel.new()
	port_overlay.name = "DirectionalPortOverlay"
	port_overlay.z_index = 20
	port_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	port_overlay.configure(self, &"ports")
	factory_graph.add_child(port_overlay)


func _make_material_node(node_id: StringName, kind: StringName, world_position: Vector2) -> GraphNode:
	var node := GraphNode.new()
	node.name = String(node_id)
	node.title = ""
	node.position_offset = world_position
	node.draggable = false
	node.resizable = false
	node.set_meta("landmark_kind", kind)
	node.set_meta("fixed_landmark", true)
	node.set_meta("material_deposit", true)

	var visual = FactoryLandmarkVisualModel.new()
	visual.configure(kind)
	node.add_child(visual)
	node.set_slot(0, false, 0, BUILTIN_PORT_COLOR, true, 0, BUILTIN_PORT_COLOR)
	_configure_round_landmark_node(node, visual.custom_minimum_size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _make_summoner_node() -> GraphNode:
	var node := GraphNode.new()
	node.name = "summoner_center"
	node.title = ""
	node.position_offset = SUMMONER_POSITION
	node.draggable = false
	node.resizable = false
	node.set_meta("landmark_kind", &"summoner")
	node.set_meta("fixed_landmark", true)

	for input_index in SUMMONER_INPUT_COUNT:
		var input_row := Control.new()
		input_row.custom_minimum_size = Vector2(1.0, 1.0)
		input_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(input_row)
		node.set_slot(input_index, true, input_index, BUILTIN_PORT_COLOR, false, 0, BUILTIN_PORT_COLOR)

	var visual = FactoryLandmarkVisualModel.new()
	visual.configure(&"summoner")
	node.add_child(visual)
	_configure_round_landmark_node(node, visual.custom_minimum_size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _make_relay_node(node_id: StringName, world_center: Vector2) -> GraphNode:
	var node := GraphNode.new()
	node.name = String(node_id)
	node.title = ""
	node.draggable = true
	node.resizable = false
	node.set_meta("landmark_kind", &"relay")
	node.set_meta("relay_node", true)

	var port_row := Control.new()
	port_row.custom_minimum_size = Vector2(1.0, 1.0)
	port_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(port_row)
	node.set_slot(0, true, 0, BUILTIN_PORT_COLOR, true, 0, BUILTIN_PORT_COLOR)

	var visual = FactoryLandmarkVisualModel.new()
	visual.configure(&"relay")
	node.add_child(visual)
	_configure_round_landmark_node(node, visual.custom_minimum_size)
	node.position_offset = world_center - visual.custom_minimum_size * 0.5
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	node.tooltip_text = "中継ノード // グリフを変えずに転送 // ドラッグ移動"
	node.gui_input.connect(_on_relay_node_gui_input.bind(node))
	return node


func _make_rotation_node(
	node_id: StringName,
	world_center: Vector2,
	angle_degrees: int
) -> GraphNode:
	var node := GraphNode.new()
	node.name = String(node_id)
	node.title = ""
	node.draggable = true
	node.resizable = false
	node.set_meta("landmark_kind", &"rotation")
	node.set_meta("rotation_node", true)
	node.set_meta("rotation_degrees", posmod(angle_degrees, 360))

	var port_row := Control.new()
	port_row.custom_minimum_size = Vector2(1.0, 1.0)
	port_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(port_row)
	node.set_slot(0, true, 0, BUILTIN_PORT_COLOR, true, 0, BUILTIN_PORT_COLOR)

	var visual = FactoryLandmarkVisualModel.new()
	visual.configure_rotation(angle_degrees)
	node.add_child(visual)
	_configure_round_landmark_node(node, visual.custom_minimum_size)
	node.position_offset = world_center - visual.custom_minimum_size * 0.5
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	node.tooltip_text = "回転ノード // %d° // 右クリックで設定" % posmod(angle_degrees, 360)
	node.gui_input.connect(_on_rotation_node_gui_input.bind(node))
	return node


func _on_relay_button_pressed() -> void:
	if relay_button.button_pressed:
		begin_relay_placement()
	else:
		cancel_relay_placement()


func _on_rotation_button_pressed() -> void:
	if rotation_button.button_pressed:
		begin_rotation_placement()
	else:
		cancel_rotation_placement()


func _on_relay_node_gui_input(event: InputEvent, relay: GraphNode) -> void:
	if not event is InputEventMouse:
		return
	var graph_event := event.duplicate() as InputEventMouse
	graph_event.position = _convert_control_point(relay, event.position, factory_graph)
	var relay_id := StringName(relay.name)
	var over_input: bool = graph_event.position.distance_to(
		directional_node_input_position(relay_id, 0, factory_graph)
	) <= PORT_HIT_RADIUS
	var over_output: bool = graph_event.position.distance_to(
		directional_output_position(relay_id, factory_graph)
	) <= PORT_HIT_RADIUS
	if not over_input and not over_output:
		return
	_on_factory_graph_input(graph_event)
	if event is InputEventMouseButton:
		relay.accept_event()


func _on_rotation_node_gui_input(event: InputEvent, rotation: GraphNode) -> void:
	if not event is InputEventMouse:
		return
	var rotation_id := StringName(rotation.name)
	var graph_event := event.duplicate() as InputEventMouse
	graph_event.position = _convert_control_point(rotation, event.position, factory_graph)
	var over_input: bool = graph_event.position.distance_to(
		directional_node_input_position(rotation_id, 0, factory_graph)
	) <= PORT_HIT_RADIUS
	var over_output: bool = graph_event.position.distance_to(
		directional_output_position(rotation_id, factory_graph)
	) <= PORT_HIT_RADIUS
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if (
			mouse_event.pressed
			and mouse_event.button_index == MOUSE_BUTTON_RIGHT
			and not over_input
			and not over_output
		):
			open_rotation_settings(rotation_id, mouse_event.global_position)
			rotation.accept_event()
			return
	if not over_input and not over_output:
		return
	_on_factory_graph_input(graph_event)
	if event is InputEventMouseButton:
		rotation.accept_event()


func _refresh_factory_status_label() -> void:
	if status_label == null:
		return
	status_label.text = "広域盤面 9000 × 6000  //  資源 30  //  中継 %d  //  回転 %d  //  召喚器 1" % [
		relay_nodes.size(),
		rotation_nodes.size(),
	]


func _configure_round_landmark_node(node: GraphNode, minimum_size: Vector2) -> void:
	node.custom_minimum_size = minimum_size
	node.add_theme_constant_override("separation", 0)
	node.add_theme_color_override("title_color", Color.TRANSPARENT)
	var transparent_style := StyleBoxFlat.new()
	transparent_style.bg_color = Color.TRANSPARENT
	transparent_style.border_color = Color.TRANSPARENT
	transparent_style.set_border_width_all(0)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		transparent_style.set_content_margin(side, 0.0)
	for style_name in [&"panel", &"panel_selected", &"titlebar", &"titlebar_selected"]:
		node.add_theme_stylebox_override(style_name, transparent_style)


func _center_initial_view() -> void:
	if factory_graph == null:
		return
	var summoner_center := SUMMONER_POSITION + summoner_node.size * 0.5
	factory_graph.scroll_offset = summoner_center * factory_graph.zoom - factory_graph.size * 0.5


static func _kind_label(kind: StringName) -> String:
	return {
		&"circle": "丸",
		&"triangle": "三角",
		&"square": "四角",
	}.get(kind, String(kind))


static func _shape_symbol(kind: StringName) -> String:
	return {
		&"circle": "○",
		&"triangle": "△",
		&"square": "□",
	}.get(kind, "?")


func glyph_symbol(glyph: GlyphModel) -> String:
	if glyph == null:
		return "?"
	var serialization := glyph.canonical_serialization()
	for target_kind in TARGET_ORDER:
		var candidate := target_glyph(target_kind)
		if candidate != null and candidate.canonical_serialization() == serialization:
			return String(TARGET_DEFINITIONS[target_kind]["glyph_label"])
	return "✦"


static func _target_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.035, 0.052, 0.96)
	style.border_color = Color(0.22, 0.62, 0.78, 0.86)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style
