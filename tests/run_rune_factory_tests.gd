extends SceneTree

const RunePacketModel := preload("res://src/rune/rune_packet.gd")
const RuneFactoryScene := preload("res://experiments/rune_factory/rune_factory_prototype.tscn")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_packet_domain()
	await _test_factory_scene()
	if failures == 0:
		print("Rune factory tests passed")
		quit(0)
	else:
		printerr("Rune factory tests failed: %d" % failures)
		quit(1)


func _test_packet_domain() -> void:
	var red_left := RunePacketModel.singleton(0, 3)
	var red_top_left := RunePacketModel.singleton(0, 0)
	var red_bottom_left := RunePacketModel.singleton(0, 5)
	var column := red_left.merged(red_top_left).merged(red_bottom_left)
	_expect(column != null and column.total_count() == 3, "same-attribute runes should merge")
	var shifted := column.shifted(Vector2i.RIGHT)
	_expect(shifted.total_count() == 2, "the rune entering the center should disappear")
	_expect(
		shifted.count_for(0, 1) == 1 and shifted.count_for(0, 6) == 1,
		"the remaining runes should map to their destination cells"
	)
	var edge := RunePacketModel.singleton(0, 2).shifted(Vector2i.RIGHT)
	_expect(edge != null and edge.is_empty(), "a rune leaving the board should disappear")
	var attuned := shifted.attuned(1)
	_expect(
		attuned.count_for(1, 1) == 1 and attuned.count_for(1, 6) == 1,
		"attribute conversion should retain position and multiplicity"
	)
	var twins := RunePacketModel.singleton(0, 0).merged(RunePacketModel.singleton(0, 0))
	_expect(
		twins != null and twins.total_count() == 2 and twins.count_for(0, 0) == 2,
		"merging an identical rune should retain both copies"
	)
	var split := attuned.extracted(&"position", 1)
	_expect(
		bool(split["ok"])
		and split["selected"].total_count() == 1
		and split["remainder"].total_count() == 1,
		"position extraction should return selected and remainder packets"
	)
	_expect(not bool(attuned.extracted(&"unknown", 1)["ok"]), "an unknown extraction selector should fail closed")
	var too_many := RunePacketModel.empty()
	for _index in RunePacketModel.MAX_RUNES:
		too_many = too_many.merged(RunePacketModel.singleton(0, 0))
	_expect(
		too_many != null
		and too_many.total_count() == RunePacketModel.MAX_RUNES
		and too_many.merged(RunePacketModel.singleton(0, 0)) == null,
		"packets should fail closed above eight runes"
	)
	_expect(
		RunePacketModel.from_rune_ids([0, 0, 10]).matches(RunePacketModel.from_rune_ids([10, 0, 0])),
		"matching should ignore ordering while preserving duplicate counts"
	)


func _test_factory_scene() -> void:
	var prototype = RuneFactoryScene.instantiate()
	root.add_child(prototype)
	await process_frame
	await process_frame
	_expect(prototype.source_count() == 24, "the world should contain all twenty-four rune sources")
	var tiers: Dictionary = prototype.source_distance_tiers()
	_expect(
		int(tiers[&"near"]) == 2 and int(tiers[&"middle"]) == 6 and int(tiers[&"far"]) == 16,
		"two sources should be near and more rune types should appear farther away"
	)
	var red_source := StringName("source_red_1")
	var shift = prototype.place_processor(&"shift", Vector2(3800.0, 2700.0))
	var attune = prototype.place_processor(&"attune", Vector2(4100.0, 2700.0))
	var shift_id := StringName(shift.name)
	var attune_id := StringName(attune.name)
	_expect(
		prototype.connect_nodes(red_source, 0, shift_id, 0)
		and prototype.connect_nodes(shift_id, 0, attune_id, 0),
		"a source should connect through rune processors"
	)
	prototype.node_menu_node_id = shift_id
	prototype._preview_node_menu_item(103)
	_expect(prototype.setting_preview_panel.visible, "hovering a setting should reveal a non-destructive preview")
	_expect(prototype.setting_preview_detail.text.contains("消滅"), "shift preview should expose removals before commit")
	prototype._clear_node_setting_preview()
	prototype.set_shift_direction(shift_id, Vector2i.RIGHT)
	var result = prototype.output_packet(attune_id)
	_expect(
		result != null and result.count_for(1, 1) == 1,
		"right shift then attribute conversion should produce the expected blue rune"
	)
	var merge = prototype.place_processor(&"merge", Vector2(4250.0, 3150.0))
	var merge_id := StringName(merge.name)
	_expect(
		prototype.connect_nodes(red_source, 0, merge_id, 0)
		and prototype.connect_nodes(red_source, 0, merge_id, 1),
		"one source output should branch into two merge inputs"
	)
	var twins = prototype.output_packet(merge_id)
	_expect(twins != null and twins.count_for(0, 0) == 2, "factory merge should preserve identical runes")
	prototype.select_input(0)
	prototype.select_target(&"red_twins")
	_expect(
		prototype.connect_nodes(merge_id, 0, StringName(prototype.summoner_node.name), 0),
		"a completed rune packet should connect to a summoner input"
	)
	var connection = prototype._connection_to(StringName(prototype.summoner_node.name), 0)
	var start: float = float(prototype._connection_flow_start(connection, {}))
	prototype.flow_time_override = start + prototype._connection_world_length(connection) / prototype.CONVEYOR_SPEED + 0.01
	_expect(prototype.summon_state(0) == &"matched", "the target should match by multiset after transport")
	prototype.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % message)
