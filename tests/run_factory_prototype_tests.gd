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

	_expect(prototype.factory_graph != null, "the prototype should expose a wide GraphEdit playfield")
	_expect(prototype.PLAYFIELD_SIZE == Vector2(9000.0, 6000.0), "the available playfield should support a large map")
	_expect(prototype.material_nodes.size() == 30, "material deposits should be scattered across the large map")
	_expect(prototype.fixed_landmark_count() == 31, "thirty material deposits and one summoner should be fixed landmarks")
	_expect(prototype.all_landmarks_locked(), "material nodes and the summoner should not be draggable")
	_expect(prototype.factory_graph.minimap_enabled, "a minimap should support navigation across the large map")
	_expect(prototype.factory_graph.zoom <= 0.40, "the initial camera should show the wider inner deposit ring")
	_expect(prototype.summoner_node.position_offset == prototype.SUMMONER_POSITION, "the summoner should remain at the factory center")
	_expect(prototype.summoner_node.get_meta("landmark_kind") == &"summoner", "the center landmark should be identifiable as the summoner")

	var counts: Dictionary = prototype.material_kind_counts()
	_expect(counts[&"circle"] == 10, "ten Circle material deposits should exist")
	_expect(counts[&"triangle"] == 10, "ten Triangle material deposits should exist")
	_expect(counts[&"square"] == 10, "ten Square material deposits should exist")
	_expect(prototype.target_panel != null and prototype.target_panel.anchor_left == 1.0, "the target sigil panel should stay at the upper right")
	_expect(prototype.target_buttons.size() == 3, "Circle, Triangle, and Square should be selectable targets")
	_expect(prototype.selected_target_kind == &"circle", "Circle should be the initial target")
	_expect(prototype.target_monster_id() == &"ring_wisp", "Circle should summon the Ring Wisp")
	_expect(prototype.summon_state() == &"idle", "the summoner should start disconnected")

	var circle_source := _first_material(prototype, &"circle")
	var triangle_source := _first_material(prototype, &"triangle")
	var square_source := _first_material(prototype, &"square")
	if circle_source != null:
		prototype.factory_graph.connection_request.emit(
			StringName(circle_source.name),
			0,
			StringName(prototype.summoner_node.name),
			0
		)
	_expect(circle_source != null and prototype.connected_material_kind() == &"circle", "dragging a Circle deposit output should connect directly to the summoner")
	_expect(prototype.summon_state() == &"matched", "matching Circle should start summoning")
	_expect("環霊ウィスプ" in prototype.summon_state_label.text, "the Circle summon state should name its monster")
	_expect(prototype.select_target(&"triangle"), "Triangle should be selectable as the target")
	_expect(prototype.target_monster_id() == &"stinger", "Triangle should summon the Stinger")
	_expect(prototype.summon_state() == &"mismatch", "switching the target should detect the connected Circle mismatch")
	_expect(triangle_source != null and prototype.connect_material_to_summoner(StringName(triangle_source.name)), "a Triangle deposit should replace the summoner input")
	_expect(prototype.factory_graph.get_connection_list().size() == 1, "the summoner should keep exactly one direct material input")
	_expect(prototype.summon_state() == &"matched", "matching Triangle should start summoning")
	_expect(prototype.select_target(&"square"), "Square should be selectable as the target")
	_expect(prototype.target_monster_id() == &"stone_block", "Square should summon the Stone Block")
	_expect(square_source != null and prototype.connect_material_to_summoner(StringName(square_source.name)), "a Square deposit should replace the summoner input")
	_expect(prototype.summon_state() == &"matched", "matching Square should start summoning")
	var active_connection: Dictionary = prototype.factory_graph.get_connection_list()[0]
	prototype.factory_graph.disconnection_request.emit(
		StringName(active_connection["from_node"]),
		int(active_connection["from_port"]),
		StringName(active_connection["to_node"]),
		int(active_connection["to_port"])
	)
	_expect(prototype.summon_state() == &"idle" and prototype.factory_graph.get_connection_list().is_empty(), "disconnecting should stop summoning")

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
