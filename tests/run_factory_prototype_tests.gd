extends SceneTree

const MainMenuScene := preload("res://src/main_menu.tscn")
const FactoryPrototypeScene := preload("res://experiments/factory_prototype/factory_prototype.tscn")

var failures := 0


func _initialize() -> void:
	await _test_main_menu()
	await _test_fixed_factory_landmarks()
	if failures == 0:
		print("All Factory Prototype tests passed.")
	quit(failures)


func _test_main_menu() -> void:
	_expect(
		ProjectSettings.get_setting("application/run/main_scene") == "res://src/main_menu.tscn",
		"the project should open on the main menu"
	)
	var menu = MainMenuScene.instantiate()
	root.add_child(menu)
	await process_frame
	_expect(menu.factory_button != null, "the menu should expose a Factory Prototype button")
	_expect(menu.sigil_lab_button != null, "the menu should preserve the Sigil Lab entry")
	_expect(menu.FACTORY_PROTOTYPE_SCENE == "res://experiments/factory_prototype/factory_prototype.tscn", "the Factory Prototype entry should target the new scene")
	_expect(menu.SIGIL_LAB_SCENE == "res://experiments/sigil_lab/sigil_lab.tscn", "the Sigil Lab entry should target the current Lab")
	menu.queue_free()
	await process_frame


func _test_fixed_factory_landmarks() -> void:
	var prototype = FactoryPrototypeScene.instantiate()
	root.add_child(prototype)
	await process_frame
	await process_frame
	if not prototype.has_method("fixed_landmark_count"):
		_expect(false, "the Factory Prototype scene script should load successfully")
		prototype.queue_free()
		await process_frame
		return

	_expect(prototype.factory_graph != null, "the prototype should expose a wide GraphEdit playfield")
	_expect(prototype.flow_audio != null and prototype.flow_audio.streams_ready(), "factory flow feedback should provide generated connection, disconnect, and arrival sounds")
	_expect(
		is_equal_approx(prototype.flow_packet_phase(0, 1, 0.0) - prototype.flow_packet_phase(0, 0, 0.0), 0.5),
		"two transported Glyphs should stay evenly spaced on each line"
	)
	_expect(
		prototype.flow_packet_phase(0, 0, 0.6) > prototype.flow_packet_phase(0, 0, 0.0),
		"transported Glyph phase should advance toward the summoner over time"
	)
	_expect(prototype.flow_packet_progress(0.0) == prototype.FLOW_PATH_START, "transport should begin just outside its source port")
	_expect(prototype.flow_packet_progress(prototype.FLOW_TRAVEL_PHASE) == 1.0, "transport should reach the exact input center before the arrival effect begins")
	_expect(prototype.flow_packet_progress(0.98) == 1.0, "the Glyph should remain centered on its input while the arrival ring expands")
	_expect(prototype.PLAYFIELD_SIZE == Vector2(9000.0, 6000.0), "the available playfield should support a large map")
	_expect(prototype.material_nodes.size() == 30, "material deposits should be scattered across the large map")
	_expect(prototype.fixed_landmark_count() == 31, "thirty material deposits and one summoner should be fixed landmarks")
	_expect(prototype.all_landmarks_locked(), "material nodes and the summoner should not be draggable")
	_expect(prototype.factory_graph.minimap_enabled, "a minimap should support navigation across the large map")
	_expect(not prototype.factory_graph.is_showing_arrange_button(), "automatic selected-node arrangement should stay hidden for the radial factory layout")
	_expect(prototype.connection_overlay != null and prototype.flow_overlay != null and prototype.port_overlay != null, "directional lines, moving Glyphs, and ports should use dedicated overlays")
	_expect(prototype.connection_overlay.z_index < prototype.flow_overlay.z_index, "flow effects should render in front of background lines")
	_expect(prototype.flow_overlay.z_index < prototype.port_overlay.z_index, "flow effects should remain behind the exact input and output ports")
	_expect(prototype.flow_audio.connection_player.volume_db == -3.0, "connection sounds should remain clearly audible")
	_expect(prototype.flow_audio.arrival_player.volume_db == -6.0, "repeated arrival sounds should remain audible without overpowering connections")
	_expect(is_zero_approx(prototype.factory_graph.connection_lines_thickness), "native GraphEdit lines should stay hidden behind the circular directional renderer")
	_expect(not prototype.factory_graph.right_disconnects, "native GraphEdit connection interaction should not reveal hidden rectangular routes")
	_expect(prototype.factory_graph.get_theme_constant("connection_hover_thickness") == 0, "native connection hover thickness should remain disabled")
	_expect(prototype.factory_graph.get_theme_color("connection_hover_tint_color").a == 0.0, "native connection hover tint should remain transparent")
	_expect(prototype.factory_graph.get_theme_color("connection_rim_color").a == 0.0, "native connection rim shadows should remain transparent")
	_expect(prototype.factory_graph.get_theme_color("connection_valid_target_tint_color").a == 0.0, "native target tint should not reveal hidden rectangular ports")
	_expect(prototype.graph_menu_panel != null and prototype.graph_minimap != null, "GraphEdit HUD surfaces should be available for line occlusion")
	_expect(prototype.graph_menu_panel.z_index > prototype.port_overlay.z_index, "the GraphEdit toolbar should cover directional lines and ports")
	_expect(prototype.graph_minimap.z_index > prototype.port_overlay.z_index, "the minimap should cover directional lines and ports")
	_expect(prototype.graph_menu_panel.get_theme_stylebox("panel").bg_color.a == 1.0, "the toolbar should fully occlude routes passing behind it")
	_expect(prototype.graph_minimap.get_theme_stylebox("panel").bg_color.a == 1.0, "the minimap should fully occlude routes passing behind it")
	_expect(prototype.factory_graph.zoom <= 0.31, "the initial camera should show the complete inner deposit ring outside the GraphEdit HUD")
	_expect(prototype.summoner_node.position_offset == prototype.SUMMONER_POSITION, "the summoner should remain at the factory center")
	_expect(prototype.summoner_node.get_meta("landmark_kind") == &"summoner", "the center landmark should be identifiable as the summoner")

	var counts: Dictionary = prototype.material_kind_counts()
	_expect(counts[&"circle"] == 10, "ten Circle material deposits should exist")
	_expect(counts[&"triangle"] == 10, "ten Triangle material deposits should exist")
	_expect(counts[&"square"] == 10, "ten Square material deposits should exist")
	_expect(prototype.target_panel != null and prototype.target_panel.anchor_left == 1.0, "the target sigil panel should stay at the upper right")
	_expect(prototype.target_buttons.size() == 3, "Circle, Triangle, and Square should be selectable targets")
	_expect(prototype.target_panel.find_child("Input1Button", true, false) == null, "the target panel should not duplicate summoner inputs as tabs")
	_expect(prototype.input_target_kinds.size() == 3, "the round summoner should retain three input targets without visible text rows")
	_expect(prototype.target_kind_for_input(0) == &"circle", "input 1 should initially target Circle")
	_expect(prototype.target_kind_for_input(1) == &"triangle", "input 2 should initially target Triangle")
	_expect(prototype.target_kind_for_input(2) == &"square", "input 3 should initially target Square")
	_expect(prototype.selected_input_index == 0 and prototype.selected_target_kind == &"circle", "the target panel should initially show input 1")
	_expect(prototype.target_monster_id() == &"ring_wisp", "input 1 should show the Ring Wisp")
	_expect(prototype.summon_state() == &"idle", "input 1 should start disconnected")
	var initial_summoner_input_positions: Array[Vector2] = []
	for input_index in prototype.SUMMONER_INPUT_COUNT:
		initial_summoner_input_positions.append(
			prototype.directional_input_position(input_index, prototype.factory_graph)
		)
	var input_hover := InputEventMouseMotion.new()
	input_hover.position = prototype.directional_input_position(1, prototype.factory_graph)
	prototype.factory_graph.gui_input.emit(input_hover)
	_expect(prototype.hovered_input_index == 1 and "INPUT 2" in prototype.factory_graph.tooltip_text, "hovering a summoner input should reveal its direct selection action")

	var circle_source := _first_material(prototype, &"circle")
	var triangle_source := _first_material(prototype, &"triangle")
	var square_source := _first_material(prototype, &"square")
	_expect(prototype.relay_button != null and prototype.relay_button.text == "＋ 中継", "the toolbar should expose relay placement")
	prototype.begin_relay_placement()
	_expect(prototype.relay_placement_active and prototype.relay_button.button_pressed, "relay placement should enter a visible one-shot mode")
	var relay_world_center := Vector2(5000.0, 4500.0)
	var relay_click := InputEventMouseButton.new()
	relay_click.button_index = MOUSE_BUTTON_LEFT
	relay_click.pressed = true
	relay_click.position = relay_world_center * prototype.factory_graph.zoom - prototype.factory_graph.scroll_offset
	prototype.factory_graph.gui_input.emit(relay_click)
	_expect(prototype.relay_nodes.size() == 1 and not prototype.relay_placement_active, "clicking the board in placement mode should create one relay and exit placement")
	var relay: GraphNode = prototype.relay_nodes[0]
	var relay_id := StringName(relay.name)
	_expect(relay.draggable and not relay.get_meta("fixed_landmark", false), "relay nodes should be draggable player-built equipment")
	_expect(prototype.fixed_landmark_count() == 31, "placing a relay should not change the fixed-landmark count")
	_expect("中継 1" in prototype.status_label.text, "the toolbar should report the number of placed relays")
	_expect(prototype._landmark_visual(relay).body_radius() > 0.0, "relay nodes should use the circular factory visual language")
	var relay_source_click := InputEventMouseButton.new()
	relay_source_click.button_index = MOUSE_BUTTON_LEFT
	relay_source_click.pressed = true
	relay_source_click.position = prototype.directional_output_position(StringName(circle_source.name), prototype.factory_graph)
	prototype.factory_graph.gui_input.emit(relay_source_click)
	var relay_input_click := InputEventMouseButton.new()
	relay_input_click.button_index = MOUSE_BUTTON_LEFT
	relay_input_click.pressed = true
	relay_input_click.position = prototype._convert_control_point(
		prototype.factory_graph,
		prototype.directional_node_input_position(relay_id, 0, prototype.factory_graph),
		relay
	)
	relay.gui_input.emit(relay_input_click)
	_expect(prototype.output_glyph_kind(relay_id) == &"circle", "clicking a material output and the visible relay input should create the connection")
	_expect(prototype.output_glyph_kind(relay_id) == &"circle", "a relay should preserve its incoming Glyph kind")
	_expect(prototype.connect_output_to_input(relay_id, StringName(prototype.summoner_node.name), 0), "a relay output should connect to a summoner input")
	var relay_center: Vector2 = prototype._node_center_in(relay, prototype.factory_graph)
	var relay_input: Vector2 = prototype.directional_node_input_position(relay_id, 0, prototype.factory_graph)
	var relay_output: Vector2 = prototype.directional_output_position(relay_id, prototype.factory_graph)
	_expect(relay_center.direction_to(relay_input).dot(relay_center.direction_to(prototype._node_center_in(circle_source, prototype.factory_graph))) > 0.8, "the relay input should face its actual upstream source")
	_expect(relay_center.direction_to(relay_output).dot(relay_center.direction_to(prototype._node_center_in(prototype.summoner_node, prototype.factory_graph))) > 0.8, "the relay output should face its actual downstream destination")
	_expect(prototype.summon_state(0) == &"matched", "Circle routed through a relay should still summon the Circle target")
	_expect(prototype.connect_output_to_input(relay_id, StringName(prototype.summoner_node.name), 1), "one relay output should distribute to another downstream input")
	_expect(prototype.connected_material_kind(1) == &"circle", "distributed relay output should preserve the same Glyph on every branch")
	_expect(prototype.factory_graph.get_connection_list().size() == 3, "relay routing should contain one upstream and two downstream connections")
	prototype.disconnect_summoner(0)
	prototype.disconnect_summoner(1)
	prototype.disconnect_input(relay_id, 0)
	_expect(prototype.factory_graph.get_connection_list().is_empty(), "relay test connections should disconnect independently")
	var second_relay: GraphNode = prototype.place_relay_at(Vector2(5300.0, 4500.0))
	var second_relay_id := StringName(second_relay.name)
	_expect(prototype.connect_output_to_input(relay_id, second_relay_id, 0), "relay nodes should chain in the processing direction")
	_expect(not prototype.connect_output_to_input(second_relay_id, relay_id, 0), "relay connections should reject a cycle")
	prototype.disconnect_input(second_relay_id, 0)
	var square_output: Vector2 = prototype.directional_output_position(StringName(square_source.name), prototype.factory_graph)
	var menu_bottom: float = prototype.graph_menu_panel.position.y + prototype.graph_menu_panel.size.y
	_expect(square_output.y > menu_bottom, "the upper inner deposit output should remain visible below the GraphEdit toolbar")
	var circle_visual = prototype._landmark_visual(circle_source)
	var summoner_visual = prototype._landmark_visual(prototype.summoner_node)
	_expect(circle_source.title.is_empty() and prototype.summoner_node.title.is_empty(), "landmark nodes should not render title text")
	_expect(circle_visual.custom_minimum_size.x == circle_visual.custom_minimum_size.y, "material landmarks should use a circular square canvas")
	_expect(summoner_visual.custom_minimum_size.x == summoner_visual.custom_minimum_size.y, "the summoner should use a circular square canvas")
	var body_hover := InputEventMouseMotion.new()
	body_hover.position = prototype._node_center_in(circle_source, prototype.factory_graph)
	prototype.factory_graph.gui_input.emit(body_hover)
	_expect("丸資源パッチ" in prototype.factory_graph.tooltip_text, "material name and fixed state should move from node text into a tooltip")
	var circle_center: Vector2 = prototype._node_center_in(circle_source, prototype.factory_graph)
	var circle_output: Vector2 = prototype.directional_output_position(StringName(circle_source.name), prototype.factory_graph)
	_expect(
		absf(circle_center.distance_to(circle_output) - prototype._landmark_radius_in(circle_source, prototype.factory_graph)) < 1.0,
		"material output ports should anchor to the visible circular body"
	)
	var circle_output_effect: Vector2 = prototype.directional_output_position(StringName(circle_source.name), prototype.flow_overlay)
	var circle_output_port: Vector2 = prototype.directional_output_position(StringName(circle_source.name), prototype.port_overlay)
	_expect(
		(prototype.flow_overlay.get_global_transform() * circle_output_effect).distance_to(
			prototype.port_overlay.get_global_transform() * circle_output_port
		) < 0.1,
		"moving Glyph effects should share the exact output-port center across overlay layers"
	)
	for input_index in prototype.SUMMONER_INPUT_COUNT:
		var arrival_effect: Vector2 = prototype.directional_input_position(input_index, prototype.flow_overlay)
		var input_port: Vector2 = prototype.directional_input_position(input_index, prototype.port_overlay)
		_expect(
			(prototype.flow_overlay.get_global_transform() * arrival_effect).distance_to(
				prototype.port_overlay.get_global_transform() * input_port
			) < 0.1,
			"arrival rings should stay centered on summoner input %d" % (input_index + 1)
		)
	body_hover.position = prototype._node_center_in(prototype.summoner_node, prototype.factory_graph)
	prototype.factory_graph.gui_input.emit(body_hover)
	_expect("召喚器" in prototype.factory_graph.tooltip_text, "summoner name and input guidance should move from node text into a tooltip")
	if circle_source != null:
		var connection_sound_count: int = prototype.flow_audio.connection_play_count
		prototype.factory_graph.connection_request.emit(
			StringName(circle_source.name),
			0,
			StringName(prototype.summoner_node.name),
			0
		)
		_expect(prototype.flow_audio.connection_play_count == connection_sound_count + 1, "a completed connection should play one short connection sound")
	_expect(circle_source != null and prototype.connected_material_kind() == &"circle", "dragging a Circle deposit output should connect directly to the summoner")
	_expect(prototype.summon_state() == &"matched", "matching Circle should start summoning")
	_expect("環霊ウィスプ" in prototype.summon_state_label.text, "the Circle summon state should name its monster")

	_click_input(prototype, 1)
	_expect(prototype.selected_input_index == 1, "clicking summoner input 2 should select it")
	_expect(prototype.selected_target_kind == &"triangle" and prototype.target_monster_id() == &"stinger", "the panel should switch to input 2's Triangle target")
	_expect(triangle_source != null and prototype.connect_material_to_summoner(StringName(triangle_source.name), 1), "a Triangle deposit should connect independently to input 2")
	_expect(prototype.summon_state(0) == &"matched" and prototype.summon_state(1) == &"matched", "inputs 1 and 2 should judge their own sigils independently")

	_click_input(prototype, 2)
	_expect(prototype.selected_input_index == 2, "clicking summoner input 3 should select it")
	_expect(prototype.selected_target_kind == &"square" and prototype.target_monster_id() == &"stone_block", "the panel should switch to input 3's Square target")
	_expect(square_source != null and prototype.connect_material_to_summoner(StringName(square_source.name), 2), "a Square deposit should connect independently to input 3")
	_expect(prototype.factory_graph.get_connection_list().size() == 3, "the summoner should retain one connection per input")
	_expect(prototype.summoning_monsters() == [&"ring_wisp", &"stinger", &"stone_block"], "all three matching inputs should summon their own monsters")

	_click_input(prototype, 1)
	_expect(prototype.select_target(&"square"), "the selected input 2 target should be independently configurable")
	_expect(prototype.summon_state(0) == &"matched", "changing input 2 must not change input 1's result")
	_expect(prototype.summon_state(1) == &"mismatch", "input 2 should re-evaluate against its new target")
	_expect(prototype.summon_state(2) == &"matched", "changing input 2 must not change input 3's result")
	_expect("INPUT 2" in prototype.target_header_label.text and prototype.selected_target_kind == &"square", "the target panel should show the selected input's target")
	_expect(square_source != null and prototype.connect_material_to_summoner(StringName(square_source.name), 1), "reconnecting input 2 should replace only that input")
	_expect(prototype.factory_graph.get_connection_list().size() == 3, "replacing one input should preserve the other input connections")
	_expect(prototype.summon_state(1) == &"matched", "input 2 should match after its own reconnection")

	_click_input(prototype, 2)
	var active_connection := _connection_for_input(prototype, 2)
	prototype.factory_graph.disconnection_request.emit(
		StringName(active_connection["from_node"]),
		int(active_connection["from_port"]),
		StringName(active_connection["to_node"]),
		int(active_connection["to_port"])
	)
	_expect(prototype.summon_state(2) == &"idle", "disconnecting input 3 should stop only that input")
	_expect(prototype.summon_state(0) == &"matched" and prototype.summon_state(1) == &"matched", "disconnecting input 3 should preserve the other summons")
	_expect(prototype.factory_graph.get_connection_list().size() == 2, "disconnecting one input should preserve two connections")

	_expect(prototype.directional_port_direction(&"circle_01", &"output").x > 0.9, "a west-side material output should face east toward the center")
	_expect(prototype.directional_port_direction(&"triangle_01", &"output").x < -0.9, "an east-side material output should face west toward the center")
	_expect(prototype.directional_port_direction(&"square_04", &"output").y > 0.9, "a north-side material output should face south toward the center")
	_expect(prototype.directional_port_direction(&"square_08", &"output").y < -0.9, "a south-side material output should face north toward the center")
	for input_index in prototype.SUMMONER_INPUT_COUNT:
		var expected_input_direction := Vector2.from_angle(
			prototype.SUMMONER_INPUT_START_ANGLE
			+ TAU * float(input_index) / float(prototype.SUMMONER_INPUT_COUNT)
		)
		_expect(
			prototype.directional_port_direction(&"summoner_center", &"input", input_index).dot(
				expected_input_direction
			) > 0.99,
			"summoner inputs should keep equal angles measured from the top"
		)
		_expect(
			prototype.directional_input_position(input_index, prototype.factory_graph).distance_to(
				initial_summoner_input_positions[input_index]
			) < 0.1,
			"summoner input pins should not move when connections change"
		)

	var output_click := InputEventMouseButton.new()
	output_click.button_index = MOUSE_BUTTON_LEFT
	output_click.pressed = true
	output_click.position = prototype.directional_output_position(StringName(square_source.name), prototype.factory_graph)
	prototype.factory_graph.gui_input.emit(output_click)
	_expect(prototype.connecting_material_id == StringName(square_source.name), "clicking a directional output should start a connection")
	for input_index in prototype.SUMMONER_INPUT_COUNT:
		_expect(
			prototype.directional_input_position(input_index, prototype.factory_graph).distance_to(
				initial_summoner_input_positions[input_index]
			) < 0.1,
			"summoner input pins should remain fixed during a connection preview"
		)
	var input_click := InputEventMouseButton.new()
	input_click.button_index = MOUSE_BUTTON_LEFT
	input_click.pressed = true
	input_click.position = prototype.directional_input_position(2, prototype.factory_graph)
	prototype.factory_graph.gui_input.emit(input_click)
	_expect(prototype.selected_input_index == 2, "connecting through an input port should also select that input")
	_expect(prototype.summon_state(2) == &"matched", "clicking an all-direction input should finish the connection")
	var disconnect_click := InputEventMouseButton.new()
	disconnect_click.button_index = MOUSE_BUTTON_RIGHT
	disconnect_click.pressed = true
	disconnect_click.position = prototype.directional_input_position(2, prototype.factory_graph)
	var disconnect_sound_count: int = prototype.flow_audio.disconnect_play_count
	prototype.factory_graph.gui_input.emit(disconnect_click)
	_expect(prototype.selected_input_index == 2, "right-clicking an input should keep its target selected")
	_expect(prototype.summon_state(2) == &"idle", "right-clicking a directional input should disconnect only that input")
	_expect(prototype.flow_audio.disconnect_play_count == disconnect_sound_count + 1, "disconnecting a directional input should play one short disconnect sound")
	var arrival_sound_count: int = prototype.flow_audio.arrival_play_count
	prototype.flow_audio.play_arrival(&"circle")
	_expect(prototype.flow_audio.arrival_play_count == arrival_sound_count + 1, "a matched Glyph arrival should have a shape-specific summon sound")

	var bounds := Rect2()
	var first := true
	var nearest_deposit_distance := INF
	for node in prototype.material_nodes:
		_expect(node.get_meta("fixed_landmark", false), "%s should be marked as a fixed landmark" % node.name)
		_expect(node.get_meta("material_deposit", false), "%s should be marked as a material deposit" % node.name)
		nearest_deposit_distance = minf(
			nearest_deposit_distance,
			node.position_offset.distance_to(prototype.SUMMONER_POSITION)
		)
		if first:
			bounds = Rect2(node.position_offset, Vector2.ZERO)
			first = false
		else:
			bounds = bounds.expand(node.position_offset)
	_expect(bounds.size.x >= 7800.0 and bounds.size.y >= 4500.0, "material deposits should span most of the large playfield")
	_expect(nearest_deposit_distance >= 1250.0, "the summoner should have enough empty space for several processing nodes")

	prototype.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % message)


func _first_material(prototype, kind: StringName) -> GraphNode:
	for node in prototype.material_nodes:
		if StringName(node.get_meta("landmark_kind", &"")) == kind:
			return node
	return null


func _connection_for_input(prototype, input_index: int) -> Dictionary:
	for connection in prototype.factory_graph.get_connection_list():
		if int(connection["to_port"]) == input_index:
			return connection
	return {}


func _click_input(prototype, input_index: int) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = prototype.directional_input_position(input_index, prototype.factory_graph)
	prototype.factory_graph.gui_input.emit(click)
