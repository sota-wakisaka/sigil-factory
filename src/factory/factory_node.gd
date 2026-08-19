class_name FactoryNodeModel
extends RefCounted

enum NodeKind {
	SOURCE,
	ROTATOR,
	TRANSLATOR,
	COLORIZER,
	COMBINER,
	SUMMONER,
}

var id: StringName
var kind: NodeKind
var config: Dictionary

var input_buffers: Array = []
var output_buffer: GlyphModel
var processing_glyph: GlyphModel
var remaining_processing_ticks := 0
var source_timer := 0


func _init(
	initial_id: StringName,
	initial_kind: NodeKind,
	initial_config: Dictionary = {}
) -> void:
	id = initial_id
	kind = initial_kind
	config = initial_config.duplicate(true)
	for _index in required_input_count():
		input_buffers.append(null)


func required_input_count() -> int:
	if kind == NodeKind.SOURCE:
		return 0
	if kind == NodeKind.COMBINER:
		return 2
	return 1


func can_accept(port: int) -> bool:
	return port >= 0 and port < input_buffers.size() and input_buffers[port] == null


func accept(port: int, glyph: GlyphModel) -> bool:
	if not can_accept(port):
		return false
	input_buffers[port] = glyph
	return true


func has_all_inputs() -> bool:
	if input_buffers.is_empty():
		return false
	for glyph in input_buffers:
		if glyph == null:
			return false
	return true


func copy_state() -> FactoryNodeModel:
	var result := FactoryNodeModel.new(id, kind, config)
	for port in mini(input_buffers.size(), result.input_buffers.size()):
		if input_buffers[port] != null:
			result.input_buffers[port] = input_buffers[port].copy()
	if output_buffer != null:
		result.output_buffer = output_buffer.copy()
	if processing_glyph != null:
		result.processing_glyph = processing_glyph.copy()
	result.remaining_processing_ticks = remaining_processing_ticks
	result.source_timer = source_timer
	return result
