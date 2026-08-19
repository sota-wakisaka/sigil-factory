extends SceneTree

const GlyphComponentModel := preload("res://src/domain/glyph_component.gd")
const GlyphModel := preload("res://src/domain/glyph.gd")
const GlyphProductionContextModel := preload("res://src/domain/glyph_production_context.gd")
const SigilMatcher := preload("res://src/domain/sigil_matcher.gd")
const SigilRecipeModel := preload("res://src/domain/sigil_recipe.gd")
const FactoryNodeModel := preload("res://src/factory/factory_node.gd")
const FactoryLineModel := preload("res://src/factory/factory_line.gd")
const FactorySimulation := preload("res://src/factory/factory_simulation.gd")
const MvpContent := preload("res://src/game/mvp_content.gd")
const UnitSpecModel := preload("res://src/battle/unit_spec.gd")
const ThreatEventModel := preload("res://src/battle/threat_event.gd")
const BattleSimulation := preload("res://src/battle/battle_simulation.gd")
const FactoryBoard := preload("res://src/ui/factory_board.gd")
const SigilGhost := preload("res://src/ui/sigil_ghost.gd")
const RunFlow := preload("res://src/game/run_flow.gd")

var failures := 0


func _initialize() -> void:
	_test_exact_match_is_order_independent()
	_test_attribute_diagnostics()
	_test_missing_and_extra_components()
	_test_diagnostics_are_stable_for_duplicate_primitives()
	_test_diagnostics_follow_player_facing_priority()
	_test_combine_structure_is_order_independent()
	_test_combine_children_use_hash_then_serialization_order()
	_test_combine_hierarchy_affects_matching()
	_test_production_context_does_not_affect_matching()
	_test_rotation_is_normalized_to_quarter_turns()
	_test_combined_rotation_transforms_positions_and_orientation()
	_test_transform_history_folds_into_final_state()
	_test_complete_overlap_is_rejected()
	_test_factory_tick_prevents_same_tick_multistage_processing()
	_test_factory_tick_uses_starting_input_availability()
	_test_factory_tick_does_not_refill_freed_line()
	_test_factory_replay_is_independent_of_insertion_order()
	_test_factory_pipeline_summons_matching_unit()
	_test_factory_records_closest_summon_failure()
	_test_factory_closest_recipe_is_order_independent()
	_test_combiner_waits_for_both_inputs()
	_test_factory_rejects_cycles()
	_test_factory_rejects_implicit_fan_out()
	_test_factory_disconnects_lines()
	_test_factory_removes_node_and_connected_lines()
	_test_factory_graph_validation_reports_dangling_nodes()
	_test_factory_validation_order_is_stable()
	_test_factory_flow_diagnostics_distinguish_blockages()
	_test_mvp_plans_produce_expected_units()
	_test_empty_factory_requires_player_wiring()
	_test_battle_units_fight_and_die()
	_test_preferred_attack_marks_weakness_feedback()
	_test_enemy_shield_takes_damage_and_opens()
	_test_battle_ends_at_time_limit()
	_test_threat_forecast_respects_horizon()
	_test_factory_edit_is_transactional()
	_test_factory_edit_preserves_custom_graph()
	_test_factory_nodes_can_be_repositioned()
	_test_factory_editor_undo_restores_graph()
	_test_factory_mana_budget_limits_and_refunds_nodes()
	_test_factory_node_configuration_is_undoable()
	_test_factory_configuration_discards_work_transactionally()
	_test_factory_rewiring_discards_work_transactionally()
	_test_factory_board_connections_change_output()
	_test_factory_board_shows_summon_failure_reason()
	_test_factory_board_replaces_failure_with_success()
	_test_factory_board_shows_distinct_flow_warning()
	_test_factory_board_holds_transient_flow_warning()
	_test_factory_ports_connect_through_mouse_input()
	_test_factory_production_preview_is_non_destructive()
	_test_sigil_ghost_tracks_plan_recipe()
	_test_run_upgrade_accelerates_ring_source()
	_test_run_flow_covers_one_route()

	if failures == 0:
		print("All domain and factory tests passed.")
	else:
		push_error("%d domain or factory test(s) failed." % failures)
	quit(failures)


func _test_exact_match_is_order_independent() -> void:
	var first := GlyphComponentModel.new(&"ring", Vector2i.ZERO, 1, 1, &"blue")
	var second := GlyphComponentModel.new(&"spike", Vector2i(1, 0), 0, 1, &"white")
	var target := GlyphModel.new([first, second])
	var actual := GlyphModel.new([second, first])
	var result := SigilMatcher.compare(actual, target)
	_expect(result["is_match"], "component order should not affect matching")


func _test_attribute_diagnostics() -> void:
	var target := GlyphModel.new([
		GlyphComponentModel.new(&"ring", Vector2i.ZERO, 1, 2, &"blue"),
	])
	var actual := GlyphModel.new([
		GlyphComponentModel.new(&"ring", Vector2i(1, 0), 0, 1, &"white"),
	])
	var result := SigilMatcher.compare(actual, target)
	var diagnostics: PackedStringArray = result["diagnostics"]
	_expect(not result["is_match"], "different attributes should not match")
	_expect(diagnostics.has("位置が違います"), "position difference should be diagnosed")
	_expect(diagnostics.has("回転が違います"), "rotation difference should be diagnosed")
	_expect(diagnostics.has("倍率が違います"), "scale difference should be diagnosed")
	_expect(diagnostics.has("色が違います"), "color difference should be diagnosed")


func _test_missing_and_extra_components() -> void:
	var target := GlyphModel.new([
		GlyphComponentModel.new(&"ring"),
		GlyphComponentModel.new(&"spike"),
	])
	var actual := GlyphModel.new([
		GlyphComponentModel.new(&"ring"),
		GlyphComponentModel.new(&"branch"),
	])
	var result := SigilMatcher.compare(actual, target)
	var diagnostics: PackedStringArray = result["diagnostics"]
	_expect(diagnostics.has("部品不足: spike"), "missing primitive should be diagnosed")
	_expect(diagnostics.has("余分な部品: branch"), "extra primitive should be diagnosed")


func _test_diagnostics_are_stable_for_duplicate_primitives() -> void:
	var target := GlyphModel.new([
		GlyphComponentModel.new(&"ring", Vector2i(0, 0), 0, 1, &"blue"),
		GlyphComponentModel.new(&"ring", Vector2i(1, 0), 0, 1, &"red"),
	])
	var first_actual := GlyphComponentModel.new(&"ring", Vector2i(0, 0), 0, 1, &"red")
	var second_actual := GlyphComponentModel.new(&"ring", Vector2i(1, 0), 0, 1, &"blue")
	var forward := SigilMatcher.compare(
		GlyphModel.new([first_actual, second_actual]),
		target
	)
	var reverse := SigilMatcher.compare(
		GlyphModel.new([second_actual, first_actual]),
		target
	)
	_expect(
		forward["diagnostics"] == reverse["diagnostics"],
		"duplicate primitive diagnostics should not depend on component insertion order"
	)
	_expect(
		forward["diagnostics"] == PackedStringArray(["色が違います"]),
		"equal-score duplicate primitives should use canonical-key tie breaking"
	)


func _test_diagnostics_follow_player_facing_priority() -> void:
	var target := GlyphModel.new([
		GlyphComponentModel.new(&"ring", Vector2i.ZERO, 1, 2, &"blue"),
		GlyphComponentModel.new(&"spike"),
	])
	var actual := GlyphModel.new([
		GlyphComponentModel.new(&"ring", Vector2i(1, 0), 0, 1, &"white"),
		GlyphComponentModel.new(&"branch"),
	])
	var diagnostics: PackedStringArray = SigilMatcher.compare(actual, target)["diagnostics"]
	_expect(
		diagnostics == PackedStringArray([
			"部品不足: spike",
			"余分な部品: branch",
			"色が違います",
			"回転が違います",
			"倍率が違います",
			"位置が違います",
		]),
		"diagnostics should follow the player-facing correction priority"
	)


func _test_combine_structure_is_order_independent() -> void:
	var ring := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	var spike := GlyphModel.new([GlyphComponentModel.new(&"spike")])
	var first := GlyphModel.combine(ring, spike)
	var second := GlyphModel.combine(spike, ring)
	_expect(
		first.canonical_serialization() == second.canonical_serialization(),
		"combine input order should not affect canonical structure"
	)
	_expect(first.canonical_hash() == second.canonical_hash(), "equal structures should share a stable hash")


func _test_combine_children_use_hash_then_serialization_order() -> void:
	var ring := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	var spike := GlyphModel.new([GlyphComponentModel.new(&"spike")])
	var ring_serialization := ring.canonical_serialization()
	var spike_serialization := spike.canonical_serialization()
	_expect(
		spike_serialization.sha256_text() < ring_serialization.sha256_text(),
		"test fixtures should have hash order opposite to their lexical order"
	)
	var combined := GlyphModel.combine(ring, spike)
	_expect(
		combined.canonical_serialization()
		== "C(%s,%s)" % [spike_serialization, ring_serialization],
		"Combine serialization should order children by canonical hash"
	)
	_expect(
		combined.combine_children[0].canonical_serialization() == spike_serialization,
		"Combine internal child order should match canonical serialization order"
	)


func _test_combine_hierarchy_affects_matching() -> void:
	var ring := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	var spike := GlyphModel.new([GlyphComponentModel.new(&"spike")])
	var branch := GlyphModel.new([GlyphComponentModel.new(&"branch")])
	var left_nested := GlyphModel.combine(GlyphModel.combine(ring, spike), branch)
	var right_nested := GlyphModel.combine(ring, GlyphModel.combine(spike, branch))
	var result := SigilMatcher.compare(left_nested, right_nested)
	_expect(not result["is_match"], "different combine hierarchy should not match")
	_expect(
		result["diagnostics"].has("合成階層が違います"),
		"hierarchy mismatch should be diagnosed"
	)


func _test_production_context_does_not_affect_matching() -> void:
	var first := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	var second := first.copy()
	second.production_context.record_node(&"rotator", true)
	second.production_context.record_source(&"north_source")
	_expect(
		SigilMatcher.compare(first, second)["is_match"],
		"production provenance should not affect sigil matching"
	)
	_expect(second.production_context.processing_count == 1, "production context should count processing")
	_expect(second.production_context.has_visited(&"rotator"), "production context should retain node kinds")


func _test_rotation_is_normalized_to_quarter_turns() -> void:
	var first := GlyphModel.new([GlyphComponentModel.new(&"ring", Vector2i.ZERO, 1)])
	var wrapped := GlyphModel.new([GlyphComponentModel.new(&"ring", Vector2i.ZERO, 5)])
	var negative := GlyphModel.new([GlyphComponentModel.new(&"ring", Vector2i.ZERO, -3)])
	_expect(SigilMatcher.compare(first, wrapped)["is_match"], "rotation should wrap after four quarter turns")
	_expect(SigilMatcher.compare(first, negative)["is_match"], "negative rotation should normalize into the same cycle")


func _test_combined_rotation_transforms_positions_and_orientation() -> void:
	var ring := GlyphModel.new([
		GlyphComponentModel.new(&"ring", Vector2i(1, 0), 0),
	])
	var spike := GlyphModel.new([
		GlyphComponentModel.new(&"spike", Vector2i(0, 1), 1),
	])
	var combined := GlyphModel.combine(ring, spike)
	var original_serialization := combined.canonical_serialization()
	combined.rotate(1)
	var expected_ring := GlyphModel.new([
		GlyphComponentModel.new(&"ring", Vector2i(0, 1), 1),
	])
	var expected_spike := GlyphModel.new([
		GlyphComponentModel.new(&"spike", Vector2i(-1, 0), 2),
	])
	var expected := GlyphModel.combine(expected_ring, expected_spike)
	_expect(
		SigilMatcher.compare(combined, expected)["is_match"],
		"rotating a combined glyph should rotate every child position and orientation"
	)
	_expect(
		combined.canonical_keys() == expected.canonical_keys(),
		"combined glyph flat components should stay synchronized with rotated children"
	)
	combined.rotate(3)
	_expect(
		combined.canonical_serialization() == original_serialization,
		"four quarter turns should restore the complete combined canonical structure"
	)


func _test_transform_history_folds_into_final_state() -> void:
	var original := GlyphModel.new([
		GlyphComponentModel.new(&"ring", Vector2i(1, -1), 0, 1, &"white"),
	])
	var sequential := original.copy()
	sequential.rotate(1)
	sequential.rotate(1)
	sequential.translate(Vector2i(2, -3))
	sequential.translate(Vector2i(-2, 3))
	sequential.recolor(&"red")
	sequential.recolor(&"white")
	var folded := original.copy()
	folded.rotate(2)
	_expect(
		sequential.canonical_serialization() == folded.canonical_serialization(),
		"equivalent transform histories should fold into the same final canonical state"
	)
	_expect(
		sequential.canonical_hash() == folded.canonical_hash(),
		"folded transform histories should share the same canonical hash"
	)


func _test_complete_overlap_is_rejected() -> void:
	var duplicate := GlyphModel.combine(
		GlyphModel.new([GlyphComponentModel.new(&"ring")]),
		GlyphModel.new([GlyphComponentModel.new(&"ring")])
	)
	var result := SigilMatcher.compare(duplicate, duplicate)
	_expect(not result["is_match"], "fully overlapping primitives should never form a valid sigil")
	_expect(
		"完全重複" in result["diagnostics"][0],
		"fully overlapping primitives should report a direct diagnostic"
	)


func _test_factory_tick_prevents_same_tick_multistage_processing() -> void:
	var simulation := FactorySimulation.new()
	var source := FactoryNodeModel.new(
		&"source",
		FactoryNodeModel.NodeKind.SOURCE,
		{"primitive_id": "ring", "interval_ticks": 1}
	)
	var rotator := FactoryNodeModel.new(
		&"rotator",
		FactoryNodeModel.NodeKind.ROTATOR,
		{"steps": 1, "processing_ticks": 1}
	)
	var summoner := FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER)
	for node in [source, rotator, summoner]:
		simulation.add_node(node)
	simulation.connect_nodes(FactoryLineModel.new(&"source_line", &"source", &"rotator", 0, 1))
	simulation.connect_nodes(FactoryLineModel.new(&"summon_line", &"rotator", &"summoner", 0, 1))
	simulation.add_recipe(SigilRecipeModel.new(
		&"turned_ring",
		GlyphModel.new([GlyphComponentModel.new(&"ring", Vector2i.ZERO, 1)]),
		&"sentinel"
	))

	simulation.tick()
	_expect(rotator.input_buffers[0] == null, "source output should still be travelling after its creation tick")
	simulation.tick()
	_expect(rotator.input_buffers[0] != null, "line should deliver to the processor on the next tick")
	_expect(rotator.output_buffer == null, "a newly delivered glyph should not be processed in the same tick")
	simulation.tick()
	_expect(summoner.input_buffers[0] == null, "processed output should still be travelling after processing")
	simulation.tick()
	_expect(simulation.summon_events.is_empty(), "a newly delivered glyph should not summon in the same tick")
	simulation.tick()
	_expect(simulation.summon_events.size() == 1, "the glyph should summon on the following tick")


func _test_factory_tick_uses_starting_input_availability() -> void:
	var simulation := FactorySimulation.new()
	var source := FactoryNodeModel.new(&"source", FactoryNodeModel.NodeKind.SOURCE)
	var rotator := FactoryNodeModel.new(
		&"rotator",
		FactoryNodeModel.NodeKind.ROTATOR,
		{"steps": 1, "processing_ticks": 1}
	)
	simulation.add_node(source)
	simulation.add_node(rotator)
	simulation.connect_nodes(FactoryLineModel.new(&"line", &"source", &"rotator", 0, 1))
	var first := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	var waiting := GlyphModel.new([GlyphComponentModel.new(&"spike")])
	rotator.input_buffers[0] = first
	var line: FactoryLineModel = simulation.lines[&"line"]
	line.payload = waiting
	line.remaining_ticks = 0

	simulation.tick()
	_expect(rotator.input_buffers[0] == null, "an input consumed this tick should remain unavailable to arriving cargo")
	_expect(line.payload != null, "cargo should wait when its target input was full at tick start")
	_expect(simulation.line_flow_state(&"line") == &"buffer_full", "snapshot-rejected cargo should retain a buffer-full diagnostic")
	_expect(
		simulation.duplicate_state().line_flow_state(&"line") == &"buffer_full",
		"duplicated preview state should preserve the actual line blockage reason"
	)
	simulation.tick()
	_expect(rotator.input_buffers[0] != null, "waiting cargo should arrive on the next tick after input becomes available")


func _test_factory_tick_does_not_refill_freed_line() -> void:
	var simulation := FactorySimulation.new()
	var source := FactoryNodeModel.new(&"source", FactoryNodeModel.NodeKind.SOURCE)
	var summoner := FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER)
	simulation.add_node(source)
	simulation.add_node(summoner)
	simulation.connect_nodes(FactoryLineModel.new(&"line", &"source", &"summoner", 0, 1))
	var glyph := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	source.output_buffer = glyph.copy()
	var line: FactoryLineModel = simulation.lines[&"line"]
	line.payload = glyph.copy()
	line.remaining_ticks = 0

	simulation.tick()
	_expect(line.payload == null, "cargo should leave a line when its target was free at tick start")
	_expect(source.output_buffer != null, "a line freed this tick should not be refilled until the next tick")
	_expect(simulation.node_flow_state(&"source") == &"output_blocked", "snapshot-held output should retain an output-blocked diagnostic")
	_expect(
		simulation.duplicate_state().node_flow_state(&"source") == &"output_blocked",
		"duplicated preview state should preserve the actual output blockage reason"
	)
	simulation.tick()
	_expect(line.payload != null, "the held output should dispatch once the line starts a tick empty")
	_expect(source.output_buffer == null, "dispatch on the following tick should clear the output buffer")


func _test_factory_replay_is_independent_of_insertion_order() -> void:
	var forward := _build_determinism_factory(false)
	var reverse := _build_determinism_factory(true)
	for _tick in 240:
		forward.tick()
		reverse.tick()
	_expect(
		_factory_runtime_signature(forward) == _factory_runtime_signature(reverse),
		"equivalent factories should replay identically regardless of insertion order"
	)


func _build_determinism_factory(reverse_order: bool) -> FactorySimulation:
	var simulation := FactorySimulation.new()
	var factory_nodes: Array[FactoryNodeModel] = [
		FactoryNodeModel.new(
			&"source", FactoryNodeModel.NodeKind.SOURCE,
			{"primitive_id": "ring", "interval_ticks": 4}
		),
		FactoryNodeModel.new(
			&"rotator", FactoryNodeModel.NodeKind.ROTATOR,
			{"steps": 1, "processing_ticks": 2}
		),
		FactoryNodeModel.new(
			&"colorizer", FactoryNodeModel.NodeKind.COLORIZER,
			{"color_id": "blue", "processing_ticks": 3}
		),
		FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER),
	]
	var factory_lines: Array[FactoryLineModel] = [
		FactoryLineModel.new(&"a", &"source", &"rotator", 0, 2),
		FactoryLineModel.new(&"b", &"rotator", &"colorizer", 0, 3),
		FactoryLineModel.new(&"c", &"colorizer", &"summoner", 0, 2),
	]
	if reverse_order:
		factory_nodes.reverse()
		factory_lines.reverse()
	for node in factory_nodes:
		simulation.add_node(node)
	for line in factory_lines:
		simulation.connect_nodes(line)
	var target := GlyphModel.new([
		GlyphComponentModel.new(&"ring", Vector2i.ZERO, 1, 1, &"blue"),
	])
	simulation.add_recipe(SigilRecipeModel.new(&"azure_ring", target, &"sentinel"))
	return simulation


func _factory_runtime_signature(simulation: FactorySimulation) -> String:
	var parts := PackedStringArray([
		"tick=%d" % simulation.tick_index,
		"discarded=%d" % simulation.discarded_glyphs,
	])
	for event in simulation.summon_events:
		parts.append("summon=%d:%s" % [event["tick"], event["unit_id"]])
	var node_ids := simulation.nodes.keys()
	node_ids.sort()
	for node_id in node_ids:
		var node: FactoryNodeModel = simulation.nodes[node_id]
		var inputs := PackedStringArray()
		for glyph in node.input_buffers:
			inputs.append(_glyph_hash_or_empty(glyph))
		parts.append("node=%s:%d:%d:%s:%s:%s" % [
			node_id,
			node.source_timer,
			node.remaining_processing_ticks,
			",".join(inputs),
			_glyph_hash_or_empty(node.processing_glyph),
			_glyph_hash_or_empty(node.output_buffer),
		])
	var line_ids := simulation.lines.keys()
	line_ids.sort()
	for line_id in line_ids:
		var line: FactoryLineModel = simulation.lines[line_id]
		parts.append("line=%s:%d:%s" % [
			line_id,
			line.remaining_ticks,
			_glyph_hash_or_empty(line.payload),
		])
	return "|".join(parts)


func _glyph_hash_or_empty(glyph) -> String:
	return "-" if glyph == null else glyph.canonical_hash()


func _test_factory_pipeline_summons_matching_unit() -> void:
	var simulation := FactorySimulation.new()
	var source := FactoryNodeModel.new(
		&"source",
		FactoryNodeModel.NodeKind.SOURCE,
		{"primitive_id": "ring", "interval_ticks": 1}
	)
	var rotator := FactoryNodeModel.new(
		&"rotator",
		FactoryNodeModel.NodeKind.ROTATOR,
		{"steps": 1, "processing_ticks": 1}
	)
	var colorizer := FactoryNodeModel.new(
		&"colorizer",
		FactoryNodeModel.NodeKind.COLORIZER,
		{"color_id": "blue", "processing_ticks": 1}
	)
	var summoner := FactoryNodeModel.new(
		&"summoner",
		FactoryNodeModel.NodeKind.SUMMONER
	)
	for node in [source, rotator, colorizer, summoner]:
		simulation.add_node(node)

	simulation.connect_nodes(FactoryLineModel.new(&"a", &"source", &"rotator"))
	simulation.connect_nodes(FactoryLineModel.new(&"b", &"rotator", &"colorizer"))
	simulation.connect_nodes(FactoryLineModel.new(&"c", &"colorizer", &"summoner"))
	var target := GlyphModel.new([
		GlyphComponentModel.new(&"ring", Vector2i.ZERO, 1, 1, &"blue"),
	])
	simulation.add_recipe(SigilRecipeModel.new(&"azure_ring", target, &"sentinel"))

	for _tick in 12:
		simulation.tick()

	_expect(not simulation.summon_events.is_empty(), "valid pipeline should summon a unit")
	if not simulation.summon_events.is_empty():
		_expect(
			simulation.summon_events[0]["unit_id"] == &"sentinel",
			"matching recipe should summon its configured unit"
		)
		var context: Dictionary = simulation.summon_events[0]["production_context"]
		_expect(context["processing_count"] == 2, "production context should count rotator and colorizer")
		_expect(context["visited_node_kinds"].has(&"source"), "production context should retain source traversal")
		_expect(context["visited_node_kinds"].has(&"summoner"), "production context should retain summoner traversal")
		_expect(context["source_ids"].has(&"source"), "production context should retain source identity")


func _test_factory_records_closest_summon_failure() -> void:
	var simulation := FactorySimulation.new()
	var source := FactoryNodeModel.new(
		&"source",
		FactoryNodeModel.NodeKind.SOURCE,
		{"primitive_id": "ring", "interval_ticks": 1}
	)
	var summoner := FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER)
	simulation.add_node(source)
	simulation.add_node(summoner)
	simulation.connect_nodes(FactoryLineModel.new(&"line", &"source", &"summoner"))
	var target := GlyphModel.new([
		GlyphComponentModel.new(&"ring", Vector2i.ZERO, 1, 1, &"blue"),
	])
	simulation.add_recipe(SigilRecipeModel.new(&"azure_ring", target, &"sentinel"))

	for _tick in 8:
		simulation.tick()

	_expect(not simulation.summon_failure_events.is_empty(), "recipe mismatch should create a summon failure event")
	if not simulation.summon_failure_events.is_empty():
		var event: Dictionary = simulation.summon_failure_events[0]
		var diagnostics: PackedStringArray = event["diagnostics"]
		_expect(event["closest_recipe_id"] == &"azure_ring", "failure should identify the closest recipe")
		_expect(diagnostics.has("回転が違います"), "failure should retain rotation diagnostics")
		_expect(diagnostics.has("色が違います"), "failure should retain color diagnostics")
		_expect(String(event["glyph_hash"]) != "", "failure should identify the rejected glyph")
	_expect(simulation.discarded_glyphs > 0, "failed summons should still count discarded glyphs")


func _test_factory_closest_recipe_is_order_independent() -> void:
	var selected_recipe_ids := PackedStringArray()
	for reverse_order in [false, true]:
		var simulation := FactorySimulation.new()
		var source := FactoryNodeModel.new(
			&"source",
			FactoryNodeModel.NodeKind.SOURCE,
			{"primitive_id": "ring", "interval_ticks": 1}
		)
		var summoner := FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER)
		simulation.add_node(source)
		simulation.add_node(summoner)
		simulation.connect_nodes(FactoryLineModel.new(&"line", &"source", &"summoner"))
		var recipes: Array[SigilRecipeModel] = [
			SigilRecipeModel.new(
				&"z_recipe",
				GlyphModel.new([GlyphComponentModel.new(&"ring", Vector2i.ZERO, 0, 1, &"red")]),
				&"sentinel"
			),
			SigilRecipeModel.new(
				&"a_recipe",
				GlyphModel.new([GlyphComponentModel.new(&"ring", Vector2i.ZERO, 0, 1, &"blue")]),
				&"scout"
			),
		]
		if reverse_order:
			recipes.reverse()
		for recipe in recipes:
			simulation.add_recipe(recipe)
		for _tick in 8:
			simulation.tick()
		selected_recipe_ids.append(String(simulation.summon_failure_events[0]["closest_recipe_id"]))
	_expect(
		selected_recipe_ids == PackedStringArray(["a_recipe", "a_recipe"]),
		"equal-rank closest recipe selection should use recipe ID instead of acquisition order"
	)


func _test_combiner_waits_for_both_inputs() -> void:
	var simulation := FactorySimulation.new()
	var ring_source := FactoryNodeModel.new(
		&"ring_source",
		FactoryNodeModel.NodeKind.SOURCE,
		{"primitive_id": "ring", "interval_ticks": 1}
	)
	var spike_source := FactoryNodeModel.new(
		&"spike_source",
		FactoryNodeModel.NodeKind.SOURCE,
		{"primitive_id": "spike", "interval_ticks": 3}
	)
	var combiner := FactoryNodeModel.new(
		&"combiner",
		FactoryNodeModel.NodeKind.COMBINER,
		{"processing_ticks": 1}
	)
	var summoner := FactoryNodeModel.new(
		&"summoner",
		FactoryNodeModel.NodeKind.SUMMONER
	)
	for node in [ring_source, spike_source, combiner, summoner]:
		simulation.add_node(node)

	simulation.connect_nodes(FactoryLineModel.new(&"ring", &"ring_source", &"combiner", 0))
	simulation.connect_nodes(FactoryLineModel.new(&"spike", &"spike_source", &"combiner", 1))
	simulation.connect_nodes(FactoryLineModel.new(&"out", &"combiner", &"summoner"))
	var target := GlyphModel.combine(
		GlyphModel.new([GlyphComponentModel.new(&"ring")]),
		GlyphModel.new([GlyphComponentModel.new(&"spike")])
	)
	simulation.add_recipe(SigilRecipeModel.new(&"bound_pair", target, &"golem"))

	for _tick in 12:
		simulation.tick()

	_expect(not simulation.summon_events.is_empty(), "combiner should produce after both inputs arrive")
	_expect(simulation.discarded_glyphs == 0, "valid combined glyph should not be discarded")
	if not simulation.summon_events.is_empty():
		var context: Dictionary = simulation.summon_events[0]["production_context"]
		_expect(context["processing_count"] == 1, "combiner should add one processing step")
		_expect(context["visited_node_kinds"].has(&"combiner"), "combined provenance should retain combiner traversal")
		_expect(context["source_ids"].size() == 2, "combined provenance should merge both source identities")


func _test_factory_rejects_cycles() -> void:
	var simulation := FactorySimulation.new()
	simulation.add_node(FactoryNodeModel.new(&"rotate", FactoryNodeModel.NodeKind.ROTATOR))
	simulation.add_node(FactoryNodeModel.new(&"color", FactoryNodeModel.NodeKind.COLORIZER))
	var first := simulation.connect_nodes(FactoryLineModel.new(&"forward", &"rotate", &"color"))
	var second := simulation.connect_nodes(FactoryLineModel.new(&"back", &"color", &"rotate"))
	_expect(first["ok"], "first DAG connection should be accepted")
	_expect(not second["ok"] and second["error"] == "cycle", "cycle should be rejected")


func _test_factory_rejects_implicit_fan_out() -> void:
	var simulation := FactorySimulation.new()
	simulation.add_node(FactoryNodeModel.new(&"source", FactoryNodeModel.NodeKind.SOURCE))
	simulation.add_node(FactoryNodeModel.new(&"first", FactoryNodeModel.NodeKind.SUMMONER))
	simulation.add_node(FactoryNodeModel.new(&"second", FactoryNodeModel.NodeKind.SUMMONER))
	var first := simulation.connect_nodes(FactoryLineModel.new(&"first_line", &"source", &"first"))
	var second := simulation.connect_nodes(FactoryLineModel.new(&"second_line", &"source", &"second"))
	_expect(first["ok"], "a node output should accept its first connection")
	_expect(
		not second["ok"] and second["error"] == "occupied_output",
		"a normal node output should not create an implicit splitter"
	)


func _test_factory_disconnects_lines() -> void:
	var simulation := FactorySimulation.new()
	simulation.add_node(FactoryNodeModel.new(&"source", FactoryNodeModel.NodeKind.SOURCE))
	simulation.add_node(FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER))
	simulation.connect_nodes(FactoryLineModel.new(&"line", &"source", &"summoner"))
	_expect(simulation.disconnect_line(&"line"), "existing factory line should disconnect")
	_expect(simulation.lines.is_empty(), "disconnected factory line should be removed")
	_expect(not simulation.disconnect_line(&"missing"), "missing factory line should not disconnect")


func _test_factory_removes_node_and_connected_lines() -> void:
	var simulation := MvpContent.build_factory(MvpContent.PLAN_SENTINEL)
	_expect(simulation.remove_node(&"rotator"), "existing factory node should be removable")
	_expect(not simulation.nodes.has(&"rotator"), "removed factory node should leave the graph")
	for line in simulation.lines.values():
		_expect(line.from_node_id != &"rotator" and line.to_node_id != &"rotator", "removing a node should remove its lines")


func _test_factory_graph_validation_reports_dangling_nodes() -> void:
	var simulation := MvpContent.build_factory(MvpContent.PLAN_SCOUT)
	_expect(simulation.validate_graph()["ok"], "complete preset factory should validate")
	simulation.add_node(FactoryNodeModel.new(&"dangling", FactoryNodeModel.NodeKind.ROTATOR))
	var result := simulation.validate_graph()
	_expect(not result["ok"], "dangling factory equipment should fail validation")
	_expect(result["errors"].has("missing_input:dangling:0"), "validation should identify missing input")
	_expect(result["errors"].has("missing_output:dangling"), "validation should identify missing output")


func _test_factory_validation_order_is_stable() -> void:
	var forward := FactorySimulation.new()
	var reverse := FactorySimulation.new()
	for node_id in [&"z_node", &"a_node"]:
		forward.add_node(FactoryNodeModel.new(node_id, FactoryNodeModel.NodeKind.ROTATOR))
	for node_id in [&"a_node", &"z_node"]:
		reverse.add_node(FactoryNodeModel.new(node_id, FactoryNodeModel.NodeKind.ROTATOR))
	_expect(
		forward.validate_graph()["errors"] == reverse.validate_graph()["errors"],
		"graph validation diagnostics should not depend on insertion order"
	)


func _test_factory_flow_diagnostics_distinguish_blockages() -> void:
	var simulation := FactorySimulation.new()
	var source := FactoryNodeModel.new(&"source", FactoryNodeModel.NodeKind.SOURCE)
	var blocked := FactoryNodeModel.new(&"blocked", FactoryNodeModel.NodeKind.ROTATOR)
	var combiner := FactoryNodeModel.new(&"combiner", FactoryNodeModel.NodeKind.COMBINER)
	for node in [source, blocked, combiner]:
		simulation.add_node(node)
	simulation.connect_nodes(FactoryLineModel.new(&"blocked_line", &"source", &"blocked"))
	var glyph := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	source.output_buffer = glyph.copy()
	blocked.input_buffers[0] = glyph.copy()
	blocked.output_buffer = glyph.copy()
	combiner.input_buffers[0] = glyph.copy()
	var line: FactoryLineModel = simulation.lines[&"blocked_line"]
	line.payload = glyph.copy()
	line.remaining_ticks = 0
	var codes := PackedStringArray()
	for diagnostic in simulation.flow_diagnostics():
		codes.append(String(diagnostic["code"]))
	_expect(codes.has("buffer_full"), "arrived cargo should diagnose a full target buffer")
	_expect(codes.has("output_blocked"), "held output should diagnose downstream blockage")
	_expect(codes.has("material_shortage"), "partially filled combiner should diagnose missing material")


func _test_mvp_plans_produce_expected_units() -> void:
	var expectations := {
		MvpContent.PLAN_SCOUT: &"scout",
		MvpContent.PLAN_SENTINEL: &"sentinel",
		MvpContent.PLAN_GOLEM: &"golem",
	}
	for plan_id in expectations:
		var simulation := MvpContent.build_factory(plan_id)
		for _tick in 160:
			simulation.tick()
		var expected_unit: StringName = expectations[plan_id]
		var produced_expected_unit := false
		for event in simulation.summon_events:
			if event["unit_id"] == expected_unit:
				produced_expected_unit = true
				break
		_expect(
			produced_expected_unit,
			"MVP plan %s should produce %s" % [plan_id, expected_unit]
		)


func _test_empty_factory_requires_player_wiring() -> void:
	var simulation := MvpContent.build_factory(MvpContent.PLAN_EMPTY)
	_expect(simulation.nodes.size() == 2, "empty workshop should start with source and summoner")
	_expect(simulation.lines.is_empty(), "empty workshop should require the player to create its first line")
	_expect(not simulation.validate_graph()["ok"], "unwired empty workshop should not start battle")
	var connection := simulation.connect_nodes(FactoryLineModel.new(&"first_line", &"ring_source", &"summoner", 0, 3))
	_expect(connection["ok"], "player should be able to complete the empty workshop")
	for _tick in 80:
		simulation.tick()
	_expect(not simulation.summon_events.is_empty(), "completed empty workshop should produce its first scout")


func _test_battle_units_fight_and_die() -> void:
	var battle := BattleSimulation.new()
	battle.add_spec(UnitSpecModel.new(&"ally", 30.0, 10.0, 1, 10.0, 30.0))
	battle.add_spec(UnitSpecModel.new(&"enemy", 20.0, 1.0, 2, 5.0, 20.0))
	battle.spawn_player(&"ally")
	_expect(battle.units[0].summon_flash_ticks > 0, "new player unit should receive summon feedback")
	battle.spawn_enemy(&"enemy")
	for _tick in 100:
		battle.tick()
		if battle.player_kills > 0:
			break
	_expect(battle.player_kills == 1, "player unit should kill weaker enemy")
	_expect(battle.units.size() == 1, "dead unit should be removed from battle")


func _test_preferred_attack_marks_weakness_feedback() -> void:
	var battle := BattleSimulation.new()
	battle.add_spec(UnitSpecModel.new(&"counter", 100.0, 2.0, 1, 1.0, 1000.0, 0.0, 1, &"target", 2.0))
	battle.add_spec(UnitSpecModel.new(&"target", 100.0, 1.0, 10, 1.0, 10.0))
	battle.spawn_player(&"counter")
	battle.spawn_enemy(&"target")
	battle.tick()
	var target: BattleUnitModel = battle.units[1]
	_expect(target.hit_flash_ticks > 0, "damaged unit should receive hit feedback")
	_expect(target.weakness_flash_ticks > 0, "preferred target hit should receive weakness feedback")


func _test_enemy_shield_takes_damage_and_opens() -> void:
	var battle := BattleSimulation.new()
	battle.add_spec(UnitSpecModel.new(
		&"breaker", 100.0, BattleSimulation.ENEMY_SHIELD_MAX_HEALTH,
		1, 100.0, 20.0, 0.0, 1, &"", 1.0, 100
	))
	battle.spawn_player(&"breaker")
	for _tick in 10:
		battle.tick()
		if not battle.is_enemy_shield_active():
			break
	_expect(battle.enemy_shield_health < BattleSimulation.ENEMY_SHIELD_MAX_HEALTH, "units at the wall should damage the enemy shield")
	_expect(not battle.is_enemy_shield_active(), "depleted enemy shield should open the route")
	var position_before := battle.units[0].position
	battle.tick()
	_expect(battle.units[0].position > position_before, "units should advance after breaking the shield")


func _test_battle_ends_at_time_limit() -> void:
	var battle := BattleSimulation.new()
	battle.battle_duration_ticks = 2
	battle.tick()
	_expect(not battle.is_finished(), "battle should run before its time limit")
	battle.tick()
	_expect(battle.is_finished(), "battle should end when its time limit expires")
	_expect(battle.winner() == BattleSimulation.Side.ENEMY, "failing to defeat the leader in time should lose the stage")


func _test_threat_forecast_respects_horizon() -> void:
	var battle := BattleSimulation.new()
	battle.add_spec(UnitSpecModel.new(&"enemy", 10.0, 1.0, 2, 1.0, 10.0))
	battle.set_schedule([
		ThreatEventModel.new(10, &"enemy", 1, "NEAR"),
		ThreatEventModel.new(30, &"enemy", 1, "FAR"),
	])
	var forecast := battle.upcoming_threats(15)
	_expect(forecast.size() == 1, "forecast should only include events inside horizon")
	if forecast.size() == 1:
		_expect(forecast[0].label == "NEAR", "forecast should return the near threat")


func _test_factory_edit_is_transactional() -> void:
	var board := FactoryBoard.new()
	board.configure(MvpContent.PLAN_SCOUT)
	for _tick in 18:
		board.advance_tick()
	var committed_tick := board.simulation.tick_index
	var committed_work_in_progress := board.work_in_progress_count()
	_expect(committed_work_in_progress > 0, "running factory should have work in progress for the edit test")
	var original_simulation := board.simulation
	board.begin_edit()
	board.preview_plan(MvpContent.PLAN_GOLEM)
	_expect(board.plan_id == MvpContent.PLAN_SCOUT, "preview should not change committed plan")
	_expect(board.simulation == original_simulation, "preview should not replace running factory")
	_expect(board.pending_discard_count() == committed_work_in_progress, "preview should disclose discarded work in progress")
	_expect(board.preview_simulation.tick_index == committed_tick, "template preview should preserve factory time")
	board.cancel_edit()
	_expect(board.simulation == original_simulation, "cancel should preserve the running factory")
	_expect(board.work_in_progress_count() == committed_work_in_progress, "cancel should restore all work in progress")
	_expect(board.simulation.discarded_glyphs == 0, "cancel should not count preview discards")
	board.begin_edit()
	board.preview_plan(MvpContent.PLAN_GOLEM)
	board.commit_edit()
	_expect(board.plan_id == MvpContent.PLAN_GOLEM, "commit should apply pending plan")
	_expect(board.simulation != original_simulation, "commit should replace factory atomically")
	_expect(board.simulation.discarded_glyphs == committed_work_in_progress, "commit should count discarded work in progress")
	board.free()


func _test_factory_edit_preserves_custom_graph() -> void:
	var board := FactoryBoard.new()
	board.size = Vector2(568, 339)
	board.configure(MvpContent.PLAN_SENTINEL)
	board.set_interaction_enabled(true)
	board.disconnect_input(&"rotator", 0)
	board.disconnect_input(&"summoner", 0)
	board.connect_nodes_interactive(&"ring_source", &"summoner", 0)
	board.move_node(&"summoner", Vector2(480, 280))
	for _tick in 80:
		board.advance_tick()
	var committed_position: Vector2 = board.node_positions[&"summoner"]
	var committed_tick := board.simulation.tick_index
	board.begin_edit()
	_expect(board.preview_node_positions[&"summoner"] == committed_position, "time stop should preserve custom node placement")
	_expect(board.preview_simulation.tick_index == committed_tick, "time stop should preserve factory progress")
	_expect(board.preview_simulation.lines.size() == board.simulation.lines.size(), "time stop should preserve custom wiring")
	board.commit_edit()
	_expect(board.observed_event_count == board.simulation.summon_events.size(), "commit should not replay historical summons")
	board.free()


func _test_factory_nodes_can_be_repositioned() -> void:
	var board := FactoryBoard.new()
	board.size = Vector2(568, 339)
	board.configure(MvpContent.PLAN_SCOUT)
	var original := board.node_positions[&"ring_source"] as Vector2
	_expect(not board.move_node(&"ring_source", Vector2(300, 160)), "running factory should reject node movement")
	board.set_interaction_enabled(true)
	_expect(board.move_node(&"ring_source", Vector2(300, 160)), "editable factory should allow node movement")
	_expect(board.node_positions[&"ring_source"] != original, "node movement should update its layout")
	board.free()


func _test_factory_editor_undo_restores_graph() -> void:
	var board := FactoryBoard.new()
	board.size = Vector2(568, 339)
	board.configure(MvpContent.PLAN_SCOUT)
	board.set_interaction_enabled(true)
	var original_node_count := board.simulation.nodes.size()
	var added_id := board.add_node_from_palette(&"rotator")
	_expect(board.simulation.nodes.has(added_id), "palette edit should add a node before undo")
	_expect(board.undo(), "factory editor should undo its latest edit")
	_expect(board.simulation.nodes.size() == original_node_count, "undo should restore the previous graph")
	_expect(not board.simulation.nodes.has(added_id), "undo should remove the newly added node")
	board.free()


func _test_factory_mana_budget_limits_and_refunds_nodes() -> void:
	var board := FactoryBoard.new()
	board.configure(MvpContent.PLAN_EMPTY)
	board.set_interaction_enabled(true)
	_expect(board.mana_used() == 40, "empty workshop source and summoner should use 40 mana")
	for _index in 4:
		_expect(board.add_node_from_palette(&"rotator") != &"", "factory should accept equipment within its mana budget")
	_expect(board.mana_used() == MvpContent.FACTORY_MANA_MAX, "four processors should fill the remaining workshop mana")
	var node_count_at_limit := board.simulation.nodes.size()
	_expect(board.add_node_from_palette(&"rotator") == &"", "factory should reject equipment beyond its mana budget")
	_expect(board.simulation.nodes.size() == node_count_at_limit, "rejected equipment should not mutate the factory graph")
	_expect("魔力不足" in board.connection_message, "budget rejection should explain required and available mana")
	_expect(board.remove_selected_node(), "removing the last affordable node should refund its mana")
	_expect(board.mana_available() == 15, "removing a processor should refund its full fixed cost")
	_expect(board.add_node_from_palette(&"colorizer") != &"", "refunded mana should be immediately reusable")
	_expect(board.mana_used() == MvpContent.FACTORY_MANA_MAX, "replacement equipment should consume the refunded capacity")
	var over_budget := FactoryNodeModel.new(&"forced_source", FactoryNodeModel.NodeKind.SOURCE)
	board.simulation.add_node(over_budget)
	var validation := board.validation_result()
	_expect(not validation["ok"], "forced over-budget graph should fail final validation")
	_expect(validation["errors"].has("mana_exceeded"), "validation should identify mana overflow explicitly")
	board.free()

	var golem_board := FactoryBoard.new()
	golem_board.configure(MvpContent.PLAN_GOLEM)
	_expect(golem_board.mana_used() == 95, "complete golem template should fit with five mana remaining")
	golem_board.free()


func _test_factory_node_configuration_is_undoable() -> void:
	var board := FactoryBoard.new()
	board.size = Vector2(568, 339)
	board.configure(MvpContent.PLAN_SCOUT)
	board.set_interaction_enabled(true)
	var rotator_id := board.add_node_from_palette(&"rotator")
	_expect(board.configure_selected_node(1), "selected rotator should accept a 180-degree setting")
	_expect(board.simulation.nodes[rotator_id].config["steps"] == 2, "inspector should update node configuration")
	_expect(board.undo(), "node configuration should be undoable")
	_expect(board.simulation.nodes[rotator_id].config["steps"] == 1, "undo should restore the previous node setting")
	board.configure(MvpContent.PLAN_SCOUT)
	_expect(board.selected_node_id == &"", "switching factory templates should clear stale inspector selection")
	board.free()


func _test_factory_configuration_discards_work_transactionally() -> void:
	var board := FactoryBoard.new()
	board.configure(MvpContent.PLAN_SCOUT)
	for _tick in 18:
		board.advance_tick()
	var committed_work_in_progress := board.work_in_progress_count()
	_expect(committed_work_in_progress > 0, "configuration test should begin with work in progress")
	_expect("環" in board.work_in_progress_summary(), "work in progress summary should name its glyph type")
	_expect(
		"環素材→召喚器" in board.work_in_progress_impact_summary(),
		"work in progress impact should identify its transport line"
	)
	board.begin_edit()
	board.set_interaction_enabled(true)
	board.selected_node_id = &"ring_source"
	_expect(board.configure_selected_node(1), "source configuration should change during time stop")
	_expect(board.pending_discard_count() == committed_work_in_progress, "configuration should disclose all pending discards")
	_expect("環" in board.pending_discard_notice(), "discard notice should name the discarded glyph type")
	_expect("影響:" in board.pending_discard_notice(), "discard notice should name affected equipment or lines")
	_expect(board.preview_simulation.discarded_glyphs == committed_work_in_progress, "preview should count discarded work")
	_expect(board.undo(), "configuration discard should be undoable")
	_expect(board.pending_discard_count() == 0, "undo should remove pending discard count")
	_expect(board.preview_simulation != null, "undo should preserve the edit transaction")
	board.cancel_edit()
	_expect(board.work_in_progress_count() == committed_work_in_progress, "cancel should restore configured work in progress")
	_expect(board.simulation.discarded_glyphs == 0, "cancel should not commit configuration discards")
	board.free()


func _test_factory_rewiring_discards_work_transactionally() -> void:
	var board := FactoryBoard.new()
	board.configure(MvpContent.PLAN_SCOUT)
	for _tick in 18:
		board.advance_tick()
	var committed_work_in_progress := board.work_in_progress_count()
	_expect(committed_work_in_progress > 0, "rewiring test should begin with work in progress")
	board.begin_edit()
	board.set_interaction_enabled(true)
	_expect(board.disconnect_input(&"summoner", 0), "time stop should allow disconnecting the active route")
	_expect(board.pending_discard_count() == committed_work_in_progress, "rewiring should disclose pending discards")
	_expect(board.preview_simulation.lines.is_empty(), "preview should contain the disconnected route")
	_expect(board.undo(), "rewiring discard should be undoable")
	_expect(board.pending_discard_count() == 0, "rewiring undo should remove pending discards")
	_expect(board.preview_simulation.lines.size() == 1, "rewiring undo should restore the route")
	board.cancel_edit()
	_expect(board.work_in_progress_count() == committed_work_in_progress, "rewiring cancel should restore work in progress")
	_expect(board.simulation.discarded_glyphs == 0, "rewiring cancel should not commit discards")
	board.free()


func _test_factory_board_connections_change_output() -> void:
	var board := FactoryBoard.new()
	board.size = Vector2(568, 339)
	board.configure(MvpContent.PLAN_SENTINEL)
	board.set_interaction_enabled(true)
	_expect(board.disconnect_input(&"rotator", 0), "editor should disconnect a processor input")
	_expect(board.disconnect_input(&"summoner", 0), "editor should disconnect a summoner input")
	var result := board.connect_nodes_interactive(&"ring_source", &"summoner", 0)
	_expect(result["ok"], "editor should connect compatible output and input ports")
	for _tick in 160:
		board.advance_tick()
	var produced_scout := false
	for event in board.simulation.summon_events:
		if event["unit_id"] == &"scout":
			produced_scout = true
			break
	_expect(produced_scout, "edited factory graph should change its summoned unit")
	board.free()


func _test_factory_board_shows_summon_failure_reason() -> void:
	var board := FactoryBoard.new()
	board.size = Vector2(568, 339)
	board.configure(MvpContent.PLAN_EMPTY)
	board.set_interaction_enabled(true)
	board.selected_node_id = &"ring_source"
	_expect(board.configure_selected_node(1), "failure feedback test should switch the source to spike")
	var result := board.connect_nodes_interactive(&"ring_source", &"summoner", 0)
	_expect(result["ok"], "failure feedback test should connect source to summoner")
	board.set_interaction_enabled(false)
	for _tick in 80:
		board.advance_tick()
		if not board.simulation.summon_failure_events.is_empty():
			break
	_expect("召喚失敗" in board.connection_message, "factory board should expose summon failure during battle")
	_expect("巨像シジルとの差分" in board.connection_message, "factory board should name the closest known recipe")
	_expect(
		"部品不足" in board.connection_message or "余分な部品" in board.connection_message,
		"factory board should explain the recipe mismatch"
	)
	board.free()


func _test_factory_board_replaces_failure_with_success() -> void:
	var board := FactoryBoard.new()
	board.configure(MvpContent.PLAN_EMPTY)
	board.set_interaction_enabled(true)
	board.selected_node_id = &"ring_source"
	board.configure_selected_node(1)
	board.connect_nodes_interactive(&"ring_source", &"summoner", 0)
	board.set_interaction_enabled(false)
	for _tick in 80:
		board.advance_tick()
		if not board.simulation.summon_failure_events.is_empty():
			break
	_expect("召喚失敗" in board.connection_message, "recovery scenario should begin from a visible summon failure")

	board.begin_edit()
	board.set_interaction_enabled(true)
	board.selected_node_id = &"ring_source"
	_expect(board.configure_selected_node(0), "recovery scenario should restore ring production")
	board.commit_edit()
	board.set_interaction_enabled(false)
	for _tick in 80:
		board.advance_tick()
		if not board.simulation.summon_events.is_empty():
			break
	_expect(
		board.connection_message == "召喚成功 // 斥候シジル",
		"successful recovery should replace the stale failure with direct success feedback"
	)
	board.free()


func _test_factory_board_shows_distinct_flow_warning() -> void:
	var board := FactoryBoard.new()
	board.configure(MvpContent.PLAN_EMPTY)
	var blocked := FactoryNodeModel.new(&"blocked", FactoryNodeModel.NodeKind.ROTATOR)
	var glyph := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	blocked.input_buffers[0] = glyph.copy()
	blocked.output_buffer = glyph.copy()
	board.simulation.add_node(blocked)
	board.advance_tick()
	_expect("出力閉塞" in board.flow_warning_message, "factory board should name output blockage separately")
	board.free()


func _test_factory_board_holds_transient_flow_warning() -> void:
	var board := FactoryBoard.new()
	board.configure(MvpContent.PLAN_EMPTY)
	var blocked := FactoryNodeModel.new(&"blocked", FactoryNodeModel.NodeKind.ROTATOR)
	var glyph := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	blocked.output_buffer = glyph
	board.simulation.add_node(blocked)
	board.advance_tick()
	_expect(board.flow_warning_message != "", "transient blockage should create a readable warning")
	blocked.output_buffer = null
	for _tick in FactoryBoard.FLOW_WARNING_HOLD_TICKS - 1:
		board.advance_tick()
		_expect(board.flow_warning_message != "", "resolved warning should remain visible for its minimum hold time")
	board.advance_tick()
	_expect(board.flow_warning_message == "", "resolved warning should clear exactly after its hold time")
	board.free()


func _test_factory_ports_connect_through_mouse_input() -> void:
	var board := FactoryBoard.new()
	root.add_child(board)
	board.size = Vector2(568, 339)
	board.configure(MvpContent.PLAN_EMPTY)
	board.set_interaction_enabled(true)
	var output_click := InputEventMouseButton.new()
	output_click.button_index = MOUSE_BUTTON_LEFT
	output_click.pressed = true
	output_click.position = board.node_local_position(&"ring_source") + Vector2(48, 0)
	board._gui_input(output_click)
	_expect(board.connecting_from_node_id == &"ring_source", "clicking an output port should begin wiring")
	var input_click := InputEventMouseButton.new()
	input_click.button_index = MOUSE_BUTTON_LEFT
	input_click.pressed = true
	input_click.position = board.node_local_position(&"summoner") - Vector2(48, 0)
	board._gui_input(input_click)
	_expect(board.simulation.lines.size() == 1, "clicking the target input port should complete wiring")
	_expect(not board.is_guided_connection_pending(), "first connection guide should clear after wiring")
	board.free()


func _test_factory_production_preview_is_non_destructive() -> void:
	var board := FactoryBoard.new()
	board.size = Vector2(568, 339)
	board.configure(MvpContent.PLAN_SCOUT)
	var tick_before := board.simulation.tick_index
	var preview := board.production_preview(160)
	_expect(preview["ok"], "complete factory should produce a preview")
	_expect(preview["counts"][&"scout"] > 0, "scout factory preview should report scouts")
	_expect(board.simulation.tick_index == tick_before, "production preview should not advance the real factory")
	board.set_interaction_enabled(true)
	board.add_node_from_palette(&"rotator")
	_expect(not board.production_preview()["ok"], "incomplete custom graph should not produce a preview")
	board.free()


func _test_sigil_ghost_tracks_plan_recipe() -> void:
	var ghost := SigilGhost.new()
	_expect(ghost.show_recipe(&"azure_guard"), "sigil ghost should accept a known recipe")
	_expect(ghost.recipe_id == &"azure_guard", "sigil ghost should retain the displayed recipe ID")
	var expected: SigilRecipeModel
	for recipe in MvpContent.recipes():
		if recipe.id == &"azure_guard":
			expected = recipe
			break
	_expect(expected != null, "ghost test recipe should exist in MVP content")
	if expected != null:
		_expect(
			ghost.glyph.canonical_serialization() == expected.glyph.canonical_serialization(),
			"sigil ghost should render a copy of the canonical recipe structure"
		)
	_expect(not ghost.show_recipe(&"missing_recipe"), "sigil ghost should reject an unknown recipe")
	_expect(ghost.recipe_id == &"azure_guard", "unknown recipe should not erase the current ghost")
	ghost.free()


func _test_run_upgrade_accelerates_ring_source() -> void:
	var board := FactoryBoard.new()
	board.set_run_upgrades([&"ring_speed"])
	board.configure(MvpContent.PLAN_SCOUT)
	var source: FactoryNodeModel = board.simulation.nodes[&"ring_source"]
	_expect(source.config["interval_ticks"] < 18, "ring speed reward should accelerate future factories")
	board.set_interaction_enabled(true)
	board.selected_node_id = &"ring_source"
	board.configure_selected_node(1)
	board.configure_selected_node(0)
	_expect(source.config["interval_ticks"] < 18, "ring speed reward should survive source reconfiguration")
	board.free()
	var processing_board := FactoryBoard.new()
	processing_board.set_run_upgrades([&"processing_speed", &"line_speed"])
	processing_board.configure(MvpContent.PLAN_SENTINEL)
	var rotator: FactoryNodeModel = processing_board.simulation.nodes[&"rotator"]
	var first_line: FactoryLineModel = processing_board.simulation.lines[&"line_1"]
	_expect(rotator.config["processing_ticks"] == 1, "processing reward should accelerate processors")
	_expect(first_line.travel_ticks == 1, "line reward should accelerate transport")
	processing_board.free()


func _test_run_flow_covers_one_route() -> void:
	var flow := RunFlow.new()
	_expect(flow.phase == RunFlow.Phase.ROUTE_SELECTION, "run should start at route selection")
	_expect(flow.advance(), "route selection should advance")
	_expect(flow.phase == RunFlow.Phase.STAGE_INFO, "route should lead to stage information")
	flow.advance()
	_expect(flow.phase == RunFlow.Phase.FACTORY_BUILD, "stage information should lead to factory build")
	flow.advance()
	_expect(flow.phase == RunFlow.Phase.BATTLE, "factory build should start battle")
	_expect(flow.pause_for_reconfiguration(), "battle should allow reconfiguration")
	_expect(flow.phase == RunFlow.Phase.FACTORY_RECONFIGURE, "pause should enter reconfiguration")
	_expect(flow.resume_battle(), "reconfiguration should resume battle")
	_expect(flow.mark_victory(), "battle should accept victory")
	flow.advance()
	_expect(flow.phase == RunFlow.Phase.REWARD, "victory should lead to reward")
	flow.advance()
	_expect(flow.phase == RunFlow.Phase.ROUTE_SELECTION, "reward should lead to the next route")
	_expect(flow.route_number == 2, "finishing a route should increment its number")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
