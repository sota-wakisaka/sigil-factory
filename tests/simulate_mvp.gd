extends SceneTree

const MvpContent := preload("res://src/game/mvp_content.gd")
const FactoryBoardControl := preload("res://src/ui/factory_board.gd")


func _initialize() -> void:
	var adaptive := _run_strategy("mixed_adaptive", [
		{"tick": 0, "plan": MvpContent.PLAN_SCOUT},
		{"tick": 250, "plan": MvpContent.PLAN_VIGIL},
		{"tick": 530, "plan": MvpContent.PLAN_FORTRESS},
	], MvpContent.ROUTE_MIXED)
	var swarm_adaptive := _run_strategy("swarm_adaptive", [
		{"tick": 0, "plan": MvpContent.PLAN_SCOUT},
		{"tick": 235, "plan": MvpContent.PLAN_VIGIL},
		{"tick": 690, "plan": MvpContent.PLAN_FORTRESS},
	], MvpContent.ROUTE_SWARM)
	var armored_adaptive := _run_strategy("armored_adaptive", [
		{"tick": 0, "plan": MvpContent.PLAN_SCOUT},
		{"tick": 235, "plan": MvpContent.PLAN_VIGIL},
		{"tick": 430, "plan": MvpContent.PLAN_FORTRESS},
	], MvpContent.ROUTE_ARMORED)
	var star_adaptive := _run_strategy("star_adaptive", [
		{"tick": 0, "plan": MvpContent.PLAN_SCOUT},
		{"tick": 250, "plan": MvpContent.PLAN_STELLAR},
		{"tick": 530, "plan": MvpContent.PLAN_FORTRESS},
	], MvpContent.ROUTE_MIXED)
	var scout_only := _run_strategy("scout_only", [
		{"tick": 0, "plan": MvpContent.PLAN_SCOUT},
	], MvpContent.ROUTE_MIXED)
	var golem_only := _run_strategy("golem_only", [
		{"tick": 0, "plan": MvpContent.PLAN_FORTRESS},
	], MvpContent.ROUTE_MIXED)
	var route_two_rewarded := _run_strategy("route_2_rewarded", [
		{"tick": 0, "plan": MvpContent.PLAN_SCOUT},
		{"tick": 250, "plan": MvpContent.PLAN_VIGIL},
		{"tick": 530, "plan": MvpContent.PLAN_FORTRESS},
	], MvpContent.ROUTE_MIXED, 2, [&"ring_speed"])
	var route_three_baseline := _run_strategy("route_3_baseline", [
		{"tick": 0, "plan": MvpContent.PLAN_SCOUT},
		{"tick": 235, "plan": MvpContent.PLAN_VIGIL},
		{"tick": 430, "plan": MvpContent.PLAN_FORTRESS},
	], MvpContent.ROUTE_ARMORED, 3)
	var route_three_rewarded := _run_strategy("route_3_rewarded", [
		{"tick": 0, "plan": MvpContent.PLAN_SCOUT},
		{"tick": 235, "plan": MvpContent.PLAN_VIGIL},
		{"tick": 430, "plan": MvpContent.PLAN_FORTRESS},
	], MvpContent.ROUTE_ARMORED, 3, [&"ring_speed", &"processing_speed"])
	var passed: bool = (
		adaptive["winner"] == BattleSimulation.Side.PLAYER
		and swarm_adaptive["winner"] == BattleSimulation.Side.PLAYER
		and armored_adaptive["winner"] == BattleSimulation.Side.PLAYER
		and star_adaptive["winner"] == BattleSimulation.Side.PLAYER
		and scout_only["winner"] != BattleSimulation.Side.PLAYER
		and golem_only["winner"] != BattleSimulation.Side.PLAYER
		and route_two_rewarded["winner"] == BattleSimulation.Side.PLAYER
		and route_three_rewarded["winner"] == BattleSimulation.Side.PLAYER
		and (
			route_three_baseline["winner"] != BattleSimulation.Side.PLAYER
			or route_three_rewarded["ticks"] < route_three_baseline["ticks"]
		)
	)
	if passed:
		print("MVP strategy validation passed.")
	else:
		push_error("MVP strategy validation failed.")
	quit(0 if passed else 1)


func _run_strategy(
	label: String,
	changes: Array[Dictionary],
	route_id: StringName,
	route_number: int = 1,
	upgrades: Array[StringName] = []
) -> Dictionary:
	var battle := MvpContent.build_battle(route_id, route_number)
	var factory_board: FactoryBoardControl
	var factory: FactorySimulation
	var event_index := 0
	var change_index := 0
	for tick in 900:
		if change_index < changes.size() and tick == changes[change_index]["tick"]:
			if factory_board != null:
				factory_board.free()
			factory_board = FactoryBoardControl.new()
			factory_board.set_run_upgrades(upgrades)
			factory_board.configure(changes[change_index]["plan"])
			factory = factory_board.simulation
			event_index = 0
			change_index += 1
		factory.tick()
		while event_index < factory.summon_events.size():
			var summon_event: Dictionary = factory.summon_events[event_index]
			var recipe_id := StringName(summon_event.get("recipe_id", ""))
			battle.spawn_player_from_recipe(
				summon_event["unit_id"],
				recipe_id,
				MvpContent.recipe_combat_modifiers(recipe_id)
			)
			event_index += 1
		battle.tick()
		if battle.is_finished():
			break
	if factory_board != null:
		factory_board.free()
	print(
		"%s route=%d upgrades=%d ticks=%d winner=%d player_hp=%.0f enemy_hp=%.0f kills=%d/%d units=%d"
		% [
			label,
			route_number,
			upgrades.size(),
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
