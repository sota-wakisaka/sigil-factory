class_name BattleSimulation
extends RefCounted

enum Side {
	PLAYER,
	ENEMY,
}

const PLAYER_SPAWN := 100.0
const ENEMY_SPAWN := 900.0
const PLAYER_LEADER_POSITION := 30.0
const ENEMY_LEADER_POSITION := 970.0
const ENEMY_SHIELD_POSITION := 760.0
const ENEMY_SHIELD_MAX_HEALTH := 40000.0
const PLAYER_LEADER_MAX_HEALTH := 1200.0
const ENEMY_LEADER_MAX_HEALTH := 5000.0

var specs: Dictionary = {}
var units: Array[BattleUnitModel] = []
var schedule: Array[ThreatEventModel] = []
var tick_index := 0
var player_leader_health := PLAYER_LEADER_MAX_HEALTH
var enemy_leader_health := ENEMY_LEADER_MAX_HEALTH
var enemy_shield_health := ENEMY_SHIELD_MAX_HEALTH
var next_instance_id := 1
var next_schedule_index := 0
var enemy_leader_vulnerable_tick := 2700
var player_kills := 0
var enemy_kills := 0
var battle_events: Array[Dictionary] = []


func add_spec(spec: UnitSpecModel) -> void:
	specs[spec.id] = spec


func set_schedule(events: Array[ThreatEventModel]) -> void:
	schedule.clear()
	for event in events:
		schedule.append(event)
	schedule.sort_custom(func(a: ThreatEventModel, b: ThreatEventModel) -> bool: return a.tick < b.tick)
	next_schedule_index = 0


func spawn_player(unit_id: StringName) -> bool:
	return _spawn_unit(unit_id, Side.PLAYER, PLAYER_SPAWN)


func spawn_enemy(unit_id: StringName) -> bool:
	return _spawn_unit(unit_id, Side.ENEMY, ENEMY_SPAWN)


func tick() -> void:
	if is_finished():
		return
	tick_index += 1
	_spawn_scheduled_enemies()
	_update_units()


func upcoming_threats(horizon_ticks: int) -> Array[ThreatEventModel]:
	var result: Array[ThreatEventModel] = []
	var last_tick := tick_index + maxi(horizon_ticks, 0)
	for index in range(next_schedule_index, schedule.size()):
		var event := schedule[index]
		if event.tick > last_tick:
			break
		result.append(event)
	return result


func is_finished() -> bool:
	return player_leader_health <= 0.0 or enemy_leader_health <= 0.0


func winner() -> int:
	if enemy_leader_health <= 0.0:
		return Side.PLAYER
	if player_leader_health <= 0.0:
		return Side.ENEMY
	return -1


func is_enemy_shield_active() -> bool:
	return enemy_shield_health > 0.0 and tick_index < enemy_leader_vulnerable_tick


func _spawn_unit(unit_id: StringName, side: int, position: float) -> bool:
	if not specs.has(unit_id):
		return false
	var unit := BattleUnitModel.new(next_instance_id, specs[unit_id], side, position)
	next_instance_id += 1
	units.append(unit)
	battle_events.append({
		"type": "spawn",
		"tick": tick_index,
		"unit_id": unit_id,
		"side": side,
		"instance_id": unit.instance_id,
	})
	return true


func _spawn_scheduled_enemies() -> void:
	while next_schedule_index < schedule.size():
		var event := schedule[next_schedule_index]
		if event.tick > tick_index:
			break
		for _count in event.count:
			spawn_enemy(event.unit_id)
		next_schedule_index += 1


func _update_units() -> void:
	var damage_by_instance: Dictionary = {}
	var player_leader_damage := 0.0
	var enemy_leader_damage := 0.0
	var enemy_shield_damage := 0.0
	var ordered_units := units.duplicate()
	ordered_units.sort_custom(
		func(a: BattleUnitModel, b: BattleUnitModel) -> bool:
			return a.instance_id < b.instance_id
	)

	for unit in ordered_units:
		if not unit.is_alive():
			continue
		unit.age_ticks += 1
		if unit.age_ticks >= unit.spec.max_lifetime_ticks:
			unit.health = 0.0
			continue
		unit.attack_cooldown = maxi(unit.attack_cooldown - 1, 0)
		var targets_in_range := _enemies_in_range(unit)
		if not targets_in_range.is_empty():
			if unit.attack_cooldown == 0:
				for target_index in mini(targets_in_range.size(), unit.spec.target_count):
					var target: BattleUnitModel = targets_in_range[target_index]
					damage_by_instance[target.instance_id] = (
						float(damage_by_instance.get(target.instance_id, 0.0))
						+ unit.spec.damage_against(target.spec)
					)
				unit.attack_cooldown = unit.spec.attack_interval_ticks
		elif _closest_enemy(unit) != null:
			_move_toward_enemy(unit)
		elif unit.side == Side.PLAYER and is_enemy_shield_active():
			if absf(ENEMY_SHIELD_POSITION - unit.position) <= unit.spec.attack_range:
				if unit.attack_cooldown == 0:
					enemy_shield_damage += unit.spec.attack_damage
					unit.attack_cooldown = unit.spec.attack_interval_ticks
			else:
				_move_toward_enemy(unit)
		else:
			var leader_position := (
				ENEMY_LEADER_POSITION if unit.side == Side.PLAYER else PLAYER_LEADER_POSITION
			)
			if absf(leader_position - unit.position) <= unit.spec.attack_range:
				if unit.attack_cooldown == 0:
					if unit.side == Side.PLAYER:
						enemy_leader_damage += unit.spec.attack_damage
					else:
						player_leader_damage += unit.spec.attack_damage
					unit.attack_cooldown = unit.spec.attack_interval_ticks
			else:
				_move_toward_enemy(unit)

	_apply_damage(damage_by_instance)
	var shield_was_active := is_enemy_shield_active()
	enemy_shield_health = maxf(enemy_shield_health - enemy_shield_damage, 0.0)
	if shield_was_active and not is_enemy_shield_active():
		battle_events.append({"type": "shield_destroyed", "tick": tick_index})
	player_leader_health = maxf(player_leader_health - player_leader_damage, 0.0)
	enemy_leader_health = maxf(enemy_leader_health - enemy_leader_damage, 0.0)


func _closest_enemy(unit: BattleUnitModel) -> BattleUnitModel:
	var closest: BattleUnitModel
	var closest_distance := INF
	for candidate in units:
		if not candidate.is_alive() or candidate.side == unit.side:
			continue
		var distance := absf(candidate.position - unit.position)
		if distance < closest_distance:
			closest = candidate
			closest_distance = distance
		elif is_equal_approx(distance, closest_distance) and candidate.instance_id < closest.instance_id:
			closest = candidate
	return closest


func _enemies_in_range(unit: BattleUnitModel) -> Array[BattleUnitModel]:
	var result: Array[BattleUnitModel] = []
	for candidate in units:
		if not candidate.is_alive() or candidate.side == unit.side:
			continue
		if absf(candidate.position - unit.position) <= unit.spec.attack_range:
			result.append(candidate)
	result.sort_custom(
		func(a: BattleUnitModel, b: BattleUnitModel) -> bool:
			var a_distance := absf(a.position - unit.position)
			var b_distance := absf(b.position - unit.position)
			if not is_equal_approx(a_distance, b_distance):
				return a_distance < b_distance
			return a.instance_id < b.instance_id
	)
	return result


func _move_toward_enemy(unit: BattleUnitModel) -> void:
	var direction := 1.0 if unit.side == Side.PLAYER else -1.0
	var maximum_position := ENEMY_LEADER_POSITION
	if unit.side == Side.PLAYER and is_enemy_shield_active():
		maximum_position = ENEMY_SHIELD_POSITION
	unit.position = clampf(
		unit.position + direction * unit.spec.move_speed,
		PLAYER_LEADER_POSITION,
		maximum_position
	)


func _apply_damage(damage_by_instance: Dictionary) -> void:
	for unit in units:
		if damage_by_instance.has(unit.instance_id):
			unit.health -= float(damage_by_instance[unit.instance_id])

	var survivors: Array[BattleUnitModel] = []
	for unit in units:
		if unit.is_alive():
			survivors.append(unit)
			continue
		if unit.side == Side.ENEMY:
			player_kills += 1
		else:
			enemy_kills += 1
		battle_events.append({
			"type": "death",
			"tick": tick_index,
			"unit_id": unit.spec.id,
			"side": unit.side,
			"instance_id": unit.instance_id,
		})
	units = survivors
