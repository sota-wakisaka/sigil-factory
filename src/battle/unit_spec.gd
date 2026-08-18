class_name UnitSpecModel
extends RefCounted

var id: StringName
var max_health: float
var attack_damage: float
var attack_interval_ticks: int
var move_speed: float
var attack_range: float
var armor: float
var target_count: int
var preferred_target_id: StringName
var preferred_multiplier: float
var max_lifetime_ticks: int


func _init(
	initial_id: StringName,
	initial_max_health: float,
	initial_attack_damage: float,
	initial_attack_interval_ticks: int,
	initial_move_speed: float,
	initial_attack_range: float,
	initial_armor: float = 0.0,
	initial_target_count: int = 1,
	initial_preferred_target_id: StringName = &"",
	initial_preferred_multiplier: float = 1.0,
	initial_max_lifetime_ticks: int = 900
) -> void:
	id = initial_id
	max_health = initial_max_health
	attack_damage = initial_attack_damage
	attack_interval_ticks = maxi(initial_attack_interval_ticks, 1)
	move_speed = initial_move_speed
	attack_range = initial_attack_range
	armor = maxf(initial_armor, 0.0)
	target_count = maxi(initial_target_count, 1)
	preferred_target_id = initial_preferred_target_id
	preferred_multiplier = maxf(initial_preferred_multiplier, 1.0)
	max_lifetime_ticks = maxi(initial_max_lifetime_ticks, 1)


func damage_against(target: UnitSpecModel) -> float:
	var multiplier := 1.0
	if preferred_target_id != &"" and target.id == preferred_target_id:
		multiplier = preferred_multiplier
	return maxf(attack_damage * multiplier - target.armor, 1.0)
