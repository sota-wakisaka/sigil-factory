class_name FactoryLineModel
extends RefCounted

var id: StringName
var from_node_id: StringName
var to_node_id: StringName
var to_port: int
var travel_ticks: int

var payload: GlyphModel
var remaining_ticks := 0


func _init(
	initial_id: StringName,
	initial_from_node_id: StringName,
	initial_to_node_id: StringName,
	initial_to_port: int = 0,
	initial_travel_ticks: int = 1
) -> void:
	id = initial_id
	from_node_id = initial_from_node_id
	to_node_id = initial_to_node_id
	to_port = initial_to_port
	travel_ticks = maxi(initial_travel_ticks, 1)


func is_empty() -> bool:
	return payload == null


func send(glyph: GlyphModel) -> bool:
	if not is_empty():
		return false
	payload = glyph.copy()
	remaining_ticks = travel_ticks
	return true

