extends SceneTree

const RunFlow := preload("res://src/game/run_flow.gd")
const MvpContent := preload("res://src/game/mvp_content.gd")

var failures := 0


func _initialize() -> void:
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
	_expect(main.factory_board.plan_id == MvpContent.PLAN_EMPTY, "first factory build should start from the guided empty workshop")
	_expect(main.sigil_ghost.recipe_id == &"open_ring", "empty workshop should show the first scout sigil goal")
	_expect(main.factory_board.mana_status_text() == "魔力 40/100 // 空き60", "factory build should disclose fixed mana capacity")
	_expect("戦闘を開始" in main.pause_button.tooltip_text, "main action tooltip should explain build confirmation")
	_expect("構築ガイド" in main.plan_label.text, "empty workshop should explain its first connection")
	_expect(main.factory_board.is_guided_connection_pending(), "empty workshop should highlight its first connection")
	var guided_result: Dictionary = main.factory_board.connect_nodes_interactive(&"ring_source", &"summoner", 0)
	_expect(guided_result["ok"], "guided factory connection should succeed")
	_expect("構築完了" in main.plan_label.text, "first connection should replace the guide with completion feedback")
	_expect(main.factory_board.disconnect_input(&"summoner", 0), "guided connection should be removable")
	_expect("構築ガイド" in main.plan_label.text, "removing the first connection should restore its guidance")
	main.factory_board.connect_nodes_interactive(&"ring_source", &"summoner", 0)
	main.get_node("Toolbar/ScoutButton").pressed.emit()
	_expect(main.factory_board.interaction_enabled, "factory build should enable node placement")
	_expect(not main.get_node("FactoryPalette/RingButton").disabled, "factory build should enable the equipment palette")
	_expect("斥候" in main.factory_board.cached_production_preview, "factory build should preview expected production")
	var node_count_before_palette: int = main.factory_board.simulation.nodes.size()
	main.get_node("FactoryPalette/RingButton").pressed.emit()
	_expect(main.factory_board.simulation.nodes.size() == node_count_before_palette + 1, "palette should add factory equipment")
	_expect("配線未完成" in main.factory_board.cached_production_preview, "dangling equipment should invalidate production preview")
	_expect(not main.inspector_option.disabled, "selected configurable equipment should enable its inspector")
	main.inspector_option.item_selected.emit(1)
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
	main._unhandled_key_input(action_key)
	_expect(main.flow.phase == RunFlow.Phase.FACTORY_RECONFIGURE, "Space should open time-stop reconfiguration")
	_expect(main.factory_board.interaction_enabled, "time stop should enable node placement")
	_expect("戦闘を再開" in main.pause_button.tooltip_text, "main action tooltip should explain edit confirmation")
	_expect(main.speed_button.disabled, "time stop should disable speed controls")
	main.get_node("Toolbar/SentinelButton").pressed.emit()
	_expect(main.sigil_ghost.recipe_id == &"azure_guard", "sentinel selection should update the completed sigil ghost")
	main._unhandled_key_input(action_key)
	_expect(main.flow.phase == RunFlow.Phase.BATTLE, "Space should confirm edits and resume battle")
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

	main.debug_victory_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.VICTORY, "placeholder completion should defeat the leader")
	_expect("生産: 斥候" in main.phase_body.text, "victory screen should summarize factory production")
	_expect("時間停止 1回" in main.phase_body.text, "victory screen should summarize time stops")
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
