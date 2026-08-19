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
	_test_canonical_encoding_frames_delimiter_ids()
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
	_test_factory_rejects_ambiguous_recipes()
	_test_recipe_registration_reports_stable_errors()
	_test_recipe_registration_rejects_missing_objects()
	_test_mvp_recipe_set_validation_reports_content_location()
	_test_factory_rejects_invalid_recipe_structures()
	_test_factory_owns_registered_recipe_data()
	_test_factory_owns_registered_node_data()
	_test_node_registration_reports_stable_errors()
	_test_factory_duplicate_owns_recipe_data()
	_test_factory_duplicate_reports_invalid_state()
	_test_combiner_waits_for_both_inputs()
	_test_factory_rejects_cycles()
	_test_factory_rejects_implicit_fan_out()
	_test_factory_owns_connected_line_state()
	_test_factory_rejects_invalid_connected_line_state()
	_test_factory_disconnects_lines()
	_test_factory_removes_node_and_connected_lines()
	_test_factory_graph_validation_reports_dangling_nodes()
	_test_factory_validation_rejects_externally_injected_lines()
	_test_factory_validation_rejects_externally_injected_cycle()
	_test_factory_validation_rejects_invalid_restored_configuration()
	_test_factory_validation_rejects_invalid_work_in_progress()
	_test_factory_validation_order_is_stable()
	_test_factory_flow_diagnostics_distinguish_blockages()
	_test_mvp_plans_produce_expected_units()
	_test_empty_factory_requires_player_wiring()
	_test_battle_units_fight_and_die()
	_test_preferred_attack_marks_weakness_feedback()
	_test_enemy_shield_takes_damage_and_opens()
	_test_battle_ends_at_time_limit()
	_test_battle_enforces_spawn_capacity_and_rate()
	_test_threat_forecast_respects_horizon()
	_test_major_change_forecast_uses_long_horizon()
	_test_factory_edit_is_transactional()
	_test_factory_edit_recovers_only_invalid_work_in_progress()
	_test_factory_edit_preserves_custom_graph()
	_test_factory_nodes_can_be_repositioned()
	_test_factory_editor_undo_restores_graph()
	_test_factory_mana_budget_limits_and_refunds_nodes()
	_test_factory_enforces_single_summoner()
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
	_test_factory_production_preview_explains_first_mismatch()
	_test_factory_board_explains_restored_validation_errors()
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


func _test_canonical_encoding_frames_delimiter_ids() -> void:
	var embedded_structure := GlyphModel.new([
		GlyphComponentModel.new(&"a|0,0|0|1|b", Vector2i.ZERO, 0, 1, &"c"),
	])
	var shifted_structure := GlyphModel.new([
		GlyphComponentModel.new(&"a", Vector2i.ZERO, 0, 1, &"b|0,0|0|1|c"),
	])
	_expect(
		embedded_structure.canonical_serialization() != shifted_structure.canonical_serialization(),
		"length-framed IDs should prevent delimiter-based canonical collisions"
	)
	_expect(
		not SigilMatcher.compare(embedded_structure, shifted_structure)["is_match"],
		"delimiter-containing IDs should not cause distinct glyphs to match"
	)
	var combined := GlyphModel.combine(embedded_structure, shifted_structure)
	_expect(
		not combined.has_complete_overlap(),
		"delimiter-containing IDs should not create false complete-overlap diagnostics"
	)
	var simulation := FactorySimulation.new()
	_expect(
		simulation.add_recipe(SigilRecipeModel.new(&"embedded", embedded_structure, &"scout")),
		"first delimiter-containing recipe should register"
	)
	_expect(
		simulation.add_recipe(SigilRecipeModel.new(&"shifted", shifted_structure, &"sentinel")),
		"distinct delimiter-containing recipe should not be rejected as a canonical duplicate"
	)


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
	var first: GlyphModel
	var second: GlyphModel
	for first_index in 64:
		var candidate_first := GlyphModel.new([
			GlyphComponentModel.new(StringName("fixture_%02d" % first_index)),
		])
		for second_index in range(first_index + 1, 64):
			var candidate_second := GlyphModel.new([
				GlyphComponentModel.new(StringName("fixture_%02d" % second_index)),
			])
			var first_serialization := candidate_first.canonical_serialization()
			var second_serialization := candidate_second.canonical_serialization()
			if (
				(first_serialization < second_serialization)
				!= (first_serialization.sha256_text() < second_serialization.sha256_text())
			):
				first = candidate_first
				second = candidate_second
				break
		if first != null:
			break
	_expect(first != null and second != null, "test should find fixtures with opposing lexical and hash order")
	if first == null or second == null:
		return
	var first_serialization := first.canonical_serialization()
	var second_serialization := second.canonical_serialization()
	var hash_first_serialization := (
		first_serialization
		if first_serialization.sha256_text() < second_serialization.sha256_text()
		else second_serialization
	)
	var hash_second_serialization := (
		second_serialization
		if hash_first_serialization == first_serialization
		else first_serialization
	)
	var combined := GlyphModel.combine(first, second)
	_expect(
		combined.canonical_serialization()
		== "C(%d:%s,%d:%s)" % [
			hash_first_serialization.length(),
			hash_first_serialization,
			hash_second_serialization.length(),
			hash_second_serialization,
		],
		"Combine serialization should order children by canonical hash"
	)
	_expect(
		combined.combine_children[0].canonical_serialization() == hash_first_serialization,
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
	source = simulation.nodes[&"source"]
	rotator = simulation.nodes[&"rotator"]
	summoner = simulation.nodes[&"summoner"]
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
	source = simulation.nodes[&"source"]
	rotator = simulation.nodes[&"rotator"]
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
	source = simulation.nodes[&"source"]
	summoner = simulation.nodes[&"summoner"]
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


func _test_factory_rejects_ambiguous_recipes() -> void:
	var simulation := FactorySimulation.new()
	var ring := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	var spike := GlyphModel.new([GlyphComponentModel.new(&"spike")])
	_expect(
		simulation.add_recipe(SigilRecipeModel.new(&"z_ring", ring, &"scout")),
		"first unique recipe should register"
	)
	_expect(
		not simulation.add_recipe(SigilRecipeModel.new(&"z_ring", spike, &"golem")),
		"duplicate recipe ID should be rejected even with a different structure"
	)
	_expect(
		not simulation.add_recipe(SigilRecipeModel.new(&"a_alias", ring, &"sentinel")),
		"duplicate canonical structure should not map to a second summon result"
	)
	_expect(
		simulation.add_recipe(SigilRecipeModel.new(&"b_spike", spike, &"golem")),
		"different canonical structure should register"
	)
	_expect(simulation.recipes.size() == 2, "only unambiguous recipes should remain registered")
	_expect(
		simulation.recipes[0].id == &"b_spike" and simulation.recipes[1].id == &"z_ring",
		"accepted recipes should use stable ID order instead of acquisition order"
	)
	_expect(MvpContent.build_factory(MvpContent.PLAN_SCOUT).recipes.size() == 3, "all MVP recipes should have unique IDs and structures")


func _test_recipe_registration_reports_stable_errors() -> void:
	var simulation := FactorySimulation.new()
	var ring := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	_expect(
		simulation.add_recipe(SigilRecipeModel.new(&"ring_recipe", ring, &"scout")),
		"registration diagnostic fixture should register"
	)
	var duplicate_result := simulation.recipe_registration_result(
		SigilRecipeModel.new(&"ring_recipe", ring, &"sentinel")
	)
	_expect(
		duplicate_result["errors"] == PackedStringArray([
			"duplicate_recipe_id",
			"duplicate_glyph_structure",
		]),
		"recipe registration should report ID and structure duplicates in stable priority order"
	)
	var invalid_result := simulation.recipe_registration_result(
		SigilRecipeModel.new(&"", GlyphModel.new(), &"")
	)
	_expect(
		invalid_result["errors"] == PackedStringArray([
			"missing_recipe_id",
			"missing_unit_id",
			"glyph:primitive_arity:root:0",
		]),
		"recipe registration should report required fields before structural errors"
	)
	_expect(simulation.recipes.size() == 1, "registration diagnostics should not mutate the recipe registry")


func _test_recipe_registration_rejects_missing_objects() -> void:
	var simulation := FactorySimulation.new()
	_expect(
		simulation.recipe_registration_result(null)["errors"] == PackedStringArray(["missing_recipe"]),
		"recipe registration should reject a missing recipe without dereferencing it"
	)
	var missing_glyph := SigilRecipeModel.new(&"missing_glyph", null, &"scout")
	_expect(
		simulation.recipe_registration_result(missing_glyph)["errors"] == PackedStringArray(["missing_glyph"]),
		"recipe construction should preserve a missing Glyph for registration diagnostics"
	)
	var missing_glyph_copy := missing_glyph.copy()
	_expect(
		missing_glyph_copy.glyph == null and missing_glyph_copy.id == &"missing_glyph",
		"copying invalid restored recipe metadata should not dereference its missing Glyph"
	)
	var stored := SigilRecipeModel.new(
		&"stored_ring",
		GlyphModel.new([GlyphComponentModel.new(&"ring")]),
		&"scout"
	)
	_expect(simulation.add_recipe(stored), "corrupt registry fixture should register")
	simulation.recipes[0].glyph = null
	var candidate := SigilRecipeModel.new(
		&"candidate_spike",
		GlyphModel.new([GlyphComponentModel.new(&"spike")]),
		&"golem"
	)
	_expect(
		simulation.recipe_registration_result(candidate)["errors"] == PackedStringArray([
			"invalid_registry_recipe:recipe[0]=stored_ring:missing_glyph",
		]),
		"registration should reject a corrupted existing registry without canonicalizing it"
	)
	_expect(simulation.recipes.size() == 1, "corrupt registry diagnostics should not add the candidate")
	var null_candidates: Array[SigilRecipeModel] = [null]
	var set_result := MvpContent.validate_recipe_set(null_candidates)
	_expect(
		set_result["errors"] == PackedStringArray(["recipe[0]=<null>:missing_recipe"]),
		"recipe set validation should retain a missing candidate's content location"
	)


func _test_mvp_recipe_set_validation_reports_content_location() -> void:
	var ring := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	var candidates: Array[SigilRecipeModel] = [
		SigilRecipeModel.new(&"ring_recipe", ring, &"scout"),
		SigilRecipeModel.new(&"ring_recipe", ring, &"sentinel"),
		SigilRecipeModel.new(&"", GlyphModel.new(), &""),
	]
	var result := MvpContent.validate_recipe_set(candidates)
	_expect(not result["ok"], "invalid recipe set should fail content validation")
	_expect(result["accepted_count"] == 1, "content validation should count only accepted recipes")
	_expect(
		result["errors"] == PackedStringArray([
			"recipe[1]=ring_recipe:duplicate_recipe_id",
			"recipe[1]=ring_recipe:duplicate_glyph_structure",
			"recipe[2]=<empty>:missing_recipe_id",
			"recipe[2]=<empty>:missing_unit_id",
			"recipe[2]=<empty>:glyph:primitive_arity:root:0",
		]),
		"recipe set diagnostics should identify content index, ID, and stable rejection reasons"
	)
	var mvp_result := MvpContent.validate_recipe_set(MvpContent.recipes())
	_expect(mvp_result["ok"] and mvp_result["accepted_count"] == 3, "shipped MVP recipes should pass aggregate validation")


func _test_factory_rejects_invalid_recipe_structures() -> void:
	var ring := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	var spike := GlyphModel.new([GlyphComponentModel.new(&"spike")])
	var branch := GlyphModel.new([GlyphComponentModel.new(&"branch")])
	var invalid_recipes: Array[SigilRecipeModel] = [
		SigilRecipeModel.new(&"", ring, &"scout"),
		SigilRecipeModel.new(&"missing_unit", ring, &""),
		SigilRecipeModel.new(&"empty", GlyphModel.new(), &"scout"),
		SigilRecipeModel.new(
			&"flat_multiple",
			GlyphModel.new([GlyphComponentModel.new(&"ring"), GlyphComponentModel.new(&"spike")]),
			&"golem"
		),
		SigilRecipeModel.new(&"unary_combine", GlyphModel.new([], null, [ring]), &"scout"),
		SigilRecipeModel.new(&"ternary_combine", GlyphModel.new([], null, [ring, spike, branch]), &"golem"),
		SigilRecipeModel.new(
			&"missing_primitive",
			GlyphModel.new([GlyphComponentModel.new(&"")]),
			&"scout"
		),
		SigilRecipeModel.new(
			&"missing_color",
			GlyphModel.new([GlyphComponentModel.new(&"ring", Vector2i.ZERO, 0, 1, &"")]),
			&"scout"
		),
		SigilRecipeModel.new(
			&"invalid_scale",
			GlyphModel.new([GlyphComponentModel.new(&"ring", Vector2i.ZERO, 0, 0)]),
			&"scout"
		),
		SigilRecipeModel.new(&"overlap", GlyphModel.combine(ring, ring), &"scout"),
	]
	var simulation := FactorySimulation.new()
	for recipe in invalid_recipes:
		_expect(not simulation.add_recipe(recipe), "invalid recipe %s should be rejected" % recipe.id)
	var cyclic_recipe := SigilRecipeModel.new(&"cyclic", ring, &"scout")
	cyclic_recipe.glyph.combine_children = [cyclic_recipe.glyph, spike]
	_expect(
		cyclic_recipe.glyph.structure_validation_errors().has("cyclic_structure:root.0"),
		"cyclic Combine should report its recursive path without recursing forever"
	)
	_expect(not simulation.add_recipe(cyclic_recipe), "cyclic Combine recipe should be rejected")
	cyclic_recipe.glyph.combine_children.clear()
	var null_child_recipe := SigilRecipeModel.new(&"null_child", ring, &"scout")
	null_child_recipe.glyph.combine_children = [null, spike]
	_expect(
		null_child_recipe.glyph.structure_validation_errors().has("invalid_child:root.0"),
		"null Combine child should report its path without crashing validation"
	)
	_expect(not simulation.add_recipe(null_child_recipe), "null-child Combine recipe should be rejected")
	_expect(simulation.recipes.is_empty(), "invalid recipe definitions should never enter the registry")
	_expect(
		simulation.add_recipe(SigilRecipeModel.new(&"valid_nested", GlyphModel.combine(ring, GlyphModel.combine(spike, branch)), &"golem")),
		"valid nested binary Combine recipe should remain accepted"
	)


func _test_factory_owns_registered_recipe_data() -> void:
	var simulation := FactorySimulation.new()
	var recipe := SigilRecipeModel.new(
		&"owned_ring",
		GlyphModel.new([GlyphComponentModel.new(&"ring")]),
		&"scout"
	)
	_expect(simulation.add_recipe(recipe), "recipe ownership fixture should register")
	recipe.id = &"mutated_id"
	recipe.unit_id = &"golem"
	recipe.glyph.recolor(&"blue")
	var registered: SigilRecipeModel = simulation.recipes[0]
	_expect(registered.id == &"owned_ring", "registered recipe ID should not share caller mutation")
	_expect(registered.unit_id == &"scout", "registered unit ID should not share caller mutation")
	_expect(
		registered.glyph.components[0].color_id == &"white",
		"registered glyph should not share caller mutation"
	)


func _test_factory_owns_registered_node_data() -> void:
	var simulation := FactorySimulation.new()
	var node := FactoryNodeModel.new(
		&"owned_source",
		FactoryNodeModel.NodeKind.SOURCE,
		{"primitive_id": "ring", "interval_ticks": 18}
	)
	node.output_buffer = GlyphModel.new([GlyphComponentModel.new(&"ring")])
	node.source_timer = 7
	_expect(simulation.add_node(node), "node ownership fixture should register")
	node.id = &"mutated_id"
	node.config["primitive_id"] = "spike"
	node.output_buffer.recolor(&"blue")
	node.source_timer = 99
	var registered: FactoryNodeModel = simulation.nodes[&"owned_source"]
	_expect(registered.id == &"owned_source", "registered node ID should not share caller mutation")
	_expect(registered.config["primitive_id"] == "ring", "registered node config should be owned")
	_expect(
		registered.output_buffer.components[0].color_id == &"white",
		"registered node work in progress should be owned"
	)
	_expect(registered.source_timer == 7, "registered node runtime counters should be copied")
	var invalid_node := FactoryNodeModel.new(&"invalid", FactoryNodeModel.NodeKind.ROTATOR)
	invalid_node.input_buffers[0] = "not-a-glyph"
	_expect(not simulation.add_node(invalid_node), "node registration should reject unsafe work in progress")
	_expect(not simulation.nodes.has(&"invalid"), "rejected node state should not leave a partial registration")


func _test_node_registration_reports_stable_errors() -> void:
	var simulation := FactorySimulation.new()
	var existing := FactoryNodeModel.new(&"existing", FactoryNodeModel.NodeKind.ROTATOR)
	_expect(simulation.add_node(existing), "node diagnostic fixture should register")
	var duplicate := FactoryNodeModel.new(&"existing", FactoryNodeModel.NodeKind.ROTATOR)
	duplicate.input_buffers[0] = "not-a-glyph"
	duplicate.output_buffer = GlyphModel.new([
		GlyphComponentModel.new(&"ring"),
		GlyphComponentModel.new(&"spike"),
	])
	var result := simulation.node_registration_result(duplicate)
	_expect(
		result["errors"] == [
			"duplicate_node_id",
			"invalid_glyph:input[0]:not_glyph",
			"invalid_glyph:output:primitive_arity:root:2",
		],
		"node registration should report identity and work-in-progress errors in stable order"
	)
	_expect(simulation.nodes.size() == 1, "node registration diagnostics should not mutate the factory")
	_expect(
		simulation.node_registration_result(null)["errors"] == ["missing_node"],
		"node registration should reject a missing object without dereferencing it"
	)
	var missing_id := FactoryNodeModel.new(&"", FactoryNodeModel.NodeKind.SUMMONER)
	_expect(
		simulation.node_registration_result(missing_id)["errors"] == ["missing_node_id"],
		"node registration should report an empty node ID"
	)


func _test_factory_duplicate_owns_recipe_data() -> void:
	var simulation := FactorySimulation.new()
	simulation.add_recipe(SigilRecipeModel.new(
		&"owned_ring",
		GlyphModel.new([GlyphComponentModel.new(&"ring")]),
		&"scout"
	))
	var duplicate := simulation.duplicate_state()
	duplicate.recipes[0].id = &"preview_only"
	duplicate.recipes[0].unit_id = &"golem"
	duplicate.recipes[0].glyph.recolor(&"blue")
	var original: SigilRecipeModel = simulation.recipes[0]
	_expect(original.id == &"owned_ring", "duplicate recipe ID mutation should not affect the original")
	_expect(original.unit_id == &"scout", "duplicate unit mutation should not affect the original")
	_expect(
		original.glyph.components[0].color_id == &"white",
		"duplicate glyph mutation should not affect the original"
	)


func _test_factory_duplicate_reports_invalid_state() -> void:
	var simulation := MvpContent.build_factory(MvpContent.PLAN_SCOUT)
	var invalid_glyph := GlyphModel.new([
		GlyphComponentModel.new(&"ring"),
		GlyphComponentModel.new(&"spike"),
	])
	simulation.nodes[&"ring_source"].output_buffer = invalid_glyph
	var tick_before := simulation.tick_index
	var result := simulation.duplicate_state_result()
	_expect(not result["ok"], "invalid work in progress should reject state duplication")
	_expect(result["state"] == null, "rejected state duplication should not expose a partial copy")
	_expect(
		result["errors"] == ["invalid_glyph:node[ring_source].output:primitive_arity:root:2"],
		"state duplication should locate the invalid glyph before deep copying"
	)
	_expect(simulation.tick_index == tick_before, "rejected state duplication should not mutate time")
	_expect(
		simulation.nodes[&"ring_source"].output_buffer == invalid_glyph,
		"rejected state duplication should leave the original work in progress untouched"
	)
	simulation.nodes[&"ring_source"].output_buffer = null
	var valid_result := simulation.duplicate_state_result()
	_expect(valid_result["ok"], "valid factory state should still duplicate through the result API")
	_expect(valid_result["state"] != simulation, "successful state duplication should return an independent factory")

	var mutated_recipe: SigilRecipeModel = simulation.recipes[0]
	mutated_recipe.glyph.combine_children = [mutated_recipe.glyph, mutated_recipe.glyph]
	var recipe_result := simulation.duplicate_state_result()
	_expect(not recipe_result["ok"], "a corrupted registered recipe should reject state duplication safely")
	_expect(
		String(recipe_result["errors"][0]).begins_with("invalid_recipe:recipe[0]="),
		"recipe duplication failure should identify the registry location"
	)
	mutated_recipe.glyph.combine_children = []


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


func _test_factory_owns_connected_line_state() -> void:
	var simulation := FactorySimulation.new()
	simulation.add_node(FactoryNodeModel.new(
		&"source",
		FactoryNodeModel.NodeKind.SOURCE,
		{"primitive_id": "ring", "interval_ticks": 2}
	))
	simulation.add_node(FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER))
	var caller_line := FactoryLineModel.new(&"owned_line", &"source", &"summoner", 0, 3)
	caller_line.payload = GlyphModel.new([GlyphComponentModel.new(&"ring")])
	caller_line.remaining_ticks = 2
	_expect(simulation.connect_nodes(caller_line)["ok"], "line ownership fixture should connect")
	caller_line.id = &"mutated_id"
	caller_line.from_node_id = &"missing"
	caller_line.to_node_id = &"missing"
	caller_line.to_port = 7
	caller_line.travel_ticks = 99
	caller_line.remaining_ticks = 88
	caller_line.payload.recolor(&"blue")
	var stored: FactoryLineModel = simulation.lines[&"owned_line"]
	_expect(stored.id == &"owned_line", "connected line ID should not share caller mutation")
	_expect(stored.from_node_id == &"source" and stored.to_node_id == &"summoner", "connected endpoints should not share caller mutation")
	_expect(stored.to_port == 0 and stored.travel_ticks == 3, "connected routing settings should not share caller mutation")
	_expect(stored.remaining_ticks == 2, "connected transport progress should not share caller mutation")
	_expect(stored.payload.components[0].color_id == &"white", "connected payload should not share caller mutation")


func _test_factory_rejects_invalid_connected_line_state() -> void:
	var simulation := FactorySimulation.new()
	simulation.add_node(FactoryNodeModel.new(&"source", FactoryNodeModel.NodeKind.SOURCE))
	simulation.add_node(FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER))
	var cyclic_payload := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	cyclic_payload.combine_children = [cyclic_payload, cyclic_payload]
	var line := FactoryLineModel.new(&"unsafe", &"source", &"summoner")
	line.payload = cyclic_payload
	var result := simulation.connect_nodes(line)
	_expect(not result["ok"] and result["error"] == "invalid_payload", "unsafe line payload should be rejected before copying")
	_expect(
		result["errors"] == [
			"invalid_glyph:payload:cyclic_structure:root.0",
			"invalid_glyph:payload:cyclic_structure:root.1",
		],
		"line connection should retain the payload structure location"
	)
	_expect(simulation.lines.is_empty(), "rejected line payload should not leave a partial connection")
	_expect(
		simulation.connect_nodes(null)["error"] == "missing_line",
		"line connection should reject a missing object without dereferencing it"
	)
	_expect(
		simulation.connect_nodes(FactoryLineModel.new(&"", &"source", &"summoner"))["error"] == "missing_line_id",
		"line connection should reject an empty line ID"
	)
	cyclic_payload.combine_children = []


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


func _test_factory_validation_rejects_externally_injected_lines() -> void:
	var simulation := FactorySimulation.new()
	var source := FactoryNodeModel.new(&"source", FactoryNodeModel.NodeKind.SOURCE)
	var second_source := FactoryNodeModel.new(&"second_source", FactoryNodeModel.NodeKind.SOURCE)
	var summoner := FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER)
	for node in [source, second_source, summoner]:
		simulation.add_node(node)
	simulation.lines[&"a_valid"] = FactoryLineModel.new(&"a_valid", &"source", &"summoner", 0)
	simulation.lines[&"b_duplicate_input"] = FactoryLineModel.new(
		&"b_duplicate_input", &"second_source", &"summoner", 0
	)
	simulation.lines[&"c_duplicate_output"] = FactoryLineModel.new(
		&"c_duplicate_output", &"source", &"summoner", 0
	)
	simulation.lines[&"d_invalid_port"] = FactoryLineModel.new(
		&"d_invalid_port", &"second_source", &"summoner", 2
	)
	simulation.lines[&"e_missing_from"] = FactoryLineModel.new(
		&"e_missing_from", &"missing", &"summoner", 0
	)
	simulation.lines[&"f_missing_to"] = FactoryLineModel.new(
		&"f_missing_to", &"second_source", &"missing", 0
	)
	var result := simulation.validate_graph()
	_expect(not result["ok"], "authoritative validation should reject externally injected invalid lines")
	_expect(result["errors"].has("occupied_input:summoner:0"), "validation should reject duplicate input wiring")
	_expect(result["errors"].has("occupied_output:source"), "validation should reject implicit output fan-out")
	_expect(result["errors"].has("invalid_port:d_invalid_port"), "validation should reject out-of-range ports")
	_expect(result["errors"].has("missing_from_node:e_missing_from"), "validation should reject missing source nodes")
	_expect(result["errors"].has("missing_to_node:f_missing_to"), "validation should reject missing target nodes")


func _test_factory_validation_rejects_externally_injected_cycle() -> void:
	var simulation := FactorySimulation.new()
	var source := FactoryNodeModel.new(&"source", FactoryNodeModel.NodeKind.SOURCE)
	var first := FactoryNodeModel.new(&"first", FactoryNodeModel.NodeKind.ROTATOR)
	var second := FactoryNodeModel.new(&"second", FactoryNodeModel.NodeKind.COLORIZER)
	var summoner := FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER)
	for node in [source, first, second, summoner]:
		simulation.add_node(node)
	simulation.lines[&"source_first"] = FactoryLineModel.new(&"source_first", &"source", &"first")
	simulation.lines[&"first_second"] = FactoryLineModel.new(&"first_second", &"first", &"second")
	simulation.lines[&"second_first"] = FactoryLineModel.new(&"second_first", &"second", &"first")
	simulation.lines[&"second_summoner"] = FactoryLineModel.new(&"second_summoner", &"second", &"summoner")
	var result := simulation.validate_graph()
	_expect(not result["ok"], "authoritative validation should reject externally injected cycles")
	_expect(result["errors"].has("cycle"), "validation should identify an injected cycle")


func _test_factory_validation_rejects_invalid_restored_configuration() -> void:
	var simulation := FactorySimulation.new()
	var source := FactoryNodeModel.new(
		&"source_id",
		FactoryNodeModel.NodeKind.SOURCE,
		{"primitive_id": "", "interval_ticks": 0}
	)
	var rotator := FactoryNodeModel.new(
		&"rotator",
		FactoryNodeModel.NodeKind.ROTATOR,
		{"steps": 4, "processing_ticks": 0}
	)
	var translator := FactoryNodeModel.new(
		&"translator",
		FactoryNodeModel.NodeKind.TRANSLATOR,
		{"offset": "not-a-vector", "processing_ticks": 1}
	)
	var colorizer := FactoryNodeModel.new(
		&"colorizer",
		FactoryNodeModel.NodeKind.COLORIZER,
		{"color_id": "", "processing_ticks": 1}
	)
	var summoner := FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER)
	simulation.nodes[&"wrong_source_key"] = source
	for node in [rotator, translator, colorizer, summoner]:
		simulation.nodes[node.id] = node
	var mismatched_line := FactoryLineModel.new(&"actual_line_id", &"source_id", &"summoner")
	simulation.lines[&"wrong_line_key"] = mismatched_line
	var result := simulation.validate_graph()
	_expect(not result["ok"], "restored invalid node and line configuration should be rejected")
	for expected_error in [
		"node_key_mismatch:wrong_source_key:source_id",
		"missing_source_primitive:wrong_source_key",
		"invalid_source_interval:wrong_source_key",
		"invalid_processing_ticks:rotator",
		"invalid_rotation_steps:rotator",
		"invalid_translation_offset:translator",
		"missing_color_id:colorizer",
		"line_key_mismatch:wrong_line_key:actual_line_id",
	]:
		_expect(result["errors"].has(expected_error), "restored validation should report %s" % expected_error)


func _test_factory_validation_rejects_invalid_work_in_progress() -> void:
	var simulation := MvpContent.build_factory(MvpContent.PLAN_SENTINEL)
	simulation.nodes[&"ring_source"].output_buffer = GlyphModel.new([
		GlyphComponentModel.new(&"ring"),
		GlyphComponentModel.new(&"spike"),
	])
	simulation.nodes[&"rotator"].input_buffers[0] = "not-a-glyph"
	var malformed_payload := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	malformed_payload.combine_children = [null, GlyphModel.new([GlyphComponentModel.new(&"ring")])]
	simulation.lines[&"line_1"].payload = malformed_payload
	var expected_errors: Array[String] = [
		"invalid_glyph:node[ring_source].output:primitive_arity:root:2",
		"invalid_glyph:node[rotator].input[0]:not_glyph",
		"invalid_glyph:line[line_1].payload:invalid_child:root.0",
	]
	_expect(
		simulation.work_in_progress_validation_errors() == expected_errors,
		"work-in-progress validation should report stable equipment and line locations"
	)
	var validation := simulation.validate_graph()
	_expect(not validation["ok"], "invalid restored work in progress should block factory execution")
	for expected_error in expected_errors:
		_expect(validation["errors"].has(expected_error), "graph validation should include %s" % expected_error)
	var tick_before := simulation.tick_index
	simulation.tick()
	_expect(simulation.tick_index == tick_before, "invalid work in progress should stop fixed-tick time")
	_expect(
		simulation.last_runtime_glyph_errors == expected_errors,
		"stopped tick should retain actionable runtime glyph errors"
	)
	simulation.discard_all_work_in_progress()
	_expect(simulation.last_runtime_glyph_errors.is_empty(), "discarding invalid work should clear stopped-tick errors")
	var board := FactoryBoard.new()
	board.size = Vector2(568, 339)
	board.configure(MvpContent.PLAN_SENTINEL)
	board.simulation.nodes[&"ring_source"].output_buffer = GlyphModel.new([
		GlyphComponentModel.new(&"ring"),
		GlyphComponentModel.new(&"spike"),
	])
	board._refresh_production_preview()
	_expect(
		"仕掛品データが破損" in board.cached_production_preview,
		"production preview should explain invalid restored work in progress"
	)
	board.free()


func _test_factory_validation_order_is_stable() -> void:
	var forward := FactorySimulation.new()
	var reverse := FactorySimulation.new()
	for node_id in [&"z_node", &"a_node"]:
		forward.add_node(FactoryNodeModel.new(node_id, FactoryNodeModel.NodeKind.ROTATOR))
	for node_id in [&"a_node", &"z_node"]:
		reverse.add_node(FactoryNodeModel.new(node_id, FactoryNodeModel.NodeKind.ROTATOR))
	var injected_lines := [
		FactoryLineModel.new(&"z_line", &"missing", &"a_node"),
		FactoryLineModel.new(&"a_line", &"z_node", &"missing"),
	]
	for line in injected_lines:
		forward.lines[line.id] = line
	injected_lines.reverse()
	for line in injected_lines:
		reverse.lines[line.id] = line
	_expect(
		forward.validate_graph()["errors"] == reverse.validate_graph()["errors"],
		"graph validation diagnostics should not depend on node or line insertion order"
	)


func _test_factory_flow_diagnostics_distinguish_blockages() -> void:
	var simulation := FactorySimulation.new()
	var source := FactoryNodeModel.new(&"source", FactoryNodeModel.NodeKind.SOURCE)
	var blocked := FactoryNodeModel.new(&"blocked", FactoryNodeModel.NodeKind.ROTATOR)
	var combiner := FactoryNodeModel.new(&"combiner", FactoryNodeModel.NodeKind.COMBINER)
	for node in [source, blocked, combiner]:
		simulation.add_node(node)
	source = simulation.nodes[&"source"]
	blocked = simulation.nodes[&"blocked"]
	combiner = simulation.nodes[&"combiner"]
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


func _test_battle_enforces_spawn_capacity_and_rate() -> void:
	var rate_battle := BattleSimulation.new()
	var durable := UnitSpecModel.new(&"durable", 100.0, 1.0, 100, 0.0, 1.0, 0.0, 1, &"", 1.0, 10000)
	rate_battle.add_spec(durable)
	for _index in BattleSimulation.MAX_SPAWNS_PER_SIDE_PER_TICK:
		_expect(rate_battle.spawn_player(&"durable"), "spawns through the per-tick limit should succeed")
	_expect(not rate_battle.spawn_player(&"durable"), "spawn beyond the same-tick rate limit should be rejected")
	_expect(
		rate_battle.battle_events[-1]["reason"] == &"rate_cap",
		"same-tick rejection should retain its rate-cap reason"
	)
	rate_battle.tick()
	_expect(rate_battle.spawn_player(&"durable"), "spawn rate budget should reset on the next battle tick")
	var rate_board := BattleBoard.new()
	rate_board.simulation = rate_battle
	_expect("上限拒否 青1" in rate_board.capacity_status_text(), "battlefield should disclose rejected player summons")
	rate_board.free()

	var capacity_battle := BattleSimulation.new()
	capacity_battle.add_spec(durable)
	var batches := int(BattleSimulation.MAX_UNITS_PER_SIDE / BattleSimulation.MAX_SPAWNS_PER_SIDE_PER_TICK)
	for batch in batches:
		for _index in BattleSimulation.MAX_SPAWNS_PER_SIDE_PER_TICK:
			_expect(capacity_battle.spawn_player(&"durable"), "spawns below the simultaneous unit cap should succeed")
		if batch < batches - 1:
			capacity_battle.tick()
	_expect(
		capacity_battle.active_unit_count(BattleSimulation.Side.PLAYER) == BattleSimulation.MAX_UNITS_PER_SIDE,
		"battle should reach but never exceed its per-side simultaneous unit cap"
	)
	_expect(not capacity_battle.spawn_player(&"durable"), "spawn beyond the simultaneous unit cap should be rejected")
	_expect(
		capacity_battle.battle_events[-1]["reason"] == &"unit_cap",
		"simultaneous-count rejection should retain its unit-cap reason"
	)


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


func _test_major_change_forecast_uses_long_horizon() -> void:
	var battle := MvpContent.build_battle()
	_expect(battle.upcoming_major_changes(299).is_empty(), "major wave should remain outside a shorter-than-sixty-second horizon")
	var changes := battle.upcoming_major_changes(300)
	_expect(changes.size() == 1, "sixty-second horizon should include the first major wave change")
	if changes.size() == 1:
		_expect(changes[0].tick == 300 and changes[0].unit_id == &"swarm", "first major change should mark the swarm phase")
	var board := BattleBoard.new()
	board.simulation = battle
	_expect(
		board.major_change_text(300, 120, 0.2) == "編成警告 60s: 群体兵→衛兵",
		"long-horizon warning should name timing, wave, and recommended counter"
	)
	battle.tick_index = 180
	_expect(
		board.major_change_text(300, 120, 0.2) == "",
		"major warning should not duplicate a change already inside the near horizon"
	)
	battle.tick_index = 270
	_expect(
		board.major_change_text(300, 120, 0.2) == "編成警告 60s: 装甲兵→巨像",
		"warning should look past the near swarm change to the next major armor phase"
	)
	board.free()


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


func _test_factory_edit_recovers_only_invalid_work_in_progress() -> void:
	var board := FactoryBoard.new()
	board.configure(MvpContent.PLAN_SENTINEL)
	var valid_glyph := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	var invalid_glyph := GlyphModel.new([
		GlyphComponentModel.new(&"ring"),
		GlyphComponentModel.new(&"spike"),
	])
	board.simulation.nodes[&"rotator"].input_buffers[0] = valid_glyph
	board.simulation.nodes[&"ring_source"].output_buffer = invalid_glyph
	var discarded_before := board.simulation.discarded_glyphs
	board.begin_edit()
	_expect(board.editing and board.preview_simulation != null, "corrupt work recovery should still enter edit mode")
	_expect(board.last_corrupt_discard_count == 1, "edit recovery should discard only one invalid work item")
	_expect(
		board.simulation.nodes[&"rotator"].input_buffers[0] != null,
		"edit recovery should preserve valid committed work in progress"
	)
	_expect(
		board.preview_simulation.nodes[&"rotator"].input_buffers[0] != null,
		"edit preview should retain a safe copy of valid work in progress"
	)
	_expect(board.simulation.nodes[&"ring_source"].output_buffer == null, "edit recovery should remove invalid committed work")
	_expect(
		board.simulation.discarded_glyphs == discarded_before + 1,
		"edit recovery should count the invalid work as discarded"
	)
	_expect("破損仕掛品 1個を廃棄" in board.connection_message, "edit recovery should explain the automatic discard")
	board.cancel_edit()
	_expect(
		board.simulation.nodes[&"rotator"].input_buffers[0] != null,
		"cancel should keep valid committed work after corrupt recovery"
	)
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


func _test_factory_enforces_single_summoner() -> void:
	var board := FactoryBoard.new()
	board.configure(MvpContent.PLAN_EMPTY)
	board.set_interaction_enabled(true)
	var initial_node_count := board.simulation.nodes.size()
	_expect(board.add_node_from_palette(&"summoner") == &"", "palette should reject a second summoner in the MVP")
	_expect(board.simulation.nodes.size() == initial_node_count, "rejected second summoner should not mutate the graph")
	_expect("1基まで" in board.connection_message, "summoner rejection should explain the MVP limit")
	_expect(board.remove_factory_node(&"summoner"), "existing summoner should remain removable")
	var replacement_id := board.add_node_from_palette(&"summoner")
	_expect(replacement_id != &"", "removing the original summoner should allow one replacement")
	board.simulation.add_node(FactoryNodeModel.new(&"forced_summoner", FactoryNodeModel.NodeKind.SUMMONER))
	var validation := board.validation_result()
	_expect(not validation["ok"], "forced multiple-summoner graph should fail validation")
	_expect(validation["errors"].has("multiple_summoners"), "validation should identify the multiple-summoner violation")
	board.free()


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
	blocked = board.simulation.nodes[&"blocked"]
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


func _test_factory_production_preview_explains_first_mismatch() -> void:
	var board := FactoryBoard.new()
	board.size = Vector2(568, 339)
	board.configure(MvpContent.PLAN_EMPTY)
	board.simulation.nodes[&"ring_source"].config["primitive_id"] = "spike"
	board.simulation.nodes[&"ring_source"].config["interval_ticks"] = 18
	board.simulation.connect_nodes(
		FactoryLineModel.new(&"preview_mismatch", &"ring_source", &"summoner")
	)
	var tick_before := board.simulation.tick_index
	var failure_count_before := board.simulation.summon_failure_events.size()
	var preview := board.production_preview(160)
	_expect(preview["ok"], "wired mismatching factory should still produce a preview")
	_expect(preview["discarded"] > 0, "mismatching factory preview should count rejected glyphs")
	var first_failure: Dictionary = preview["first_failure"]
	_expect(not first_failure.is_empty(), "mismatching factory preview should expose its first failure")
	if not first_failure.is_empty():
		_expect(
			first_failure["closest_recipe_id"] == &"bound_colossus",
			"preview should identify the closest recipe before battle"
		)
		var diagnostics: PackedStringArray = first_failure["diagnostics"]
		_expect(diagnostics[0] == "部品不足: ring", "preview should retain the highest-priority correction")
	board._refresh_production_preview()
	_expect("巨像: 部品不足 環" in board.cached_production_preview, "preview UI should explain the first correction")
	_expect(board.simulation.tick_index == tick_before, "mismatch preview should not advance the real factory")
	_expect(
		board.simulation.summon_failure_events.size() == failure_count_before,
		"mismatch preview should not add failures to the real factory"
	)
	board.free()


func _test_factory_board_explains_restored_validation_errors() -> void:
	var board := FactoryBoard.new()
	board.size = Vector2(568, 339)
	board.configure(MvpContent.PLAN_SCOUT)
	board.simulation.nodes[&"ring_source"].config["primitive_id"] = ""
	var validation := board.validation_result()
	_expect(not validation["ok"], "invalid restored source configuration should block factory start")
	_expect(
		validation["message"] == "素材源「ring_source」の素材設定がありません",
		"factory start rejection should name the invalid source setting"
	)
	board._refresh_production_preview()
	_expect(
		"素材源「ring_source」の素材設定がありません" in board.cached_production_preview,
		"production preview should show the same actionable validation reason"
	)
	_expect(
		board._validation_message(["cycle"]) == "配線が循環しています。循環するラインを解除してください",
		"restored cycle should have an actionable player-facing message"
	)
	_expect(
		"出力が分岐" in board._validation_message(["occupied_output:source"]),
		"restored implicit fan-out should explain the wiring violation"
	)
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
