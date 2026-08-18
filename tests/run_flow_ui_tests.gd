extends SceneTree

const RunFlow := preload("res://src/game/run_flow.gd")

var failures := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main.tscn")
	var main := scene.instantiate()
	root.add_child(main)
	await process_frame

	_expect(main.flow.phase == RunFlow.Phase.ROUTE_SELECTION, "UI should open at route selection")
	_expect(main.phase_overlay.visible, "placeholder phases should use the overlay")

	main.phase_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.STAGE_INFO, "route OK should show stage information")
	_expect("制限時間 3:00" in main.phase_body.text, "stage information should disclose the battle duration")
	main.phase_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.FACTORY_BUILD, "stage OK should open factory build")
	_expect(not main.phase_overlay.visible, "factory build should expose the workspace")
	_expect(main.factory_board.interaction_enabled, "factory build should enable node placement")
	_expect(not main.get_node("FactoryPalette/RingButton").disabled, "factory build should enable the equipment palette")
	var node_count_before_palette: int = main.factory_board.simulation.nodes.size()
	main.get_node("FactoryPalette/RingButton").pressed.emit()
	_expect(main.factory_board.simulation.nodes.size() == node_count_before_palette + 1, "palette should add factory equipment")
	main.get_node("FactoryPalette/DeleteButton").pressed.emit()
	_expect(main.factory_board.simulation.nodes.size() == node_count_before_palette, "delete button should remove selected equipment")

	main.pause_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.BATTLE, "build confirmation should start battle")
	_expect(not main.factory_board.interaction_enabled, "running battle should lock node placement")
	_expect(main.get_node("FactoryPalette/RingButton").disabled, "running battle should lock the equipment palette")
	_expect("敵防壁HP" in main.status_label.text, "battle status should identify the active enemy shield")
	_expect("残り 03:00" in main.status_label.text, "battle status should show the remaining time")
	_expect(not main.speed_button.disabled, "battle should enable speed controls")
	main.speed_button.pressed.emit()
	_expect(main.current_battle_speed() == 2.0, "speed button should switch battle to double speed")
	main.elapsed_since_tick = 0.0
	var tick_before_speed_test: int = main.battle_board.simulation.tick_index
	main._process(0.2)
	_expect(main.battle_board.simulation.tick_index == tick_before_speed_test + 2, "double speed should advance two simulation ticks per normal interval")
	main.speed_button.pressed.emit()
	_expect(main.current_battle_speed() == 4.0, "speed button should switch battle to quadruple speed")
	main.speed_button.pressed.emit()
	_expect(main.current_battle_speed() == 1.0, "speed button should cycle back to normal speed")
	main.pause_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.FACTORY_RECONFIGURE, "time stop should open reconfiguration")
	_expect(main.factory_board.interaction_enabled, "time stop should enable node placement")
	_expect(main.speed_button.disabled, "time stop should disable speed controls")
	main.pause_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.BATTLE, "edit confirmation should resume battle")

	main.debug_victory_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.VICTORY, "placeholder completion should defeat the leader")
	main.phase_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.REWARD, "victory OK should open rewards")
	main.phase_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.ROUTE_SELECTION, "reward OK should return to route selection")
	_expect(main.flow.route_number == 2, "UI should display the next route")

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
