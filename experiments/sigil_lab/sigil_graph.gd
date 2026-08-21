class_name SigilGraph
extends RefCounted

const GlyphModel := preload("res://src/domain/glyph.gd")
const GlyphComponentModel := preload("res://src/domain/glyph_component.gd")

const SOURCE := &"source"
const ROTATE := &"rotate"
const MOVE := &"move"
const SCALE := &"scale"
const REPEAT := &"repeat"
const COLOR := &"color"
const COMBINE := &"combine"
const OUTPUT := &"output"

const NODE_KINDS := [SOURCE, ROTATE, MOVE, SCALE, REPEAT, COLOR, COMBINE, OUTPUT]
const PRIMITIVES := [&"circle", &"triangle", &"square"]
const COLORS := [&"white", &"blue", &"red"]
const REPEAT_COUNTS := [2, 3, 4, 5, 6, 8]
const MAX_COMBINE_INPUTS := GlyphModel.MAX_COMBINE_CHILDREN

var nodes: Dictionary = {}
var connections: Array[Dictionary] = []
var last_error: StringName = &""


func add_node(node_id: StringName, kind: StringName, config: Dictionary = {}) -> bool:
	last_error = &""
	if node_id == &"" or nodes.has(node_id):
		last_error = &"duplicate_node"
		return false
	if not kind in NODE_KINDS:
		last_error = &"invalid_kind"
		return false
	if kind == OUTPUT and output_node_id() != &"":
		last_error = &"output_exists"
		return false
	var normalized := _normalized_config(kind, config)
	if not bool(normalized["ok"]):
		last_error = normalized["error"]
		return false
	nodes[node_id] = {
		"kind": kind,
		"config": normalized["config"],
	}
	return true


func remove_node(node_id: StringName) -> bool:
	last_error = &""
	if not nodes.has(node_id):
		last_error = &"missing_node"
		return false
	nodes.erase(node_id)
	var retained: Array[Dictionary] = []
	for connection in connections:
		if connection["from"] != node_id and connection["to"] != node_id:
			retained.append(connection)
	connections = retained
	return true


func set_node_config(node_id: StringName, config: Dictionary) -> bool:
	last_error = &""
	if not nodes.has(node_id):
		last_error = &"missing_node"
		return false
	var kind: StringName = nodes[node_id]["kind"]
	var normalized := _normalized_config(kind, config)
	if not bool(normalized["ok"]):
		last_error = normalized["error"]
		return false
	var entry: Dictionary = nodes[node_id]
	entry["config"] = normalized["config"]
	nodes[node_id] = entry
	return true


func node_kind(node_id: StringName) -> StringName:
	if not nodes.has(node_id):
		return &""
	return nodes[node_id]["kind"]


func node_config(node_id: StringName) -> Dictionary:
	if not nodes.has(node_id):
		return {}
	return nodes[node_id]["config"].duplicate(true)


func output_node_id() -> StringName:
	var ids: Array = nodes.keys()
	ids.sort_custom(func(a, b) -> bool: return String(a) < String(b))
	for node_id in ids:
		if nodes[node_id]["kind"] == OUTPUT:
			return node_id
	return &""


func connection_result(
	from_node_id: StringName,
	from_port: int,
	to_node_id: StringName,
	to_port: int
) -> Dictionary:
	if not nodes.has(from_node_id) or not nodes.has(to_node_id):
		return _connection_error(&"missing_node")
	if from_node_id == to_node_id:
		return _connection_error(&"cycle")
	if from_port != 0 or to_port < 0 or to_port >= input_count(to_node_id):
		return _connection_error(&"invalid_port")
	if node_kind(from_node_id) == OUTPUT or node_kind(to_node_id) == SOURCE:
		return _connection_error(&"invalid_direction")
	for connection in connections:
		if connection["to"] == to_node_id and int(connection["to_port"]) == to_port:
			return _connection_error(&"input_occupied")
	if _would_create_cycle(from_node_id, to_node_id):
		return _connection_error(&"cycle")
	return {"ok": true, "error": &""}


func connect_nodes(
	from_node_id: StringName,
	from_port: int,
	to_node_id: StringName,
	to_port: int
) -> bool:
	last_error = &""
	var result := connection_result(from_node_id, from_port, to_node_id, to_port)
	if not bool(result["ok"]):
		last_error = result["error"]
		return false
	connections.append({
		"from": from_node_id,
		"from_port": from_port,
		"to": to_node_id,
		"to_port": to_port,
	})
	connections.sort_custom(_connection_less)
	return true


func disconnect_nodes(
	from_node_id: StringName,
	from_port: int,
	to_node_id: StringName,
	to_port: int
) -> bool:
	last_error = &""
	for index in connections.size():
		var connection := connections[index]
		if (
			connection["from"] == from_node_id
			and int(connection["from_port"]) == from_port
			and connection["to"] == to_node_id
			and int(connection["to_port"]) == to_port
		):
			connections.remove_at(index)
			return true
	last_error = &"missing_connection"
	return false


func input_count(node_id: StringName) -> int:
	match node_kind(node_id):
		SOURCE:
			return 0
		COMBINE:
			return GlyphModel.MAX_COMBINE_CHILDREN
		ROTATE, MOVE, SCALE, REPEAT, COLOR, OUTPUT:
			return 1
	return 0


func evaluate(node_id: StringName) -> Dictionary:
	var result := _evaluate(node_id, {}, {})
	if result.get("glyph") is GlyphModel:
		result["glyph"] = result["glyph"].copy()
	return result


func evaluate_output() -> Dictionary:
	var node_id := output_node_id()
	if node_id == &"":
		return {"ok": false, "glyph": null, "error": &"missing_output"}
	return evaluate(node_id)


func clear(keep_output: bool = true) -> void:
	var output_id := output_node_id()
	nodes.clear()
	connections.clear()
	last_error = &""
	if keep_output and output_id != &"":
		add_node(output_id, OUTPUT)


func _evaluate(node_id: StringName, cache: Dictionary, active: Dictionary) -> Dictionary:
	if cache.has(node_id):
		return _result_copy(cache[node_id])
	if active.has(node_id):
		return {"ok": false, "glyph": null, "error": &"cycle"}
	if not nodes.has(node_id):
		return {"ok": false, "glyph": null, "error": &"missing_node"}
	active[node_id] = true
	var kind := node_kind(node_id)
	var result: Dictionary
	if kind == SOURCE:
		var config := node_config(node_id)
		result = {
			"ok": true,
			"glyph": GlyphModel.new([
				GlyphComponentModel.new(StringName(config["primitive_id"])),
			]),
			"error": &"",
		}
	elif kind == COMBINE:
		var inputs: Array = []
		for input_port in input_count(node_id):
			var source_id := _incoming_node(node_id, input_port)
			if source_id == &"":
				continue
			var input_result := _evaluate(source_id, cache, active)
			if not bool(input_result["ok"]):
				result = input_result
				active.erase(node_id)
				cache[node_id] = result
				return _result_copy(result)
			inputs.append(input_result["glyph"])
		if inputs.size() < GlyphModel.MIN_COMBINE_CHILDREN:
			result = {"ok": false, "glyph": null, "error": &"missing_input"}
		else:
			result = _apply_node(kind, node_config(node_id), inputs)
	else:
		var inputs: Array = []
		for input_port in input_count(node_id):
			var source_id := _incoming_node(node_id, input_port)
			if source_id == &"":
				result = {"ok": false, "glyph": null, "error": &"missing_input"}
				active.erase(node_id)
				cache[node_id] = result
				return _result_copy(result)
			var input_result := _evaluate(source_id, cache, active)
			if not bool(input_result["ok"]):
				result = input_result
				active.erase(node_id)
				cache[node_id] = result
				return _result_copy(result)
			inputs.append(input_result["glyph"])
		result = _apply_node(kind, node_config(node_id), inputs)
	active.erase(node_id)
	cache[node_id] = result
	return _result_copy(result)


func _apply_node(kind: StringName, config: Dictionary, inputs: Array) -> Dictionary:
	var glyph: GlyphModel
	match kind:
		ROTATE:
			glyph = inputs[0].copy()
			glyph.rotate_degrees(int(config["degrees"]))
		MOVE:
			glyph = inputs[0].copy()
			glyph.translate(config["offset"])
		SCALE:
			glyph = inputs[0].copy()
			glyph.stretch_percent(int(config["x_percent"]), int(config["y_percent"]))
		REPEAT:
			glyph = GlyphModel.radial_repeat(inputs[0], int(config["count"]))
			if glyph == null:
				return {"ok": false, "glyph": null, "error": &"invalid_repeat"}
		COLOR:
			glyph = inputs[0].copy()
			glyph.recolor(StringName(config["color_id"]))
		COMBINE:
			glyph = GlyphModel.combine_many(
				inputs,
				StringName(config.get("connection_mode", GlyphModel.CONNECTION_RADIAL))
			)
		OUTPUT:
			glyph = inputs[0].copy()
		_:
			return {"ok": false, "glyph": null, "error": &"invalid_kind"}
	var errors := glyph.structure_validation_errors()
	if not errors.is_empty():
		return {
			"ok": false,
			"glyph": null,
			"error": &"invalid_glyph",
			"details": errors,
		}
	return {"ok": true, "glyph": glyph, "error": &""}


func _incoming_node(node_id: StringName, input_port: int) -> StringName:
	for connection in connections:
		if connection["to"] == node_id and int(connection["to_port"]) == input_port:
			return connection["from"]
	return &""


func _would_create_cycle(from_node_id: StringName, to_node_id: StringName) -> bool:
	var pending: Array[StringName] = [to_node_id]
	var visited: Dictionary = {}
	while not pending.is_empty():
		var current: StringName = pending.pop_back()
		if current == from_node_id:
			return true
		if visited.has(current):
			continue
		visited[current] = true
		for connection in connections:
			if connection["from"] == current:
				pending.append(connection["to"])
	return false


func _normalized_config(kind: StringName, config: Dictionary) -> Dictionary:
	match kind:
		SOURCE:
			var primitive_id := StringName(config.get("primitive_id", &"circle"))
			if not primitive_id in PRIMITIVES:
				return {"ok": false, "error": &"invalid_primitive", "config": {}}
			return {"ok": true, "error": &"", "config": {"primitive_id": primitive_id}}
		ROTATE:
			var degrees := (
				int(config["degrees"])
				if config.has("degrees")
				else int(config.get("steps", 1)) * 90
			)
			if degrees < -359 or degrees > 359:
				return {"ok": false, "error": &"invalid_rotation", "config": {}}
			return {"ok": true, "error": &"", "config": {"degrees": posmod(degrees, 360)}}
		MOVE:
			var offset = config.get("offset", Vector2i(0, -3))
			if (
				not offset is Vector2i
				or offset == Vector2i.ZERO
				or (offset.x != 0 and offset.y != 0)
				or absi(offset.x) > 6
				or absi(offset.y) > 6
			):
				return {"ok": false, "error": &"invalid_offset", "config": {}}
			return {"ok": true, "error": &"", "config": {"offset": offset}}
		SCALE:
			var x_percent := int(config.get("x_percent", 150))
			var y_percent := int(config.get("y_percent", 100))
			if (
				x_percent < 25
				or x_percent > 400
				or y_percent < 25
				or y_percent > 400
			):
				return {"ok": false, "error": &"invalid_scale", "config": {}}
			return {
				"ok": true,
				"error": &"",
				"config": {"x_percent": x_percent, "y_percent": y_percent},
			}
		REPEAT:
			var count := int(config.get("count", 6))
			if not count in REPEAT_COUNTS:
				return {"ok": false, "error": &"invalid_repeat", "config": {}}
			return {"ok": true, "error": &"", "config": {"count": count}}
		COLOR:
			var color_id := StringName(config.get("color_id", &"blue"))
			if not color_id in COLORS:
				return {"ok": false, "error": &"invalid_color", "config": {}}
			return {"ok": true, "error": &"", "config": {"color_id": color_id}}
		COMBINE:
			var connection_mode := StringName(config.get(
				"connection_mode",
				GlyphModel.CONNECTION_RADIAL
			))
			if not connection_mode in GlyphModel.COMBINE_CONNECTION_MODES:
				return {"ok": false, "error": &"invalid_connection_mode", "config": {}}
			return {
				"ok": true,
				"error": &"",
				"config": {"connection_mode": connection_mode},
			}
		OUTPUT:
			return {"ok": true, "error": &"", "config": {}}
	return {"ok": false, "error": &"invalid_kind", "config": {}}


static func _connection_less(first: Dictionary, second: Dictionary) -> bool:
	var first_key := "%s:%d>%s:%d" % [first["from"], first["from_port"], first["to"], first["to_port"]]
	var second_key := "%s:%d>%s:%d" % [second["from"], second["from_port"], second["to"], second["to_port"]]
	return first_key < second_key


static func _connection_error(error: StringName) -> Dictionary:
	return {"ok": false, "error": error}


static func _result_copy(result: Dictionary) -> Dictionary:
	var copy := result.duplicate(true)
	if result.get("glyph") is GlyphModel:
		copy["glyph"] = result["glyph"].copy()
	return copy
