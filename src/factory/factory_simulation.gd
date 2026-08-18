class_name FactorySimulation
extends RefCounted

const FactoryNodeModel := preload("res://src/factory/factory_node.gd")
const SigilMatcher := preload("res://src/domain/sigil_matcher.gd")

var nodes: Dictionary = {}
var lines: Dictionary = {}
var recipes: Array[SigilRecipeModel] = []
var summon_events: Array[Dictionary] = []
var discarded_glyphs := 0
var tick_index := 0


func add_node(node: FactoryNodeModel) -> bool:
	if nodes.has(node.id):
		return false
	nodes[node.id] = node
	return true


func add_recipe(recipe: SigilRecipeModel) -> void:
	recipes.append(recipe)


func connect_nodes(line: FactoryLineModel) -> Dictionary:
	if lines.has(line.id):
		return _connection_error("duplicate_line")
	if not nodes.has(line.from_node_id) or not nodes.has(line.to_node_id):
		return _connection_error("missing_node")

	var target: FactoryNodeModel = nodes[line.to_node_id]
	if line.to_port < 0 or line.to_port >= target.required_input_count():
		return _connection_error("invalid_port")
	for existing_line in lines.values():
		if (
			existing_line.to_node_id == line.to_node_id
			and existing_line.to_port == line.to_port
		):
			return _connection_error("occupied_port")

	lines[line.id] = line
	if _has_cycle():
		lines.erase(line.id)
		return _connection_error("cycle")
	return {"ok": true, "error": ""}


func disconnect_line(line_id: StringName) -> bool:
	if not lines.has(line_id):
		return false
	lines.erase(line_id)
	return true


func duplicate_state() -> FactorySimulation:
	var result := FactorySimulation.new()
	for recipe in recipes:
		result.add_recipe(recipe)
	for node_id in nodes:
		var node: FactoryNodeModel = nodes[node_id]
		var copied_node := FactoryNodeModel.new(node.id, node.kind, node.config)
		for port in node.input_buffers.size():
			if node.input_buffers[port] != null:
				copied_node.input_buffers[port] = node.input_buffers[port].copy()
		if node.output_buffer != null:
			copied_node.output_buffer = node.output_buffer.copy()
		if node.processing_glyph != null:
			copied_node.processing_glyph = node.processing_glyph.copy()
		copied_node.remaining_processing_ticks = node.remaining_processing_ticks
		copied_node.source_timer = node.source_timer
		result.add_node(copied_node)
	for line_id in lines:
		var line: FactoryLineModel = lines[line_id]
		var copied_line := FactoryLineModel.new(
			line.id, line.from_node_id, line.to_node_id, line.to_port, line.travel_ticks
		)
		if line.payload != null:
			copied_line.payload = line.payload.copy()
		copied_line.remaining_ticks = line.remaining_ticks
		result.lines[copied_line.id] = copied_line
	result.summon_events = summon_events.duplicate(true)
	result.discarded_glyphs = discarded_glyphs
	result.tick_index = tick_index
	return result


func tick() -> void:
	tick_index += 1
	_advance_lines()
	_advance_nodes()
	_dispatch_outputs()


func _advance_lines() -> void:
	for line_id in _sorted_keys(lines):
		var line: FactoryLineModel = lines[line_id]
		if line.payload == null:
			continue
		if line.remaining_ticks > 0:
			line.remaining_ticks -= 1
		if line.remaining_ticks > 0:
			continue
		var target: FactoryNodeModel = nodes[line.to_node_id]
		if target.accept(line.to_port, line.payload):
			line.payload = null


func _advance_nodes() -> void:
	for node_id in _sorted_keys(nodes):
		var node: FactoryNodeModel = nodes[node_id]
		match node.kind:
			FactoryNodeModel.NodeKind.SOURCE:
				_tick_source(node)
			FactoryNodeModel.NodeKind.SUMMONER:
				_tick_summoner(node)
			_:
				_tick_processor(node)


func _tick_source(node: FactoryNodeModel) -> void:
	node.source_timer += 1
	var interval := maxi(int(node.config.get("interval_ticks", 1)), 1)
	if node.source_timer < interval or node.output_buffer != null:
		return
	node.source_timer = 0
	var component := GlyphComponentModel.new(
		StringName(node.config.get("primitive_id", "ring")),
		Vector2i.ZERO,
		0,
		1,
		StringName(node.config.get("color_id", "white"))
	)
	node.output_buffer = GlyphModel.new([component])


func _tick_processor(node: FactoryNodeModel) -> void:
	if node.processing_glyph == null and node.output_buffer == null and node.has_all_inputs():
		node.processing_glyph = _consume_inputs(node)
		node.remaining_processing_ticks = maxi(
			int(node.config.get("processing_ticks", 1)),
			1
		)

	if node.processing_glyph == null:
		return
	node.remaining_processing_ticks -= 1
	if node.remaining_processing_ticks > 0:
		return
	node.output_buffer = _apply_node_operation(node, node.processing_glyph)
	node.processing_glyph = null


func _tick_summoner(node: FactoryNodeModel) -> void:
	if not node.has_all_inputs():
		return
	var glyph: GlyphModel = node.input_buffers[0]
	node.input_buffers[0] = null
	for recipe in recipes:
		var result := SigilMatcher.compare(glyph, recipe.glyph)
		if result["is_match"]:
			summon_events.append({
				"tick": tick_index,
				"recipe_id": recipe.id,
				"unit_id": recipe.unit_id,
				"summoner_id": node.id,
			})
			return
	discarded_glyphs += 1


func _consume_inputs(node: FactoryNodeModel) -> GlyphModel:
	if node.kind == FactoryNodeModel.NodeKind.COMBINER:
		var combined := GlyphModel.new()
		for glyph in node.input_buffers:
			for component in glyph.components:
				combined.components.append(component.copy())
		for index in node.input_buffers.size():
			node.input_buffers[index] = null
		return combined

	var glyph: GlyphModel = node.input_buffers[0]
	node.input_buffers[0] = null
	return glyph.copy()


func _apply_node_operation(node: FactoryNodeModel, glyph: GlyphModel) -> GlyphModel:
	var result := glyph.copy()
	match node.kind:
		FactoryNodeModel.NodeKind.ROTATOR:
			var steps := int(node.config.get("steps", 1))
			for component in result.components:
				component.rotation_step = posmod(component.rotation_step + steps, 4)
		FactoryNodeModel.NodeKind.TRANSLATOR:
			var offset: Vector2i = node.config.get("offset", Vector2i.ZERO)
			for component in result.components:
				component.position += offset
		FactoryNodeModel.NodeKind.COLORIZER:
			var color_id := StringName(node.config.get("color_id", "white"))
			for component in result.components:
				component.color_id = color_id
	return result


func _dispatch_outputs() -> void:
	for node_id in _sorted_keys(nodes):
		var node: FactoryNodeModel = nodes[node_id]
		if node.output_buffer == null:
			continue
		for line_id in _outgoing_line_ids(node.id):
			var line: FactoryLineModel = lines[line_id]
			if line.send(node.output_buffer):
				node.output_buffer = null
				break


func _outgoing_line_ids(node_id: StringName) -> Array:
	var result: Array = []
	for line_id in lines:
		if lines[line_id].from_node_id == node_id:
			result.append(line_id)
	result.sort()
	return result


func _has_cycle() -> bool:
	var visited: Dictionary = {}
	var active: Dictionary = {}
	for node_id in nodes:
		if _visit_for_cycle(node_id, visited, active):
			return true
	return false


func _visit_for_cycle(
	node_id: StringName,
	visited: Dictionary,
	active: Dictionary
) -> bool:
	if active.has(node_id):
		return true
	if visited.has(node_id):
		return false
	visited[node_id] = true
	active[node_id] = true
	for line_id in _outgoing_line_ids(node_id):
		if _visit_for_cycle(lines[line_id].to_node_id, visited, active):
			return true
	active.erase(node_id)
	return false


func _sorted_keys(values: Dictionary) -> Array:
	var keys := values.keys()
	keys.sort()
	return keys


func _connection_error(code: String) -> Dictionary:
	return {"ok": false, "error": code}
