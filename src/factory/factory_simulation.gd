class_name FactorySimulation
extends RefCounted

const FactoryNodeModel := preload("res://src/factory/factory_node.gd")
const SigilMatcher := preload("res://src/domain/sigil_matcher.gd")

var nodes: Dictionary = {}
var lines: Dictionary = {}
var recipes: Array[SigilRecipeModel] = []
var summon_events: Array[Dictionary] = []
var summon_failure_events: Array[Dictionary] = []
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
		if existing_line.from_node_id == line.from_node_id:
			return _connection_error("occupied_output")

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


func remove_node(node_id: StringName) -> bool:
	if not nodes.has(node_id):
		return false
	var connected_line_ids: Array[StringName] = []
	for line_id in lines:
		var line: FactoryLineModel = lines[line_id]
		if line.from_node_id == node_id or line.to_node_id == node_id:
			connected_line_ids.append(line_id)
	for line_id in connected_line_ids:
		lines.erase(line_id)
	nodes.erase(node_id)
	return true


func validate_graph() -> Dictionary:
	var errors: Array[String] = []
	var has_source := false
	var has_summoner := false
	for node in nodes.values():
		has_source = has_source or node.kind == FactoryNodeModel.NodeKind.SOURCE
		has_summoner = has_summoner or node.kind == FactoryNodeModel.NodeKind.SUMMONER
		for port in node.required_input_count():
			var has_input := false
			for line in lines.values():
				if line.to_node_id == node.id and line.to_port == port:
					has_input = true
					break
			if not has_input:
				errors.append("missing_input:%s:%d" % [node.id, port])
		if node.kind != FactoryNodeModel.NodeKind.SUMMONER:
			var has_output := false
			for line in lines.values():
				if line.from_node_id == node.id:
					has_output = true
					break
			if not has_output:
				errors.append("missing_output:%s" % node.id)
	if not has_source:
		errors.append("missing_source")
	if not has_summoner:
		errors.append("missing_summoner")
	return {"ok": errors.is_empty(), "errors": errors}


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
	result.summon_failure_events = summon_failure_events.duplicate(true)
	result.discarded_glyphs = discarded_glyphs
	result.tick_index = tick_index
	return result


func discard_all_work_in_progress() -> int:
	var discarded_now := 0
	for node in nodes.values():
		for port in node.input_buffers.size():
			if node.input_buffers[port] != null:
				discarded_now += 1
				node.input_buffers[port] = null
		if node.output_buffer != null:
			discarded_now += 1
			node.output_buffer = null
		if node.processing_glyph != null:
			discarded_now += 1
			node.processing_glyph = null
		node.remaining_processing_ticks = 0
	for line in lines.values():
		if line.payload != null:
			discarded_now += 1
			line.payload = null
		line.remaining_ticks = 0
	discarded_glyphs += discarded_now
	return discarded_now


func tick() -> void:
	tick_index += 1
	_advance_nodes()
	_advance_lines()
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
	var glyph := GlyphModel.new([component])
	glyph.production_context.record_node(&"source", false)
	glyph.production_context.record_source(node.id)
	node.output_buffer = glyph


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
	glyph.production_context.record_node(&"summoner", false)
	var closest_recipe_id: StringName = &""
	var closest_diagnostics := PackedStringArray()
	var closest_score := 2147483647
	for recipe in recipes:
		var result := SigilMatcher.compare(glyph, recipe.glyph)
		if result["is_match"]:
			summon_events.append({
				"tick": tick_index,
				"recipe_id": recipe.id,
				"unit_id": recipe.unit_id,
				"summoner_id": node.id,
				"production_context": glyph.production_context.to_dictionary(),
			})
			return
		var diagnostics: PackedStringArray = result["diagnostics"]
		if diagnostics.size() < closest_score:
			closest_score = diagnostics.size()
			closest_recipe_id = recipe.id
			closest_diagnostics = diagnostics.duplicate()
	discarded_glyphs += 1
	if recipes.is_empty():
		closest_diagnostics = PackedStringArray(["獲得済みシジルがありません"])
	summon_failure_events.append({
		"tick": tick_index,
		"summoner_id": node.id,
		"glyph_hash": glyph.canonical_hash(),
		"closest_recipe_id": closest_recipe_id,
		"diagnostics": closest_diagnostics,
	})


func _consume_inputs(node: FactoryNodeModel) -> GlyphModel:
	if node.kind == FactoryNodeModel.NodeKind.COMBINER:
		var combined := GlyphModel.combine(node.input_buffers[0], node.input_buffers[1])
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
			result.rotate(steps)
		FactoryNodeModel.NodeKind.TRANSLATOR:
			var offset: Vector2i = node.config.get("offset", Vector2i.ZERO)
			result.translate(offset)
		FactoryNodeModel.NodeKind.COLORIZER:
			var color_id := StringName(node.config.get("color_id", "white"))
			result.recolor(color_id)
	result.production_context.record_node(_node_kind_id(node.kind), true)
	return result


func _node_kind_id(kind: FactoryNodeModel.NodeKind) -> StringName:
	match kind:
		FactoryNodeModel.NodeKind.SOURCE:
			return &"source"
		FactoryNodeModel.NodeKind.ROTATOR:
			return &"rotator"
		FactoryNodeModel.NodeKind.TRANSLATOR:
			return &"translator"
		FactoryNodeModel.NodeKind.COLORIZER:
			return &"colorizer"
		FactoryNodeModel.NodeKind.COMBINER:
			return &"combiner"
		FactoryNodeModel.NodeKind.SUMMONER:
			return &"summoner"
	return &"unknown"


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
