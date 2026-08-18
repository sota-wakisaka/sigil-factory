class_name UnitSpecModel
extends RefCounted

var id: StringName
var max_health: float
var attack_damage: float
var attack_interval_ticks: int
var move_speed: float
var attack_range: float


func _init(
	initial_id: StringName,
	initial_max_health: float,
	initial_attack_damage: float,
	initial_attack_interval_ticks: int,
	initial_move_speed: float,
	initial_attack_range: float
) -> void:
	id = initial_id
	max_health = initial_max_health
	attack_damage = initial_attack_damage
	attack_interval_ticks = maxi(initial_attack_interval_ticks, 1)
	move_speed = initial_move_speed
	attack_range = initial_attack_range

