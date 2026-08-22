extends SceneTree

const MainMenuScene := preload("res://src/main_menu.tscn")
const FactoryPrototypeScene := preload("res://experiments/factory_prototype/factory_prototype.tscn")

var failures := 0


func _initialize() -> void:
	await _test_main_menu()
	await _test_fixed_factory_landmarks()
	await _test_move_processing_node()
	await _test_processed_rotation_target()
	await _test_scale_processing_node()
	await _test_repeat_processing_node()
	await _test_combine_processing_node()
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
	var short_line_length := 520.0
	var long_line_length := 1040.0
	_expect(
		prototype.flow_travel_duration(long_line_length) > prototype.flow_travel_duration(short_line_length) * 1.99,
		"a line twice as long should take twice as long to traverse"
	)
	_expect(
		prototype.flow_packet_slot_count(long_line_length) > prototype.flow_packet_slot_count(short_line_length),
		"a longer conveyor should hold more Glyphs instead of changing their spacing"
	)
	_expect(
		is_equal_approx(
			prototype.flow_packet_interval(),
			prototype.FLOW_GLYPH_SPACING_WORLD_UNITS / prototype.conveyor_speed_for_grade(1)
		),
		"conveyor throughput should come from fixed world spacing and grade speed"
	)
	var sample_time := 1.4
	var short_progress: float = prototype.flow_packet_progress(short_line_length, 0, 0, sample_time)
	var long_progress: float = prototype.flow_packet_progress(long_line_length, 0, 0, sample_time)
	var next_long_progress: float = prototype.flow_packet_progress(long_line_length, 0, 1, sample_time)
	_expect(
		short_progress > long_progress,
		"the same elapsed time should cover a smaller fraction of a longer line"
	)
	_expect(
		is_equal_approx(
			(short_progress - prototype.FLOW_PATH_START) * short_line_length,
			(long_progress - prototype.FLOW_PATH_START) * long_line_length
		),
		"transported Glyphs should cover the same world distance at the same time"
	)
	_expect(
		is_equal_approx(
			(next_long_progress - long_progress) * long_line_length,
			prototype.FLOW_GLYPH_SPACING_WORLD_UNITS
		),
		"Glyphs should keep the same world spacing on every conveyor length"
	)
	_expect(prototype.flow_packet_progress(short_line_length, 0, 0, 0.0) == prototype.FLOW_PATH_START, "transport should begin just outside its source port")
	_expect(prototype.flow_packet_progress(short_line_length, 1.0, 0, 0.99) < 0.0, "a newly connected conveyor should stay empty before its start time")
	_expect(prototype.flow_packet_progress(short_line_length, 1.0, 0, 1.0) == prototype.FLOW_PATH_START, "the first Glyph should emerge from the source when transport starts")
	_expect(prototype.flow_packet_progress(long_line_length, 1.0, 1, 1.0) < 0.0, "a new conveyor should not be prefilled with older Glyphs")
	var short_arrival_time: float = prototype.flow_travel_duration(short_line_length)
	_expect(is_equal_approx(prototype.flow_packet_progress(short_line_length, 0, 0, short_arrival_time), 1.0), "transport should reach the exact input center before the arrival effect begins")
	_expect(prototype.flow_connection_arrival_progress(short_line_length, 0.0, short_arrival_time + 0.1) > 0.0, "the arrival ring should expand after a Glyph crosses the input")
	_expect(
		prototype.flow_arrival_cycle(0, short_arrival_time + 0.01, short_line_length)
		> prototype.flow_arrival_cycle(0, short_arrival_time + 0.01, long_line_length),
		"arrival feedback should occur later on a longer line"
	)
	var relay_delay: float = prototype.flow_travel_duration(600.0)
	_expect(
		is_equal_approx(
			prototype.flow_packet_progress(600.0, relay_delay, 0, relay_delay + 0.2),
			prototype.flow_packet_progress(600.0, 0.0, 0, 0.2)
		),
		"a relay should preserve conveyor phase and speed across connected segments"
	)
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
	_expect(prototype.target_buttons.size() == 8, "basic and radial-layer targets should be selectable")
	for target_kind in prototype.TARGET_ORDER:
		var target_button = prototype.target_buttons[target_kind]
		_expect(
			target_button.glyph_value != null
			and target_button.text == ""
			and target_button.custom_minimum_size.y >= 48.0,
			"every target selector should display its actual Glyph thumbnail instead of a text abbreviation"
		)
	_expect(prototype.target_panel.find_child("Input1Button", true, false) == null, "the target panel should not duplicate summoner inputs as tabs")
	_expect(prototype.input_target_kinds.size() == 3, "the round summoner should retain three input targets without visible text rows")
	_expect(prototype.target_kind_for_input(0) == &"circle", "input 1 should initially target Circle")
	_expect(prototype.target_kind_for_input(1) == &"triangle", "input 2 should initially target Triangle")
	_expect(prototype.target_kind_for_input(2) == &"square", "input 3 should initially target Square")
	_expect(
		prototype.target_glyph_for_input(0).canonical_serialization()
		!= prototype.target_glyph_for_input(1).canonical_serialization(),
		"summoner targets should be real canonical Glyph data instead of display-only shape names"
	)
	_expect(
		prototype.target_glyph(&"diamond").canonical_serialization()
		== prototype.primitive_glyph(&"square").rotated_degrees(45).canonical_serialization(),
		"the Diamond target should be the canonical result of rotating Square by 45 degrees"
	)
	for target_kind in [&"triad", &"four_gate", &"hex_star", &"octa_orbit"]:
		_expect(
			prototype.GlyphPainterModel.can_draw(prototype.target_glyph(target_kind)),
			"radial targets should be real drawable CanonicalGlyph data"
		)
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
	_expect(prototype.rotation_button != null and prototype.rotation_button.text == "＋ 回転", "the toolbar should expose rotation placement")
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
	prototype.begin_rotation_placement()
	_expect(
		prototype.rotation_placement_active
		and prototype.rotation_button.button_pressed
		and not prototype.relay_placement_active,
		"rotation placement should be a visible one-shot mode exclusive with relay placement"
	)
	var rotation_world_center := Vector2(5200.0, 4300.0)
	var rotation_click := InputEventMouseButton.new()
	rotation_click.button_index = MOUSE_BUTTON_LEFT
	rotation_click.pressed = true
	rotation_click.position = rotation_world_center * prototype.factory_graph.zoom - prototype.factory_graph.scroll_offset
	prototype.factory_graph.gui_input.emit(rotation_click)
	_expect(
		prototype.rotation_nodes.size() == 1 and not prototype.rotation_placement_active,
		"clicking the board in rotation placement mode should create one processor and exit placement"
	)
	var rotation: GraphNode = prototype.rotation_nodes[0]
	var rotation_id := StringName(rotation.name)
	_expect(rotation.draggable and prototype.rotation_angle(rotation_id) == 45, "a new rotation node should be draggable and default to 45 degrees")
	_expect("回転 1" in prototype.status_label.text, "the toolbar should report the number of rotation processors")
	_expect(
		prototype.connect_output_to_input(StringName(square_source.name), rotation_id, 0),
		"a material output should connect to a rotation input from any direction"
	)
	var rotated_square = prototype.output_glyph(rotation_id)
	_expect(
		rotated_square != null
		and rotated_square.canonical_serialization()
		== prototype.primitive_glyph(&"square").rotated_degrees(45).canonical_serialization(),
		"the rotation node should apply a pure 45 degree transform to its input Glyph"
	)
	var settings_click := InputEventMouseButton.new()
	settings_click.button_index = MOUSE_BUTTON_RIGHT
	settings_click.pressed = true
	settings_click.position = prototype._convert_control_point(
		prototype.factory_graph,
		prototype._node_center_in(rotation, prototype.factory_graph),
		rotation
	)
	settings_click.global_position = Vector2(620.0, 360.0)
	rotation.gui_input.emit(settings_click)
	_expect(
		prototype.rotation_settings_popup != null
		and prototype.rotation_settings_popup.visible
		and prototype.rotation_settings_node_id == rotation_id,
		"right-clicking a processor body should open that node's settings menu"
	)
	_expect(
		prototype.rotation_settings_preset_buttons.has(45)
		and prototype.rotation_settings_preset_buttons[45].button_pressed
		and prototype.rotation_settings_preset_buttons[45].icon != null,
		"the settings menu should start from the selected preset and show its direction"
	)
	var original_rotation_glyph: String = prototype.output_glyph(rotation_id).canonical_serialization()
	prototype.rotation_settings_preset_buttons[72].mouse_entered.emit()
	_expect(
		prototype.rotation_angle(rotation_id) == 45
		and prototype._landmark_visual(rotation).rotation_angle_degrees == 72
		and prototype.output_glyph(rotation_id).canonical_serialization() == original_rotation_glyph,
		"hovering a preset should preview only its direction without changing factory state"
	)
	prototype.rotation_settings_preset_buttons[72].mouse_exited.emit()
	_expect(
		prototype._landmark_visual(rotation).rotation_angle_degrees == 45,
		"leaving a preset should restore the committed direction"
	)
	prototype.rotation_settings_preset_buttons[60].pressed.emit()
	_expect(
		prototype.rotation_angle(rotation_id) == 60
		and prototype.rotation_settings_preset_buttons[60].button_pressed
		and
		prototype.output_glyph(rotation_id).canonical_serialization()
		== prototype.primitive_glyph(&"square").rotated_degrees(60).canonical_serialization(),
		"selecting a preset should deterministically rebuild its output Glyph"
	)
	_expect(
		not prototype.set_rotation_angle(rotation_id, 37)
		and prototype.rotation_angle(rotation_id) == 60,
		"arbitrary near-match angles should be rejected"
	)
	prototype.rotation_settings_popup.hide()
	var body_wheel := InputEventMouseButton.new()
	body_wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	body_wheel.pressed = true
	body_wheel.position = settings_click.position
	rotation.gui_input.emit(body_wheel)
	_expect(
		prototype.rotation_angle(rotation_id) == 60,
		"scrolling the node body should no longer modify its angle outside the settings menu"
	)
	prototype.disconnect_input(rotation_id, 0)
	var relay_source_click := InputEventMouseButton.new()
	prototype.flow_time_override = 10.0
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
	var relay_output_glyph = prototype.output_glyph(relay_id)
	_expect(
		relay_output_glyph != null
		and relay_output_glyph.canonical_serialization()
		== prototype.primitive_glyph(&"circle").canonical_serialization(),
		"a relay should expose the same canonical Glyph as its material source"
	)
	if relay_output_glyph != null:
		relay_output_glyph.components[0].primitive_id = &"triangle"
		_expect(
			prototype.output_glyph_kind(relay_id) == &"circle",
			"callers should receive an owned Glyph copy instead of mutating factory output state"
		)
	var circle_source_id := StringName(circle_source.name)
	var upstream_flow_start: float = prototype.connection_flow_start_time(
		circle_source_id,
		relay_id,
		0
	)
	var upstream_line_length: float = prototype.connection_world_length(
		circle_source_id,
		relay_id,
		0
	)
	_expect(is_equal_approx(upstream_flow_start, 10.0), "a material conveyor should begin when its connection is created")
	_expect(
		prototype.flow_packet_progress(upstream_line_length, upstream_flow_start, 0, 10.0)
		== prototype.FLOW_PATH_START,
		"the first live Glyph should emerge from the material source"
	)
	_expect(
		prototype.flow_packet_progress(upstream_line_length, upstream_flow_start, 1, 10.0) < 0.0,
		"a live material conveyor should not be instantly prefilled"
	)
	var initial_packets: Array[Dictionary] = prototype.transport_packets_for_connection(
		circle_source_id,
		relay_id,
		0,
		10.0
	)
	_expect(initial_packets.size() == 1, "the transport model should own one source packet at connection time")
	if not initial_packets.is_empty():
		_expect(String(initial_packets[0]["packet_id"]).ends_with("#0"), "the first transported Glyph should have a stable sequence identity")
		var transported_glyph = initial_packets[0].get("glyph")
		_expect(
			transported_glyph != null
			and String(initial_packets[0]["canonical_glyph"])
			== prototype.primitive_glyph(&"circle").canonical_serialization(),
			"each conveyor packet should carry the canonical Glyph it visibly transports"
		)
		if transported_glyph != null:
			transported_glyph.components[0].primitive_id = &"square"
			var fresh_packets: Array[Dictionary] = prototype.transport_packets_for_connection(
				circle_source_id,
				relay_id,
				0,
				10.0
			)
			_expect(
				not fresh_packets.is_empty()
				and String(fresh_packets[0]["canonical_glyph"])
				== prototype.primitive_glyph(&"circle").canonical_serialization(),
				"mutating one packet copy must not alias later transport previews"
			)
	_expect(prototype.connect_output_to_input(relay_id, StringName(prototype.summoner_node.name), 0), "a relay output should connect to a summoner input")
	var downstream_flow_start: float = prototype.connection_flow_start_time(
		relay_id,
		StringName(prototype.summoner_node.name),
		0
	)
	_expect(
		is_equal_approx(
			downstream_flow_start,
			upstream_flow_start + prototype.flow_travel_duration(upstream_line_length)
		),
		"a relay conveyor should stay empty until the first upstream Glyph arrives"
	)
	_expect(
		prototype.transport_packets_for_connection(
			relay_id,
			StringName(prototype.summoner_node.name),
			0,
			10.0
		).is_empty(),
		"the downstream transport queue should be empty before the relay receives a Glyph"
	)
	_expect(prototype.summon_state(0) == &"transporting", "a connected relay route should not summon before its first Glyph arrives")
	_expect(prototype.summoned_monster_count(&"ring_wisp") == 0, "connecting a route should not create a monster immediately")
	_advance_input_to_first_arrival(prototype, 0)
	var relay_center: Vector2 = prototype._node_center_in(relay, prototype.factory_graph)
	var relay_input: Vector2 = prototype.directional_node_input_position(relay_id, 0, prototype.factory_graph)
	var relay_output: Vector2 = prototype.directional_output_position(relay_id, prototype.factory_graph)
	_expect(relay_center.direction_to(relay_input).dot(relay_center.direction_to(prototype._node_center_in(circle_source, prototype.factory_graph))) > 0.8, "the relay input should face its actual upstream source")
	_expect(relay_center.direction_to(relay_output).dot(relay_center.direction_to(prototype._node_center_in(prototype.summoner_node, prototype.factory_graph))) > 0.8, "the relay output should face its actual downstream destination")
	_expect(prototype.summon_state(0) == &"matched", "Circle routed through a relay should summon after the Glyph arrives")
	_expect(prototype.summoned_monster_count(&"ring_wisp") == 1, "the first matching arrival should summon exactly one monster")
	_expect(prototype.summon_event_count() == 1, "the first delivered Glyph should create one arrival event")
	_expect(
		String(prototype.summon_events[0]["canonical_glyph"])
		== prototype.target_glyph_for_input(0).canonical_serialization(),
		"summon events should record the same canonical Glyph used for matching"
	)
	var ring_count_before_rewire: int = prototype.summoned_monster_count(&"ring_wisp")
	_expect(
		prototype.connect_output_to_input(StringName(triangle_source.name), relay_id, 0),
		"a relay input should accept a replacement material route"
	)
	_expect(prototype.summon_state(0) == &"transporting", "rewiring an upstream relay input should reset downstream delivery state")
	_advance_input_to_first_arrival(prototype, 0)
	_expect(prototype.summon_state(0) == &"mismatch", "the replacement Glyph should be judged only after traversing the relay")
	_expect(
		prototype.summoned_monster_count(&"ring_wisp") == ring_count_before_rewire,
		"an arriving mismatched Glyph should not summon a monster"
	)
	_expect(prototype.connect_output_to_input(circle_source_id, relay_id, 0), "the relay should reconnect to its matching source")
	_expect(prototype.summon_state(0) == &"transporting", "reconnecting the upstream route should require a fresh delivery")
	_advance_input_to_first_arrival(prototype, 0)
	_expect(prototype.summon_state(0) == &"matched", "the restored relay route should match after its fresh arrival")
	upstream_flow_start = prototype.connection_flow_start_time(circle_source_id, relay_id, 0)
	_expect(prototype.connect_output_to_input(relay_id, StringName(prototype.summoner_node.name), 1), "one relay output should distribute to another downstream input")
	var branch_flow_start: float = prototype.connection_flow_start_time(
		relay_id,
		StringName(prototype.summoner_node.name),
		1
	)
	var upstream_first_arrival: float = upstream_flow_start + prototype.flow_travel_duration(upstream_line_length)
	_expect(branch_flow_start >= prototype.flow_time_override, "a late relay branch should wait for the next available upstream Glyph")
	var branch_phase := fposmod(
		branch_flow_start - upstream_first_arrival,
		prototype.flow_packet_interval()
	)
	_expect(
		is_zero_approx(branch_phase)
		or is_equal_approx(branch_phase, prototype.flow_packet_interval()),
		"a late relay branch should inherit the upstream production phase"
	)
	_expect(prototype.connected_material_kind(1) == &"circle", "distributed relay output should preserve the same Glyph on every branch")
	_expect(prototype.factory_graph.get_connection_list().size() == 3, "relay routing should contain one upstream and two downstream connections")
	prototype.disconnect_summoner(0)
	prototype.disconnect_summoner(1)
	prototype.disconnect_input(relay_id, 0)
	_expect(prototype.factory_graph.get_connection_list().is_empty(), "relay test connections should disconnect independently")
	var second_relay: GraphNode = prototype.place_relay_at(Vector2(5800.0, 4500.0))
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
		var arrival_sound_before_delivery: int = prototype.flow_audio.arrival_play_count
		var ring_wisps_before_direct: int = prototype.summoned_monster_count(&"ring_wisp")
		prototype.factory_graph.connection_request.emit(
			StringName(circle_source.name),
			0,
			StringName(prototype.summoner_node.name),
			0
		)
		_expect(prototype.flow_audio.connection_play_count == connection_sound_count + 1, "a completed connection should play one short connection sound")
		_expect(prototype.summon_state(0) == &"transporting", "a direct connection should remain in transport before arrival")
		_expect(prototype.summoned_monster_count(&"ring_wisp") == ring_wisps_before_direct, "a direct connection should not summon on contact")
		_expect(prototype.flow_audio.arrival_play_count == arrival_sound_before_delivery, "a connection should not play its arrival sound early")
		var direct_line_start: Vector2 = prototype.directional_output_position(
			StringName(circle_source.name),
			prototype.factory_graph
		)
		var direct_line_finish: Vector2 = prototype.directional_input_position(0, prototype.factory_graph)
		var direct_line_midpoint := direct_line_start.lerp(direct_line_finish, 0.5)
		var direct_line_hit: Dictionary = prototype.directional_connection_at(direct_line_midpoint)
		_expect(
			StringName(direct_line_hit.get("from_node", &"")) == StringName(circle_source.name)
			and StringName(direct_line_hit.get("to_node", &"")) == StringName(prototype.summoner_node.name),
			"the visible directional line should be a stable hover and interaction target"
		)
		var direct_line_hover := InputEventMouseMotion.new()
		direct_line_hover.position = direct_line_midpoint
		prototype.factory_graph.gui_input.emit(direct_line_hover)
		_expect(
			prototype.hovered_connection_key != ""
			and "距離" in prototype.factory_graph.tooltip_text
			and "初回" in prototype.factory_graph.tooltip_text
			and "間隔" in prototype.factory_graph.tooltip_text,
			"hovering a conveyor should reveal its distance, first travel time, and fixed interval"
		)
		prototype.factory_graph.mouse_exited.emit()
		_expect(
			prototype.hovered_connection_key == "" and prototype.factory_graph.tooltip_text.is_empty(),
			"leaving the factory board should clear the temporary conveyor inspection state"
		)
		prototype.factory_graph.gui_input.emit(direct_line_hover)
		var direct_line_cut := InputEventMouseButton.new()
		direct_line_cut.button_index = MOUSE_BUTTON_RIGHT
		direct_line_cut.pressed = true
		direct_line_cut.position = direct_line_midpoint
		direct_line_cut.global_position = Vector2(640.0, 420.0)
		var direct_disconnect_sound_count: int = prototype.flow_audio.disconnect_play_count
		prototype.factory_graph.gui_input.emit(direct_line_cut)
		_expect(
			prototype.line_settings_popup.visible
			and not prototype.line_settings_connection.is_empty()
			and "距離" in prototype.line_settings_details.text,
			"right-clicking the visible conveyor should open its individual menu"
		)
		_expect(prototype.summon_state(0) == &"transporting", "opening a conveyor menu must not delete that route")
		_expect(prototype.flow_audio.disconnect_play_count == direct_disconnect_sound_count, "opening a conveyor menu must not play a deletion sound")
		prototype.line_settings_delete_button.pressed.emit()
		_expect(prototype.summon_state(0) == &"idle", "choosing delete in the conveyor menu should remove only that route")
		_expect(prototype.flow_audio.disconnect_play_count == direct_disconnect_sound_count + 1, "deleting from the conveyor menu should play one disconnect sound")
		_expect(prototype.hovered_connection_key == "", "disconnecting a hovered conveyor should clear its stale highlight")
		_expect(
			prototype.connect_material_to_summoner(StringName(circle_source.name), 0),
			"a line removed from its body should be reconnectable through the same source output"
		)
		var direct_first_arrival: float = prototype.summoner_arrival_time(0, 0)
		var direct_seconds_remaining: float = prototype.transport_seconds_until_first_arrival(
			0,
			prototype.flow_time_override
		)
		_expect(direct_seconds_remaining > 0.0, "a newly connected input should expose a positive first-delivery ETA")
		prototype._refresh_transport_countdown(prototype.flow_time_override)
		_expect(
			("%.1fs" % direct_seconds_remaining) in prototype.summon_state_label.text,
			"the selected input should show its first-delivery ETA while transporting"
		)
		var halfway_time := lerpf(prototype.flow_time_override, direct_first_arrival, 0.5)
		var halfway_remaining: float = prototype.transport_seconds_until_first_arrival(0, halfway_time)
		prototype._refresh_transport_countdown(halfway_time)
		_expect(
			halfway_remaining < direct_seconds_remaining
			and ("%.1fs" % halfway_remaining) in prototype.summon_state_label.text,
			"the transport ETA should count down against conveyor travel instead of line progress"
		)
		_advance_input_to_first_arrival(prototype, 0)
		_expect(prototype.flow_audio.arrival_play_count == arrival_sound_before_delivery + 1, "the first delivered Glyph should play one arrival sound")
	_expect(circle_source != null and prototype.connected_material_kind() == &"circle", "dragging a Circle deposit output should connect directly to the summoner")
	_expect(prototype.summon_state() == &"matched", "matching Circle should start summoning after arrival")
	_expect("環霊ウィスプ" in prototype.summon_state_label.text, "the Circle summon state should name its monster")
	var direct_ring_count: int = prototype.summoned_monster_count(&"ring_wisp")
	prototype.flow_time_override += prototype.flow_packet_interval() * 2.0 + 0.001
	prototype.process_transport_at(prototype.flow_time_override)
	_expect(
		prototype.summoned_monster_count(&"ring_wisp") == direct_ring_count + 2,
		"each subsequent delivered Glyph should summon one additional monster"
	)

	_click_input(prototype, 1)
	_expect(prototype.selected_input_index == 1, "clicking summoner input 2 should select it")
	_expect(prototype.selected_target_kind == &"triangle" and prototype.target_monster_id() == &"stinger", "the panel should switch to input 2's Triangle target")
	_expect(triangle_source != null and prototype.connect_material_to_summoner(StringName(triangle_source.name), 1), "a Triangle deposit should connect independently to input 2")
	_expect(prototype.summon_state(1) == &"transporting", "input 2 should wait for its own first delivery")
	_advance_input_to_first_arrival(prototype, 1)
	_expect(prototype.summon_state(0) == &"matched" and prototype.summon_state(1) == &"matched", "inputs 1 and 2 should judge their own sigils independently")

	_click_input(prototype, 2)
	_expect(prototype.selected_input_index == 2, "clicking summoner input 3 should select it")
	_expect(prototype.selected_target_kind == &"square" and prototype.target_monster_id() == &"stone_block", "the panel should switch to input 3's Square target")
	_expect(square_source != null and prototype.connect_material_to_summoner(StringName(square_source.name), 2), "a Square deposit should connect independently to input 3")
	_expect(prototype.summon_state(2) == &"transporting", "input 3 should wait for its own first delivery")
	_advance_input_to_first_arrival(prototype, 2)
	_expect(prototype.factory_graph.get_connection_list().size() == 3, "the summoner should retain one connection per input")
	_expect(prototype.summoning_monsters() == [&"ring_wisp", &"stinger", &"stone_block"], "all three matching inputs should summon their own monsters")

	_click_input(prototype, 1)
	_expect(prototype.select_target(&"square"), "the selected input 2 target should be independently configurable")
	_expect(prototype.summon_state(0) == &"matched", "changing input 2 must not change input 1's result")
	_expect(prototype.summon_state(1) == &"mismatch", "input 2 should re-evaluate against its new target")
	_expect(prototype.summon_state(2) == &"matched", "changing input 2 must not change input 3's result")
	_expect("INPUT 2" in prototype.target_header_label.text and prototype.selected_target_kind == &"square", "the target panel should show the selected input's target")
	_expect(square_source != null and prototype.connect_material_to_summoner(StringName(square_source.name), 1), "reconnecting input 2 should replace only that input")
	_expect(prototype.summon_state(1) == &"transporting", "replacing an input should discard the old delivery state")
	_advance_input_to_first_arrival(prototype, 1)
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
	var disconnected_input_events := _summon_event_count_for_input(prototype, 2)
	prototype.flow_time_override += prototype.flow_packet_interval() * 2.0
	prototype.process_transport_at(prototype.flow_time_override)
	_expect(prototype.summon_state(2) == &"idle", "disconnecting input 3 should stop only that input")
	_expect(
		_summon_event_count_for_input(prototype, 2) == disconnected_input_events,
		"disconnecting a line should remove its transported Glyphs and stop later arrivals"
	)
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
	_expect(prototype.summon_state(2) == &"transporting", "clicking an all-direction input should start transport")
	_advance_input_to_first_arrival(prototype, 2)
	_expect(prototype.summon_state(2) == &"matched", "the all-direction input should summon after delivery")
	var disconnect_click := InputEventMouseButton.new()
	disconnect_click.button_index = MOUSE_BUTTON_RIGHT
	disconnect_click.pressed = true
	disconnect_click.position = prototype.directional_input_position(2, prototype.factory_graph)
	disconnect_click.global_position = Vector2(760.0, 520.0)
	var disconnect_sound_count: int = prototype.flow_audio.disconnect_play_count
	prototype.factory_graph.gui_input.emit(disconnect_click)
	_expect(prototype.selected_input_index == 2, "right-clicking an input should keep its target selected")
	_expect(prototype.line_settings_popup.visible, "right-clicking a connected input should open the same conveyor menu")
	_expect(prototype.summon_state(2) == &"matched", "opening the input's conveyor menu must preserve its route")
	prototype.line_settings_delete_button.pressed.emit()
	_expect(prototype.summon_state(2) == &"idle", "choosing delete from an input's menu should disconnect only that input")
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

	var relay_menu_click := InputEventMouseButton.new()
	relay_menu_click.button_index = MOUSE_BUTTON_RIGHT
	relay_menu_click.pressed = true
	relay_menu_click.position = prototype._convert_control_point(
		prototype.factory_graph,
		prototype._node_center_in(relay, prototype.factory_graph),
		relay
	)
	relay_menu_click.global_position = Vector2(580.0, 360.0)
	relay.gui_input.emit(relay_menu_click)
	_expect(
		prototype.relay_settings_popup.visible
		and prototype.relay_settings_node_id == relay_id
		and prototype.relay_settings_delete_button != null,
		"right-clicking a relay body should open its individual menu with deletion"
	)
	prototype.relay_settings_delete_button.pressed.emit()
	await process_frame
	_expect(
		prototype.relay_nodes.size() == 1
		and StringName(prototype.relay_nodes[0].name) == second_relay_id,
		"deleting from the relay menu should remove only that player-built node"
	)
	_expect("中継 1" in prototype.status_label.text, "deleting a relay should refresh the factory equipment count")
	_expect(prototype.fixed_landmark_count() == 31, "deleting player equipment must not remove fixed landmarks")

	prototype.queue_free()
	await process_frame


func _test_processed_rotation_target() -> void:
	var prototype = FactoryPrototypeScene.instantiate()
	root.add_child(prototype)
	await process_frame
	await process_frame
	prototype.flow_time_override = 0.0
	var square_source := _first_material(prototype, &"square")
	var rotation = prototype.place_rotation_at(Vector2(3900.0, 2450.0), 45)
	var rotation_id := StringName(rotation.name)
	prototype.select_input(2)
	_expect(prototype.select_target(&"diamond"), "the processed Diamond target should be selectable per input")
	_expect(prototype.target_monster_id(2) == &"razor_kite", "Diamond should select the first processed-Sigil monster")
	_expect(
		prototype.connect_output_to_input(StringName(square_source.name), rotation_id, 0),
		"Square should connect to the rotation processor"
	)
	_expect(
		prototype.connect_output_to_input(rotation_id, StringName(prototype.summoner_node.name), 2),
		"a rotation output should connect to a summoner input"
	)
	_expect(prototype.summon_state(2) == &"transporting", "the rotated Glyph should travel before it is judged")
	_advance_input_to_first_arrival(prototype, 2)
	_expect(prototype.summon_state(2) == &"matched", "Square rotated by 45 degrees should match Diamond")
	var razor_kites_after_match: int = prototype.summoned_monster_count(&"razor_kite")
	_expect(razor_kites_after_match == 1, "the first matching processed Glyph should summon one Razor Kite")
	var processed_event: Dictionary = prototype.summon_events.back()
	_expect(
		String(processed_event.get("canonical_glyph", ""))
		== prototype.target_glyph(&"diamond").canonical_serialization(),
		"the summon event should retain the same canonical processed Glyph shown on the conveyor"
	)
	_expect(not prototype.set_rotation_angle(rotation_id, 37), "an active processor should reject a non-preset angle")
	_expect(prototype.summon_state(2) == &"matched", "a rejected angle must not restart or change the active route")
	_expect(prototype.set_rotation_angle(rotation_id, 60), "an active processor should accept another exact preset")
	_expect(prototype.summon_state(2) == &"transporting", "changing an active processor should restart only its downstream delivery")
	_advance_input_to_first_arrival(prototype, 2)
	_expect(prototype.summon_state(2) == &"mismatch", "a 60 degree Square should not match the 45 degree Diamond")
	_expect(prototype.summoned_monster_count(&"razor_kite") == razor_kites_after_match, "a mismatched processed Glyph must not summon")
	_expect(prototype.set_rotation_angle(rotation_id, 45), "the rotation should return to the target angle")
	_advance_input_to_first_arrival(prototype, 2)
	_expect(prototype.summon_state(2) == &"matched", "restoring 45 degrees should restore the processed recipe")
	var rotation_menu_click := InputEventMouseButton.new()
	rotation_menu_click.button_index = MOUSE_BUTTON_RIGHT
	rotation_menu_click.pressed = true
	rotation_menu_click.position = prototype._convert_control_point(
		prototype.factory_graph,
		prototype._node_center_in(rotation, prototype.factory_graph),
		rotation
	)
	rotation_menu_click.global_position = Vector2(620.0, 360.0)
	rotation.gui_input.emit(rotation_menu_click)
	_expect(
		prototype.rotation_settings_popup.visible
		and prototype.rotation_settings_delete_button != null,
		"the rotation menu should include deletion beside its angle setting"
	)
	prototype.rotation_settings_delete_button.pressed.emit()
	await process_frame
	_expect(prototype.rotation_nodes.is_empty(), "deleting from the rotation menu should remove the processor")
	_expect(prototype.factory_graph.get_connection_list().is_empty(), "deleting a processor should remove all of its attached conveyors")
	_expect(prototype.summon_state(2) == &"idle", "deleting a connected processor should clear its downstream summon state")
	_expect("回転 0" in prototype.status_label.text, "deleting a rotation node should refresh the equipment count")
	prototype.queue_free()
	await process_frame


func _test_move_processing_node() -> void:
	var prototype = FactoryPrototypeScene.instantiate()
	root.add_child(prototype)
	await process_frame
	await process_frame
	prototype.flow_time_override = 0.0
	_expect(
		prototype.move_button != null and prototype.move_button.text == "＋ 移動",
		"the toolbar should expose cardinal move-node placement"
	)
	var square_source := _first_material(prototype, &"square")
	var move_node = prototype.place_move_at(Vector2(3900.0, 2450.0), Vector2i(0, -3))
	var move_id := StringName(move_node.name)
	_expect(
		move_node.draggable
		and prototype.move_offset(move_id) == Vector2i(0, -3)
		and "移動 1" in prototype.status_label.text,
		"a move node should retain its cardinal one-unit-step offset"
	)
	_expect(
		not prototype.set_move_offset(move_id, Vector2i(1, 1))
		and not prototype.set_move_offset(move_id, Vector2i(0, -7))
		and prototype.move_offset(move_id) == Vector2i(0, -3),
		"diagonal and out-of-range move settings should fail closed"
	)
	_expect(
		prototype.connect_output_to_input(StringName(square_source.name), move_id, 0),
		"a material should connect to the move input"
	)
	var source_glyph: Object = prototype.primitive_glyph(&"square")
	var moved_glyph: Object = prototype.output_glyph(move_id)
	_expect(
		moved_glyph.canonical_serialization()
		== source_glyph.translated(Vector2i(0, -3)).canonical_serialization(),
		"the move processor should return a translated Glyph"
	)
	_expect(
		source_glyph.components[0].position == Vector2.ZERO,
		"move processing should not mutate the source Glyph"
	)
	prototype.select_input(1)
	prototype.select_target(&"square")
	_expect(
		prototype.connect_output_to_input(move_id, StringName(prototype.summoner_node.name), 1),
		"a moved output should connect to a summoner input"
	)
	_advance_input_to_first_arrival(prototype, 1)
	_expect(prototype.summon_state(1) == &"mismatch", "a translated Square should not match the centered Square")

	var menu_click := InputEventMouseButton.new()
	menu_click.button_index = MOUSE_BUTTON_RIGHT
	menu_click.pressed = true
	menu_click.position = prototype._convert_control_point(
		prototype.factory_graph,
		prototype._node_center_in(move_node, prototype.factory_graph),
		move_node
	)
	menu_click.global_position = Vector2(620.0, 360.0)
	move_node.gui_input.emit(menu_click)
	_expect(
		prototype.move_settings_popup.visible
		and prototype.move_settings_node_id == move_id
		and prototype.move_settings_direction_buttons[0].button_pressed
		and prototype.move_settings_distance.get_item_id(
			prototype.move_settings_distance.selected
		) == 3,
		"right-clicking a move node should expose direction and exact distance"
	)
	prototype.move_settings_direction_buttons[1].pressed.emit()
	var distance_two_index: int = prototype.move_settings_distance.get_item_index(2)
	prototype.move_settings_distance.select(distance_two_index)
	prototype.move_settings_distance.item_selected.emit(distance_two_index)
	_expect(
		prototype.move_offset(move_id) == Vector2i(2, 0)
		and prototype.output_glyph(move_id).canonical_serialization()
		== source_glyph.translated(Vector2i(2, 0)).canonical_serialization(),
		"the settings menu should apply rightward two-unit movement deterministically"
	)
	_expect(prototype.summon_state(1) == &"transporting", "changing movement should restart downstream transport")

	prototype.move_settings_delete_button.pressed.emit()
	await process_frame
	_expect(prototype.move_nodes.is_empty(), "the move-node menu should delete that processor")
	_expect(prototype.factory_graph.get_connection_list().is_empty(), "deleting a move node should remove attached conveyors")
	_expect(prototype.summon_state(1) == &"idle", "deleting a move node should clear downstream summon state")
	prototype.queue_free()
	await process_frame


func _test_scale_processing_node() -> void:
	var prototype = FactoryPrototypeScene.instantiate()
	root.add_child(prototype)
	await process_frame
	await process_frame
	prototype.flow_time_override = 0.0
	_expect(
		prototype.scale_button != null and prototype.scale_button.text == "＋ 変形",
		"the toolbar should expose stepped scale-node placement"
	)
	var square_source := _first_material(prototype, &"square")
	var scale = prototype.place_scale_at(Vector2(3900.0, 2450.0), 200, 50)
	var scale_id := StringName(scale.name)
	_expect(
		scale.draggable
		and prototype.scale_percent(scale_id) == Vector2i(200, 50)
		and "変形 1" in prototype.status_label.text,
		"a scale node should use the requested presets and update the equipment count"
	)
	_expect(
		not prototype.set_scale_percent(scale_id, 125, 50)
		and prototype.scale_percent(scale_id) == Vector2i(200, 50),
		"non-preset stretch values should fail closed"
	)
	_expect(
		prototype.connect_output_to_input(StringName(square_source.name), scale_id, 0),
		"a material should connect to the scale input from any direction"
	)
	prototype.select_input(1)
	_expect(prototype.select_target(&"square"), "the scale test input should target the original Square")
	_expect(
		prototype.connect_output_to_input(scale_id, StringName(prototype.summoner_node.name), 1),
		"a scaled output should connect to a summoner input"
	)
	var expected_stretched: Object = prototype.primitive_glyph(&"square").stretched_percent(200, 50)
	_expect(
		prototype.output_glyph(scale_id).canonical_serialization()
		== expected_stretched.canonical_serialization(),
		"the scale processor should return a new deterministically stretched Glyph"
	)
	_advance_input_to_first_arrival(prototype, 1)
	_expect(prototype.summon_state(1) == &"mismatch", "a stretched rectangle should not match the original Square")

	var menu_click := InputEventMouseButton.new()
	menu_click.button_index = MOUSE_BUTTON_RIGHT
	menu_click.pressed = true
	menu_click.position = prototype._convert_control_point(
		prototype.factory_graph,
		prototype._node_center_in(scale, prototype.factory_graph),
		scale
	)
	menu_click.global_position = Vector2(620.0, 360.0)
	scale.gui_input.emit(menu_click)
	_expect(
		prototype.scale_settings_popup.visible
		and prototype.scale_settings_node_id == scale_id
		and prototype.scale_settings_x.get_item_id(prototype.scale_settings_x.selected) == 200
		and prototype.scale_settings_y.get_item_id(prototype.scale_settings_y.selected) == 50
		and prototype.scale_settings_x.get_item_icon(0) != null,
		"right-clicking a scale node should open shape-backed preset controls"
	)
	var x_100_index: int = prototype.scale_settings_x.get_item_index(100)
	var y_100_index: int = prototype.scale_settings_y.get_item_index(100)
	prototype.scale_settings_x.select(x_100_index)
	prototype.scale_settings_x.item_selected.emit(x_100_index)
	prototype.scale_settings_y.select(y_100_index)
	prototype.scale_settings_y.item_selected.emit(y_100_index)
	_expect(
		prototype.scale_percent(scale_id) == Vector2i(100, 100)
		and prototype.output_glyph(scale_id).canonical_serialization()
		== prototype.primitive_glyph(&"square").canonical_serialization(),
		"selecting the 100 percent presets should restore the exact source Glyph"
	)
	_expect(prototype.summon_state(1) == &"transporting", "changing a scale preset should restart downstream transport")
	_advance_input_to_first_arrival(prototype, 1)
	_expect(prototype.summon_state(1) == &"matched", "the restored 100 percent Square should summon after arrival")

	prototype.scale_settings_delete_button.pressed.emit()
	await process_frame
	_expect(prototype.scale_nodes.is_empty(), "the scale-node menu should delete that processor")
	_expect(prototype.factory_graph.get_connection_list().is_empty(), "deleting a scale node should remove attached conveyors")
	_expect(prototype.summon_state(1) == &"idle", "deleting a scale node should clear downstream summon state")
	_expect("変形 0" in prototype.status_label.text, "deleting a scale node should refresh the equipment count")
	prototype.queue_free()
	await process_frame


func _test_repeat_processing_node() -> void:
	var prototype = FactoryPrototypeScene.instantiate()
	root.add_child(prototype)
	await process_frame
	await process_frame
	prototype.flow_time_override = 0.0
	_expect(
		prototype.repeat_button != null and prototype.repeat_button.text == "＋ 反復",
		"the toolbar should expose radial repeat placement"
	)
	var triangle_source := _first_material(prototype, &"triangle")
	var move_node = prototype.place_move_at(Vector2(3500.0, 2450.0), Vector2i(4, 0))
	var repeat_node = prototype.place_repeat_at(Vector2(3900.0, 2450.0), 3)
	var move_id := StringName(move_node.name)
	var repeat_id := StringName(repeat_node.name)
	_expect(
		repeat_node.draggable
		and prototype.repeat_count(repeat_id) == 3
		and "反復 1" in prototype.status_label.text,
		"a repeat node should use its requested preset and update the equipment count"
	)
	_expect(
		not prototype.set_repeat_count(repeat_id, 7)
		and prototype.repeat_count(repeat_id) == 3,
		"a non-preset repeat count should fail closed"
	)
	prototype.connect_output_to_input(StringName(triangle_source.name), move_id, 0)
	prototype.connect_output_to_input(move_id, repeat_id, 0)
	var moved_triangle = prototype.primitive_glyph(&"triangle").translated(Vector2i(4, 0))
	var expected_three = prototype.GlyphModelScript.radial_array(
		moved_triangle,
		3,
		4,
		0,
		prototype.GlyphModelScript.FACING_RADIAL,
		prototype.GlyphModelScript.CONNECTION_NONE
	)
	_expect(
		prototype.output_glyph(repeat_id).canonical_serialization()
		== expected_three.canonical_serialization(),
		"repeat should apply equal-angle copies around the shared origin without mutating its input"
	)
	_expect(
		prototype.output_glyph(move_id).canonical_serialization()
		== moved_triangle.canonical_serialization(),
		"repeat should preserve the upstream Glyph value"
	)

	var menu_click := InputEventMouseButton.new()
	menu_click.button_index = MOUSE_BUTTON_RIGHT
	menu_click.pressed = true
	menu_click.position = prototype._convert_control_point(
		prototype.factory_graph,
		prototype._node_center_in(repeat_node, prototype.factory_graph),
		repeat_node
	)
	menu_click.global_position = Vector2(620.0, 350.0)
	repeat_node.gui_input.emit(menu_click)
	_expect(
		prototype.repeat_settings_popup.visible
		and prototype.repeat_settings_node_id == repeat_id
		and prototype.repeat_settings_count.get_item_id(
			prototype.repeat_settings_count.selected
		) == 3,
		"right-clicking a repeat node should expose its repeat count"
	)
	_expect(
		prototype.repeat_settings_radius.get_item_id(prototype.repeat_settings_radius.selected) == 4
		and prototype.repeat_settings_phase.selected == 0
		and prototype.repeat_settings_facing.selected == 1
		and prototype.repeat_settings_link.selected == 0,
		"the repeat menu should expose radius, phase, facing, and link settings"
	)
	var six_index: int = prototype.repeat_settings_count.get_item_index(6)
	prototype.repeat_settings_count.select(six_index)
	prototype.repeat_settings_count.item_selected.emit(six_index)
	var expected_six = prototype.GlyphModelScript.radial_array(
		moved_triangle,
		6,
		4,
		0,
		prototype.GlyphModelScript.FACING_RADIAL,
		prototype.GlyphModelScript.CONNECTION_NONE
	)
	_expect(
		prototype.repeat_count(repeat_id) == 6
		and prototype.output_glyph(repeat_id).canonical_serialization()
		== expected_six.canonical_serialization(),
		"the repeat menu should deterministically change the radial count"
	)
	_expect(
		prototype.set_repeat_layout(
			repeat_id,
			3,
			4,
			&"base",
			prototype.GlyphModelScript.FACING_RADIAL,
			prototype.GlyphModelScript.CONNECTION_RADIAL
		),
		"the repeat node should accept a complete radial-layer setting"
	)
	var triad_combine = prototype.place_combine_at(
		Vector2(4300.0, 2450.0),
		prototype.GlyphModelScript.CONNECTION_SIMPLE
	)
	var triad_combine_id := StringName(triad_combine.name)
	var centered_circle_source := _first_material(prototype, &"circle")
	prototype.connect_output_to_input(StringName(centered_circle_source.name), triad_combine_id, 0)
	prototype.connect_output_to_input(repeat_id, triad_combine_id, 1)
	_expect(
		prototype.output_glyph(triad_combine_id).canonical_serialization()
		== prototype.target_glyph(&"triad").canonical_serialization(),
		"a player-built radial branch and center core should exactly reproduce the Triad target"
	)

	var no_op_repeat = prototype.place_repeat_at(
		Vector2(3900.0, 2800.0),
		8,
		0,
		&"base",
		prototype.GlyphModelScript.FACING_FIXED,
		prototype.GlyphModelScript.CONNECTION_NONE
	)
	var no_op_id := StringName(no_op_repeat.name)
	prototype.connect_output_to_input(StringName(centered_circle_source.name), no_op_id, 0)
	_expect(
		prototype.output_glyph(no_op_id) != null
		and prototype.output_glyph(no_op_id).canonical_serialization()
		== prototype.primitive_glyph(&"circle").canonical_serialization(),
		"a rotationally symmetric center overlap should remain a valid no-op repeat"
	)
	_expect(
		not prototype.connect_output_to_input(repeat_id, move_id, 0),
		"a repeated output should not reconnect into its upstream branch"
	)

	prototype.repeat_settings_delete_button.pressed.emit()
	await process_frame
	_expect(prototype._repeat_node(repeat_id) == null, "the repeat menu should delete that processor")
	_expect(
		prototype._repeat_node(no_op_id) != null and "反復 1" in prototype.status_label.text,
		"deleting one repeat node should retain unrelated repeat equipment"
	)
	prototype.queue_free()
	await process_frame


func _test_combine_processing_node() -> void:
	var prototype = FactoryPrototypeScene.instantiate()
	root.add_child(prototype)
	await process_frame
	await process_frame
	prototype.flow_time_override = 0.0
	_expect(
		prototype.combine_button != null and prototype.combine_button.text == "＋ 合成",
		"the toolbar should expose eight-input combine placement"
	)
	var square_source := _first_material(prototype, &"square")
	var horizontal = prototype.place_scale_at(Vector2(3400.0, 2350.0), 100, 25)
	var vertical = prototype.place_scale_at(Vector2(3400.0, 2700.0), 25, 100)
	var combine_node = prototype.place_combine_at(
		Vector2(3900.0, 2525.0),
		prototype.GlyphModelScript.CONNECTION_SIMPLE
	)
	var horizontal_id := StringName(horizontal.name)
	var vertical_id := StringName(vertical.name)
	var combine_id := StringName(combine_node.name)
	_expect(
		prototype._valid_input_port(combine_id, 0)
		and prototype._valid_input_port(combine_id, 7)
		and not prototype._valid_input_port(combine_id, 8),
		"a combine node should expose exactly eight all-direction inputs"
	)
	prototype.connect_output_to_input(StringName(square_source.name), horizontal_id, 0)
	prototype.connect_output_to_input(StringName(square_source.name), vertical_id, 0)
	_expect(
		prototype.connect_output_to_input(horizontal_id, combine_id, 0)
		and prototype.connect_output_to_input(vertical_id, combine_id, 4),
		"two branched processors should connect to separate combine inputs"
	)
	var combined_glyph: Object = prototype.output_glyph(combine_id)
	var square_glyph: Object = prototype.primitive_glyph(&"square")
	var expected_overlap: Object = prototype.GlyphModelScript.combine_many(
		[square_glyph.stretched_percent(100, 25), square_glyph.stretched_percent(25, 100)],
		prototype.GlyphModelScript.CONNECTION_SIMPLE
	)
	_expect(
		combined_glyph != null
		and combined_glyph.canonical_serialization() == expected_overlap.canonical_serialization(),
		"simple combine should overlap both stretched branches without mutating either branch"
	)
	var availability: Dictionary = prototype.combine_mode_availability(combine_id)
	_expect(
		availability["complete"]
		and availability["modes"][prototype.GlyphModelScript.CONNECTION_SIMPLE]
		and not availability["modes"][prototype.GlyphModelScript.CONNECTION_RADIAL]
		and not availability["modes"][prototype.GlyphModelScript.CONNECTION_PAIRWISE],
		"overlapping children should allow only line-free Simple Combine"
	)
	_expect(
		not prototype.set_combine_connection_mode(
			combine_id,
			prototype.GlyphModelScript.CONNECTION_RADIAL
		),
		"a line mode with no visible connector should fail closed"
	)

	var menu_click := InputEventMouseButton.new()
	menu_click.button_index = MOUSE_BUTTON_RIGHT
	menu_click.pressed = true
	menu_click.position = prototype._convert_control_point(
		prototype.factory_graph,
		prototype._node_center_in(combine_node, prototype.factory_graph),
		combine_node
	)
	menu_click.global_position = Vector2(620.0, 350.0)
	combine_node.gui_input.emit(menu_click)
	_expect(
		prototype.combine_settings_popup.visible
		and prototype.combine_settings_node_id == combine_id
		and prototype.combine_settings_mode.selected == 0
		and prototype.combine_settings_mode.is_item_disabled(1)
		and prototype.combine_settings_mode.is_item_disabled(2)
		and prototype.combine_settings_mode.get_item_icon(0) != null,
		"the combine menu should show icons and disable invisible connection modes"
	)

	prototype.select_input(2)
	prototype.select_target(&"square")
	_expect(
		prototype.connect_output_to_input(
			combine_id,
			StringName(prototype.summoner_node.name),
			2
		),
		"a combined output should connect to the summoner"
	)
	var combine_flow_start: float = prototype.connection_flow_start_time(
		combine_id,
		StringName(prototype.summoner_node.name),
		2
	)
	var horizontal_arrival: float = prototype.connection_flow_start_time(
		horizontal_id,
		combine_id,
		0
	) + prototype.flow_travel_duration(
		prototype.connection_world_length(horizontal_id, combine_id, 0)
	)
	var vertical_arrival: float = prototype.connection_flow_start_time(
		vertical_id,
		combine_id,
		4
	) + prototype.flow_travel_duration(
		prototype.connection_world_length(vertical_id, combine_id, 4)
	)
	_expect(
		combine_flow_start >= maxf(horizontal_arrival, vertical_arrival),
		"combine transport should wait until every connected input has arrived"
	)
	_expect(
		not prototype.connect_output_to_input(combine_id, horizontal_id, 0),
		"a combine output should not reconnect into its own upstream branch"
	)

	prototype.combine_settings_delete_button.pressed.emit()
	await process_frame
	_expect(prototype.combine_nodes.is_empty(), "the combine menu should delete that processor")
	_expect(
		prototype.factory_graph.get_connection_list().size() == 2,
		"deleting a combine node should keep only the two independent source branches"
	)
	_expect(prototype.summon_state(2) == &"idle", "deleting a combine should clear downstream summon state")

	var circle_source := _first_material(prototype, &"circle")
	var move_left = prototype.place_move_at(Vector2(4100.0, 2300.0), Vector2i(-6, 0))
	var move_right = prototype.place_move_at(Vector2(4100.0, 2750.0), Vector2i(6, 0))
	var spaced_combine = prototype.place_combine_at(Vector2(4500.0, 2525.0))
	var move_left_id := StringName(move_left.name)
	var move_right_id := StringName(move_right.name)
	var spaced_combine_id := StringName(spaced_combine.name)
	prototype.connect_output_to_input(StringName(circle_source.name), move_left_id, 0)
	prototype.connect_output_to_input(StringName(circle_source.name), move_right_id, 0)
	prototype.connect_output_to_input(move_left_id, spaced_combine_id, 2)
	prototype.connect_output_to_input(move_right_id, spaced_combine_id, 6)
	var spaced_availability: Dictionary = prototype.combine_mode_availability(spaced_combine_id)
	_expect(
		spaced_availability["modes"][prototype.GlyphModelScript.CONNECTION_RADIAL]
		and spaced_availability["modes"][prototype.GlyphModelScript.CONNECTION_PAIRWISE]
		and prototype.set_combine_connection_mode(
			spaced_combine_id,
			prototype.GlyphModelScript.CONNECTION_PAIRWISE
		)
		and prototype.output_glyph(spaced_combine_id).combine_connection_mode
		== prototype.GlyphModelScript.CONNECTION_PAIRWISE,
		"spatially separated children should enable visible center and pairwise connections"
	)
	_expect(
		prototype.set_move_offset(move_right_id, Vector2i(-6, 0))
		and prototype.combine_connection_mode(spaced_combine_id)
		== prototype.GlyphModelScript.CONNECTION_SIMPLE,
		"an upstream change that removes every connector should normalize back to Simple Combine"
	)
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


func _advance_input_to_first_arrival(prototype, input_index: int) -> void:
	var first_arrival: float = prototype.summoner_arrival_time(input_index, 0)
	_expect(not is_inf(first_arrival), "input %d should expose a finite first arrival" % (input_index + 1))
	if is_inf(first_arrival):
		return
	prototype.flow_time_override = first_arrival + 0.001
	prototype.process_transport_at(prototype.flow_time_override)


func _summon_event_count_for_input(prototype, input_index: int) -> int:
	var count := 0
	for event in prototype.summon_events:
		if int(event["input_index"]) == input_index:
			count += 1
	return count
