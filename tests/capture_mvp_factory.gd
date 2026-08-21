extends SceneTree

const MvpContent := preload("res://src/game/mvp_content.gd")


func _initialize() -> void:
	var output := "C:/Users/sotaw/AppData/Local/Temp/sigil-factory-mvp.png"
	var plan_id := MvpContent.PLAN_VIGIL
	var capture_phase := "factory"
	var upgrades: Array[StringName] = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--plan="):
			plan_id = StringName(argument.trim_prefix("--plan="))
		elif argument.begins_with("--upgrades="):
			for upgrade_id in argument.trim_prefix("--upgrades=").split(",", false):
				upgrades.append(StringName(upgrade_id))
		elif argument.begins_with("--phase="):
			capture_phase = argument.trim_prefix("--phase=")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1536, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: PackedScene = load("res://src/main.tscn")
	var main := scene.instantiate()
	viewport.add_child(main)
	await process_frame
	main.acquired_rewards = upgrades
	if capture_phase == "route":
		main._apply_phase()
	elif capture_phase == "stage":
		main.phase_button.pressed.emit()
	elif capture_phase in ["battle", "defeat", "victory", "reward"]:
		main.phase_button.pressed.emit()
		main.phase_button.pressed.emit()
		main._select_plan(plan_id)
		main.pause_button.pressed.emit()
		if capture_phase == "defeat":
			main.produced_units = {&"scout": 30, &"sentinel": 0, &"golem": 0}
			main.produced_recipes = {&"watchful_eye": 30}
			main.battle_board.simulation.player_damage_by_recipe = {&"watchful_eye": 321.0}
			main.battle_board.simulation.tick_index = main.battle_board.simulation.battle_duration_ticks - 1
			main.battle_board.advance_tick()
		elif capture_phase == "battle":
			main.battle_board.spawn_player(&"scout", &"watchful_eye")
			main.battle_board.spawn_player(&"sentinel", &"vigil_cross")
			main.battle_board.spawn_player(&"sentinel", &"stellar_sentinel")
			main.battle_board.spawn_player(&"golem", &"fortress_compass")
			for index in main.battle_board.simulation.units.size():
				main.battle_board.simulation.units[index].position = 90.0 + float(index) * 75.0
		if capture_phase == "victory":
			main.produced_units = {&"scout": 3, &"sentinel": 4, &"golem": 0}
			main.produced_recipes = {&"watchful_eye": 3, &"stellar_sentinel": 4}
			main.battle_board.simulation.player_damage_by_recipe = {
				&"watchful_eye": 123.0,
				&"stellar_sentinel": 456.0,
			}
		if capture_phase in ["victory", "reward"]:
			main.debug_victory_button.pressed.emit()
		if capture_phase == "reward":
			main.phase_button.pressed.emit()
	elif capture_phase == "factory":
		main.phase_button.pressed.emit()
		main.phase_button.pressed.emit()
		main._select_plan(plan_id)
	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	var error := image.save_png(output)
	if error == OK:
		print("MVP factory capture: %s" % output)
	else:
		printerr("MVP factory capture failed: %s" % error)
	quit(0 if error == OK else 1)
