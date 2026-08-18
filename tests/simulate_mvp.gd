extends SceneTree

const MvpContent := preload("res://src/game/mvp_content.gd")


func _initialize() -> void:
	var adaptive := _run_strategy("adaptive", [
		{"tick": 0, "plan": MvpContent.PLAN_SCOUT},
		{"tick": 250, "plan": MvpContent.PLAN_SENTINEL},
		{"tick": 530, "plan": MvpContent.PLAN_GOLEM},
	])
	var scout_only := _run_strategy("scout_only", [
		{"tick": 0, "plan": MvpContent.PLAN_SCOUT},
	])
	var golem_only := _run_strategy("golem_only", [
		{"tick": 0, "plan": MvpContent.PLAN_GOLEM},
	])
	var passed: bool = (
		adaptive["winner"] == BattleSimulation.Side.PLAYER
		and scout_only["winner"] != BattleSimulation.Side.PLAYER
		and golem_only["winner"] != BattleSimulation.Side.PLAYER
	)
	if passed:
		print("MVP strategy validation passed.")
	else:
		push_error("MVP strategy validation failed.")
	quit(0 if passed else 1)


func _run_strategy(label: String, changes: Array[Dictionary]) -> Dictionary:
	var battle := MvpContent.build_battle()
	var factory: FactorySimulation
	var event_index := 0
	var change_index := 0
	for tick in 900:
		if change_index < changes.size() and tick == changes[change_index]["tick"]:
			factory = MvpContent.build_factory(changes[change_index]["plan"])
			event_index = 0
			change_index += 1
		factory.tick()
		while event_index < factory.summon_events.size():
			battle.spawn_player(factory.summon_events[event_index]["unit_id"])
			event_index += 1
		battle.tick()
		if battle.is_finished():
			break
	print(
		"%s ticks=%d winner=%d player_hp=%.0f enemy_hp=%.0f kills=%d/%d units=%d"
		% [
			label,
			battle.tick_index,
			battle.winner(),
			battle.player_leader_health,
			battle.enemy_leader_health,
			battle.player_kills,
			battle.enemy_kills,
			battle.units.size(),
		]
	)
	return {
		"winner": battle.winner(),
		"ticks": battle.tick_index,
		"player_health": battle.player_leader_health,
		"enemy_health": battle.enemy_leader_health,
	}
