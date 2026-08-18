class_name ThreatEventModel
extends RefCounted

var tick: int
var unit_id: StringName
var count: int
var label: String
var lane: StringName


func _init(
	initial_tick: int,
	initial_unit_id: StringName,
	initial_count: int,
	initial_label: String,
	initial_lane: StringName = &"center"
) -> void:
	tick = initial_tick
	unit_id = initial_unit_id
	count = maxi(initial_count, 1)
	label = initial_label
	lane = initial_lane

