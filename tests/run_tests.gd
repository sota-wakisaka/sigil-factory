extends SceneTree

const GlyphComponentModel := preload("res://src/domain/glyph_component.gd")
const GlyphModel := preload("res://src/domain/glyph.gd")
const MeaningGlyphsModel := preload("res://src/domain/meaning_glyphs.gd")
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
const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")
const GlyphTooltipModel := preload("res://src/ui/glyph_tooltip.gd")
const GlyphComparisonTooltipModel := preload("res://src/ui/glyph_comparison_tooltip.gd")
const RunFlow := preload("res://src/game/run_flow.gd")

var failures := 0


func _initialize() -> void:
	_test_exact_match_is_order_independent()
	_test_matcher_rejects_invalid_structures_safely()
	_test_canonical_encoding_frames_delimiter_ids()
	_test_attribute_diagnostics()
	_test_missing_and_extra_components()
	_test_diagnostics_are_stable_for_duplicate_primitives()
	_test_diagnostics_follow_player_facing_priority()
	_test_combine_structure_is_order_independent()
	_test_combine_connection_modes_are_visible_and_canonical()
	_test_pairwise_connections_remove_overlaps()
	_test_combine_children_use_hash_then_serialization_order()
	_test_combine_hierarchy_affects_matching()
	_test_production_context_does_not_affect_matching()
	_test_rotation_is_normalized_to_quarter_turns()
	_test_free_angle_rotation_is_canonical()
	_test_combined_rotation_transforms_positions_and_orientation()
	_test_combined_move_transforms_structure_center()
	_test_transform_history_folds_into_final_state()
	_test_complete_overlap_is_rejected()
	_test_meaning_glyph_library_is_owned_and_valid()
	_test_factory_tick_prevents_same_tick_multistage_processing()
	_test_factory_tick_uses_starting_input_availability()
	_test_factory_tick_does_not_refill_freed_line()
	_test_factory_replay_is_independent_of_insertion_order()
	_test_factory_pipeline_summons_matching_unit()
	_test_factory_meaning_glyph_source_summons_registered_recipe()
	_test_factory_recipe_match_preview_is_non_destructive()
	_test_factory_records_closest_summon_failure()
	_test_factory_closest_recipe_is_order_independent()
	_test_factory_rejects_ambiguous_recipes()
	_test_recipe_registration_reports_stable_errors()
	_test_recipe_registration_rejects_missing_objects()
	_test_mvp_recipe_set_validation_reports_content_location()
	_test_factory_rejects_invalid_recipe_structures()
	_test_glyph_preserves_invalid_restored_elements_for_diagnostics()
	_test_shared_glyph_painter_rejects_invalid_structures()
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
	_test_factory_tick_preserves_work_during_corrupt_recipe_state()
	_test_factory_validation_order_is_stable()
	_test_factory_flow_diagnostics_distinguish_blockages()
	_test_mvp_plans_produce_expected_units()
	_test_mvp_routes_have_distinct_valid_schedules()
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
	_test_factory_mutations_fail_closed_without_undo_snapshot()
	_test_factory_mana_budget_limits_and_refunds_nodes()
	_test_factory_goal_equipment_presence_tracks_inventory()
	_test_factory_enforces_single_summoner()
	_test_factory_node_configuration_is_undoable()
	_test_factory_configuration_discards_work_transactionally()
	_test_factory_preset_preview_is_undoable()
	_test_source_configuration_resets_generation_progress()
	_test_factory_setting_preview_is_non_destructive()
	_test_factory_rewiring_discards_work_transactionally()
	_test_factory_board_connections_change_output()
	_test_factory_board_shows_summon_failure_reason()
	_test_factory_board_replaces_failure_with_success()
	_test_factory_board_shows_distinct_flow_warning()
	_test_factory_board_holds_transient_flow_warning()
	_test_factory_board_exposes_visible_work_in_progress_glyphs()
	_test_factory_board_offers_visual_glyph_tooltips()
	_test_factory_board_exposes_node_activity_progress()
	_test_factory_processor_role_marks_follow_settings()
	_test_factory_interaction_legend_is_explanatory_and_non_destructive()
	_test_factory_downstream_route_focus_is_non_destructive()
	_test_factory_ports_connect_through_mouse_input()
	_test_factory_overlapping_hits_follow_draw_order()
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


func _test_matcher_rejects_invalid_structures_safely() -> void:
	var ring := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	var missing_actual := SigilMatcher.compare(null, ring)
	_expect(not missing_actual["is_match"], "matcher should reject a missing actual Glyph")
	_expect(
		missing_actual["diagnostics"] == PackedStringArray(["入力グリフがありません"]),
		"missing actual Glyph should return a direct diagnostic"
	)
	var missing_target := SigilMatcher.compare(ring, null)
	_expect(not missing_target["is_match"], "matcher should reject a missing target Glyph")
	_expect(
		missing_target["diagnostics"] == PackedStringArray(["シジル定義がありません"]),
		"missing target Glyph should identify the recipe definition"
	)
	var missing_components: Array[GlyphComponentModel] = [null]
	var invalid_component := GlyphModel.new(missing_components)
	var invalid_result := SigilMatcher.compare(invalid_component, ring)
	_expect(not invalid_result["is_match"], "matcher should reject an invalid actual component")
	_expect(
		"invalid_component:root" in invalid_result["diagnostics"][0],
		"invalid actual component should retain its structural path"
	)
	var spike := GlyphModel.new([GlyphComponentModel.new(&"spike")])
	var cyclic := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	cyclic.combine_children = [cyclic, spike]
	var cyclic_result := SigilMatcher.compare(cyclic, ring)
	_expect(not cyclic_result["is_match"], "matcher should reject a cyclic actual Glyph without recursing forever")
	_expect(
		"cyclic_structure:root.0" in cyclic_result["diagnostics"][0],
		"cyclic matcher rejection should retain the recursive path"
	)
	cyclic.combine_children.clear()


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


func _test_combine_connection_modes_are_visible_and_canonical() -> void:
	var top := GlyphModel.new([GlyphComponentModel.new(&"spike", Vector2(0, -4))])
	var right := GlyphModel.new([GlyphComponentModel.new(&"spike", Vector2(3.464, 2), 0, 1, &"white", 120)])
	var left := GlyphModel.new([GlyphComponentModel.new(&"spike", Vector2(-3.464, 2), 0, 1, &"white", 240)])
	var radial := GlyphModel.combine_many([top, right, left], GlyphModel.CONNECTION_RADIAL)
	var pairwise := GlyphModel.combine_many([top, right, left], GlyphModel.CONNECTION_PAIRWISE)
	_expect(
		not SigilMatcher.compare(radial, pairwise)["is_match"],
		"radial and pairwise Combine modes should remain distinct CanonicalGlyphs"
	)
	_expect(
		SigilMatcher.compare(radial, pairwise)["diagnostics"].has("接続方式が違います"),
		"connection-only mismatches should identify the selected Combine mode"
	)
	_expect(
		pairwise.copy().canonical_serialization() == pairwise.canonical_serialization(),
		"Glyph copies should preserve the Combine connection mode"
	)
	var visuals := GlyphPainterModel.combine_visuals(pairwise)
	_expect(visuals["connections"].size() == 3, "three pairwise children should form three edge-to-edge connections")
	var child_centers: Array[Vector2] = [
		Vector2(0, -24),
		Vector2(20.784, 12),
		Vector2(-20.784, 12),
	]
	for connection in visuals["connections"]:
		for child_center in child_centers:
			_expect(
				connection["from"].distance_to(child_center) > 0.1
				and connection["to"].distance_to(child_center) > 0.1,
				"pairwise connections should stop before entering child Glyphs"
			)


func _test_pairwise_connections_remove_overlaps() -> void:
	var left := GlyphModel.new([GlyphComponentModel.new(&"ring", Vector2(-4, 0))])
	var center := GlyphModel.new([GlyphComponentModel.new(&"spike", Vector2.ZERO)])
	var right := GlyphModel.new([GlyphComponentModel.new(&"branch", Vector2(4, 0))])
	var pairwise := GlyphModel.combine_many(
		[left, center, right],
		GlyphModel.CONNECTION_PAIRWISE
	)
	var visuals := GlyphPainterModel.combine_visuals(pairwise)
	_expect(
		visuals["connections"].size() == 2,
		"collinear pairwise edges should merge instead of drawing darker overlapping lines"
	)
	for connection in visuals["connections"]:
		var from: Vector2 = connection["from"]
		var to: Vector2 = connection["to"]
		_expect(
			from.distance_to(Vector2.ZERO) >= 2.7 and to.distance_to(Vector2.ZERO) >= 2.7,
			"pairwise edges should be cut where they pass through the centered child Glyph"
		)


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
		== "C(3:0,0;%d:%s,%d:%s)" % [
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


func _test_free_angle_rotation_is_canonical() -> void:
	var glyph := GlyphModel.new([
		GlyphComponentModel.new(&"spike", Vector2i(0, -4)),
	])
	var original := glyph.canonical_serialization()
	glyph.rotate_degrees(120)
	_expect(glyph.components[0].rotation_degrees == 120, "free-angle rotation should preserve the visible angle")
	_expect(
		GlyphComponentModel.coordinate_key(glyph.components[0].position.x) == "3.464"
		and GlyphComponentModel.coordinate_key(glyph.components[0].position.y) == "2",
		"free-angle rotation should rotate position around the shared origin"
	)
	glyph.rotate_degrees(120)
	glyph.rotate_degrees(120)
	_expect(glyph.canonical_serialization() == original, "three 120° rotations should restore the exact canonical Glyph")
	var forty_five := GlyphModel.new([GlyphComponentModel.new(&"spike")])
	forty_five.rotate_degrees(45)
	_expect(
		not SigilMatcher.compare(forty_five, GlyphModel.new([GlyphComponentModel.new(&"spike")]))["is_match"],
		"45° and 0° Glyphs should remain distinct"
	)


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


func _test_combined_move_transforms_structure_center() -> void:
	var ring := GlyphModel.new([
		GlyphComponentModel.new(&"ring", Vector2i(-2, 0)),
	])
	var spike := GlyphModel.new([
		GlyphComponentModel.new(&"spike", Vector2i(2, 0)),
	])
	var combined := GlyphModel.combine(ring, spike)
	combined.translate(Vector2i(0, -4))
	_expect(combined.combine_origin == Vector2(0, -4), "moving a completed Combine should move its structural center")
	var visuals := GlyphPainterModel.combine_visuals(combined)
	_expect(visuals["circles"][0]["center"] == Vector2(0, -24), "the Combine circle should follow the moved center")
	for connection in visuals["connections"]:
		_expect(connection["from"] == Vector2(0, -24), "moved Combine spokes should begin at the moved center")
	var owned_copy := combined.copy()
	_expect(owned_copy.combine_origin == combined.combine_origin, "Glyph copies should preserve every Combine center")
	combined.rotate(1)
	_expect(combined.combine_origin == Vector2(4, 0), "rotating a moved Combine should rotate its center around the root origin")

	var moved_ring := ring.copy()
	var moved_spike := spike.copy()
	moved_ring.translate(Vector2i(0, -4))
	moved_spike.translate(Vector2i(0, -4))
	var moved_before_combine := GlyphModel.combine(moved_ring, moved_spike)
	_expect(
		not SigilMatcher.compare(owned_copy, moved_before_combine)["is_match"],
		"moving a completed group should remain distinct from moving its children before Combine"
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


func _test_meaning_glyph_library_is_owned_and_valid() -> void:
	_expect(MeaningGlyphsModel.IDS.size() == 5, "shared meaning Glyphs should expose the five accepted marks")
	var first_eye := MeaningGlyphsModel.glyph(MeaningGlyphsModel.EYE)
	var second_eye := MeaningGlyphsModel.glyph(MeaningGlyphsModel.EYE)
	_expect(first_eye != null and second_eye != null, "shared meaning Glyph lookup should return authored copies")
	if first_eye != null and second_eye != null:
		var untouched := second_eye.canonical_serialization()
		first_eye.components[0].position = Vector2(9, 9)
		_expect(
			second_eye.canonical_serialization() == untouched,
			"meaning Glyph callers should not share mutable component state"
		)
	var seen: Dictionary = {}
	for glyph_id in MeaningGlyphsModel.IDS:
		var glyph := MeaningGlyphsModel.glyph(glyph_id)
		_expect(glyph != null, "%s should be available to product content" % glyph_id)
		if glyph == null:
			continue
		_expect(glyph.structure_validation_errors().is_empty(), "%s should be structurally valid" % glyph_id)
		_expect(glyph.combine_connection_mode == GlyphModel.CONNECTION_SIMPLE, "%s should keep line-free grouping" % glyph_id)
		var serialization := glyph.canonical_serialization()
		_expect(not seen.has(serialization), "%s should remain canonically distinct" % glyph_id)
		seen[serialization] = true
	_expect(MeaningGlyphsModel.glyph(&"unknown") == null, "unknown meaning Glyph IDs should fail closed")


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


func _test_factory_meaning_glyph_source_summons_registered_recipe() -> void:
	var simulation := FactorySimulation.new()
	var source := FactoryNodeModel.new(
		&"meaning_source",
		FactoryNodeModel.NodeKind.SOURCE,
		{"meaning_glyph_id": MeaningGlyphsModel.CROSS, "interval_ticks": 1}
	)
	var summoner := FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER)
	_expect(simulation.add_node(source), "a registered meaning Glyph should be accepted as a factory source")
	_expect(simulation.add_node(summoner), "meaning Glyph pipeline should accept a summoner")
	_expect(
		simulation.connect_nodes(FactoryLineModel.new(&"meaning_line", &"meaning_source", &"summoner"))["ok"],
		"meaning Glyph source should connect through ordinary factory lines"
	)
	simulation.add_recipe(SigilRecipeModel.new(&"cross_mark", MeaningGlyphsModel.glyph(MeaningGlyphsModel.CROSS), &"sentinel"))
	for _tick in 8:
		simulation.tick()
	_expect(not simulation.summon_events.is_empty(), "registered meaning Glyph should reach exact recipe matching")
	if not simulation.summon_events.is_empty():
		_expect(simulation.summon_events[0]["recipe_id"] == &"cross_mark", "meaning source should preserve canonical identity")
	var ambiguous := FactoryNodeModel.new(
		&"ambiguous",
		FactoryNodeModel.NodeKind.SOURCE,
		{"primitive_id": "ring", "meaning_glyph_id": MeaningGlyphsModel.EYE, "interval_ticks": 1}
	)
	_expect(simulation.add_node(ambiguous), "restored source configuration should be retained for diagnostics")
	var unknown := FactoryNodeModel.new(
		&"unknown",
		FactoryNodeModel.NodeKind.SOURCE,
		{"meaning_glyph_id": "missing", "interval_ticks": 1}
	)
	_expect(simulation.add_node(unknown), "unknown restored meaning Glyph should be retained for diagnostics")
	var validation_errors: PackedStringArray = simulation.validate_graph()["errors"]
	_expect(validation_errors.has("ambiguous_source_glyph:ambiguous"), "a source should not hide two competing Glyph definitions")
	_expect(validation_errors.has("unknown_meaning_glyph:unknown:missing"), "unknown meaning Glyph IDs should fail closed before simulation")


func _test_factory_recipe_match_preview_is_non_destructive() -> void:
	var simulation := MvpContent.build_factory(MvpContent.PLAN_SCOUT)
	var ring := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	var spike := GlyphModel.new([GlyphComponentModel.new(&"spike")])
	var event_count := simulation.summon_events.size()
	var discard_count := simulation.discarded_glyphs
	var matching := simulation.recipe_match_result(ring)
	_expect(matching["ok"] and matching["is_match"], "match preview should identify an acquired exact recipe")
	_expect(matching["recipe_id"] == &"open_ring", "match preview should expose the exact recipe ID")
	var mismatch := simulation.recipe_match_result(spike)
	_expect(mismatch["ok"] and not mismatch["is_match"], "match preview should identify a non-matching Glyph")
	_expect(mismatch["closest_recipe_id"] != &"", "mismatch preview should retain the closest acquired recipe")
	var missing := simulation.recipe_match_result(null)
	_expect(not missing["ok"] and not missing["is_match"], "match preview should reject a missing candidate safely")
	_expect(
		missing["errors"] == ["invalid_glyph:candidate:missing_glyph"],
		"missing match candidate should retain its API location"
	)
	_expect(simulation.summon_events.size() == event_count, "match preview should not emit summon events")
	_expect(simulation.discarded_glyphs == discard_count, "match preview should not discard its candidate")


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
	var too_many_children: Array = []
	for child_index in 9:
		too_many_children.append(GlyphModel.new([
			GlyphComponentModel.new(StringName("arity_%d" % child_index)),
		]))
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
		SigilRecipeModel.new(&"oversized_combine", GlyphModel.new([], null, too_many_children), &"golem"),
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
		"valid nested Combine recipe should remain accepted"
	)


func _test_glyph_preserves_invalid_restored_elements_for_diagnostics() -> void:
	var missing_components: Array[GlyphComponentModel] = [null]
	var missing_component := GlyphModel.new(missing_components)
	_expect(
		missing_component.structure_validation_errors() == PackedStringArray(["invalid_component:root"]),
		"Glyph construction should retain a null component for structural diagnostics"
	)
	_expect(
		missing_component.copy().structure_validation_errors() == PackedStringArray(["invalid_component:root"]),
		"Glyph copying should retain a null component without dereferencing it"
	)
	var ring := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	var missing_child := GlyphModel.new([], null, [null, ring])
	_expect(
		missing_child.structure_validation_errors() == PackedStringArray(["invalid_child:root.0"]),
		"Glyph construction should retain a null Combine child with its path"
	)
	_expect(
		missing_child.copy().structure_validation_errors() == PackedStringArray(["invalid_child:root.0"]),
		"Glyph copying should retain a null Combine child without dereferencing it"
	)


func _test_shared_glyph_painter_rejects_invalid_structures() -> void:
	var valid := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	var invalid := GlyphModel.new([GlyphComponentModel.new(&"ring"), GlyphComponentModel.new(&"spike")])
	_expect(GlyphPainterModel.can_draw(valid), "shared Glyph painter should accept a valid structure")
	_expect(not GlyphPainterModel.can_draw(invalid), "shared Glyph painter should reject an invalid structure")
	_expect(
		GlyphPainterModel.component_color(&"blue") == GlyphPainterModel.BLUE_GLYPH,
		"shared Glyph painter should own the color mapping used by every factory view"
	)
	_expect(
		GlyphPainterModel.primitive_stroke_width(2.0) > GlyphPainterModel.combine_stroke_width(2.0)
		and GlyphPainterModel.combine_stroke_width(2.0) > GlyphPainterModel.connection_stroke_width(2.0),
		"shared Glyph painter should enforce Primitive > Combine circle > connection line hierarchy"
	)
	var spike := GlyphModel.new([GlyphComponentModel.new(&"spike")])
	var branch := GlyphModel.new([GlyphComponentModel.new(&"branch")])
	var nested := GlyphModel.combine(GlyphModel.combine(valid, spike), branch)
	var nested_visuals := GlyphPainterModel.combine_visuals(nested, 2.0)
	_expect(nested_visuals["circles"].size() == 2, "each nested Combine should produce its own structural circle")
	_expect(nested_visuals["connections"].is_empty(), "coincident nested Combine children should not create artificial spokes")
	_expect(
		float(nested_visuals["circles"][0]["radius"]) > float(nested_visuals["circles"][1]["radius"]),
		"outer Combine circle should remain larger than its nested child circle"
	)
	var left := GlyphModel.new([GlyphComponentModel.new(&"ring", Vector2i(-1, 0))])
	var right := GlyphModel.new([GlyphComponentModel.new(&"spike", Vector2i(1, 0))])
	var separated_visuals := GlyphPainterModel.combine_visuals(GlyphModel.combine(left, right), 2.0)
	_expect(separated_visuals["connections"].size() == 2, "positioned Combine children should draw low-priority structural connections")
	var coincident := GlyphModel.combine(valid, spike)
	var coincident_visuals := GlyphPainterModel.combine_visuals(coincident, 2.0)
	_expect(coincident_visuals["connections"].is_empty(), "children at the exact Combine center should not draw misleading connection lines")
	_expect(
		coincident_visuals["circles"][0]["center"] == Vector2.ZERO,
		"Combine circles should stay at the canonical origin instead of the children centroid"
	)
	var reversed := GlyphModel.new([], null, [spike, valid])
	_expect(
		GlyphPainterModel.combine_visuals(reversed, 2.0)["connections"] == coincident_visuals["connections"],
		"Combine connection layout should follow canonical child order rather than restored array order"
	)
	var radial_children: Array = []
	for child_index in 6:
		radial_children.append(GlyphModel.new([
			GlyphComponentModel.new(
				StringName("radial_%d" % child_index),
				Vector2i(Vector2.RIGHT.rotated(float(child_index) * TAU / 6.0).round())
			),
		]))
	var radial := GlyphModel.combine_many(radial_children)
	var radial_visuals := GlyphPainterModel.combine_visuals(radial, 2.0)
	_expect(radial.is_structure_valid(), "Combine should accept up to six children in one hierarchy level")
	_expect(radial_visuals["circles"].size() == 1, "six-way Combine should need only one structural circle")
	_expect(radial_visuals["connections"].size() == 6, "six-way Combine should connect every child from the center")
	for connection in radial_visuals["connections"]:
		_expect(connection["from"] == Vector2.ZERO, "positioned six-way children should all connect from the canonical center")


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


func _test_factory_tick_preserves_work_during_corrupt_recipe_state() -> void:
	var simulation := MvpContent.build_factory(MvpContent.PLAN_SCOUT)
	var summoner: FactoryNodeModel = simulation.nodes[&"summoner"]
	var waiting := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	summoner.input_buffers[0] = waiting
	var corrupted_recipe: SigilRecipeModel = simulation.recipes[0]
	var original_glyph := corrupted_recipe.glyph
	corrupted_recipe.glyph = null
	var tick_before := simulation.tick_index
	var discarded_before := simulation.discarded_glyphs
	simulation.tick()
	var expected_errors: Array[String] = [
		"invalid_recipe:recipe[0]=azure_guard:missing_glyph",
	]
	_expect(simulation.tick_index == tick_before, "corrupt recipe state should stop fixed-tick time")
	_expect(summoner.input_buffers[0] == waiting, "stopped recipe validation should preserve the waiting Glyph")
	_expect(simulation.discarded_glyphs == discarded_before, "corrupt recipe state should not discard valid work")
	_expect(
		simulation.last_runtime_recipe_errors == expected_errors,
		"stopped tick should retain the corrupt recipe registry location"
	)
	var validation := simulation.validate_graph()
	_expect(not validation["ok"], "corrupt recipe registry should block graph execution")
	_expect(validation["errors"].has(expected_errors[0]), "graph validation should share the recipe corruption reason")
	corrupted_recipe.glyph = original_glyph
	simulation.tick()
	_expect(simulation.tick_index == tick_before + 1, "restoring the recipe should resume fixed-tick time")
	_expect(simulation.last_runtime_recipe_errors.is_empty(), "successful resumed tick should clear recipe errors")

	var board := FactoryBoard.new()
	board.configure(MvpContent.PLAN_SCOUT)
	board.simulation.recipes[0].glyph = null
	var board_validation := board.validation_result()
	_expect(not board_validation["ok"], "factory board should block a corrupted acquired recipe")
	_expect(
		board_validation["message"] == "取得済みシジルデータが破損しています。ランデータを再読み込みしてください",
		"factory board should explain recipe corruption separately from wiring errors"
	)
	board._refresh_production_preview()
	_expect(
		"取得済みシジルデータが破損" in board.cached_production_preview,
		"32-second preview should share the recipe corruption explanation"
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


func _test_mvp_routes_have_distinct_valid_schedules() -> void:
	var signatures: Dictionary = {}
	for route_id in MvpContent.ROUTE_IDS:
		var schedule := MvpContent.threat_schedule(route_id)
		_expect(not schedule.is_empty(), "%s should provide a battle schedule" % route_id)
		var previous_tick := -1
		var unit_counts: Dictionary = {}
		for event in schedule:
			_expect(event.tick >= previous_tick, "%s threats should stay ordered" % route_id)
			_expect(event.tick <= 900, "%s threats should fit the three-minute encounter" % route_id)
			previous_tick = event.tick
			unit_counts[event.unit_id] = int(unit_counts.get(event.unit_id, 0)) + event.count
		var signature := JSON.stringify(unit_counts)
		_expect(not signatures.has(signature), "%s should change the encountered enemy mix" % route_id)
		signatures[signature] = route_id
		var battle := MvpContent.build_battle(route_id)
		_expect(battle.schedule.size() == schedule.size(), "%s should reach the battle simulation unchanged" % route_id)
	_expect(
		MvpContent.threat_schedule(&"unknown").size() == MvpContent.threat_schedule(MvpContent.ROUTE_MIXED).size(),
		"unknown routes should fail safely to the mixed encounter"
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
		board.major_change_text(300, 120, 0.2) == "編成警告 60s: 群体兵",
		"long-horizon warning should disclose timing and wave without prescribing a counter"
	)
	battle.tick_index = 180
	_expect(
		board.major_change_text(300, 120, 0.2) == "",
		"major warning should not duplicate a change already inside the near horizon"
	)
	battle.tick_index = 270
	_expect(
		board.major_change_text(300, 120, 0.2) == "編成警告 60s: 装甲兵",
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
	var visual_summary := board.work_in_progress_visual_summary()
	_expect(not visual_summary.is_empty(), "time-stop preview should expose work-in-progress as grouped CanonicalGlyphs")
	var visual_count := 0
	for entry in visual_summary:
		visual_count += entry["count"]
	_expect(visual_count == committed_work_in_progress, "visual work-in-progress summary should preserve the exact item count")
	var original_simulation := board.simulation
	board.begin_edit()
	board.size = Vector2(1196, 401)
	var work_center := Vector2(72, 28)
	_expect(board.work_in_progress_summary_index_at(work_center) == 0, "time-stop Glyph summary should expose a stable hover target")
	_expect(board.cursor_shape_at(work_center) == Control.CURSOR_HELP, "time-stop Glyph should advertise its visual details")
	_expect(board._get_tooltip(work_center) == "glyph_preview", "time-stop Glyph should open a large CanonicalGlyph tooltip")
	_expect("工場内" in board.tooltip_context, "time-stop Glyph tooltip should retain its grouped item count")
	board.preview_plan(MvpContent.PLAN_GOLEM)
	_expect(board.plan_id == MvpContent.PLAN_SCOUT, "preview should not change committed plan")
	_expect(board.display_plan_id() == MvpContent.PLAN_GOLEM, "factory visuals should use the pending goal during reconfiguration")
	_expect(board.node_edit_state(&"ring_source") == &"changed", "preset preview should mark changed shared equipment")
	_expect(board.node_edit_state(&"combiner") == &"added", "preset preview should mark newly added equipment")
	_expect(board.line_edit_state(&"line_summon") == &"added", "preset preview should mark newly added factory lines")
	_expect(&"line_1" in board.removed_edit_line_ids(), "preset preview should retain removed committed lines as visual differences")
	var changed_badge := board.node_local_position(&"ring_source") + Vector2(43, -31)
	_expect(board.edit_difference_at(changed_badge) == &"changed", "changed equipment badge should expose its pending state on hover")
	_expect(board.cursor_shape_at(changed_badge) == Control.CURSOR_HELP, "edit difference badge should advertise its explanation")
	_expect(board._get_tooltip(changed_badge) == "変更予定", "changed equipment badge should explain itself only on hover")
	_expect(board.production_summary_is_goal(&"golem") and not board.production_summary_is_goal(&"scout"), "production summary should emphasize the pending goal instead of the committed one")
	_expect(board.line_goal_match_state(&"line_summon") == &"match", "final line should compare against the pending goal Glyph")
	_expect(board.simulation == original_simulation, "preview should not replace running factory")
	_expect(board.pending_discard_count() == committed_work_in_progress, "preview should disclose discarded work in progress")
	var discard_badge := board.pending_discard_badge_center()
	_expect(board.pending_discard_badge_at(discard_badge), "pending discard badge should expose a stable hover target")
	_expect(board.cursor_shape_at(discard_badge) == Control.CURSOR_HELP, "pending discard badge should advertise its explanation")
	var discard_connector := board.pending_discard_connector()
	_expect(
		not discard_connector.is_empty() and discard_connector["start"].x < discard_connector["finish"].x,
		"pending discard should visually connect the preserved work summary to its discard badge"
	)
	_expect("影響:" in board._get_tooltip(discard_badge), "pending discard badge should explain the affected equipment on hover")
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
	root.add_child(board)
	board.size = Vector2(568, 339)
	board.configure(MvpContent.PLAN_SCOUT)
	var original := board.node_positions[&"ring_source"] as Vector2
	_expect(not board.move_node(&"ring_source", Vector2(300, 160)), "running factory should reject node movement")
	board.set_interaction_enabled(true)
	var node_center := board.node_local_position(&"ring_source")
	var summoner_center := board.node_local_position(&"summoner")
	_expect(not board.placement_is_valid(&"ring_source", summoner_center), "drag placement should reject equipment overlap")
	_expect(not board.placement_is_valid(&"ring_source", Vector2(board.size.x - 120, 40)), "drag placement should keep equipment out of the production and mana HUD")
	_expect(not board.placement_is_valid(&"ring_source", Vector2(120, board.size.y - 20)), "drag placement should keep equipment out of the interaction legend")
	_expect(not board.move_node(&"ring_source", summoner_center), "overlapping drag should leave the equipment at its last valid position")
	_expect(board.node_local_position(&"ring_source").is_equal_approx(node_center), "rejected overlap should preserve the original equipment position")
	var hover := InputEventMouseMotion.new()
	hover.position = node_center + Vector2(0, 22)
	board._gui_input(hover)
	_expect(board.hovered_node_id == &"ring_source", "hover should visibly identify draggable equipment before selection")
	hover.position = Vector2(8, 8)
	board._gui_input(hover)
	_expect(board.hovered_node_id == &"", "moving into empty board space should clear equipment hover")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = node_center
	board._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = node_center
	board._gui_input(release)
	_expect(board.undo_history.is_empty(), "selecting equipment without moving it should not consume an undo step")
	board._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = node_center + Vector2(60, 30)
	board._gui_input(motion)
	release.position = motion.position
	board._gui_input(release)
	_expect(board.node_positions[&"ring_source"] != original, "node movement should update its layout")
	_expect(board.undo_history.size() == 1, "one drag should create exactly one undo step")
	_expect(board.undo(), "node movement should be undoable")
	_expect(board.node_positions[&"ring_source"] == original, "undo should restore the position before the drag")
	board.free()


func _test_factory_editor_undo_restores_graph() -> void:
	var board := FactoryBoard.new()
	board.size = Vector2(568, 339)
	board.configure(MvpContent.PLAN_SCOUT)
	board.set_interaction_enabled(true)
	var original_node_count := board.simulation.nodes.size()
	var added_id := board.add_node_from_palette(&"rotator")
	_expect(board.simulation.nodes.has(added_id), "palette edit should add a node before undo")
	var added_position: Vector2 = board.node_positions[added_id]
	for existing_id in board.node_positions:
		if existing_id == added_id:
			continue
		var existing_position: Vector2 = board.node_positions[existing_id]
		_expect(
			absf(added_position.x - existing_position.x) >= 85.0 or absf(added_position.y - existing_position.y) >= 75.0,
			"palette equipment should choose an open radial slot instead of overlapping the template"
		)
	_expect(board.undo(), "factory editor should undo its latest edit")
	_expect(board.simulation.nodes.size() == original_node_count, "undo should restore the previous graph")
	_expect(not board.simulation.nodes.has(added_id), "undo should remove the newly added node")
	board.free()


func _test_factory_mana_budget_limits_and_refunds_nodes() -> void:
	var board := FactoryBoard.new()
	board.size = Vector2(1196, 401)
	board.configure(MvpContent.PLAN_EMPTY)
	board.set_interaction_enabled(true)
	_expect(board.mana_used() == 40, "empty workshop source and summoner should use 40 mana")
	var first_added: StringName = &""
	for index in 4:
		var added_id := board.add_node_from_palette(&"rotator")
		_expect(added_id != &"", "factory should accept equipment within its mana budget")
		if index == 0:
			first_added = added_id
	var first_center := board.node_local_position(first_added)
	var summoner_center := board.node_local_position(&"summoner")
	_expect(first_center.direction_to(board._output_port_position(first_added)).dot(first_center.direction_to(summoner_center)) > 0.99, "unconnected radial output should face the central summoner")
	_expect(first_center.direction_to(board._input_port_position(first_added, 0)).dot(first_center.direction_to(summoner_center)) < -0.99, "unconnected radial input should face away from the central summoner")
	board.connecting_from_node_id = first_added
	_expect(summoner_center.direction_to(board._input_port_position(&"summoner", 0)).dot(summoner_center.direction_to(first_center)) > 0.99, "wiring target input should turn toward the selected source")
	board.connecting_from_node_id = &""
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


func _test_factory_goal_equipment_presence_tracks_inventory() -> void:
	var board := FactoryBoard.new()
	board.configure(MvpContent.PLAN_SCOUT)
	_expect(board.goal_equipment_present(&"ring_source"), "scout inventory should report its exact ring source as present")
	_expect(board.goal_equipment_present(&"summoner"), "scout inventory should report its summoner as present")
	_expect(not board.goal_equipment_present(&"spike_source"), "ring source should not satisfy the separate spike inventory marker")
	_expect(not board.goal_equipment_present(&"rotator"), "absent processing equipment should remain missing")
	board.set_interaction_enabled(true)
	board.selected_node_id = &"ring_source"
	_expect(board.configure_selected_node(1), "inventory fixture should switch its source Primitive")
	_expect(not board.goal_equipment_present(&"ring_source") and board.goal_equipment_present(&"spike_source"), "source inventory should follow its current Primitive instead of node kind alone")
	_expect(board.undo(), "inventory fixture should undo the source change")
	_expect(board.goal_equipment_present(&"ring_source") and not board.goal_equipment_present(&"spike_source"), "Undo should restore the exact source inventory state")
	board.free()

	var sentinel_board := FactoryBoard.new()
	sentinel_board.configure(MvpContent.PLAN_SENTINEL)
	_expect(sentinel_board.goal_equipment_present(&"rotator") and sentinel_board.goal_equipment_present(&"colorizer"), "sentinel inventory should expose both processing categories")
	sentinel_board.set_interaction_enabled(true)
	sentinel_board.selected_node_id = &"rotator"
	_expect(sentinel_board.remove_selected_node(), "inventory fixture should remove a processing category")
	_expect(not sentinel_board.goal_equipment_present(&"rotator"), "removed processing equipment should become missing immediately")
	_expect(sentinel_board.undo() and sentinel_board.goal_equipment_present(&"rotator"), "Undo should restore a removed equipment category")
	sentinel_board.free()


func _test_factory_mutations_fail_closed_without_undo_snapshot() -> void:
	var board := FactoryBoard.new()
	board.size = Vector2(1196, 401)
	board.configure(MvpContent.PLAN_SCOUT)
	board.set_interaction_enabled(true)
	var extra_rotator_id := board.add_node_from_palette(&"rotator")
	_expect(extra_rotator_id != &"", "snapshot failure fixture should first create one valid undo entry")
	board.selected_node_id = &"ring_source"
	var invalid_glyph := GlyphModel.new([
		GlyphComponentModel.new(&"ring"),
		GlyphComponentModel.new(&"spike"),
	])
	board.simulation.nodes[&"ring_source"].output_buffer = invalid_glyph
	var nodes_before := board.simulation.nodes.size()
	var lines_before := board.simulation.lines.size()
	var positions_before: Dictionary = board.node_positions.duplicate(true)
	var undo_before := board.undo_history.size()
	var undo_signature_before := _factory_runtime_signature(board.undo_history[0]["simulation"])
	var node_serial_before := board.node_serial
	var connection_serial_before := board.connection_serial
	var plan_before := board.plan_id

	_expect(board.add_node_from_palette(&"colorizer") == &"", "failed undo capture should reject equipment addition")
	_expect(not board.remove_factory_node(extra_rotator_id), "failed undo capture should reject equipment deletion")
	_expect(not board.configure_selected_node(1), "failed undo capture should reject equipment configuration")
	var connect_result := board.connect_nodes_interactive(&"ring_source", extra_rotator_id, 0)
	_expect(not connect_result["ok"] and connect_result["error"] == "undo_snapshot", "failed undo capture should reject rewiring before replacing an input")
	_expect(not board.disconnect_input(&"summoner", 0), "failed undo capture should reject disconnection")
	_expect(not board.apply_plan(MvpContent.PLAN_SENTINEL), "failed undo capture should reject template replacement")

	var drag_start := board.node_local_position(&"ring_source")
	var drag_target := drag_start
	for offset in [Vector2(0, 80), Vector2(0, -80), Vector2(90, 0), Vector2(-90, 0)]:
		if board.placement_is_valid(&"ring_source", drag_start + offset):
			drag_target = drag_start + offset
			break
	_expect(drag_target != drag_start, "snapshot failure fixture should find one valid drag destination")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = drag_start
	board._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = drag_target
	board._gui_input(motion)

	_expect(board.simulation.nodes.size() == nodes_before and board.simulation.lines.size() == lines_before, "failed undo capture should preserve graph membership")
	_expect(board.node_positions == positions_before, "failed undo capture should preserve every equipment position")
	_expect(board.simulation.nodes[&"ring_source"].config["primitive_id"] == "ring", "failed undo capture should preserve equipment settings")
	_expect(board.simulation.nodes[&"ring_source"].output_buffer == invalid_glyph, "failed undo capture should not discard or replace corrupt work in progress")
	_expect(board.undo_history.size() == undo_before and _factory_runtime_signature(board.undo_history[0]["simulation"]) == undo_signature_before, "failed undo capture should preserve earlier valid undo history")
	_expect(board.node_serial == node_serial_before and board.connection_serial == connection_serial_before, "failed undo capture should preserve future equipment and line IDs")
	_expect(board.plan_id == plan_before and board.selected_node_id == &"ring_source", "failed undo capture should preserve the plan and current selection")
	_expect(not board.dragging_node and not board.drag_snapshot_pending, "failed drag snapshot should stop cleanly without moving the equipment")
	_expect("工場状態を保存できません" in board.connection_message, "rejected mutation should expose the shared snapshot diagnostic")
	board.free()

	var edit_board := FactoryBoard.new()
	edit_board.configure(MvpContent.PLAN_SENTINEL)
	_expect(edit_board.begin_edit(), "preview snapshot failure fixture should enter editing while valid")
	edit_board.set_interaction_enabled(true)
	var preview_before: FactorySimulation = edit_board.preview_simulation
	var pending_plan_before := edit_board.pending_plan_id
	var edit_undo_before := edit_board.undo_history.size()
	edit_board.preview_simulation.nodes[&"ring_source"].output_buffer = invalid_glyph
	_expect(not edit_board.preview_plan(MvpContent.PLAN_GOLEM), "failed undo capture should reject a transactional template preview")
	_expect(edit_board.preview_simulation == preview_before and edit_board.pending_plan_id == pending_plan_before, "failed template preview should preserve the current edit simulation and plan")
	_expect(edit_board.undo_history.size() == edit_undo_before and edit_board.preview_simulation.nodes[&"ring_source"].output_buffer == invalid_glyph, "failed template preview should preserve edit history and work in progress")
	edit_board.cancel_edit()
	edit_board.free()


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
	_expect(
		board.selected_node_details()["title"] == "回転 +180°",
		"rotator label should reflect the configured angle"
	)
	_expect(board.undo(), "node configuration should be undoable")
	_expect(board.simulation.nodes[rotator_id].config["steps"] == 1, "undo should restore the previous node setting")
	board.selected_node_id = rotator_id
	_expect(
		board.selected_node_details()["title"] == "回転 +90°",
		"rotator label should follow the angle restored by undo"
	)
	var colorizer_id := board.add_node_from_palette(&"colorizer")
	_expect(board.configure_selected_node(1), "selected colorizer should accept a red setting")
	_expect(board.simulation.nodes[colorizer_id].config["color_id"] == "red", "inspector should store the selected color")
	_expect(
		board.selected_node_details()["title"] == "赤着色",
		"colorizer label should reflect the configured color"
	)
	_expect(board.undo(), "colorizer configuration should be undoable")
	board.selected_node_id = colorizer_id
	_expect(
		board.selected_node_details()["title"] == "青着色",
		"colorizer label should follow the color restored by undo"
	)
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


func _test_factory_preset_preview_is_undoable() -> void:
	var board := FactoryBoard.new()
	board.configure(MvpContent.PLAN_SCOUT)
	board.begin_edit()
	board.set_interaction_enabled(true)
	var added_node_id := board.add_node_from_palette(&"rotator")
	_expect(added_node_id != &"", "preset undo test should create a custom edit")
	var edited_node_count := board.preview_simulation.nodes.size()
	var preview_before_same_click := board.preview_simulation
	var positions_before_same_click := board.preview_node_positions.duplicate(true)
	var undo_before_same_click := board.undo_history.size()
	var discarded_before_same_click := board.preview_simulation.discarded_glyphs
	var timing_before_same_click := board.cached_production_event_offsets.duplicate(true)
	_expect(not board.preview_plan(MvpContent.PLAN_SCOUT), "reselecting the active template should be an explicit no-op")
	_expect(board.preview_simulation == preview_before_same_click, "same-template no-op should preserve the custom preview object and runtime state")
	_expect(board.preview_node_positions == positions_before_same_click and board.preview_simulation.nodes.has(added_node_id), "same-template no-op should preserve custom equipment and positions")
	_expect(board.undo_history.size() == undo_before_same_click, "same-template no-op should not consume an undo step")
	_expect(board.preview_simulation.discarded_glyphs == discarded_before_same_click, "same-template no-op should not discard work")
	_expect(board.cached_production_event_offsets == timing_before_same_click, "same-template no-op should not recalculate or replace the timing forecast")
	_expect(board.preview_plan(MvpContent.PLAN_GOLEM), "different preset should create a transactional preview")
	_expect(board.pending_plan_id == MvpContent.PLAN_GOLEM and board.undo_history.size() == 2, "preset preview should become one undoable edit")
	_expect(board.undo(), "preset preview should undo to the preceding custom graph")
	_expect(board.pending_plan_id == MvpContent.PLAN_SCOUT, "undoing a preset should restore its preceding goal")
	_expect(board.preview_simulation.nodes.size() == edited_node_count and board.preview_simulation.nodes.has(added_node_id), "undoing a preset should restore all custom equipment")
	_expect(board.undo(), "custom edit before a preset should remain separately undoable")
	_expect(not board.preview_simulation.nodes.has(added_node_id), "second undo should restore the original transaction graph")
	board.free()


func _test_source_configuration_resets_generation_progress() -> void:
	var board := FactoryBoard.new()
	board.configure(MvpContent.PLAN_SCOUT)
	var committed_source: FactoryNodeModel = board.simulation.nodes[&"ring_source"]
	committed_source.config["primitive_id"] = "spike"
	committed_source.config["interval_ticks"] = 54
	committed_source.source_timer = 53
	board.begin_edit()
	board.set_interaction_enabled(true)
	board.selected_node_id = &"ring_source"
	_expect(board.configure_selected_node(0), "source should accept a different Primitive during time stop")
	var preview_source: FactoryNodeModel = board.preview_simulation.nodes[&"ring_source"]
	_expect(preview_source.source_timer == 0, "changing source Primitive should reset incompatible generation progress")
	board.cancel_edit()
	_expect(board.display_plan_id() == MvpContent.PLAN_SCOUT, "cancel should restore the committed goal for factory visuals")
	_expect(
		board.node_edit_state(&"ring_source") == &"unchanged"
		and board.removed_edit_node_ids().is_empty()
		and board.line_edit_state(&"line_1") == &"unchanged"
		and board.removed_edit_line_ids().is_empty(),
		"leaving edit mode should clear all factory difference markers"
	)
	_expect(
		committed_source.source_timer == 53 and committed_source.config["primitive_id"] == "spike",
		"canceling source reconfiguration should preserve the committed Primitive and progress"
	)
	board.begin_edit()
	board.set_interaction_enabled(true)
	board.selected_node_id = &"ring_source"
	board.configure_selected_node(0)
	board.commit_edit()
	var changed_source: FactoryNodeModel = board.simulation.nodes[&"ring_source"]
	board.advance_tick()
	_expect(changed_source.source_timer == 1 and changed_source.output_buffer == null, "new source should restart generation instead of producing immediately")
	board.free()


func _test_factory_setting_preview_is_non_destructive() -> void:
	var cases := [
		{"plan": MvpContent.PLAN_SCOUT, "node_id": &"ring_source", "option": 1},
		{"plan": MvpContent.PLAN_SENTINEL, "node_id": &"rotator", "option": 1},
		{"plan": MvpContent.PLAN_SENTINEL, "node_id": &"colorizer", "option": 1},
	]
	for case in cases:
		var board := FactoryBoard.new()
		board.configure(case["plan"])
		if case["node_id"] == &"rotator":
			for _tick in 25:
				board.advance_tick()
		_expect(board.begin_edit(), "setting preview fixture should enter a transaction")
		board.set_interaction_enabled(true)
		board.selected_node_id = case["node_id"]
		var runtime_before := _factory_runtime_signature(board.preview_simulation)
		var config_before: Dictionary = board.preview_simulation.nodes[case["node_id"]].config.duplicate(true)
		var production_before := board.production_snapshot()
		var undo_before := board.undo_history.size()
		var discard_before := board.pending_discard_count()
		var committed_candidate := board.final_summoner_candidate_glyph()
		var hypothetical := board.setting_option_candidate(case["option"])
		_expect(hypothetical["active"] and GlyphPainterModel.can_draw(hypothetical["glyph"]), "hovered setting should expose a predicted final Glyph")
		_expect(
			committed_candidate == null
			or committed_candidate.canonical_serialization() != hypothetical["glyph"].canonical_serialization(),
			"alternative setting should visibly change the final candidate"
		)
		_expect(_factory_runtime_signature(board.preview_simulation) == runtime_before, "setting hover should not mutate work in progress, timers, lines, or events")
		_expect(board.preview_simulation.nodes[case["node_id"]].config == config_before, "setting hover should not mutate the selected equipment config")
		_expect(board.production_snapshot() == production_before, "setting hover should not replace the live 32-second forecast cache")
		_expect(board.undo_history.size() == undo_before and board.pending_discard_count() == discard_before, "setting hover should not create undo or discard costs")
		_expect(board.setting_option_preview_cache.size() == 1, "first setting hover should cache its isolated prediction")
		var cached_hypothetical := board.setting_option_candidate(case["option"])
		_expect(board.setting_option_preview_cache.size() == 1 and cached_hypothetical["glyph"].canonical_serialization() == hypothetical["glyph"].canonical_serialization(), "repeated hover should reuse the same graph-revision prediction")
		_expect(board.configure_selected_node(case["option"]), "clicking the hovered alternative should commit one real edit")
		var confirmed_candidate := board.final_summoner_candidate_glyph()
		_expect(confirmed_candidate != null and confirmed_candidate.canonical_serialization() == hypothetical["glyph"].canonical_serialization(), "confirmed setting should match the Glyph shown during hover")
		_expect(board.undo_history.size() == undo_before + 1, "only the confirmed setting should add one undo step")
		_expect(board.setting_option_preview_cache.is_empty(), "committed graph revision should clear hypothetical setting cache")
		board.cancel_edit()
		board.free()
	var invalid_board := FactoryBoard.new()
	invalid_board.configure(MvpContent.PLAN_SCOUT)
	_expect(invalid_board.begin_edit(), "invalid setting preview fixture should enter a transaction")
	invalid_board.set_interaction_enabled(true)
	_expect(invalid_board.disconnect_input(&"summoner", 0), "invalid setting preview fixture should break the final route")
	invalid_board.selected_node_id = &"ring_source"
	var invalid_candidate := invalid_board.setting_option_candidate(1)
	_expect(
		invalid_candidate["active"]
		and invalid_candidate["validity"] == &"invalid"
		and invalid_candidate["output_state"] == &"no_output"
		and invalid_candidate["glyph"] == null,
		"invalid hypothetical graph should remain distinct from a valid forecast with no output"
	)
	invalid_board.cancel_edit()
	invalid_board.free()


func _test_factory_rewiring_discards_work_transactionally() -> void:
	var board := FactoryBoard.new()
	board.configure(MvpContent.PLAN_SCOUT)
	for _tick in 18:
		board.advance_tick()
	var committed_work_in_progress := board.work_in_progress_count()
	_expect(committed_work_in_progress > 0, "rewiring test should begin with work in progress")
	board.begin_edit()
	board.set_interaction_enabled(true)
	var original_line_id: StringName = board.preview_simulation.lines.keys()[0]
	var undo_count_before := board.undo_history.size()
	board.connecting_from_node_id = &"ring_source"
	board.hovered_input_node_id = &"summoner"
	board.hovered_input_port = 0
	_expect(board.connection_preview_state() == &"already_connected", "same connection preview should differ from a new valid route")
	var no_op_result := board.connect_nodes_interactive(&"ring_source", &"summoner", 0)
	board.connecting_from_node_id = &""
	_expect(no_op_result["ok"] and not no_op_result["changed"], "reselecting the same connection should be an explicit no-op")
	_expect(board.preview_simulation.lines.has(original_line_id), "same-connection no-op should preserve the existing line ID")
	_expect(board.work_in_progress_count() == committed_work_in_progress and board.pending_discard_count() == 0, "same-connection no-op should preserve every work item")
	_expect(board.undo_history.size() == undo_count_before, "same-connection no-op should not consume an undo step")
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
	_expect(board.connection_feedback_kind() == &"error", "summon failure should collapse its permanent sentence into an error badge")
	board.size = Vector2(1196, 401)
	_expect(board.connection_feedback_badge_at(Vector2(28, 27)), "connection feedback badge should expose a stable hover target")
	_expect("召喚失敗" in board._get_tooltip(Vector2(28, 27)), "connection feedback badge should retain the detailed message on hover")
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
	_expect(board.warning_marker_symbol(&"output_blocked") == &"cross", "output blockage should use a shape marker in addition to color")
	_expect(board.warning_marker_symbol(&"material_shortage") == &"half_empty", "combiner shortage should show which paired input is missing")
	_expect(board.warning_marker_symbol(&"buffer_full") == &"stop", "blocked transport should use a stop marker")
	board.size = Vector2(1196, 401)
	_expect(board.flow_warning_badge_at(Vector2(28, board.size.y - 18)), "long runtime warning should collapse into a hoverable badge")
	_expect(board.cursor_shape_at(Vector2(28, board.size.y - 18)) == Control.CURSOR_HELP, "runtime warning badge should advertise its explanation")
	_expect("出力閉塞" in board._get_tooltip(Vector2(28, board.size.y - 18)), "runtime warning badge should retain the actionable reason on hover")
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


func _test_factory_board_exposes_visible_work_in_progress_glyphs() -> void:
	var board := FactoryBoard.new()
	board.size = Vector2(1196, 401)
	board.configure(MvpContent.PLAN_SENTINEL)
	_expect(MvpContent.layout_for_plan(MvpContent.PLAN_SENTINEL)[&"summoner"] == Vector2(410, 195), "factory templates should place the summoner at the radial workspace center")
	_expect(board.line_goal_match_state(&"line_1") == &"not_applicable", "raw material path should not be judged against the final recipe")
	_expect(board.line_goal_match_state(&"line_2") == &"not_applicable", "intermediate processing should not look like a failed final recipe")
	_expect(board.line_goal_match_state(&"line_3") == &"match", "only the summoner path should show final recipe success")
	var source_center := board.node_local_position(&"ring_source")
	var rotator_center := board.node_local_position(&"rotator")
	var output_direction := source_center.direction_to(board._output_port_position(&"ring_source"))
	_expect(output_direction.dot(source_center.direction_to(rotator_center)) > 0.99, "factory output port should face its downstream equipment in a radial layout")
	var rotator: FactoryNodeModel = board.simulation.nodes[&"rotator"]
	var input_glyph := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	var output_glyph := GlyphModel.new([GlyphComponentModel.new(&"spike", Vector2i.ZERO, 1, 1, &"blue")])
	rotator.input_buffers[0] = input_glyph
	_expect(
		board.visible_glyph_for_node(&"rotator") == input_glyph,
		"node glyph display should fall back to buffered input while waiting"
	)
	rotator.output_buffer = output_glyph
	_expect(
		board.visible_glyph_for_node(&"rotator") == output_glyph,
		"node glyph display should prioritize processed output"
	)
	var line: FactoryLineModel = board.simulation.lines[&"line_1"]
	_expect(
		board.predicted_glyph_for_line(&"line_1") != null,
		"empty pre-battle line should expose a persistent predicted Glyph marker"
	)
	_expect(
		board.line_has_preview_space(Vector2.ZERO, Vector2(FactoryBoard.MIN_PREDICTED_LINE_GLYPH_LENGTH, 0)),
		"line prediction should appear when its conduit has enough visual space"
	)
	_expect(
		not board.line_has_preview_space(Vector2.ZERO, Vector2(FactoryBoard.MIN_PREDICTED_LINE_GLYPH_LENGTH - 1.0, 0)),
		"short conduit should leave prediction display to its equipment nodes"
	)
	line.payload = output_glyph
	_expect(
		board.visible_glyph_for_line(&"line_1") == output_glyph,
		"line glyph display should expose the transported structure"
	)
	_expect(
		board.predicted_glyph_for_line(&"line_1") == null,
		"actual transported Glyph should replace the persistent line prediction"
	)
	_expect(FactoryBoard.FACTORY_LINE_WIDTH <= 2.0, "factory conduit should stay visually weaker than transported Glyph strokes")
	_expect(board.transport_glyph_draw_scale(output_glyph) >= 1.5, "single-Primitive transport Glyph should be readable on the full-width board")
	var combined_transport := GlyphModel.combine(input_glyph, output_glyph)
	_expect(
		board.transport_glyph_draw_scale(combined_transport) < board.transport_glyph_draw_scale(output_glyph),
		"combined transport Glyph should use a separate scale that keeps its circle inside the halo"
	)
	var invalid := GlyphModel.new([GlyphComponentModel.new(&"ring"), GlyphComponentModel.new(&"spike")])
	line.payload = invalid
	_expect(
		board.visible_glyph_for_line(&"line_1") == null,
		"invalid transported Glyph should stay with corruption diagnostics instead of being drawn"
	)
	board.free()
	var match_board := FactoryBoard.new()
	match_board.configure(MvpContent.PLAN_SCOUT)
	var summon_line: FactoryLineModel = match_board.simulation.lines[&"line_1"]
	summon_line.payload = GlyphModel.new([GlyphComponentModel.new(&"ring")])
	_expect(
		match_board.line_recipe_match_state(&"line_1") == &"match",
		"summoner-bound matching Glyph should expose a positive arrival state"
	)
	_expect(
		match_board.recipe_match_marker_symbol(&"match") == &"check",
		"matching arrival marker should use a check in addition to color"
	)
	summon_line.payload = GlyphModel.new([GlyphComponentModel.new(&"spike")])
	_expect(
		match_board.line_recipe_match_state(&"line_1") == &"mismatch",
		"summoner-bound mismatching Glyph should expose a rejected arrival state"
	)
	_expect(
		match_board.recipe_match_marker_symbol(&"mismatch") == &"cross",
		"mismatching arrival marker should use a cross in addition to color"
	)
	var summoner: FactoryNodeModel = match_board.simulation.nodes[&"summoner"]
	summoner.input_buffers[0] = GlyphModel.new([GlyphComponentModel.new(&"ring")])
	_expect(
		match_board.input_recipe_match_state(&"summoner", 0) == &"match",
		"matching state should remain visible after the Glyph reaches the summoner input"
	)
	summoner.input_buffers[0] = GlyphModel.new([GlyphComponentModel.new(&"spike")])
	_expect(
		match_board.input_recipe_match_state(&"summoner", 0) == &"mismatch",
		"mismatch state should remain visible after the Glyph reaches the summoner input"
	)
	match_board.free()
	var combine_board := FactoryBoard.new()
	combine_board.size = Vector2(1196, 401)
	combine_board.configure(MvpContent.PLAN_GOLEM)
	var combiner: FactoryNodeModel = combine_board.simulation.nodes[&"combiner"]
	var ring := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	var spike := GlyphModel.new([GlyphComponentModel.new(&"spike")])
	var combiner_output_preview := combine_board.display_glyph_for_node(&"combiner")
	_expect(
		combiner_output_preview != null and not combiner_output_preview.combine_children.is_empty(),
		"combiner center should expose its predicted combined output before battle"
	)
	var combiner_center := combine_board.node_local_position(&"combiner") + Vector2(0, 3)
	_expect(
		combine_board.cursor_shape_at(combiner_center) == Control.CURSOR_HELP,
		"displayed node Glyph should advertise its large visual tooltip instead of node dragging"
	)
	combine_board.set_interaction_enabled(true)
	combine_board._update_pointer_hover(combiner_center)
	_expect(
		combine_board.hovered_node_glyph_id == &"combiner" and combine_board.hovered_node_id == &"",
		"node Glyph hover should highlight the symbol without highlighting the draggable equipment frame"
	)
	_expect(
		combine_board.predicted_input_glyph_for_node(&"combiner", 0).canonical_serialization() == ring.canonical_serialization(),
		"combiner should preview the ring expected at its first empty input"
	)
	_expect(
		combine_board.predicted_input_glyph_for_node(&"combiner", 1).canonical_serialization() == spike.canonical_serialization(),
		"combiner should preview the spike expected at its second empty input"
	)
	_expect(
		combine_board.input_glyph_display_state(&"combiner", 0) == &"predicted",
		"empty connected combiner input should identify its Glyph as a prediction"
	)
	var predicted_input_center := combine_board.input_glyph_center(&"combiner", 0)
	_expect(
		combine_board.cursor_shape_at(predicted_input_center) == Control.CURSOR_HELP,
		"input Glyph should advertise its detailed hover instead of node dragging"
	)
	combine_board._update_pointer_hover(predicted_input_center)
	_expect(
		combine_board.hovered_input_glyph_node_id == &"combiner"
		and combine_board.hovered_input_glyph_port == 0
		and combine_board.hovered_node_id == &"",
		"input Glyph hover should highlight the socket without highlighting the whole draggable node"
	)
	combine_board.set_interaction_enabled(false)
	_expect(
		combine_board.hovered_node_glyph_id == &""
		and combine_board.hovered_input_glyph_node_id == &""
		and combine_board.hovered_input_glyph_port == -1,
		"locking factory interaction should clear transient Glyph hover emphasis"
	)
	combine_board.set_interaction_enabled(true)
	_expect(
		combine_board._get_tooltip(predicted_input_center) == "glyph_comparison"
		and "32秒予測の入力Glyph" in combine_board.tooltip_context,
		"predicted combiner input should open its own large comparison before the node tooltip"
	)
	_expect(
		combine_board.tooltip_glyph.canonical_serialization() == ring.canonical_serialization(),
		"input socket tooltip should preserve the exact predicted Primitive"
	)
	var predicted_input_tooltip = combine_board._make_custom_tooltip("glyph_comparison")
	_expect(predicted_input_tooltip.candidate_label == "入力Glyph", "input comparison should label its right-hand Glyph as an input")
	predicted_input_tooltip.free()
	_expect(
		combine_board.predicted_input_glyph_for_node(&"combiner", 2) == null,
		"predicted input Glyph lookup should reject an out-of-range port"
	)
	combiner.input_buffers[0] = ring
	combiner.input_buffers[1] = spike
	combine_board.simulation.lines[&"line_ring"].payload = ring
	_expect(
		combine_board.line_recipe_match_state(&"line_ring") == &"not_applicable",
		"intermediate factory lines should not be judged as final recipes"
	)
	_expect(
		combine_board.input_recipe_match_state(&"combiner", 0) == &"not_applicable",
		"non-summoner inputs should not receive final-recipe markers"
	)
	_expect(
		combine_board.visible_input_glyph_for_node(&"combiner", 0) == ring,
		"combiner display should retain the first input Glyph separately"
	)
	_expect(
		combine_board.input_glyph_display_state(&"combiner", 0) == &"actual",
		"arrived combiner input should replace its predicted display state"
	)
	_expect(
		combine_board._get_tooltip(predicted_input_center) == "glyph_comparison"
		and "到着済み入力Glyph" in combine_board.tooltip_context,
		"arrived combiner input should identify itself separately from a plan prediction"
	)
	_expect(
		combine_board._get_tooltip(combiner_center) == "glyph_comparison"
		and "32秒予測の出力Glyph" in combine_board.tooltip_context
		and not combine_board.tooltip_glyph.combine_children.is_empty(),
		"combiner center tooltip should keep matching the displayed combined output after one input arrives"
	)
	var node_output_tooltip = combine_board._make_custom_tooltip("glyph_comparison")
	_expect(node_output_tooltip.candidate_label == "設備出力", "node comparison should label its right-hand Glyph as equipment output")
	node_output_tooltip.free()
	_expect(
		combine_board.visible_input_glyph_for_node(&"combiner", 1) == spike,
		"combiner display should retain the second input Glyph separately"
	)
	_expect(
		combine_board.visible_input_glyph_for_node(&"combiner", 2) == null,
		"input Glyph lookup should reject an out-of-range port"
	)
	combine_board.configure(MvpContent.PLAN_SCOUT)
	_expect(
		combine_board.hovered_node_glyph_id == &""
		and combine_board.hovered_input_glyph_node_id == &""
		and combine_board.hovered_input_glyph_port == -1,
		"reconfiguring the factory should clear Glyph hover state"
	)
	combine_board.free()


func _test_factory_board_offers_visual_glyph_tooltips() -> void:
	var board := FactoryBoard.new()
	board.size = Vector2(1196, 401)
	board.configure(MvpContent.PLAN_EMPTY)
	_expect(board.final_summoner_candidate_glyph() == null, "unwired factory should not invent a final candidate Glyph")
	_expect(board.final_summoner_candidate()["state"] == &"missing", "unwired factory should identify its missing final candidate")
	_expect(board.output_validation_state(&"ring_source") == &"missing", "unwired factory should mark the exact missing output port")
	_expect(board.input_validation_state(&"summoner", 0) == &"missing", "unwired factory should mark the exact missing input port")
	var missing_input_position := board._input_port_position(&"summoner", 0)
	_expect(board.validation_fault_at(missing_input_position) == "入力を接続", "missing input marker should give a short local repair action")
	_expect(board.cursor_shape_at(missing_input_position) == Control.CURSOR_HELP, "validation marker should advertise its local explanation")
	board.set_interaction_enabled(true)
	board.connect_nodes_interactive(&"ring_source", &"summoner", 0)
	_expect(board.output_validation_state(&"ring_source") == &"valid", "connecting the source should clear its output fault marker")
	_expect(board.input_validation_state(&"summoner", 0) == &"valid", "connecting the missing input should clear its port fault marker")
	board.disconnect_input(&"summoner", 0)
	var source_center := board.node_local_position(&"ring_source")
	_expect(board._get_tooltip(source_center) == "glyph_comparison", "source equipment should compare its Primitive with the selected target")
	_expect(board.tooltip_context == "素材Primitive", "unconnected source tooltip should identify its material Primitive")
	_expect(
		board.source_glyph_for_node(&"ring_source").canonical_serialization() == board.tooltip_glyph.canonical_serialization(),
		"source tooltip should use the same CanonicalGlyph as the persistent node symbol"
	)
	var source_tooltip = board._make_custom_tooltip("glyph_comparison")
	_expect(source_tooltip.get_script() == GlyphComparisonTooltipModel, "factory equipment hover should reuse the large target comparison")
	_expect(source_tooltip.custom_minimum_size.x >= 300.0, "factory Glyph tooltip should provide a readable large preview")
	source_tooltip.free()
	board.configure(MvpContent.PLAN_SCOUT)
	var predicted_candidate := board.final_summoner_candidate_glyph()
	_expect(board.final_summoner_candidate()["state"] == &"predicted", "non-destructive final output should retain its predicted origin")
	_expect(predicted_candidate != null, "valid factory should expose its predicted final summoner candidate")
	_expect(
		predicted_candidate.canonical_serialization() == MvpContent.recipes()[0].glyph.canonical_serialization(),
		"predicted final candidate should preserve the produced CanonicalGlyph"
	)
	var transported := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	board.simulation.lines[&"line_1"].payload = transported
	_expect(board.final_summoner_candidate()["state"] == &"actual", "transported final output should replace the predicted candidate with an actual one")
	var line_start := board._output_port_position(&"ring_source")
	var line_finish := board._input_port_position(&"summoner", 0)
	_expect(board._get_tooltip(line_start.lerp(line_finish, 0.5)) == "glyph_comparison", "transport line should compare its Glyph with the selected target")
	_expect(board.tooltip_context == "輸送中Glyph", "line tooltip should identify the Glyph as transported work")
	_expect(
		board.tooltip_glyph.canonical_serialization() == transported.canonical_serialization(),
		"line tooltip should copy the actual transported CanonicalGlyph"
	)
	var line_tooltip = board._make_custom_tooltip("glyph_comparison")
	_expect(line_tooltip.get_script() == GlyphComparisonTooltipModel, "line hover should reuse the side-by-side target comparison")
	line_tooltip.free()
	_expect(board._get_tooltip(Vector2(8, 8)) == "", "empty board space should not show a Glyph tooltip")
	_expect(board.node_frame_kind(&"ring_source") == &"source_hex", "source should use a dedicated non-rectangular frame")
	_expect(board.node_frame_kind(&"summoner") == &"summon_circle", "summoner should use a dedicated circular frame")
	board.free()


func _test_factory_board_exposes_node_activity_progress() -> void:
	var board := FactoryBoard.new()
	board.configure(MvpContent.PLAN_SENTINEL)
	var source: FactoryNodeModel = board.simulation.nodes[&"ring_source"]
	source.source_timer = 11
	_expect(
		is_equal_approx(board.node_activity_progress(&"ring_source"), 0.5),
		"source activity should expose fixed-tick generation progress"
	)
	source.output_buffer = GlyphModel.new([GlyphComponentModel.new(&"ring")])
	_expect(
		board.node_activity_progress(&"ring_source") == 1.0,
		"ready source output should show completed activity"
	)
	var rotator: FactoryNodeModel = board.simulation.nodes[&"rotator"]
	_expect(board.node_activity_progress(&"rotator") < 0.0, "idle processor should not show active progress")
	rotator.processing_glyph = GlyphModel.new([GlyphComponentModel.new(&"ring")])
	rotator.remaining_processing_ticks = 1
	_expect(
		is_equal_approx(board.node_activity_progress(&"rotator"), 0.5),
		"processor activity should expose remaining fixed ticks"
	)
	rotator.processing_glyph = null
	rotator.output_buffer = GlyphModel.new([GlyphComponentModel.new(&"ring", Vector2i.ZERO, 1)])
	_expect(board.node_activity_progress(&"rotator") == 1.0, "ready processor output should show completed activity")
	_expect(board.node_activity_progress(&"summoner") < 0.0, "summoner should not show a manufacturing progress bar")
	_expect(board.node_activity_progress(&"missing") < 0.0, "missing equipment should not expose progress")
	board.free()


func _test_factory_ports_connect_through_mouse_input() -> void:
	var board := FactoryBoard.new()
	root.add_child(board)
	board.size = Vector2(568, 339)
	board.configure(MvpContent.PLAN_EMPTY)
	board.set_interaction_enabled(true)
	var port_hover := InputEventMouseMotion.new()
	port_hover.position = board._output_port_position(&"ring_source")
	board._gui_input(port_hover)
	_expect(board.hovered_port_kind() == &"output", "output port should gain a visual hover ring before wiring")
	var output_click := InputEventMouseButton.new()
	output_click.button_index = MOUSE_BUTTON_LEFT
	output_click.pressed = true
	output_click.position = board._output_port_position(&"ring_source")
	board._gui_input(output_click)
	_expect(board.connecting_from_node_id == &"ring_source", "clicking an output port should begin wiring")
	_expect(not board.is_guided_connection_pending(), "explicit wiring should replace the starter guide instead of drawing both paths")
	_expect(board.cancel_pending_connection(), "wiring should be cancellable without mutating the graph")
	_expect(board.connecting_from_node_id == &"" and board.is_guided_connection_pending(), "cancelling should restore the starter guide")
	board._gui_input(output_click)
	_expect(board.input_port_connectable(&"summoner", 0), "wiring mode should identify the valid target input before click")
	_expect(not board.input_port_connectable(&"ring_source", 0), "wiring mode should not highlight a node without a valid input")
	_expect(board.get_cursor_shape(board.node_local_position(&"ring_source") + Vector2(0, 22)) == Control.CURSOR_DRAG, "equipment frame hover should advertise drag without permanent text")
	_expect(board.get_cursor_shape(board._output_port_position(&"ring_source")) == Control.CURSOR_POINTING_HAND, "output hover should advertise connection")
	_expect(board.get_cursor_shape(board._input_port_position(&"summoner", 0)) == Control.CURSOR_POINTING_HAND, "input hover should advertise connection")
	port_hover.position = board._input_port_position(&"summoner", 0)
	board._gui_input(port_hover)
	_expect(board.hovered_port_kind() == &"input" and board.input_port_connectable(&"summoner", 0), "input hover should combine target feedback with connection validity")
	_expect(board.connection_preview_state() == &"valid", "connection preview should identify a valid target before click")
	_expect(board.connection_preview_endpoint() == board._input_port_position(&"summoner", 0), "connection preview should snap to the hovered input port")
	var input_click := InputEventMouseButton.new()
	input_click.button_index = MOUSE_BUTTON_LEFT
	input_click.pressed = true
	input_click.position = board._input_port_position(&"summoner", 0)
	board._gui_input(input_click)
	_expect(board.simulation.lines.size() == 1, "clicking the target input port should complete wiring")
	_expect(not board.is_guided_connection_pending(), "first connection guide should clear after wiring")
	var line_center := board._output_port_position(&"ring_source").lerp(board._input_port_position(&"summoner", 0), 0.5)
	port_hover.position = line_center
	board._gui_input(port_hover)
	_expect(board.hovered_line_id != &"" and board.get_cursor_shape(line_center) == Control.CURSOR_POINTING_HAND, "line hover should expose wiring as an interactive target")
	var line_disconnect := InputEventMouseButton.new()
	line_disconnect.button_index = MOUSE_BUTTON_RIGHT
	line_disconnect.pressed = true
	line_disconnect.position = line_center
	board._gui_input(line_disconnect)
	_expect(board.simulation.lines.is_empty(), "right-clicking a highlighted line should disconnect it directly")
	board.free()
	var invalid_board := FactoryBoard.new()
	invalid_board.size = Vector2(1196, 401)
	invalid_board.configure(MvpContent.PLAN_SENTINEL)
	invalid_board.set_interaction_enabled(true)
	_expect(invalid_board.disconnect_input(&"colorizer", 0), "invalid connection test should expose a missing target input")
	var rejected_input := invalid_board._input_port_position(&"colorizer", 0)
	_expect(invalid_board.validation_fault_at(rejected_input) == "入力を接続", "idle missing input should retain its local repair tooltip")
	invalid_board.connecting_from_node_id = &"ring_source"
	invalid_board.hovered_input_node_id = &"colorizer"
	invalid_board.hovered_input_port = 0
	invalid_board.connection_cursor = Vector2(12, 12)
	_expect(invalid_board.connection_preview_state() == &"invalid", "occupied output should produce an invalid red connection preview")
	_expect(invalid_board.connection_target_result(&"colorizer", 0)["reason"] == &"occupied_output", "connection preview should retain the specific rejection reason")
	_expect(invalid_board.validation_fault_at(rejected_input) == "", "active wiring should suppress the stale missing-input instruction")
	_expect(invalid_board._get_tooltip(rejected_input) == "出力は使用中", "rejected target should explain the actual connection failure")
	_expect(invalid_board.cursor_shape_at(rejected_input) == Control.CURSOR_FORBIDDEN, "rejected target should use an action cursor instead of a help cursor")
	_expect(invalid_board.connection_preview_endpoint() == invalid_board._input_port_position(&"colorizer", 0), "invalid preview should still snap to the rejected port")
	invalid_board.free()


func _test_factory_overlapping_hits_follow_draw_order() -> void:
	var board := FactoryBoard.new()
	board.size = Vector2(1196, 401)
	board.configure(MvpContent.PLAN_EMPTY)
	var back_source := FactoryNodeModel.new(&"back_source", FactoryNodeModel.NodeKind.SOURCE, {"primitive_id": "ring", "interval_ticks": 18})
	var front_source := FactoryNodeModel.new(&"front_source", FactoryNodeModel.NodeKind.SOURCE, {"primitive_id": "spike", "interval_ticks": 54})
	board.simulation.nodes[back_source.id] = back_source
	board.simulation.nodes[front_source.id] = front_source
	board.node_positions[back_source.id] = Vector2(280, 110)
	board.node_positions[front_source.id] = Vector2(280, 110)
	var source_center := board.node_local_position(front_source.id)
	var output_center := board._output_port_position(front_source.id)
	_expect(board._node_at(source_center) == front_source.id, "overlapping node body should resolve to the last drawn equipment")
	_expect(board._output_port_at(output_center) == front_source.id, "overlapping output ports should resolve to the same front equipment as its body")
	_expect(board.node_glyph_at(source_center + Vector2(0, 3)) == front_source.id, "overlapping node Glyphs should inspect the front equipment")
	var back_rotator := FactoryNodeModel.new(&"back_rotator", FactoryNodeModel.NodeKind.ROTATOR, {"steps": 1, "processing_ticks": 2})
	var front_rotator := FactoryNodeModel.new(&"front_rotator", FactoryNodeModel.NodeKind.ROTATOR, {"steps": 1, "processing_ticks": 2})
	back_rotator.input_buffers[0] = GlyphModel.new([GlyphComponentModel.new(&"ring")])
	front_rotator.input_buffers[0] = GlyphModel.new([GlyphComponentModel.new(&"spike")])
	board.simulation.nodes[back_rotator.id] = back_rotator
	board.simulation.nodes[front_rotator.id] = front_rotator
	board.node_positions[back_rotator.id] = Vector2(280, 260)
	board.node_positions[front_rotator.id] = Vector2(280, 260)
	var input_center := board._input_port_position(front_rotator.id, 0)
	var input_hit := board._input_port_at(input_center)
	_expect(input_hit.get("node_id", &"") == front_rotator.id, "overlapping input ports should resolve to the last drawn equipment")
	var input_glyph_hit := board.input_glyph_at(board.input_glyph_center(front_rotator.id, 0))
	_expect(input_glyph_hit.get("node_id", &"") == front_rotator.id, "overlapping input Glyphs should inspect the front equipment")
	board.free()


func _test_factory_processor_role_marks_follow_settings() -> void:
	var board := FactoryBoard.new()
	board.configure(MvpContent.PLAN_SENTINEL)
	board.set_interaction_enabled(true)
	var rotator_state := board.node_role_mark_state(&"rotator")
	_expect(rotator_state["valid"] and rotator_state["direction"] == Vector2i.RIGHT, "90-degree rotator role mark should point right like the setting option")
	board.selected_node_id = &"rotator"
	_expect(board.configure_selected_node(1), "rotator role mark fixture should accept 180 degrees")
	_expect(board.node_role_mark_state(&"rotator")["direction"] == Vector2i.DOWN, "180-degree rotator role mark should point down immediately after configuration")
	_expect(board.configure_selected_node(2), "rotator role mark fixture should accept 270 degrees")
	_expect(board.node_role_mark_state(&"rotator")["direction"] == Vector2i.LEFT, "270-degree rotator role mark should point left")
	_expect(board.undo(), "rotator role mark configuration should remain undoable")
	_expect(board.node_role_mark_state(&"rotator")["direction"] == Vector2i.DOWN, "rotator role mark should follow the angle restored by undo")
	_expect(board.rotator_role_direction(0) == Vector2i.ZERO and board.rotator_role_direction(4) == Vector2i.ZERO, "invalid rotations should not masquerade as a valid direction")
	var colorizer_state := board.node_role_mark_state(&"colorizer")
	_expect(colorizer_state["valid"] and colorizer_state["pattern"] == &"filled", "blue colorizer should use the filled color-independent mark")
	board.selected_node_id = &"colorizer"
	_expect(board.configure_selected_node(1), "colorizer role mark fixture should accept red")
	_expect(board.node_role_mark_state(&"colorizer")["pattern"] == &"striped", "red colorizer should add stripes instead of relying on hue")
	_expect(board.configure_selected_node(2), "colorizer role mark fixture should accept white")
	_expect(board.node_role_mark_state(&"colorizer")["pattern"] == &"hollow", "white colorizer should use a hollow double ring")
	_expect(board.undo(), "colorizer role mark configuration should remain undoable")
	_expect(board.node_role_mark_state(&"colorizer")["pattern"] == &"striped", "colorizer role mark should follow the color restored by undo")
	_expect(board.colorizer_role_pattern(&"unknown") == &"invalid", "unknown colors should retain the invalid marker instead of a valid pattern")
	board.free()


func _test_factory_interaction_legend_is_explanatory_and_non_destructive() -> void:
	var board := FactoryBoard.new()
	root.add_child(board)
	board.size = Vector2(568, 339)
	board.configure(MvpContent.PLAN_SCOUT)
	board.set_interaction_enabled(true)
	board.selected_node_id = &"ring_source"
	var expected_tooltips := [
		"ドラッグ // 設備を移動",
		"出力 → 入力 // 順にクリック",
		"右クリック // 配線を切断",
	]
	var runtime_before := _factory_runtime_signature(board.simulation)
	var production_before := board.production_snapshot()
	var undo_count_before := board.undo_history.size()
	for index in board.interaction_legend_count():
		var rect := board.interaction_legend_rect(index)
		var center := rect.get_center()
		_expect(board.interaction_legend_index_at(center) == index, "each factory gesture tile should expose its own stable hover target")
		_expect(board._get_tooltip(center) == expected_tooltips[index], "gesture tooltip should describe the actual compact interaction")
		_expect(board.cursor_shape_at(center) == Control.CURSOR_HELP, "gesture tiles should advertise on-demand help rather than a click action")
		board._update_pointer_hover(center)
		_expect(board.hovered_interaction_legend_index == index, "gesture hover should drive only its local outline feedback")
	var first_rect := board.interaction_legend_rect(0)
	var gap_position := Vector2(first_rect.end.x + 6.0, first_rect.get_center().y)
	_expect(board.interaction_legend_index_at(gap_position) == -1, "the gap between gesture tiles should not steal board input")
	_expect(board.interaction_legend_index_at(Vector2(first_rect.end.x, first_rect.get_center().y)) == -1, "gesture hit testing should exclude the right edge like Rect2.has_point")
	var second_center := board.interaction_legend_rect(1).get_center()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = second_center
	board._gui_input(click)
	_expect(board.selected_node_id == &"ring_source", "clicking an explanatory gesture tile should not clear the selected equipment")
	_expect(_factory_runtime_signature(board.simulation) == runtime_before and board.production_snapshot() == production_before, "gesture inspection should not mutate simulation or production prediction")
	_expect(board.undo_history.size() == undo_count_before and board.connecting_from_node_id == &"", "gesture inspection should not add Undo state or begin wiring")
	board.connecting_from_node_id = &"ring_source"
	_expect(board.interaction_legend_index_at(second_center) == -1, "active wiring should keep its operation cursor instead of opening generic gesture help")
	board.connecting_from_node_id = &""
	board.set_interaction_enabled(false)
	_expect(board.interaction_legend_index_at(second_center) == -1 and board._get_tooltip(second_center) == "", "locked factory gestures should be neither hoverable nor explained")
	_expect(board.cursor_shape_at(second_center) == Control.CURSOR_ARROW, "locked gesture tiles should fall back to the normal cursor")
	board.free()


func _test_factory_production_preview_is_non_destructive() -> void:
	var board := FactoryBoard.new()
	board.size = Vector2(568, 339)
	board.configure(MvpContent.PLAN_SCOUT)
	var tick_before := board.simulation.tick_index
	var preview := board.production_preview(160)
	var scout_offsets: PackedInt32Array = preview["event_offsets"][&"scout"]
	_expect(scout_offsets.size() == preview["counts"][&"scout"], "production timeline should contain one offset per successful summon")
	var previous_offset := 0
	for offset in scout_offsets:
		_expect(offset >= 1 and offset <= 160, "production timeline offsets should stay relative to the 32-second window")
		_expect(offset > previous_offset, "production timeline offsets should preserve chronological event order")
		previous_offset = offset
	board.simulation.tick_index = 100
	var shifted_preview := board.production_preview(160)
	_expect(shifted_preview["event_offsets"][&"scout"] == scout_offsets, "production timeline should use offsets instead of absolute simulation ticks")
	board.simulation.tick_index = tick_before
	board._refresh_production_preview()
	_expect(board.cached_production_valid, "valid production preview should expose visual summary state")
	_expect(board.cached_production_counts == preview["counts"], "visual production summary should preserve exact forecast counts")
	_expect(board.cached_production_event_offsets == preview["event_offsets"], "visual production summary should preserve exact summon event timing")
	_expect(board.cached_production_discarded == preview["discarded"], "visual production summary should preserve the mismatch count")
	_expect(is_equal_approx(board.mana_fill_ratio(), float(board.mana_used()) / 100.0), "mana meter should reflect the fixed factory capacity")
	board.set_interaction_enabled(true)
	_expect(board.palette_availability(&"ring_source")["available"], "affordable source should be available in the visual palette")
	_expect(board.palette_availability(&"summoner")["reason"] == &"summoner_limit", "existing summoner should visibly block another summoner")
	_expect(board.interaction_legend_count() == 3, "factory should replace the permanent instruction sentence with three gesture icons")
	_expect(board.persistent_node_label_count() == 0, "factory node silhouettes and Glyphs should replace overlapping persistent node names")
	board.size = Vector2(1196, 401)
	var summary_center := board.production_summary_center(0)
	_expect(board.production_summary_unit_at(summary_center) == &"scout", "production Glyph should expose a stable hover target")
	_expect(board.production_summary_unit_at(summary_center + Vector2(0, 38)) == &"scout", "production timeline should share the Glyph tooltip hit target")
	_expect(board.production_summary_unit_at(summary_center + Vector2(32, 34)) == &"scout", "production timing-change marker should remain inside the Glyph tooltip target")
	_expect(board.cursor_shape_at(summary_center) == Control.CURSOR_HELP, "production forecast Glyph should advertise its visual details")
	_expect(board.production_summary_is_goal(&"scout") and not board.production_summary_is_goal(&"golem"), "production summary should visually outline the selected sigil goal")
	_expect(board._get_tooltip(summary_center) == "glyph_preview", "production Glyph should open the same large visual tooltip as factory Glyphs")
	_expect(board.tooltip_glyph != null and "生産見込み" in board.tooltip_context, "production tooltip should pair its CanonicalGlyph with the forecast count")
	_expect("初回" in board.tooltip_context and "間隔" in board.tooltip_context, "production tooltip should expose first arrival and observed cadence without permanent text")
	_expect(board.production_timing_tooltip(PackedInt32Array()) == "32秒内の召喚なし", "empty timing series should not claim the factory can never summon")
	_expect("未観測" in board.production_timing_tooltip(PackedInt32Array([20])), "single summon should not invent a cadence")
	_expect("間隔 2.0秒" in board.production_timing_tooltip(PackedInt32Array([10, 20, 30])), "regular event spacing should expose its observed interval")
	_expect("2.0–3.0秒" in board.production_timing_tooltip(PackedInt32Array([10, 20, 35])), "variable spacing should expose its observed range instead of an average")
	var preview_line_center := board._output_port_position(&"ring_source").lerp(board._input_port_position(&"summoner", 0), 0.5)
	_expect(board.display_glyph_for_line(&"line_1") != null, "empty pre-battle line should expose its predicted CanonicalGlyph")
	_expect(board._get_tooltip(preview_line_center) == "glyph_comparison" and "32秒予測" in board.tooltip_context, "empty line hover should compare its predicted transport Glyph with the target")
	_expect(board.line_goal_match_state(&"line_1") == &"match", "summoner path should compare its predicted Glyph with the selected goal before battle")
	_expect(board.line_recipe_match_state(&"line_1") == &"match", "empty final line should preview the same registered-recipe acceptance used by summoning")
	board.plan_id = MvpContent.PLAN_SENTINEL
	_expect(board.line_goal_match_state(&"line_1") == &"mismatch", "a valid owned recipe may intentionally differ from the selected goal")
	_expect(board.line_recipe_match_state(&"line_1") == &"match", "a valid owned non-goal recipe should remain a successful final-line signal")
	board.plan_id = MvpContent.PLAN_SCOUT
	board.selected_node_id = &"ring_source"
	board.configure_selected_node(1)
	_expect(board.line_goal_match_state(&"line_1") == &"mismatch", "changing the source should immediately mark the summoner path as a goal mismatch")
	_expect(board.line_recipe_match_state(&"line_1") == &"mismatch", "a Glyph rejected by every registered recipe should mark the final line as failed")
	_expect(preview["ok"], "complete factory should produce a preview")
	_expect(preview["counts"][&"scout"] > 0, "scout factory preview should report scouts")
	_expect(
		preview["node_outputs"].has(&"ring_source"),
		"production preview should capture the source's first output Glyph"
	)
	_expect(board.simulation.tick_index == tick_before, "production preview should not advance the real factory")
	board.set_interaction_enabled(true)
	board.add_node_from_palette(&"rotator")
	_expect(not board.production_preview()["ok"], "incomplete custom graph should not produce a preview")
	board.free()


	var comparison_board := FactoryBoard.new()
	comparison_board.size = Vector2(1196, 401)
	comparison_board.configure(MvpContent.PLAN_SCOUT)
	comparison_board.set_interaction_enabled(true)
	var baseline := comparison_board.production_snapshot()
	var baseline_scout_count := int(baseline["counts"][&"scout"])
	_expect(baseline["event_offsets"][&"scout"].size() == baseline_scout_count, "comparison snapshot should carry the exact baseline timeline")
	baseline["counts"][&"scout"] = -1
	_expect(comparison_board.cached_production_counts[&"scout"] == baseline_scout_count, "production snapshots should not alias the board cache")
	baseline["counts"][&"scout"] = baseline_scout_count
	_expect(not comparison_board.set_production_comparison_baseline(baseline), "comparison should only begin inside a transactional edit")
	_expect(comparison_board.begin_edit(), "valid factory should enter comparison edit")
	var edit_baseline := comparison_board.production_snapshot()
	_expect(comparison_board.set_production_comparison_baseline(edit_baseline), "edit should accept a matching cached production baseline")
	var mutated_offsets: PackedInt32Array = edit_baseline["event_offsets"][&"scout"]
	mutated_offsets[0] = -1
	edit_baseline["event_offsets"][&"scout"] = mutated_offsets
	_expect(comparison_board.production_event_offsets(&"scout", true)[0] >= 1, "comparison baseline timeline should not alias the caller snapshot")
	var neutral_difference := comparison_board.production_difference_state(&"scout")
	_expect(neutral_difference["count_state"] == &"unchanged" and neutral_difference["timing_state"] == &"unchanged", "time stop should begin with an unchanged quantity and schedule")
	var synthetic_before := {
		"ok": true,
		"horizon_ticks": 160,
		"counts": {&"scout": 3},
		"event_offsets": {&"scout": PackedInt32Array([30, 60, 90])},
		"discarded": 0,
	}
	var synthetic_after := synthetic_before.duplicate(true)
	synthetic_after["event_offsets"][&"scout"] = PackedInt32Array([20, 50, 80])
	var synthetic_comparison := comparison_board.compare_production_snapshots(synthetic_before, synthetic_after)
	_expect(synthetic_comparison["changed"], "same-count retiming should be classified as a production change")
	_expect(synthetic_comparison["units"][&"scout"]["count_state"] == &"unchanged" and synthetic_comparison["units"][&"scout"]["timing_state"] == &"earlier", "uniformly advanced summon events should remain independent from quantity")
	synthetic_after["event_offsets"][&"scout"] = PackedInt32Array([40, 70, 100])
	_expect(comparison_board.compare_production_snapshots(synthetic_before, synthetic_after)["units"][&"scout"]["timing_state"] == &"later", "uniformly delayed summon events should be identified without being scored as worse")
	synthetic_after["event_offsets"][&"scout"] = PackedInt32Array([20, 70, 80])
	_expect(comparison_board.compare_production_snapshots(synthetic_before, synthetic_after)["units"][&"scout"]["timing_state"] == &"reshaped", "mixed schedule movement should remain a distinct neutral state")
	synthetic_after["event_offsets"][&"scout"] = PackedInt32Array([20, 55, 85])
	_expect(comparison_board.compare_production_snapshots(synthetic_before, synthetic_after)["units"][&"scout"]["timing_state"] == &"reshaped", "non-uniform movement in one direction should preserve the changed interval shape")
	synthetic_after = synthetic_before.duplicate(true)
	synthetic_after["discarded"] = 2
	synthetic_comparison = comparison_board.compare_production_snapshots(synthetic_before, synthetic_after)
	_expect(synthetic_comparison["changed"] and synthetic_comparison["discarded"]["state"] == &"increase", "forecast discard-only changes should not be reported as unchanged")
	var discard_before := synthetic_after.duplicate(true)
	var discard_after := synthetic_before.duplicate(true)
	_expect(comparison_board.compare_production_snapshots(discard_before, discard_after)["discarded"]["state"] == &"decrease", "forecast discard reduction should remain a neutral directional comparison")
	_expect(comparison_board.compare_production_snapshots(discard_before, discard_before)["discarded"]["state"] == &"unchanged", "equal nonzero forecast discard should collapse to one value")
	synthetic_after["horizon_ticks"] = 120
	_expect(comparison_board.compare_production_snapshots(synthetic_before, synthetic_after)["validity"] == &"invalid", "mismatched forecast windows should not produce a false comparison")
	comparison_board.preview_plan(MvpContent.PLAN_GOLEM)
	_expect(comparison_board.production_difference_state(&"scout")["count_state"] == &"decrease", "golem proposal should disclose lost scout output before commit")
	_expect(comparison_board.production_difference_state(&"golem")["count_state"] == &"increase", "golem proposal should disclose gained golem output before commit")
	comparison_board._get_tooltip(comparison_board.production_summary_center(2) + Vector2(0, 38))
	_expect("旧" in comparison_board.tooltip_context and "新" in comparison_board.tooltip_context and "初回" in comparison_board.tooltip_context, "comparison timeline tooltip should distinguish both observed schedules")
	_expect(comparison_board.undo(), "comparison test should undo the proposed template")
	neutral_difference = comparison_board.production_difference_state(&"scout")
	_expect(neutral_difference["count_state"] == &"unchanged" and neutral_difference["timing_state"] == &"unchanged", "undo should restore the candidate without moving the baseline")
	comparison_board.production_comparison_baseline["discarded"] = 2
	_expect(comparison_board.production_discard_difference_state()["state"] == &"decrease", "live comparison should disclose forecast discard reduction separately from unit output")
	var discard_chip := Vector2(comparison_board.size.x - 36.0, 16.0)
	_expect(comparison_board.production_discard_badge_at(discard_chip), "forecast discard comparison should expose its complete stacked-chip hit target")
	_expect(comparison_board.disconnect_input(&"summoner", 0), "comparison test should allow an invalid disconnected proposal")
	_expect(comparison_board.production_difference_state(&"scout")["validity"] == &"invalid", "invalid proposal should show an unknown candidate instead of a false zero")
	_expect(comparison_board.production_discard_difference_state()["state"] == &"invalid" and comparison_board.production_discard_badge_at(discard_chip), "invalid proposal should retain the known baseline discard beside an unknown candidate")
	_expect("2 → ?" in comparison_board._get_tooltip(discard_chip), "invalid discard tooltip should never convert an unknown candidate into zero")
	_expect(comparison_board.production_event_offsets(&"scout").is_empty(), "invalid proposal should clear the stale candidate event timeline")
	comparison_board._get_tooltip(comparison_board.production_summary_center(0) + Vector2(0, 38))
	_expect("新 ?" in comparison_board.tooltip_context, "invalid timeline tooltip should not report the last valid candidate timing")
	_expect(comparison_board.production_summary_unit_at(comparison_board.production_summary_center(0)) == &"scout", "invalid proposal should keep the baseline Glyphs inspectable")
	_expect(comparison_board.undo(), "comparison test should repair the invalid proposal through undo")
	neutral_difference = comparison_board.production_difference_state(&"scout")
	_expect(neutral_difference["count_state"] == &"unchanged" and neutral_difference["timing_state"] == &"unchanged", "repair should restore a live comparison against the original baseline")
	comparison_board.cancel_edit()
	_expect(not comparison_board.production_comparison_active, "cancel should clear every comparison decoration")
	comparison_board.free()


	var timing_board := FactoryBoard.new()
	timing_board.configure(MvpContent.PLAN_SCOUT)
	timing_board.simulation.tick()
	timing_board._refresh_production_preview()
	_expect(timing_board.begin_edit(), "timing-only comparison should enter a transaction from warm factory state")
	var timing_baseline := timing_board.production_snapshot()
	_expect(timing_board.set_production_comparison_baseline(timing_baseline), "timing-only comparison should freeze the warm production schedule")
	timing_board.set_interaction_enabled(true)
	timing_board.selected_node_id = &"ring_source"
	_expect(timing_board.configure_selected_node(1) and timing_board.configure_selected_node(0), "changing a source away and back should produce a valid retimed candidate")
	var timing_only_difference := timing_board.production_difference_state(&"scout")
	_expect(timing_only_difference["count_state"] == &"unchanged" and timing_only_difference["timing_state"] == &"later", "resetting the warm source phase should disclose a later schedule even when the 32-second count is unchanged")
	_expect(timing_board.undo() and timing_board.undo(), "timing-only comparison should undo both source configuration changes")
	timing_only_difference = timing_board.production_difference_state(&"scout")
	_expect(timing_only_difference["count_state"] == &"unchanged" and timing_only_difference["timing_state"] == &"unchanged", "undo should restore the exact warm schedule without moving its baseline")
	timing_board.cancel_edit()
	timing_board.free()
	var sentinel_board := FactoryBoard.new()
	sentinel_board.configure(MvpContent.PLAN_SENTINEL)
	var source_preview := sentinel_board.predicted_output_glyph_for_node(&"ring_source")
	var rotation_preview := sentinel_board.predicted_output_glyph_for_node(&"rotator")
	var color_preview := sentinel_board.predicted_output_glyph_for_node(&"colorizer")
	_expect(source_preview != null, "factory board should cache the predicted source output")
	_expect(rotation_preview != null, "factory board should cache the predicted rotated output")
	_expect(color_preview != null, "factory board should cache the predicted colored output")
	if source_preview != null and rotation_preview != null and color_preview != null:
		_expect(
			sentinel_board.node_glyph_draw_scale(source_preview) >= 1.5,
			"label-free node should spend its interior space on a legible single-Primitive Glyph"
		)
		_expect(source_preview.components[0].rotation_step == 0, "source prediction should retain the raw orientation")
		_expect(rotation_preview.components[0].rotation_step == 1, "rotator prediction should expose its quarter turn")
		_expect(color_preview.components[0].color_id == &"blue", "colorizer prediction should expose its output color")
	sentinel_board.free()


func _test_factory_downstream_route_focus_is_non_destructive() -> void:
	var sentinel_board := FactoryBoard.new()
	sentinel_board.configure(MvpContent.PLAN_SENTINEL)
	var runtime_before := _factory_runtime_signature(sentinel_board.simulation)
	var production_before := sentinel_board.production_snapshot()
	var sentinel_route := sentinel_board.focused_downstream_route(&"ring_source")
	_expect(
		sentinel_route["node_ids"] == [&"colorizer", &"ring_source", &"rotator", &"summoner"]
		and sentinel_route["line_ids"] == [&"line_1", &"line_2", &"line_3"]
		and sentinel_route["reaches_summoner"],
		"sentinel focus should trace the selected source through every downstream processor to the summoner"
	)
	_expect(_factory_runtime_signature(sentinel_board.simulation) == runtime_before and sentinel_board.production_snapshot() == production_before, "route inspection should not mutate simulation or the production forecast")
	sentinel_board.free()

	var golem_board := FactoryBoard.new()
	golem_board.configure(MvpContent.PLAN_GOLEM)
	var ring_route := golem_board.focused_downstream_route(&"ring_source")
	_expect(
		ring_route["node_ids"] == [&"colorizer", &"combiner", &"ring_source", &"summoner"]
		and ring_route["line_ids"] == [&"line_color", &"line_ring", &"line_summon"],
		"one golem source should focus only its own branch and the shared downstream route"
	)
	_expect(not ring_route["node_ids"].has(&"spike_source") and not ring_route["line_ids"].has(&"line_spike"), "route focus should not claim a sibling source branch")
	golem_board.set_interaction_enabled(true)
	golem_board.selected_node_id = &"spike_source"
	golem_board.hovered_node_id = &"ring_source"
	_expect(golem_board.focused_route_start_node_id() == &"ring_source", "hovered equipment should temporarily take focus priority over selection")
	_expect(golem_board.node_focus_marker_kind(&"spike_source", &"ring_source") == &"selected" and golem_board.node_focus_marker_kind(&"ring_source", &"ring_source") == &"hover", "filled selection and hollow hover markers should remain distinct without color")
	golem_board.hovered_node_id = &""
	_expect(golem_board.focused_route_start_node_id() == &"spike_source", "selection should restore route focus after hover exits")
	_expect(golem_board.node_focus_marker_kind(&"spike_source", &"spike_source") == &"selected" and golem_board.node_focus_marker_kind(&"ring_source", &"spike_source") == &"none", "hover marker should disappear when the selected route regains focus")
	var line_hover_runtime_before := _factory_runtime_signature(golem_board.simulation)
	var line_hover_production_before := golem_board.production_snapshot()
	var line_hover_undo_before := golem_board.undo_history.size()
	golem_board.selected_node_id = &"ring_source"
	golem_board.hovered_line_id = &"line_spike"
	_expect(golem_board.focused_route_start_node_id() == &"spike_source", "hovered line should temporarily focus the route from its sending equipment")
	var spike_line_route := golem_board.focused_downstream_route(golem_board.focused_route_start_node_id())
	_expect(
		spike_line_route["node_ids"] == [&"colorizer", &"combiner", &"spike_source", &"summoner"]
		and spike_line_route["line_ids"] == [&"line_color", &"line_spike", &"line_summon"]
		and not spike_line_route["node_ids"].has(&"ring_source")
		and not spike_line_route["line_ids"].has(&"line_ring"),
		"line hover should replace the selected sibling route with only its own branch and shared downstream"
	)
	_expect(golem_board.node_focus_marker_kind(&"ring_source", &"spike_source") == &"selected" and golem_board.node_focus_marker_kind(&"spike_source", &"spike_source") == &"hover", "line route should keep the selected origin filled and mark its temporary source as hollow")
	golem_board.hovered_line_id = &"line_color"
	_expect(golem_board.focused_route_start_node_id() == &"combiner", "shared downstream line should focus from its own sender without claiming either source branch")
	var shared_line_route := golem_board.focused_downstream_route(golem_board.focused_route_start_node_id())
	_expect(shared_line_route["node_ids"] == [&"colorizer", &"combiner", &"summoner"] and shared_line_route["line_ids"] == [&"line_color", &"line_summon"], "shared line focus should omit both upstream material branches")
	golem_board.hovered_line_id = &"missing_line"
	_expect(golem_board.focused_route_start_node_id() == &"ring_source", "stale hovered line should safely fall back to the selected route")
	golem_board.hovered_line_id = &""
	_expect(golem_board.focused_route_start_node_id() == &"ring_source", "line hover exit should restore the selected route immediately")
	_expect(_factory_runtime_signature(golem_board.simulation) == line_hover_runtime_before and golem_board.production_snapshot() == line_hover_production_before and golem_board.undo_history.size() == line_hover_undo_before, "line route inspection should not mutate simulation, production, or Undo history")
	golem_board.connecting_from_node_id = &"ring_source"
	_expect(golem_board.focused_route_start_node_id() == &"", "active rewiring should suppress route focus behind the connection preview")
	golem_board.connecting_from_node_id = &""
	golem_board.hovered_line_id = &"line_color"
	_expect(golem_board.disconnect_input(&"colorizer", 0), "route focus fixture should disconnect the shared downstream route")
	_expect(golem_board.hovered_line_id == &"" and golem_board.focused_route_start_node_id() == &"ring_source", "successful topology change should clear line hover and retain only the selected route")
	var interrupted_route := golem_board.focused_downstream_route(&"ring_source")
	_expect(
		interrupted_route["node_ids"] == [&"combiner", &"ring_source"]
		and interrupted_route["line_ids"] == [&"line_ring"]
		and not interrupted_route["reaches_summoner"],
		"a broken route should focus only the reachable segment up to its dead end"
	)
	_expect(golem_board.undo(), "route focus fixture should restore its disconnected line")
	_expect(golem_board.hovered_line_id == &"", "Undo should not restore transient line hover from the graph snapshot")
	golem_board.free()


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
	board.set_interaction_enabled(true)
	board.size = Vector2(1196, 401)
	var discard_badge := Vector2(board.size.x - 18.0, 28.0)
	_expect(board.production_discard_badge_at(discard_badge), "mismatching forecast should expose a hoverable discard-count badge")
	_expect(board.cursor_shape_at(discard_badge) == Control.CURSOR_HELP, "forecast discard badge should advertise its explanation")
	_expect("不一致Glyph" in board._get_tooltip(discard_badge), "forecast discard badge should explain the rejected Glyph count on hover")
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
	board.selected_node_id = &"ring_source"
	_expect(board.selected_node_details()["selected_index"] == -1, "invalid restored source setting should not masquerade as a valid ring selection")
	_expect(board.selected_node_details()["title"] == "素材未設定", "invalid restored source setting should ask for a fresh choice")
	var validation := board.validation_result()
	_expect(not validation["ok"], "invalid restored source configuration should block factory start")
	_expect(
		validation["message"] == "素材源「ring_source」の素材設定がありません",
		"factory start rejection should name the invalid source setting"
	)
	board._refresh_production_preview()
	_expect(board.node_validation_state(&"ring_source") == &"configuration", "invalid restored source setting should mark its equipment directly")
	var invalid_marker := board.node_local_position(&"ring_source") + Vector2(34, -20)
	_expect(board.validation_fault_at(invalid_marker) == "素材を再選択", "invalid equipment marker should give a short local repair action")
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
	board.set_interaction_enabled(true)
	_expect(board.configure_selected_node(0), "one valid inspector choice should repair an invalid restored source setting")
	_expect(board.selected_node_details()["selected_index"] == 0, "repaired source setting should select its valid ring option")
	board.free()
	var processor_board := FactoryBoard.new()
	processor_board.configure(MvpContent.PLAN_SENTINEL)
	processor_board.set_interaction_enabled(true)
	processor_board.simulation.nodes[&"rotator"].config["processing_ticks"] = 0
	processor_board.selected_node_id = &"rotator"
	processor_board._refresh_production_preview()
	_expect(processor_board.configure_selected_node(0), "reselecting a rotator option should repair its corrupt processing time")
	_expect(processor_board.simulation.nodes[&"rotator"].config["processing_ticks"] >= 1, "rotator repair should restore a valid processing time")
	processor_board.free()
	var interval_board := FactoryBoard.new()
	interval_board.configure(MvpContent.PLAN_SCOUT)
	interval_board.set_interaction_enabled(true)
	interval_board.simulation.nodes[&"ring_source"].config["interval_ticks"] = 0
	interval_board.selected_node_id = &"ring_source"
	interval_board._refresh_production_preview()
	_expect(not interval_board.cached_production_valid, "corrupt restored source interval should invalidate the forecast")
	_expect(interval_board.configure_selected_node(0), "reselecting the same source material should repair its corrupt interval")
	_expect(interval_board.simulation.nodes[&"ring_source"].config["interval_ticks"] >= 1, "source repair should restore a positive interval")
	_expect(interval_board.cached_production_valid, "source interval repair should immediately restore the production forecast")
	interval_board.free()


func _test_sigil_ghost_tracks_plan_recipe() -> void:
	var ghost := SigilGhost.new()
	_expect(ghost.show_recipe(&"azure_guard"), "sigil ghost should accept a known recipe")
	_expect(ghost.persistent_label() == "目標", "persistent comparison card should identify its left Glyph as the goal")
	_expect(ghost.custom_minimum_size.x >= 320.0 and ghost.custom_minimum_size.y >= 80.0, "sigil goal should reserve a large persistent comparison card")
	_expect(ghost.glyph_draw_scale() >= 1.3, "sigil goal should keep its persistent CanonicalGlyph readable")
	var target_tooltip = ghost._make_custom_tooltip(ghost.tooltip_text)
	_expect(target_tooltip.get_script() == GlyphTooltipModel, "sigil goal hover should create a visual Glyph tooltip")
	_expect(target_tooltip.custom_minimum_size.x >= 300.0, "visual Glyph tooltip should be substantially larger than the persistent sample")
	_expect(
		target_tooltip.glyph.canonical_serialization() == ghost.glyph.canonical_serialization(),
		"visual Glyph tooltip should draw the same CanonicalGlyph as the target"
	)
	target_tooltip.free()
	_expect(ghost.recipe_id == &"azure_guard", "sigil ghost should retain the displayed recipe ID")
	_expect(ghost.glyph_draw_scale() == 2.45, "single-Primitive completion target should stay readable beside the factory candidate")
	ghost.show_candidate(ghost.glyph, &"predicted")
	_expect(ghost.candidate_state == &"match", "identical factory candidate should show a positive comparison state")
	_expect(ghost.candidate_origin == &"predicted" and ghost.candidate_ring_style() == &"dashed", "predicted factory candidate should keep a dashed visual grammar")
	var mismatching_candidate := GlyphModel.new([GlyphComponentModel.new(&"spike")])
	ghost.show_candidate(mismatching_candidate)
	_expect(ghost.candidate_state == &"mismatch", "different factory candidate should show a negative comparison state")
	_expect(ghost.mouse_default_cursor_shape == Control.CURSOR_HELP, "persistent goal card should advertise its visual inspection")
	_expect(ghost.hover_slot_at(Vector2(132, 40)) == &"target" and ghost.hover_slot_at(Vector2(266, 40)) == &"candidate", "persistent goal card should distinguish its two visual targets")
	ghost.hovered_slot = ghost.hover_slot_at(Vector2(132, 40))
	_expect(ghost.hovered_slot == &"target", "goal card should retain which Glyph receives hover emphasis")
	_expect(ghost._get_tooltip(Vector2(132, 40)) == "target", "target half should request its own Glyph preview")
	var target_with_candidate_tooltip = ghost._make_custom_tooltip("target")
	_expect(target_with_candidate_tooltip.get_script() == GlyphTooltipModel, "target half should stay a single completed-Glyph preview when an output candidate exists")
	target_with_candidate_tooltip.free()
	_expect(ghost._get_tooltip(Vector2(240, 25)) == "candidate", "candidate half of the goal card should have its own large tooltip")
	_expect(
		ghost.tooltip_glyph.canonical_serialization() == mismatching_candidate.canonical_serialization(),
		"candidate tooltip should use the compared CanonicalGlyph"
	)
	var comparison_tooltip = ghost._make_custom_tooltip("candidate")
	_expect(comparison_tooltip.get_script() == GlyphComparisonTooltipModel, "available factory output should open a side-by-side visual comparison")
	_expect(comparison_tooltip.custom_minimum_size.x >= 500.0, "side-by-side comparison should be substantially larger than the persistent card")
	_expect(comparison_tooltip.comparison_state == &"mismatch", "comparison tooltip should preserve the mismatch state")
	_expect(&"primitive" in comparison_tooltip.difference_categories(), "side-by-side comparison should identify a Primitive-shape difference visually")
	_expect(
		comparison_tooltip.target_glyph.canonical_serialization() == ghost.glyph.canonical_serialization()
		and comparison_tooltip.candidate_glyph.canonical_serialization() == mismatching_candidate.canonical_serialization(),
		"comparison tooltip should own exact copies of both compared CanonicalGlyphs"
	)
	comparison_tooltip.free()
	var sentinel_recipe: SigilRecipeModel
	for recipe in MvpContent.recipes():
		if recipe.id == &"azure_guard":
			sentinel_recipe = recipe
	var attribute_comparison = GlyphComparisonTooltipModel.new()
	attribute_comparison.configure(
		sentinel_recipe.glyph,
		GlyphModel.new([GlyphComponentModel.new(&"ring")]),
		"衛兵"
	)
	_expect(&"rotation" in attribute_comparison.difference_categories(), "comparison should expose a rotation difference without a written guide")
	_expect(&"color" in attribute_comparison.difference_categories(), "comparison should expose a color difference without a written guide")
	_expect(&"combine" not in attribute_comparison.difference_categories(), "single Glyph attribute changes should not masquerade as a Combine hierarchy difference")
	attribute_comparison.free()
	var ring_leaf := GlyphModel.new([GlyphComponentModel.new(&"ring")])
	var spike_leaf := GlyphModel.new([GlyphComponentModel.new(&"spike")])
	var branch_leaf := GlyphModel.new([GlyphComponentModel.new(&"branch")])
	var left_grouped := GlyphModel.combine(GlyphModel.combine(ring_leaf, spike_leaf), branch_leaf)
	var right_grouped := GlyphModel.combine(ring_leaf, GlyphModel.combine(spike_leaf, branch_leaf))
	_expect(
		GlyphPainterModel.combine_visuals(left_grouped, 2.0)["connections"].is_empty()
		and GlyphPainterModel.combine_visuals(right_grouped, 2.0)["connections"].is_empty(),
		"coincident Combine subtrees should rely on their circles instead of invented directional lines"
	)
	var hierarchy_comparison = GlyphComparisonTooltipModel.new()
	hierarchy_comparison.configure(left_grouped, right_grouped, "合成階層")
	_expect(&"combine" in hierarchy_comparison.difference_categories(), "comparison should expose which Primitive belongs to each Combine subtree")
	hierarchy_comparison.free()
	ghost.show_candidate(null)
	_expect(ghost.candidate_state == &"missing", "missing factory candidate should leave an empty comparison slot")
	_expect(ghost.hover_slot_at(Vector2(132, 40)) == &"target" and ghost.hover_slot_at(Vector2(266, 40)) == &"candidate", "empty factory output should preserve separate target and candidate hover geometry")
	_expect(ghost.hover_slot_at(Vector2(-1, 40)) == &"" and ghost.hover_slot_at(Vector2(321, 40)) == &"" and ghost.hover_slot_at(Vector2(266, 81)) == &"", "goal comparison slots should reject points outside the control")
	_expect(ghost._get_tooltip(Vector2(266, 40)) == "工場出力 // 候補なし", "empty candidate slot should explain its own missing output instead of the target Glyph")
	_expect(ghost._make_custom_tooltip("工場出力 // 候補なし") == null, "empty candidate slot should use one native line instead of a null-Glyph custom preview")
	_expect(ghost._get_tooltip(Vector2(132, 40)) == "target", "empty candidate state should not change the target slot tooltip")
	ghost.hovered_slot = &"candidate"
	ghost.show_candidate(null)
	_expect(ghost.hovered_slot == &"candidate", "clearing the factory candidate should preserve hover on the same empty candidate slot")
	ghost.show_candidate(null, &"hypothetical", &"no_output")
	_expect(ghost._get_tooltip(Vector2(266, 40)) == "設定候補 // 32秒内に出力なし", "hypothetical no-output state should retain its more specific forecast tooltip")
	ghost.show_candidate(null, &"hypothetical", &"invalid")
	_expect(ghost._get_tooltip(Vector2(266, 40)) == "設定候補 // 予測できません", "invalid hypothetical output should remain distinct from an empty valid forecast")
	ghost.show_candidate(null)
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
	_expect(ghost.show_recipe(&"bound_colossus"), "sigil ghost should accept the combined recipe")
	_expect(ghost.glyph_draw_scale() == 1.35, "combined completion target should keep its outer ring inside the comparison panel")
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
