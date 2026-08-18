class_name BattleUnitModel
extends RefCounted

var instance_id: int
var spec: UnitSpecModel
var side: int
var position: float
var health: float
var attack_cooldown := 0
var age_ticks := 0


func _init(
	initial_instance_id: int,
	initial_spec: UnitSpecModel,
	initial_side: int,
	initial_position: float
) -> void:
	instance_id = initial_instance_id
	spec = initial_spec
	side = initial_side
	position = initial_position
	health = spec.max_health


func is_alive() -> bool:
	return health > 0.0
