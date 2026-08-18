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
	main.phase_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.FACTORY_BUILD, "stage OK should open factory build")
	_expect(not main.phase_overlay.visible, "factory build should expose the workspace")

	main.pause_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.BATTLE, "build confirmation should start battle")
	main.pause_button.pressed.emit()
	_expect(main.flow.phase == RunFlow.Phase.FACTORY_RECONFIGURE, "time stop should open reconfiguration")
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
