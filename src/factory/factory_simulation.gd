class_name FactorySimulation
extends RefCounted

const FactoryNodeModel := preload("res://src/factory/factory_node.gd")
const SigilMatcher := preload("res://src/domain/sigil_matcher.gd")

var nodes: Dictionary = {}
var lines: Dictionary = {}
var recipes: Array[SigilRecipeModel] = []
var summon_events: Array[Dictionary] = []
var summon_failure_events: Array[Dictionary] = []
var blocked_line_ids: Array[StringName] = []
var blocked_output_node_ids: Array[StringName] = []
var last_runtime_glyph_errors: Array[String] = []
var discarded_glyphs := 0
var tick_index := 0


func add_node(node: FactoryNodeModel) -> bool:
	if not node_registration_result(node)["ok"]:
		return false
	var stored_node := node.copy_state()
	nodes[stored_node.id] = stored_node
	return true


func node_registration_result(node: FactoryNodeModel) -> Dictionary:
	var errors: Array[String] = []
	if node == null:
		return {"ok": false, "errors": ["missing_node"]}
	if node.id == &"":
		errors.append("missing_node_id")
	if nodes.has(node.id):
		errors.append("duplicate_node_id")
	for port in node.input_buffers.size():
		_append_runtime_glyph_errors(errors, node.input_buffers[port], "input[%d]" % port)
	_append_runtime_glyph_errors(errors, node.processing_glyph, "processing")
	_append_runtime_glyph_errors(errors, node.output_buffer, "output")
	return {"ok": errors.is_empty(), "errors": errors}


func add_recipe(recipe: SigilRecipeModel) -> bool:
	if not recipe_registration_result(recipe)["ok"]:
		return false
	recipes.append(recipe.copy())
	recipes.sort_custom(
		func(first: SigilRecipeModel, second: SigilRecipeModel) -> bool:
			return String(first.id) < String(second.id)
	)
	return true


func recipe_registration_result(recipe: SigilRecipeModel) -> Dictionary:
	var errors := PackedStringArray()
	if recipe.id == &"":
		errors.append("missing_recipe_id")
	if recipe.unit_id == &"":
		errors.append("missing_unit_id")
	var structure_errors := recipe.glyph.structure_validation_errors()
	for structure_error in structure_errors:
		errors.append("glyph:%s" % structure_error)
	if not structure_errors.is_empty():
		return {"ok": false, "errors": errors}
	var candidate_serialization := recipe.glyph.canonical_serialization()
	for existing in recipes:
		if existing.id == recipe.id and not errors.has("duplicate_recipe_id"):
			errors.append("duplicate_recipe_id")
		if (
			existing.glyph.canonical_serialization() == candidate_serialization
			and not errors.has("duplicate_glyph_structure")
		):
			errors.append("duplicate_glyph_structure")
	return {"ok": errors.is_empty(), "errors": errors}


func connect_nodes(line: FactoryLineModel) -> Dictionary:
	if line == null:
		return _connection_error("missing_line")
	if line.id == &"":
		return _connection_error("missing_line_id")
	var payload_errors: Array[String] = []
	_append_runtime_glyph_errors(payload_errors, line.payload, "payload")
	if not payload_errors.is_empty():
		return _connection_error("invalid_payload", payload_errors)
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

	var stored_line := line.copy()
	lines[stored_line.id] = stored_line
	if _has_cycle():
		lines.erase(stored_line.id)
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
	for node_key in _sorted_keys(nodes):
		var configured_node: FactoryNodeModel = nodes[node_key]
		errors.append_array(_node_configuration_errors(node_key, configured_node))
	errors.append_array(work_in_progress_validation_errors())
	var structurally_valid_line_ids: Dictionary = {}
	var input_line_counts: Dictionary = {}
	var output_line_counts: Dictionary = {}
	for line_id in _sorted_keys(lines):
		var line: FactoryLineModel = lines[line_id]
		var line_is_valid := true
		if line.id == &"":
			errors.append("missing_line_id:%s" % line_id)
			line_is_valid = false
		elif line.id != line_id:
			errors.append("line_key_mismatch:%s:%s" % [line_id, line.id])
			line_is_valid = false
		if not nodes.has(line.from_node_id):
			errors.append("missing_from_node:%s" % line_id)
			line_is_valid = false
		if not nodes.has(line.to_node_id):
			errors.append("missing_to_node:%s" % line_id)
			line_is_valid = false
		if not line_is_valid:
			continue
		var target: FactoryNodeModel = nodes[line.to_node_id]
		if line.to_port < 0 or line.to_port >= target.required_input_count():
			errors.append("invalid_port:%s" % line_id)
			continue
		structurally_valid_line_ids[line_id] = true
		var input_key := _input_key(line.to_node_id, line.to_port)
		input_line_counts[input_key] = int(input_line_counts.get(input_key, 0)) + 1
		output_line_counts[line.from_node_id] = int(output_line_counts.get(line.from_node_id, 0)) + 1
	for input_key in _sorted_keys(input_line_counts):
		if int(input_line_counts[input_key]) > 1:
			errors.append("occupied_input:%s" % input_key)
	for node_id in _sorted_keys(output_line_counts):
		if int(output_line_counts[node_id]) > 1:
			errors.append("occupied_output:%s" % node_id)
	if _has_cycle():
		errors.append("cycle")
	var has_source := false
	var summoner_count := 0
	for node_id in _sorted_keys(nodes):
		var node: FactoryNodeModel = nodes[node_id]
		has_source = has_source or node.kind == FactoryNodeModel.NodeKind.SOURCE
		summoner_count += int(node.kind == FactoryNodeModel.NodeKind.SUMMONER)
		for port in node.required_input_count():
			var has_input := false
			for line_id in _sorted_keys(structurally_valid_line_ids):
				var line: FactoryLineModel = lines[line_id]
				if line.to_node_id == node.id and line.to_port == port:
					has_input = true
					break
			if not has_input:
				errors.append("missing_input:%s:%d" % [node.id, port])
		if node.kind != FactoryNodeModel.NodeKind.SUMMONER:
			var has_output := false
			for line_id in _sorted_keys(structurally_valid_line_ids):
				var line: FactoryLineModel = lines[line_id]
				if line.from_node_id == node.id:
					has_output = true
					break
			if not has_output:
				errors.append("missing_output:%s" % node.id)
	if not has_source:
		errors.append("missing_source")
	if summoner_count == 0:
		errors.append("missing_summoner")
	elif summoner_count > 1:
		errors.append("multiple_summoners")
	return {"ok": errors.is_empty(), "errors": errors}


func work_in_progress_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	for node_id in _sorted_keys(nodes):
		var node: FactoryNodeModel = nodes[node_id]
		for port in node.input_buffers.size():
			_append_runtime_glyph_errors(
				errors,
				node.input_buffers[port],
				"node[%s].input[%d]" % [node_id, port]
			)
		_append_runtime_glyph_errors(errors, node.processing_glyph, "node[%s].processing" % node_id)
		_append_runtime_glyph_errors(errors, node.output_buffer, "node[%s].output" % node_id)
	for line_id in _sorted_keys(lines):
		var line: FactoryLineModel = lines[line_id]
		_append_runtime_glyph_errors(errors, line.payload, "line[%s].payload" % line_id)
	return errors


func _append_runtime_glyph_errors(errors: Array[String], glyph_value, location: String) -> void:
	if glyph_value == null:
		return
	if not glyph_value is GlyphModel:
		errors.append("invalid_glyph:%s:not_glyph" % location)
		return
	var glyph: GlyphModel = glyph_value
	for structure_error in glyph.structure_validation_errors():
		errors.append("invalid_glyph:%s:%s" % [location, structure_error])


func _node_configuration_errors(node_key: StringName, node: FactoryNodeModel) -> Array[String]:
	var errors: Array[String] = []
	if node.id == &"":
		errors.append("missing_node_id:%s" % node_key)
	elif node.id != node_key:
		errors.append("node_key_mismatch:%s:%s" % [node_key, node.id])
	if node.kind < FactoryNodeModel.NodeKind.SOURCE or node.kind > FactoryNodeModel.NodeKind.SUMMONER:
		errors.append("invalid_node_kind:%s" % node_key)
		return errors
	if node.kind == FactoryNodeModel.NodeKind.SOURCE:
		if StringName(node.config.get("primitive_id", "")) == &"":
			errors.append("missing_source_primitive:%s" % node_key)
		if int(node.config.get("interval_ticks", 0)) < 1:
			errors.append("invalid_source_interval:%s" % node_key)
		return errors
	if node.kind == FactoryNodeModel.NodeKind.SUMMONER:
		return errors
	if int(node.config.get("processing_ticks", 0)) < 1:
		errors.append("invalid_processing_ticks:%s" % node_key)
	match node.kind:
		FactoryNodeModel.NodeKind.ROTATOR:
			var steps := int(node.config.get("steps", 0))
			if steps < 1 or steps > 3:
				errors.append("invalid_rotation_steps:%s" % node_key)
		FactoryNodeModel.NodeKind.TRANSLATOR:
			if typeof(node.config.get("offset", null)) != TYPE_VECTOR2I:
				errors.append("invalid_translation_offset:%s" % node_key)
		FactoryNodeModel.NodeKind.COLORIZER:
			if StringName(node.config.get("color_id", "")) == &"":
				errors.append("missing_color_id:%s" % node_key)
	return errors


func flow_diagnostics() -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	for line_id in _sorted_keys(lines):
		if line_flow_state(line_id) == &"buffer_full":
			var line: FactoryLineModel = lines[line_id]
			diagnostics.append({
				"code": &"buffer_full",
				"line_id": line_id,
				"node_id": line.to_node_id,
			})
	for node_id in _sorted_keys(nodes):
		var state := node_flow_state(node_id)
		if state != &"running":
			diagnostics.append({"code": state, "node_id": node_id})
	return diagnostics


func line_flow_state(line_id: StringName) -> StringName:
	if not lines.has(line_id):
		return &"missing"
	var line: FactoryLineModel = lines[line_id]
	if line.payload == null:
		return &"empty"
	if blocked_line_ids.has(line_id):
		return &"buffer_full"
	if line.remaining_ticks > 0:
		return &"transporting"
	var target: FactoryNodeModel = nodes.get(line.to_node_id)
	if target != null and not target.can_accept(line.to_port):
		return &"buffer_full"
	return &"arrived"


func node_flow_state(node_id: StringName) -> StringName:
	if not nodes.has(node_id):
		return &"missing"
	var node: FactoryNodeModel = nodes[node_id]
	if node.output_buffer != null:
		if blocked_output_node_ids.has(node_id):
			return &"output_blocked"
		var outgoing := _outgoing_line_ids(node_id)
		var can_dispatch := false
		for line_id in outgoing:
			if lines[line_id].payload == null:
				can_dispatch = true
				break
		if not can_dispatch:
			return &"output_blocked"
	if node.kind == FactoryNodeModel.NodeKind.COMBINER:
		var filled_inputs := 0
		for glyph in node.input_buffers:
			filled_inputs += int(glyph != null)
		if filled_inputs > 0 and filled_inputs < node.required_input_count():
			return &"material_shortage"
	return &"running"


func duplicate_state_result() -> Dictionary:
	var errors := work_in_progress_validation_errors()
	errors.append_array(_recipe_state_validation_errors())
	if not errors.is_empty():
		return {"ok": false, "state": null, "errors": errors}
	return {"ok": true, "state": _duplicate_state_unchecked(), "errors": []}


func duplicate_state() -> FactorySimulation:
	var result := duplicate_state_result()
	if not result["ok"]:
		push_error("Cannot duplicate invalid factory state: %s" % ", ".join(result["errors"]))
		return null
	return result["state"]


func _recipe_state_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var validator := FactorySimulation.new()
	for recipe_index in recipes.size():
		var recipe: SigilRecipeModel = recipes[recipe_index]
		if recipe == null:
			errors.append("invalid_recipe:recipe[%d]=<null>:missing_recipe" % recipe_index)
			continue
		var registration := validator.recipe_registration_result(recipe)
		if not registration["ok"]:
			var recipe_label := String(recipe.id) if recipe.id != &"" else "<empty>"
			for registration_error in registration["errors"]:
				errors.append(
					"invalid_recipe:recipe[%d]=%s:%s"
					% [recipe_index, recipe_label, registration_error]
				)
			continue
		validator.add_recipe(recipe)
	return errors


func _duplicate_state_unchecked() -> FactorySimulation:
	var result := FactorySimulation.new()
	for recipe in recipes:
		result.add_recipe(recipe)
	for node_id in nodes:
		var node: FactoryNodeModel = nodes[node_id]
		var copied_node := node.copy_state()
		result.nodes[copied_node.id] = copied_node
	for line_id in lines:
		var line: FactoryLineModel = lines[line_id]
		var copied_line := line.copy()
		result.lines[copied_line.id] = copied_line
	result.summon_events = summon_events.duplicate(true)
	result.summon_failure_events = summon_failure_events.duplicate(true)
	result.blocked_line_ids = blocked_line_ids.duplicate()
	result.blocked_output_node_ids = blocked_output_node_ids.duplicate()
	result.last_runtime_glyph_errors = last_runtime_glyph_errors.duplicate()
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
	blocked_line_ids.clear()
	blocked_output_node_ids.clear()
	last_runtime_glyph_errors.clear()
	return discarded_now


func discard_invalid_work_in_progress() -> int:
	var discarded_now := 0
	for node_id in _sorted_keys(nodes):
		var node: FactoryNodeModel = nodes[node_id]
		for port in node.input_buffers.size():
			if not _runtime_glyph_is_valid(node.input_buffers[port]):
				node.input_buffers[port] = null
				discarded_now += 1
		if node.processing_glyph != null and not _runtime_glyph_is_valid(node.processing_glyph):
			node.processing_glyph = null
			node.remaining_processing_ticks = 0
			discarded_now += 1
		if node.output_buffer != null and not _runtime_glyph_is_valid(node.output_buffer):
			node.output_buffer = null
			discarded_now += 1
	for line_id in _sorted_keys(lines):
		var line: FactoryLineModel = lines[line_id]
		if line.payload != null and not _runtime_glyph_is_valid(line.payload):
			line.payload = null
			line.remaining_ticks = 0
			discarded_now += 1
	discarded_glyphs += discarded_now
	last_runtime_glyph_errors = work_in_progress_validation_errors()
	return discarded_now


func _runtime_glyph_is_valid(glyph_value) -> bool:
	return (
		glyph_value == null
		or (
			glyph_value is GlyphModel
			and (glyph_value as GlyphModel).structure_validation_errors().is_empty()
		)
	)


func tick() -> void:
	last_runtime_glyph_errors = work_in_progress_validation_errors()
	if not last_runtime_glyph_errors.is_empty():
		return
	tick_index += 1
	var input_acceptance := _snapshot_input_acceptance()
	var line_availability := _snapshot_line_availability()
	blocked_line_ids.clear()
	blocked_output_node_ids.clear()
	_advance_nodes()
	_advance_lines(input_acceptance)
	_dispatch_outputs(line_availability)


func _snapshot_input_acceptance() -> Dictionary:
	var snapshot := {}
	for node_id in _sorted_keys(nodes):
		var node: FactoryNodeModel = nodes[node_id]
		for port in node.required_input_count():
			snapshot[_input_key(node_id, port)] = node.can_accept(port)
	return snapshot


func _snapshot_line_availability() -> Dictionary:
	var snapshot := {}
	for line_id in _sorted_keys(lines):
		snapshot[line_id] = lines[line_id].payload == null
	return snapshot


func _input_key(node_id: StringName, port: int) -> String:
	return "%s:%d" % [node_id, port]


func _advance_lines(input_acceptance: Dictionary) -> void:
	for line_id in _sorted_keys(lines):
		var line: FactoryLineModel = lines[line_id]
		if line.payload == null:
			continue
		if line.remaining_ticks > 0:
			line.remaining_ticks -= 1
		if line.remaining_ticks > 0:
			continue
		var target: FactoryNodeModel = nodes[line.to_node_id]
		var accepted_at_tick_start := bool(
			input_acceptance.get(_input_key(line.to_node_id, line.to_port), false)
		)
		if accepted_at_tick_start and target.accept(line.to_port, line.payload):
			line.payload = null
		else:
			blocked_line_ids.append(line_id)


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
	var closest_rank := 2147483647
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
		var rank := _summon_failure_rank(diagnostics)
		if (
			rank < closest_rank
			or (
				rank == closest_rank
				and (closest_recipe_id == &"" or String(recipe.id) < String(closest_recipe_id))
			)
		):
			closest_rank = rank
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


func _summon_failure_rank(diagnostics: PackedStringArray) -> int:
	var structural_differences := 0
	var attribute_differences := 0
	for diagnostic in diagnostics:
		if (
			diagnostic.begins_with("部品不足:")
			or diagnostic.begins_with("余分な部品:")
			or diagnostic == "合成階層が違います"
		):
			structural_differences += 1
		else:
			attribute_differences += 1
	return structural_differences * 100 + attribute_differences


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


func _dispatch_outputs(line_availability: Dictionary) -> void:
	for node_id in _sorted_keys(nodes):
		var node: FactoryNodeModel = nodes[node_id]
		if node.output_buffer == null:
			continue
		var dispatched := false
		for line_id in _outgoing_line_ids(node.id):
			if not bool(line_availability.get(line_id, false)):
				continue
			var line: FactoryLineModel = lines[line_id]
			if line.send(node.output_buffer):
				node.output_buffer = null
				dispatched = true
				break
		if not dispatched:
			blocked_output_node_ids.append(node_id)


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


func _connection_error(code: String, errors: Array[String] = []) -> Dictionary:
	return {"ok": false, "error": code, "errors": errors.duplicate()}
