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
	_expect(prototype.PLAYFIELD_SIZE == Vector2(2600.0, 1800.0), "the available playfield should start wide")
	_expect(prototype.material_nodes.size() == 6, "two sources for each basic shape should be scattered")
	_expect(prototype.fixed_landmark_count() == 7, "six material nodes and one summoner should be fixed landmarks")
	_expect(prototype.all_landmarks_locked(), "material nodes and the summoner should not be draggable")
	_expect(prototype.summoner_node.position_offset == prototype.SUMMONER_POSITION, "the summoner should remain at the factory center")
	_expect(prototype.summoner_node.get_meta("landmark_kind") == &"summoner", "the center landmark should be identifiable as the summoner")

	var counts: Dictionary = prototype.material_kind_counts()
	_expect(counts[&"circle"] == 2, "two Circle material nodes should exist")
	_expect(counts[&"triangle"] == 2, "two Triangle material nodes should exist")
	_expect(counts[&"square"] == 2, "two Square material nodes should exist")

	var bounds := Rect2()
	var first := true
	for node in prototype.material_nodes:
		_expect(node.get_meta("fixed_landmark", false), "%s should be marked as a fixed landmark" % node.name)
		if first:
			bounds = Rect2(node.position_offset, Vector2.ZERO)
			first = false
		else:
			bounds = bounds.expand(node.position_offset)
	_expect(bounds.size.x >= 1500.0 and bounds.size.y >= 900.0, "material sources should be visibly scattered over the playfield")

	prototype.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % message)
