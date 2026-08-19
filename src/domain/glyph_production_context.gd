class_name GlyphProductionContextModel
extends RefCounted

var processing_count := 0
var visited_node_kinds: Array[StringName] = []
var source_ids: Array[StringName] = []


func _init(
	initial_processing_count: int = 0,
	initial_visited_node_kinds: Array[StringName] = [],
	initial_source_ids: Array[StringName] = []
) -> void:
	processing_count = maxi(initial_processing_count, 0)
	for node_kind in initial_visited_node_kinds:
		_add_unique(visited_node_kinds, node_kind)
	for source_id in initial_source_ids:
		_add_unique(source_ids, source_id)
	visited_node_kinds.sort()
	source_ids.sort()


func copy() -> GlyphProductionContextModel:
	return GlyphProductionContextModel.new(
		processing_count,
		visited_node_kinds,
		source_ids
	)


func record_node(node_kind: StringName, counts_as_processing: bool) -> void:
	_add_unique(visited_node_kinds, node_kind)
	visited_node_kinds.sort()
	if counts_as_processing:
		processing_count += 1


func record_source(source_id: StringName) -> void:
	_add_unique(source_ids, source_id)
	source_ids.sort()


func has_visited(node_kind: StringName) -> bool:
	return visited_node_kinds.has(node_kind)


func to_dictionary() -> Dictionary:
	return {
		"processing_count": processing_count,
		"visited_node_kinds": visited_node_kinds.duplicate(),
		"source_ids": source_ids.duplicate(),
	}


static func merge(contexts: Array) -> GlyphProductionContextModel:
	var result := GlyphProductionContextModel.new()
	for context in contexts:
		if context == null:
			continue
		result.processing_count += context.processing_count
		for node_kind in context.visited_node_kinds:
			result._add_unique(result.visited_node_kinds, node_kind)
		for source_id in context.source_ids:
			result._add_unique(result.source_ids, source_id)
	result.visited_node_kinds.sort()
	result.source_ids.sort()
	return result


func _add_unique(values: Array[StringName], value: StringName) -> void:
	if not values.has(value):
		values.append(value)
