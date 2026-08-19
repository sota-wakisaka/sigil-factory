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
const RunFlow := preload("res://src/game/run_flow.gd")

var failures := 0


func _initialize() -> void:
	_test_exact_match_is_order_independent()
	_test_attribute_diagnostics()
	_test_missing_and_extra_components()
	_test_combine_structure_is_order_independent()
	_test_combine_hierarchy_affects_matching()
	_test_production_context_does_not_affect_matching()
	_test_factory_pipeline_summons_matching_unit()
	_test_combiner_waits_for_both_inputs()
	_test_factory_rejects_cycles()
	_test_factory_disconnects_lines()
	_test_factory_removes_node_and_connected_lines()
	_test_factory_graph_validation_reports_dangling_nodes()
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
	_test_factory_node_configuration_is_undoable()
	_test_factory_board_connections_change_output()
	_test_factory_ports_connect_through_mouse_input()
	_test_factory_production_preview_is_non_destructive()
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
	var original_simulation := board.simulation
	board.begin_edit()
	board.preview_plan(MvpContent.PLAN_GOLEM)
	_expect(board.plan_id == MvpContent.PLAN_SCOUT, "preview should not change committed plan")
	_expect(board.simulation == original_simulation, "preview should not replace running factory")
	board.commit_edit()
	_expect(board.plan_id == MvpContent.PLAN_GOLEM, "commit should apply pending plan")
	_expect(board.simulation != original_simulation, "commit should replace factory atomically")
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
