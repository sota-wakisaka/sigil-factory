extends SceneTree

const RunFlow := preload("res://src/game/run_flow.gd")
const MvpContent := preload("res://src/game/mvp_content.gd")

var failures := 0


func _initialize() -> void:
	_expect(
		float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec")) <= 0.25,
		"visual Glyph tooltips should appear without interrupting factory inspection"
	)
	var scene: PackedScene = load("res://src/main.tscn")
	var main := scene.instantiate()
	root.add_child(main)
	await process_frame

	_expect(main.flow.phase == RunFlow.Phase.ROUTE_SELECTION, "UI should open at route selection")
	_expect(main.phase_overlay.visible, "placeholder phases should use the overlay")
	_expect(main.route_option.visible and main.route_option.item_count == 3, "route selection should offer three branches")

	main.phase_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.STAGE_INFO, "route OK should show stage information")
	_expect("中央ルート" in main.phase_body.text, "stage information should retain the selected route")
	_expect("制限時間 3:00" in main.phase_body.text, "stage information should disclose the battle duration")
	_expect("群体兵 → 衛兵" in main.phase_body.text, "stage information should disclose wave counters")
	_expect("装甲兵 → 巨像" in main.phase_body.text, "stage information should use the same unit name as the factory")
	main.phase_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.FACTORY_BUILD, "stage OK should open factory build")
	_expect(not main.phase_overlay.visible, "factory build should expose the workspace")
	_expect(main.factory_board.visible and not main.battle_board.visible, "factory build should open the factory tab")
	_expect(main.factory_board.size.x >= 1100.0, "factory tab should use the full workspace width")
	_expect(not main.progress_label.visible and not main.get_node("Hint").visible, "workspace should not spend space on persistent instruction text")
	_expect(not main.threat_label.visible and not main.status_label.visible, "factory tab should hide battle-only forecast and status text")
	main.battle_tab.pressed.emit()
	_expect(main.battle_board.visible and not main.factory_board.visible, "battle tab should reuse the full workspace")
	_expect(main.threat_label.visible and main.status_label.visible, "battle tab should restore its forecast and status")
	_expect(not main.get_node("FactoryPalette").visible, "battle tab should hide factory-only controls")
	main.factory_tab.pressed.emit()
	_expect(main.factory_board.visible and main.get_node("FactoryPalette").visible, "factory tab should restore factory controls")
	_expect(main.factory_board.plan_id == MvpContent.PLAN_EMPTY, "first factory build should start from the guided empty workshop")
	_expect(main.sigil_ghost.recipe_id == &"open_ring", "empty workshop should show the first scout sigil goal")
	_expect(main.get_node("Toolbar/EmptyButton").button_pressed, "current factory plan should remain visually selected")
	_expect(main.get_node("Toolbar/EmptyButton").glyph != null, "manual plan button should show its target CanonicalGlyph")
	_expect(main.get_node("Toolbar/EmptyButton").mode_badge_kind() == &"manual_wiring", "manual workshop should carry a wiring badge in addition to its shared target Glyph")
	_expect(main.get_node("Toolbar/ScoutButton").mode_badge_kind() == &"template", "completed factory choice should remain visually distinct from manual wiring")
	var manual_plan_tooltip = main.get_node("Toolbar/EmptyButton")._make_custom_tooltip("")
	_expect("自分で最初の配線" in manual_plan_tooltip.context, "manual plan Glyph tooltip should retain its wiring purpose")
	_expect(manual_plan_tooltip.context_lines().size() >= 2, "long plan purpose should wrap instead of clipping at the tooltip edge")
	manual_plan_tooltip.free()
	var scout_plan_tooltip = main.get_node("Toolbar/ScoutButton")._make_custom_tooltip("")
	_expect("高速生産" in scout_plan_tooltip.context, "template Glyph tooltip should retain its production purpose")
	scout_plan_tooltip.free()
	_expect(main.get_node("Toolbar/EmptyButton").glyph_draw_scale() >= 1.4, "single-Primitive plan Glyph should remain readable without hover")
	_expect(main.get_node("Toolbar/GolemButton").glyph_draw_scale() >= 1.4, "combined plan Glyph should reserve a similarly readable button footprint")
	_expect(main.factory_board.mana_status_text() == "魔力 40/100 // 空き60", "factory build should disclose fixed mana capacity")
	_expect("戦闘を開始" in main.pause_button.tooltip_text, "main action tooltip should explain build confirmation")
	_expect(main.pause_button.action_kind == "start" and main.pause_button.text == "戦闘開始", "factory build should use a compact play action")
	_expect(not main.plan_label.visible and main.factory_state.state == &"pending", "empty workshop should replace its header sentence with a pending connection badge")
	_expect("配線待ち" in main.factory_state.tooltip_text, "factory state badge should retain detail on hover")
	var error_badge_position := Vector2(main.factory_board.size.x - 18.0, 27.0)
	_expect(main.factory_board.production_error_at(error_badge_position), "invalid production preview should collapse its permanent sentence into a hoverable badge")
	_expect("入力が未接続" in main.factory_board._get_tooltip(error_badge_position), "production error badge should retain the actionable validation reason on hover")
	_expect(main.factory_board.is_guided_connection_pending(), "empty workshop should highlight its first connection")
	var guided_result: Dictionary = main.factory_board.connect_nodes_interactive(&"ring_source", &"summoner", 0)
	_expect(guided_result["ok"], "guided factory connection should succeed")
	_expect(main.factory_state.state == &"ready", "first connection should replace the guide with a visual ready badge")
	_expect(main.sigil_ghost.candidate_state == &"match", "completed starter wiring should visually match factory output against the target")
	_expect(main.sigil_ghost.candidate_origin == &"predicted", "pre-battle factory output should remain visibly identified as a prediction")
	_expect(main.factory_board.disconnect_input(&"summoner", 0), "guided connection should be removable")
	_expect(main.factory_state.state == &"pending", "removing the first connection should restore the pending connection badge")
	_expect(main.sigil_ghost.candidate_state == &"missing", "broken wiring should clear the final candidate comparison")
	main.factory_board.connect_nodes_interactive(&"ring_source", &"summoner", 0)
	main.get_node("Toolbar/ScoutButton").pressed.emit()
	_expect(main.get_node("Toolbar/ScoutButton").button_pressed, "selected sigil plan should be highlighted")
	_expect(main.factory_state.state == &"ready", "complete factory template should show the same ready state as manually completed wiring")
	_expect(not main.get_node("Toolbar/EmptyButton").button_pressed, "previous sigil plan should clear its highlight")
	main.get_node("FactoryPalette/UndoButton").pressed.emit()
	_expect(main.factory_board.plan_id == MvpContent.PLAN_EMPTY and main.factory_board.simulation.lines.size() == 1, "build-phase preset undo should restore the preceding hand-wired factory")
	_expect(main.get_node("Toolbar/EmptyButton").button_pressed and not main.get_node("Toolbar/ScoutButton").button_pressed, "build-phase preset undo should restore its plan highlight")
	main.get_node("Toolbar/ScoutButton").pressed.emit()
	_expect(
		main.get_node("Toolbar/ScoutButton").glyph.canonical_serialization() == main.sigil_ghost.glyph.canonical_serialization(),
		"selected plan button and persistent goal should draw the same CanonicalGlyph"
	)
	_expect(main.sigil_ghost.candidate_state == &"match", "template output should immediately compare against its selected target")
	_expect(main.factory_board.interaction_enabled, "factory build should enable node placement")
	_expect(not main.get_node("FactoryPalette/RingButton").disabled, "factory build should enable the equipment palette")
	_expect(main.get_node("FactoryPalette/SummonButton").disabled, "palette should visually block the one-summoner limit before click")
	_expect(main.get_node("FactoryPalette/SummonButton").availability_reason == &"summoner_limit", "summoner palette badge should distinguish its one-node limit")
	_expect("1基まで" in main.get_node("FactoryPalette/SummonButton").tooltip_text, "disabled summoner should explain its actual limit on hover")
	_expect(main.get_node("FactoryPalette/DeleteButton").disabled, "delete should stay unavailable until a node is selected")
	_expect(main.get_node("FactoryPalette/DeleteButton").availability_reason == &"selection", "delete palette badge should identify a missing selection")
	_expect("設備を選択" in main.get_node("FactoryPalette/DeleteButton").tooltip_text, "disabled delete should explain how to enable it on hover")
	_expect(not main.get_node("FactoryPalette/UndoButton").disabled, "undo should retain the latest template application")
	_expect(main.get_node("FactoryPalette/UndoButton").availability_reason == &"", "available undo should clear its empty-history badge")
	_expect(not main.inspector_label.visible, "empty inspector should remove its idle target instead of reserving a blank control")
	_expect(not main.inspector_option.visible, "empty inspector should hide its unusable setting dropdown")
	_expect(main.get_node("FactoryPalette/RingButton").preview_glyph != null, "source palette choice should use its Primitive as the main icon")
	_expect(main.get_node("FactoryPalette/RingButton").text == "", "palette choice should not rely on the native text label")
	var source_palette_tooltip = main.get_node("FactoryPalette/RingButton")._make_custom_tooltip("")
	_expect(source_palette_tooltip is GlyphTooltip, "source palette choice should enlarge its CanonicalGlyph on hover")
	_expect(source_palette_tooltip.glyph.canonical_serialization() == main.get_node("FactoryPalette/RingButton").preview_glyph.canonical_serialization(), "source palette tooltip should preserve the exact displayed Primitive")
	source_palette_tooltip.free()
	_expect(main.get_node("FactoryPalette/SummonButton").equipment_kind == &"summoner", "summoner palette choice should expose its dedicated vector icon kind")
	_expect(main.get_node("FactoryPalette/RingButton").mana_cost == 20, "palette should expose source mana cost without requiring a tooltip")
	_expect(main.get_node("FactoryPalette/RotateButton").mana_cost == 15, "palette should expose processor mana cost with the same visual convention")
	_expect(main.get_node("FactoryPalette/RingButton").goal_relevant, "scout target should visually link to its ring source tool")
	_expect(not main.get_node("FactoryPalette/RotateButton").goal_relevant, "scout target should not mark an unused rotation tool")
	main.sigil_ghost.show_recipe(&"azure_guard")
	main._refresh_factory_goal_tools()
	_expect(main.get_node("FactoryPalette/RotateButton").goal_relevant, "rotated target should visually mark the rotation tool")
	_expect(main.get_node("FactoryPalette/ColorButton").goal_relevant, "colored target should visually mark the color tool")
	main.sigil_ghost.show_recipe(&"bound_colossus")
	main._refresh_factory_goal_tools()
	_expect(main.get_node("FactoryPalette/SpikeButton").goal_relevant, "combined target should visually mark its spike source")
	_expect(main.get_node("FactoryPalette/CombineButton").goal_relevant, "combined target should visually mark the combine tool")
	main.sigil_ghost.show_recipe(&"open_ring")
	main._refresh_factory_goal_tools()
	_expect(main.get_node("FactoryPalette/RotateButton").custom_minimum_size.y >= 50.0, "palette icon should reserve readable vertical space")
	_expect(
		"90°・180°・270°" in main.get_node("FactoryPalette/RotateButton").tooltip_text,
		"rotator palette tooltip should disclose every inspector setting"
	)
	_expect(
		"青・赤・白" in main.get_node("FactoryPalette/ColorButton").tooltip_text,
		"colorizer palette tooltip should disclose every inspector setting"
	)
	_expect("斥候" in main.factory_board.cached_production_preview, "factory build should preview expected production")
	var node_count_before_palette: int = main.factory_board.simulation.nodes.size()
	main.get_node("FactoryPalette/RingButton").pressed.emit()
	_expect(not main.get_node("FactoryPalette/DeleteButton").disabled, "adding a node should immediately enable delete for its selection")
	_expect(not main.get_node("FactoryPalette/UndoButton").disabled, "adding a node should immediately enable undo")
	_expect(main.inspector_label.visible and main.inspector_label.selected, "selected equipment should reveal its equipment silhouette")
	_expect(main.factory_board.simulation.nodes.size() == node_count_before_palette + 1, "palette should add factory equipment")
	_expect(
		"出力が未接続" in main.factory_board.cached_production_preview,
		"dangling equipment should invalidate production preview with a specific reason"
	)
	_expect(main.inspector_option.visible and not main.inspector_option.disabled, "selected configurable equipment should reveal and enable its inspector")
	_expect(main.inspector_option.visual_kind == FactoryNodeModel.NodeKind.SOURCE, "source inspector should use its Primitive visual language")
	_expect(main.inspector_option.visual_index == 0 and main.inspector_option.get_item_text(0) == "環", "source setting should keep text subordinate to the ring icon")
	_expect(main.inspector_option.get_item_icon(0) != null and main.inspector_option.get_item_icon(1) != null, "source dropdown should keep Primitive icons visible in every choice")
	_expect(main.inspector_option._setting_icon(FactoryNodeModel.NodeKind.ROTATOR, 0) != null, "rotation dropdown should expose its visual operation icon")
	_expect(
		main.inspector_option.rotation_direction_for_index(0) == Vector2i.RIGHT
		and main.inspector_option.rotation_direction_for_index(1) == Vector2i.DOWN
		and main.inspector_option.rotation_direction_for_index(2) == Vector2i.LEFT,
		"rotation dropdown should distinguish 90, 180, and 270 degrees by direction instead of text alone"
	)
	_expect(main.inspector_option._setting_icon(FactoryNodeModel.NodeKind.COLORIZER, 0) != null and main.inspector_option._setting_icon(FactoryNodeModel.NodeKind.COLORIZER, 1) != null, "color dropdown should expose distinct blue and red swatches")
	main.inspector_option.item_selected.emit(1)
	_expect(main.inspector_option.visual_index == 1, "setting icon should follow the selected source Primitive")
	var selected_source: FactoryNodeModel = main.factory_board.simulation.nodes[main.factory_board.selected_node_id]
	_expect(selected_source.config["primitive_id"] == "spike", "inspector should change a selected source to spike material")
	main.pause_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.FACTORY_BUILD, "invalid factory should not start battle")
	_expect("戦闘を開始できません" in main.status_label.text, "invalid factory should explain why battle cannot start")
	main.get_node("FactoryPalette/DeleteButton").pressed.emit()
	_expect(main.factory_board.simulation.nodes.size() == node_count_before_palette, "delete button should remove selected equipment")
	main.get_node("FactoryPalette/UndoButton").pressed.emit()
	_expect(main.factory_board.simulation.nodes.size() == node_count_before_palette + 1, "undo button should restore deleted equipment")
	main.get_node("FactoryPalette/UndoButton").pressed.emit()
	_expect(main.factory_board.simulation.nodes.size() == node_count_before_palette + 1, "undo button should restore the previous equipment setting")
	main.get_node("FactoryPalette/UndoButton").pressed.emit()
	_expect(main.factory_board.simulation.nodes.size() == node_count_before_palette, "undo button should restore the graph before equipment was added")

	main.pause_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.BATTLE, "build confirmation should start battle")
	_expect(main.battle_board.visible and not main.factory_board.visible, "battle phase should open the battle tab")
	_expect(main.threat_label.visible and main.status_label.visible, "running battle should expose battle-only information")
	_expect(not main.factory_board.interaction_enabled, "running battle should lock node placement")
	_expect(main.get_node("FactoryPalette/RingButton").disabled, "running battle should lock the equipment palette")
	_expect("敵防壁HP" in main.status_label.text, "battle status should identify the active enemy shield")
	_expect("残り 03:00" in main.status_label.text, "battle status should show the remaining time")
	_expect("生産 斥候" in main.status_label.text and "衛兵" in main.status_label.text and "巨像" in main.status_label.text, "battle status should name each production count")
	_expect(main.status_label.get_minimum_size().x <= main.size.x, "battle status should fit the default viewport width")
	_expect("推奨: 斥候" in main.threat_label.text, "enemy forecast should recommend an initial counter")
	_expect("編成警告 60s: 群体兵→衛兵" in main.threat_label.text, "battle should warn major wave changes sixty seconds ahead")
	_expect(main.threat_label.get_minimum_size().x <= main.size.x, "combined long and near forecasts should fit the default viewport")
	_expect(main.battle_board.wave_status_text() == "前線形成", "battlefield should identify the current wave phase")
	_expect("戦場容量 青0/48  赤0/48" in main.battle_board.capacity_status_text(), "battlefield should disclose per-side unit capacity")
	_expect(not main.speed_button.disabled, "battle should enable speed controls")
	_expect("時間を停止" in main.pause_button.tooltip_text, "main action tooltip should explain time stop during battle")
	_expect(main.pause_button.action_kind == "pause" and main.pause_button.text == "時間停止", "battle should use a compact pause action")
	var speed_key := InputEventKey.new()
	speed_key.keycode = KEY_F
	speed_key.pressed = true
	main._unhandled_key_input(speed_key)
	_expect(main.current_battle_speed() == 2.0, "speed button should switch battle to double speed")
	main.elapsed_since_tick = 0.0
	var tick_before_speed_test: int = main.battle_board.simulation.tick_index
	main._process(0.2)
	_expect(main.battle_board.simulation.tick_index == tick_before_speed_test + 2, "double speed should advance two simulation ticks per normal interval")
	main.speed_button.pressed.emit()
	_expect(main.current_battle_speed() == 4.0, "speed button should switch battle to quadruple speed")
	main.speed_button.pressed.emit()
	_expect(main.current_battle_speed() == 1.0, "speed button should cycle back to normal speed")
	var action_key := InputEventKey.new()
	action_key.keycode = KEY_SPACE
	action_key.pressed = true
	var preserved_recipe = main.factory_board.simulation.recipes[0]
	main.factory_board.simulation.recipes[0] = null
	main._unhandled_key_input(action_key)
	_expect(main.flow.phase == RunFlow.Phase.BATTLE, "failed factory duplication should keep battle phase active")
	_expect(not main.factory_board.editing and not main.factory_board.interaction_enabled, "failed factory duplication should not expose the committed factory to direct editing")
	main._process(0.0)
	_expect("工場状態を複製できません" in main.threat_label.text, "failed time stop should keep its explanation visible across status refreshes")
	main.factory_board.simulation.recipes[0] = preserved_recipe
	main._unhandled_key_input(action_key)
	_expect(main.flow.phase == RunFlow.Phase.FACTORY_RECONFIGURE, "Space should open time-stop reconfiguration")
	_expect(main.action_error_hold_ticks == 0 and main.action_error_message == "", "successful retry should clear the stale time-stop failure")
	_expect(main.factory_board.production_comparison_active, "successful time stop should expose a pre-commit production comparison")
	_expect(main.factory_board.production_difference_state(&"scout")["state"] == &"unchanged", "time stop should begin from the committed production baseline")
	_expect(main.factory_board.visible and not main.battle_board.visible, "time stop should return to the full-width factory tab")
	_expect(main.factory_board.interaction_enabled, "time stop should enable node placement")
	_expect(main.factory_state.state == &"paused", "time stop should use a pause badge while work-in-progress stays in the factory visual summary")
	_expect("戦闘を再開" in main.pause_button.tooltip_text, "main action tooltip should explain edit confirmation")
	_expect(main.pause_button.action_kind == "resume" and main.pause_button.text == "確定・再開", "reconfiguration should pair confirmation with a visual resume action")
	_expect(main.cancel_button.action_kind == "cancel" and main.cancel_button.text == "破棄", "reconfiguration should keep discard visually distinct and terse")
	_expect(main.speed_button.disabled, "time stop should disable speed controls")
	main.get_node("Toolbar/SentinelButton").pressed.emit()
	_expect(main.sigil_ghost.recipe_id == &"azure_guard", "sentinel selection should update the completed sigil ghost")
	_expect(main.factory_board.production_difference_state(&"scout")["state"] == &"decrease", "sentinel preview should show scout loss before confirmation")
	_expect(main.factory_board.production_difference_state(&"sentinel")["state"] == &"increase", "sentinel preview should show sentinel gain before confirmation")
	main.get_node("FactoryPalette/UndoButton").pressed.emit()
	_expect(main.factory_board.pending_plan_id == MvpContent.PLAN_SCOUT, "undo should restore the plan before a preset preview")
	_expect(main.factory_board.production_difference_state(&"scout")["state"] == &"unchanged", "preset undo should return the production comparison to baseline")
	_expect(main.sigil_ghost.recipe_id == &"open_ring" and main.get_node("Toolbar/ScoutButton").button_pressed, "preset undo should restore goal Glyph and plan highlight")
	main.get_node("Toolbar/SentinelButton").pressed.emit()
	main._unhandled_key_input(action_key)
	_expect(main.flow.phase == RunFlow.Phase.BATTLE, "Space should confirm edits and resume battle")
	_expect(not main.factory_board.production_comparison_active, "commit should clear the pre-commit comparison session")
	_expect("変更効果" in main.plan_label.text, "battle resume should explain the production effect of reconfiguration")
	_expect("斥候" in main.plan_label.text and "衛兵" in main.plan_label.text, "production effect should name changed unit outputs")
	_expect("変更追跡 0/15秒" in main.plan_label.text, "battle resume should begin a bounded impact observation window")
	main.battle_board.simulation.tick_index += 75
	main.battle_board.simulation.player_kills += 3
	main.battle_board.simulation.enemy_kills += 1
	main.battle_board.simulation.enemy_shield_health -= 120.0
	main._refresh_status()
	_expect("変更後15秒" in main.plan_label.text, "impact observation should become a fixed result after fifteen seconds")
	_expect("敵撃破 +3" in main.plan_label.text, "impact result should report enemies defeated after the change")
	_expect("味方損失 +1" in main.plan_label.text, "impact result should report allied losses after the change")
	_expect("目標ダメージ 120" in main.plan_label.text, "impact result should report objective damage after the change")
	main.pause_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.FACTORY_RECONFIGURE, "second time stop should open another transactional preview")
	_expect(main.factory_board.production_comparison_active, "each time stop should capture a fresh production baseline")
	main.get_node("Toolbar/GolemButton").pressed.emit()
	_expect(main.sigil_ghost.recipe_id == &"bound_colossus" and main.get_node("Toolbar/GolemButton").button_pressed, "preview should move goal visuals to the proposed plan")
	_expect(main.factory_board.production_difference_state(&"sentinel")["state"] == &"decrease" and main.factory_board.production_difference_state(&"golem")["state"] == &"increase", "second comparison should use the newly committed sentinel factory as its baseline")
	main.cancel_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.BATTLE and main.factory_board.plan_id == MvpContent.PLAN_SENTINEL, "discard should resume with the committed factory plan")
	_expect(not main.factory_board.production_comparison_active, "discard should clear the production comparison session")
	_expect(main.sigil_ghost.recipe_id == &"azure_guard", "discard should restore the committed goal Glyph")
	_expect(main.get_node("Toolbar/SentinelButton").button_pressed and not main.get_node("Toolbar/GolemButton").button_pressed, "discard should restore the committed plan highlight")

	main.debug_victory_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.VICTORY, "placeholder completion should defeat the leader")
	_expect("生産: 斥候" in main.phase_body.text, "victory screen should summarize factory production")
	_expect("時間停止 2回" in main.phase_body.text, "victory screen should summarize committed and discarded time stops")
	main.phase_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.REWARD, "victory OK should open rewards")
	_expect(main.reward_option.visible and main.reward_option.item_count == 3, "reward phase should offer three run upgrades")
	main.phase_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.ROUTE_SELECTION, "reward OK should return to route selection")
	_expect(main.flow.route_number == 2, "UI should display the next route")
	_expect(main.acquired_rewards.size() == 1, "selected reward should persist into the next route")
	_expect("迅速な環" in main.phase_body.text, "next route should display acquired run rewards")
	var upgraded_source: FactoryNodeModel = main.factory_board.simulation.nodes[&"ring_source"]
	_expect(upgraded_source.config["interval_ticks"] < 18, "selected reward should modify the next route factory")

	main.phase_button.pressed.emit()
	main.phase_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.FACTORY_BUILD, "next route should reach factory build again")
	main.get_node("Toolbar/ScoutButton").pressed.emit()
	main.pause_button.pressed.emit()
	main.produced_units = {&"scout": 30, &"sentinel": 0, &"golem": 0}
	main.battle_board.simulation.tick_index = main.battle_board.simulation.battle_duration_ticks - 1
	main.battle_board.advance_tick()
	_expect("DEFEAT" in main.status_label.text, "time limit should display defeat analysis")
	_expect("再構成0回" in main.plan_label.text, "defeat analysis should identify a missed reconfiguration decision")
	_expect("群体兵で衛兵、装甲兵で巨像" in main.plan_label.text, "defeat analysis should recommend concrete counter production")
	main.factory_change_count = 1
	main.produced_units = {&"scout": 0, &"sentinel": 0, &"golem": 0}
	main.factory_board.simulation.discarded_glyphs = 3
	_expect("改善: 配線" in main._defeat_advice(), "zero successful summons with discards should identify wiring or matching")
	main.produced_units = {&"scout": 20, &"sentinel": 0, &"golem": 5}
	main.factory_board.simulation.discarded_glyphs = 0
	_expect("衛兵0" in main._defeat_advice(), "missing swarm counter should be identified explicitly")
	main.produced_units = {&"scout": 20, &"sentinel": 5, &"golem": 0}
	_expect("巨像0" in main._defeat_advice(), "missing armor counter should be identified explicitly")
	_expect(main.debug_victory_button.text == "再挑戦", "defeat should turn the temporary action into retry")
	main.debug_victory_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.FACTORY_BUILD, "retry should return to factory build")

	main.queue_free()
	if failures == 0:
		print("Run flow UI test passed.")
	else:
		push_error("%d run flow UI test(s) failed." % failures)
	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
