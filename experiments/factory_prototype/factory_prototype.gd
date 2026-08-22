class_name FactoryPrototype
extends Control

const FactoryLandmarkVisualModel := preload("res://experiments/factory_prototype/factory_landmark.gd")
const FactoryDirectionalOverlayModel := preload("res://experiments/factory_prototype/factory_directional_overlay.gd")

const MENU_SCENE := "res://src/main_menu.tscn"
const PLAYFIELD_SIZE := Vector2(9000.0, 6000.0)
const SUMMONER_POSITION := Vector2(4400.0, 2895.0)
const SUMMONER_INPUT_COUNT := 3
const PORT_COLOR := Color(0.28, 0.78, 1.0, 1.0)
const PORT_IDLE_COLOR := Color(0.20, 0.55, 0.70, 0.92)
const PORT_HIT_RADIUS := 13.0
const PORT_DRAW_RADIUS := 5.5
const BUILTIN_PORT_COLOR := Color(0.0, 0.0, 0.0, 0.0)
const TARGET_ORDER := [&"circle", &"triangle", &"square"]
const TARGET_DEFINITIONS := {
	&"circle": {
		"glyph_label": "○",
		"monster_id": &"ring_wisp",
		"monster_name": "環霊ウィスプ",
		"role": "軽量・浮遊・群体",
	},
	&"triangle": {
		"glyph_label": "△",
		"monster_id": &"stinger",
		"monster_name": "針獣スティンガー",
		"role": "高速・突撃・軽装",
	},
	&"square": {
		"glyph_label": "□",
		"monster_id": &"stone_block",
		"monster_name": "石殻ブロック",
		"role": "低速・防壁・重装",
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
var connection_overlay
var port_overlay
var status_label: Label
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
var hovered_input_index := -1
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
	_place_landmarks()
	_refresh_summon_state()
	call_deferred("_center_initial_view")


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


func select_target(target_kind: StringName) -> bool:
	if not TARGET_DEFINITIONS.has(target_kind):
		return false
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


func target_monster_id(input_index: int = -1) -> StringName:
	var resolved_index := selected_input_index if input_index < 0 else input_index
	var target_kind := target_kind_for_input(resolved_index)
	if not TARGET_DEFINITIONS.has(target_kind):
		return &""
	return StringName(TARGET_DEFINITIONS[target_kind]["monster_id"])


func connected_material_kind(input_index: int = -1) -> StringName:
	var resolved_index := selected_input_index if input_index < 0 else input_index
	if resolved_index < 0 or resolved_index >= SUMMONER_INPUT_COUNT:
		return &""
	if factory_graph == null or summoner_node == null:
		return &""
	for connection in factory_graph.get_connection_list():
		if StringName(connection["to_node"]) != StringName(summoner_node.name):
			continue
		if int(connection["to_port"]) != resolved_index:
			continue
		var source := _material_node(StringName(connection["from_node"]))
		if source != null:
			return StringName(source.get_meta("landmark_kind", &""))
	return &""


func summon_state(input_index: int = -1) -> StringName:
	var resolved_index := selected_input_index if input_index < 0 else input_index
	var material_kind := connected_material_kind(resolved_index)
	if material_kind == &"":
		return &"idle"
	return &"matched" if material_kind == target_kind_for_input(resolved_index) else &"mismatch"


func summoning_monsters() -> Array[StringName]:
	var result: Array[StringName] = []
	for input_index in SUMMONER_INPUT_COUNT:
		if summon_state(input_index) == &"matched":
			result.append(target_monster_id(input_index))
	return result


func connect_material_to_summoner(material_node_id: StringName, input_index: int = -1) -> bool:
	var resolved_index := selected_input_index if input_index < 0 else input_index
	var source := _material_node(material_node_id)
	if (
		source == null
		or summoner_node == null
		or resolved_index < 0
		or resolved_index >= SUMMONER_INPUT_COUNT
	):
		return false
	_remove_summoner_input_connection(resolved_index)
	var error := factory_graph.connect_node(
		StringName(source.name),
		0,
		StringName(summoner_node.name),
		resolved_index,
		true
	)
	if error != OK:
		_refresh_summon_state()
		return false
	_clear_directional_connection_preview()
	_refresh_summon_state()
	return true


func disconnect_summoner(input_index: int = -1) -> void:
	var resolved_index := selected_input_index if input_index < 0 else input_index
	_remove_summoner_input_connection(resolved_index)
	_refresh_summon_state()


func _on_connection_request(
	from_node: StringName,
	from_port: int,
	to_node: StringName,
	to_port: int
) -> void:
	if (
		from_port != 0
		or to_port < 0
		or to_port >= SUMMONER_INPUT_COUNT
		or summoner_node == null
		or to_node != StringName(summoner_node.name)
		or _material_node(from_node) == null
	):
		summon_state_label.text = "直接接続できるのは資源パッチ → 召喚器"
		summon_state_label.add_theme_color_override("font_color", Color(0.96, 0.62, 0.40))
		return
	connect_material_to_summoner(from_node, to_port)


func _on_disconnection_request(
	from_node: StringName,
	from_port: int,
	to_node: StringName,
	to_port: int
) -> void:
	if factory_graph.is_node_connected(from_node, from_port, to_node, to_port):
		factory_graph.disconnect_node(from_node, from_port, to_node, to_port)
	_refresh_summon_state()


func _on_factory_graph_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		connection_pointer = event.position
		hovered_input_index = directional_input_at(event.position)
		hovered_material_id = directional_output_at(event.position)
		if hovered_input_index >= 0:
			factory_graph.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			factory_graph.tooltip_text = "INPUT %d // 左クリックで目標表示 // 右クリックで切断" % (hovered_input_index + 1)
		elif hovered_material_id != &"":
			factory_graph.mouse_default_cursor_shape = Control.CURSOR_CROSS
			factory_graph.tooltip_text = "%s資源パッチ // 固定 // 出力を接続" % _kind_label(
				StringName(_material_node(hovered_material_id).get_meta("landmark_kind", &""))
			)
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
		var disconnect_input := directional_input_at(mouse_event.position)
		if disconnect_input >= 0:
			select_input(disconnect_input)
			disconnect_summoner(disconnect_input)
			factory_graph.accept_event()
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	connection_pointer = mouse_event.position
	if mouse_event.pressed:
		var input_index := directional_input_at(mouse_event.position)
		if input_index >= 0:
			select_input(input_index)
			if connecting_material_id != &"":
				connect_material_to_summoner(connecting_material_id, input_index)
			factory_graph.accept_event()
			return
		var material_id := directional_output_at(mouse_event.position)
		if material_id != &"":
			connecting_material_id = material_id
			connection_press_position = mouse_event.position
			connection_drag_moved = false
			summon_state_label.text = "接続先の召喚器入力を選択"
			summon_state_label.add_theme_color_override("font_color", Color(0.58, 0.86, 1.0))
			factory_graph.accept_event()
			return
		if connecting_material_id != &"":
			_clear_directional_connection_preview()
			_refresh_summon_state()
		return
	if connecting_material_id == &"":
		return
	var release_input := directional_input_at(mouse_event.position)
	if release_input >= 0:
		select_input(release_input)
		connect_material_to_summoner(connecting_material_id, release_input)
		factory_graph.accept_event()
		return
	if connection_drag_moved:
		_clear_directional_connection_preview()
		_refresh_summon_state()
		factory_graph.accept_event()


func _clear_directional_connection_preview() -> void:
	connecting_material_id = &""
	connection_drag_moved = false


func directional_output_at(graph_position: Vector2) -> StringName:
	for node in material_nodes:
		var node_id := StringName(node.name)
		if graph_position.distance_to(directional_output_position(node_id, factory_graph)) <= PORT_HIT_RADIUS:
			return node_id
	return &""


func directional_input_at(graph_position: Vector2) -> int:
	for input_index in SUMMONER_INPUT_COUNT:
		if graph_position.distance_to(directional_input_position(input_index, factory_graph)) <= PORT_HIT_RADIUS:
			return input_index
	return -1


func directional_landmark_at(graph_position: Vector2) -> StringName:
	for node in material_nodes:
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
	if material == null:
		return ""
	return "%s資源パッチ // 固定 // 出力を接続" % _kind_label(
		StringName(material.get_meta("landmark_kind", &""))
	)


func directional_output_position(node_id: StringName, coordinate_space: Control) -> Vector2:
	var source := _material_node(node_id)
	if source == null or summoner_node == null or coordinate_space == null:
		return Vector2.ZERO
	var source_center := _node_center_in(source, coordinate_space)
	var summoner_center := _node_center_in(summoner_node, coordinate_space)
	var direction := source_center.direction_to(summoner_center)
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
	var base := _node_boundary_position(summoner_node, direction, coordinate_space)
	var tangent := Vector2(-direction.y, direction.x)
	base += tangent * float(input_index - 1) * 18.0
	return base


func directional_port_direction(node_id: StringName, port_kind: StringName, input_index: int = -1) -> Vector2:
	var node: GraphNode = summoner_node if port_kind == &"input" else _material_node(node_id)
	if node == null:
		return Vector2.ZERO
	var point := (
		directional_input_position(input_index, factory_graph)
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
	_draw_directional_ports(overlay)


func _draw_directional_connection_lines(overlay: Control) -> void:
	for connection in factory_graph.get_connection_list():
		var from_node_id := StringName(connection["from_node"])
		var input_index := int(connection["to_port"])
		var start := directional_output_position(from_node_id, overlay)
		var finish := directional_input_position(input_index, overlay)
		var color := PORT_COLOR
		match summon_state(input_index):
			&"matched":
				color = Color(0.34, 0.86, 0.76, 0.96)
			&"mismatch":
				color = Color(0.96, 0.62, 0.34, 0.96)
		_draw_connection_curve(overlay, start, finish, color, 3.0)
	if connecting_material_id != &"":
		var preview_start: Vector2 = directional_output_position(connecting_material_id, overlay)
		var preview_finish: Vector2 = _convert_control_point(factory_graph, connection_pointer, overlay)
		_draw_connection_curve(overlay, preview_start, preview_finish, Color(0.42, 0.82, 1.0, 0.72), 2.0)


func _draw_directional_ports(overlay: Control) -> void:
	for node in material_nodes:
		var node_id := StringName(node.name)
		var position := directional_output_position(node_id, overlay)
		var active := node_id == connecting_material_id or node_id == hovered_material_id
		var direction := _node_center_in(node, overlay).direction_to(position)
		_draw_output_port(overlay, position, direction, PORT_COLOR if active else PORT_IDLE_COLOR, active)
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
		_draw_input_target_marker(overlay, position + inward * 14.0, target_kind_for_input(input_index), color)
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


func _draw_connection_curve(
	overlay: Control,
	start: Vector2,
	finish: Vector2,
	color: Color,
	width: float
) -> void:
	var distance := start.distance_to(finish)
	var direction := start.direction_to(finish)
	var handle_length := minf(distance * 0.28, 120.0)
	var first_control := start + direction * handle_length
	var second_control := finish - direction * handle_length
	var points := PackedVector2Array()
	for index in 25:
		points.append(start.bezier_interpolate(first_control, second_control, finish, float(index) / 24.0))
	overlay.draw_polyline(points, color, width, true)


func _summoner_input_direction(input_index: int, coordinate_space: Control) -> Vector2:
	for connection in factory_graph.get_connection_list():
		if (
			StringName(connection["to_node"]) == StringName(summoner_node.name)
			and int(connection["to_port"]) == input_index
		):
			var source := _material_node(StringName(connection["from_node"]))
			if source != null:
				return _node_center_in(summoner_node, coordinate_space).direction_to(
					_node_center_in(source, coordinate_space)
				)
	if connecting_material_id != &"":
		var active_source := _material_node(connecting_material_id)
		if active_source != null:
			return _node_center_in(summoner_node, coordinate_space).direction_to(
				_node_center_in(active_source, coordinate_space)
			)
	return Vector2.from_angle([PI, -PI * 0.5, 0.0][input_index])


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


func _remove_summoner_input_connection(input_index: int) -> void:
	if input_index < 0 or input_index >= SUMMONER_INPUT_COUNT:
		return
	if factory_graph == null or summoner_node == null:
		return
	for connection in factory_graph.get_connection_list():
		if StringName(connection["to_node"]) != StringName(summoner_node.name):
			continue
		if int(connection["to_port"]) != input_index:
			continue
		factory_graph.disconnect_node(
			StringName(connection["from_node"]),
			int(connection["from_port"]),
			StringName(connection["to_node"]),
			int(connection["to_port"])
		)


func _material_node(node_id: StringName) -> GraphNode:
	for node in material_nodes:
		if StringName(node.name) == node_id:
			return node
	return null


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
			summon_state_label.text = "召喚中 // %s" % definition["monster_name"]
			summon_state_label.add_theme_color_override("font_color", Color(0.48, 0.92, 0.76))
		&"mismatch":
			var material_kind := connected_material_kind(selected_input_index)
			summon_state_label.text = "不一致 // 接続 %s  /  目標 %s" % [
				_shape_symbol(material_kind),
				definition["glyph_label"],
			]
			summon_state_label.add_theme_color_override("font_color", Color(0.96, 0.68, 0.38))
		_:
			summon_state_label.text = "%sを召喚器へ直接接続" % definition["glyph_label"]
			summon_state_label.add_theme_color_override("font_color", Color(0.48, 0.70, 0.82))


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

	var title := Label.new()
	title.text = "FACTORY PROTOTYPE // 固定素材地帯"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.76, 0.91, 1.0))
	toolbar.add_child(title)

	status_label = Label.new()
	status_label.text = "広域盤面 9000 × 6000  //  資源パッチ 30  //  中央召喚器 1"
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.44, 0.68, 0.78))
	toolbar.add_child(status_label)

	var graph_area := Control.new()
	graph_area.name = "FactoryGraphArea"
	graph_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_area.custom_minimum_size = Vector2(900.0, 620.0)
	page.add_child(graph_area)

	factory_graph = GraphEdit.new()
	factory_graph.name = "FactoryGraph"
	factory_graph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	factory_graph.right_disconnects = true
	factory_graph.connection_lines_curvature = 0.12
	factory_graph.minimap_enabled = true
	factory_graph.zoom = 0.36
	factory_graph.connection_request.connect(_on_connection_request)
	factory_graph.disconnection_request.connect(_on_disconnection_request)
	factory_graph.gui_input.connect(_on_factory_graph_input)
	graph_area.add_child(factory_graph)

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
		button.custom_minimum_size = Vector2(70.0, 32.0)
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


static func _target_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.035, 0.052, 0.96)
	style.border_color = Color(0.22, 0.62, 0.78, 0.86)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style
