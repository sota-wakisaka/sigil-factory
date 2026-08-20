class_name SealCompiler
extends RefCounted

const SealProgramModel := preload("res://src/sigil_v2/seal_program.gd")
const SealRenderPlanModel := preload("res://src/sigil_v2/seal_render_plan.gd")
const SealMotifLibraryModel := preload("res://src/sigil_v2/seal_motif_library.gd")

const ANGLE_TICKS := 120
const ORBIT_RADIUS := 580
const BOUNDARY_RADIUS := 900
const MOTIF_EXTENT := 280
const MAX_PREFLIGHT_ERRORS := 16
const ALLOWED_CONCENTRIC_SCALES := [Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4)]


static func compile(program, limits: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	var metrics := {
		"nodes": 0,
		"max_depth": 0,
		"max_repeat_nesting": 0,
		"work": 0,
		"segments": 0,
		"motifs": 0,
	}
	_preflight(program, limits, errors, metrics)
	if not errors.is_empty():
		return {"ok": false, "plan": null, "errors": errors, "metrics": metrics}

	var state := {
		"limits": limits,
		"errors": errors,
		"metrics": metrics,
	}
	var compiled := _compile_node(program, state, "root")
	if not errors.is_empty():
		return {"ok": false, "plan": null, "errors": errors, "metrics": metrics}

	var commands: Array = compiled.get("commands", [])
	var anchors: Array = compiled.get("anchors", [])
	commands = _stable_unique(commands, Callable(SealRenderPlanModel, "stable_dictionary_key"), state, "commands")
	if not errors.is_empty():
		return {"ok": false, "plan": null, "errors": errors, "metrics": metrics}
	anchors = _stable_unique(anchors, Callable(SealRenderPlanModel, "stable_dictionary_key"), state, "anchors")
	if not errors.is_empty():
		return {"ok": false, "plan": null, "errors": errors, "metrics": metrics}
	if commands.size() > int(limits.get("max_commands", 0)):
		errors.append("limit_commands:%d>%d" % [commands.size(), int(limits.get("max_commands", 0))])
	if anchors.size() > int(limits.get("max_anchors", 0)):
		errors.append("limit_anchors:%d>%d" % [anchors.size(), int(limits.get("max_anchors", 0))])
	if int(metrics["segments"]) > int(limits.get("max_segments", 0)):
		errors.append("limit_segments:%d>%d" % [metrics["segments"], int(limits.get("max_segments", 0))])
	if int(metrics["motifs"]) > int(limits.get("max_motifs", 0)):
		errors.append("limit_motifs:%d>%d" % [metrics["motifs"], int(limits.get("max_motifs", 0))])
	if not errors.is_empty():
		return {"ok": false, "plan": null, "errors": errors, "metrics": metrics}

	_consume_work(state, commands.size(), "bounds")
	if not errors.is_empty():
		return {"ok": false, "plan": null, "errors": errors, "metrics": metrics}
	var bounds_radius := _bounds_radius(commands)
	var plan := SealRenderPlanModel.new(
		commands,
		anchors,
		[],
		bounds_radius,
		metrics,
		compiled.get("metadata", [])
	)
	return {"ok": true, "plan": plan, "errors": errors, "metrics": metrics}


static func _preflight(program, limits: Dictionary, errors: PackedStringArray, metrics: Dictionary) -> void:
	var stack: Array = [{
		"node": program,
		"path": "root",
		"depth": 1,
		"repeat_depth": 0,
		"exit": false,
	}]
	var active: Dictionary = {}
	while not stack.is_empty():
		if errors.size() >= MAX_PREFLIGHT_ERRORS:
			return
		var frame: Dictionary = stack.pop_back()
		var node_value = frame["node"]
		if not node_value is SealProgramModel:
			errors.append("invalid_node:%s" % frame["path"])
			continue
		var node: SealProgram = node_value
		var instance_key: int = node.get_instance_id()
		if bool(frame["exit"]):
			active.erase(instance_key)
			continue
		if active.has(instance_key):
			errors.append("cyclic_program:%s" % frame["path"])
			continue
		active[instance_key] = true
		stack.append({
			"node": node,
			"path": frame["path"],
			"depth": frame["depth"],
			"repeat_depth": frame["repeat_depth"],
			"exit": true,
		})
		metrics["nodes"] = int(metrics["nodes"]) + 1
		metrics["max_depth"] = maxi(int(metrics["max_depth"]), int(frame["depth"]))
		var next_repeat_depth := int(frame["repeat_depth"])
		if node.op == SealProgramModel.Op.ORBIT or node.op == SealProgramModel.Op.CONCENTRIC:
			next_repeat_depth += 1
		metrics["max_repeat_nesting"] = maxi(int(metrics["max_repeat_nesting"]), next_repeat_depth)
		if int(metrics["nodes"]) > int(limits.get("max_nodes", 0)):
			errors.append("limit_nodes:%d>%d" % [metrics["nodes"], int(limits.get("max_nodes", 0))])
			return
		var frame_exceeds_limit := false
		if int(frame["depth"]) > int(limits.get("max_depth", 0)):
			errors.append("limit_depth:%s:%d>%d" % [frame["path"], frame["depth"], int(limits.get("max_depth", 0))])
			frame_exceeds_limit = true
		if next_repeat_depth > int(limits.get("max_repeat_nesting", 0)):
			errors.append("limit_repeat_nesting:%s:%d>%d" % [
				frame["path"],
				next_repeat_depth,
				int(limits.get("max_repeat_nesting", 0)),
			])
			frame_exceeds_limit = true
		if frame_exceeds_limit:
			continue
		var errors_before_validation := errors.size()
		_validate_node(node, String(frame["path"]), limits, errors)
		if errors.size() > errors_before_validation:
			continue
		var children: Array = node.children()
		for index in range(children.size() - 1, -1, -1):
			stack.append({
				"node": children[index],
				"path": "%s.%d" % [frame["path"], index],
				"depth": int(frame["depth"]) + 1,
				"repeat_depth": next_repeat_depth,
				"exit": false,
			})


static func _validate_node(
	node: SealProgram,
	path: String,
	limits: Dictionary,
	errors: PackedStringArray
) -> void:
	var parameters: Dictionary = node.parameters()
	var expected_children: int = {
		SealProgramModel.Op.MOTIF: 0,
		SealProgramModel.Op.ORBIT: 1,
		SealProgramModel.Op.BOUNDARY: 1,
		SealProgramModel.Op.COMPOSE: 2,
		SealProgramModel.Op.CIRCUIT: 1,
		SealProgramModel.Op.CONCENTRIC: 1,
	}.get(node.op, -1)
	if expected_children < 0:
		errors.append("invalid_operator:%s:%d" % [path, node.op])
		return
	if node.child_count() != expected_children:
		errors.append("invalid_arity:%s:%d!=%d" % [path, node.child_count(), expected_children])
	match node.op:
		SealProgramModel.Op.MOTIF:
			if not StringName(parameters.get("motif_id", &"")) in [&"crescent", &"fang", &"branch"]:
				errors.append("invalid_motif:%s" % path)
			if not StringName(parameters.get("ink_id", &"")) in [&"white", &"blue", &"red"]:
				errors.append("invalid_ink:%s" % path)
		SealProgramModel.Op.ORBIT:
			var count := int(parameters.get("count", 0))
			if count < 2 or count > int(limits.get("max_repeat_count", 0)) or ANGLE_TICKS % count != 0:
				errors.append("invalid_orbit_count:%s:%d" % [path, count])
			var child = node.child_at(0)
			if child is SealProgramModel and child.op != SealProgramModel.Op.MOTIF:
				errors.append("phase0_orbit_requires_motif:%s" % path)
			if not StringName(parameters.get("facing", &"")) in [&"fixed", &"outward", &"tangent"]:
				errors.append("invalid_facing:%s" % path)
		SealProgramModel.Op.BOUNDARY:
			if not StringName(parameters.get("shape", &"")) in [&"circle", &"triangle"]:
				errors.append("invalid_boundary:%s" % path)
		SealProgramModel.Op.CIRCUIT:
			var topology := StringName(parameters.get("topology", &""))
			if not topology in [&"adjacent", &"star", &"spokes"]:
				errors.append("invalid_topology:%s" % path)
			if StringName(parameters.get("target_group_key", &"")) == &"":
				errors.append("missing_target_group:%s" % path)
			if int(parameters.get("step", 0)) < 1:
				errors.append("invalid_circuit_step:%s" % path)
		SealProgramModel.Op.CONCENTRIC:
			var count := int(parameters.get("count", 0))
			if count < 2 or count > mini(3, int(limits.get("max_repeat_count", 0))):
				errors.append("invalid_concentric_count:%s:%d" % [path, count])
			var scale_num := int(parameters.get("scale_num", 0))
			var scale_den := int(parameters.get("scale_den", 0))
			if (
				scale_num <= 0
				or scale_den <= 0
				or scale_num > 4
				or scale_den > 4
			):
				errors.append("invalid_concentric_scale:%s" % path)
			else:
				var scale_ratio := _reduced_ratio(scale_num, scale_den)
				if not scale_ratio in ALLOWED_CONCENTRIC_SCALES:
					errors.append("invalid_concentric_scale:%s" % path)
			var phase_step := int(parameters.get("phase_step_tick", -1))
			if phase_step < 0 or phase_step >= ANGLE_TICKS:
				errors.append("invalid_concentric_phase:%s:%d" % [path, phase_step])


static func _compile_node(program: SealProgram, state: Dictionary, path: String) -> Dictionary:
	_consume_work(state, 1, path)
	if not state["errors"].is_empty():
		return {"commands": [], "anchors": [], "metadata": []}
	var parameters := program.parameters()
	match program.op:
		SealProgramModel.Op.MOTIF:
			_consume_work(state, 1, path)
			state["metrics"]["motifs"] = int(state["metrics"]["motifs"]) + 1
			state["metrics"]["segments"] = int(state["metrics"]["segments"]) + _motif_segments(StringName(parameters["motif_id"]))
			return {"commands": [{
				"kind": &"motif",
				"motif_id": StringName(parameters["motif_id"]),
				"ink_id": StringName(parameters["ink_id"]),
				"center_radius": 0,
				"center_angle_tick": 0,
				"rotation_tick": int(parameters["orientation_tick"]),
				"scale_num": 1,
				"scale_den": 1,
				"semantic_role": &"motif",
			}], "anchors": [], "metadata": []}
		SealProgramModel.Op.ORBIT:
			return _compile_orbit(program, state, path)
		SealProgramModel.Op.BOUNDARY:
			return _compile_boundary(program, state, path)
		SealProgramModel.Op.COMPOSE:
			return _compile_compose(program, state, path)
		SealProgramModel.Op.CIRCUIT:
			return _compile_circuit(program, state, path)
		SealProgramModel.Op.CONCENTRIC:
			return _compile_concentric(program, state, path)
	state["errors"].append("invalid_operator:%s" % path)
	return {"commands": [], "anchors": [], "metadata": []}


static func _compile_orbit(program: SealProgram, state: Dictionary, path: String) -> Dictionary:
	var parameters := program.parameters()
	var child: SealProgram = program.child_at(0)
	var base := _compile_node(child, state, path + ".0")
	if not state["errors"].is_empty():
		return {"commands": [], "anchors": [], "metadata": []}
	var count := int(parameters["count"])
	var phase := int(parameters["phase_tick"])
	var facing := StringName(parameters["facing"])
	var group_key := SealProgramModel.orbit_group_key(child, count, phase, facing)
	var commands: Array = []
	var anchors: Array = []
	for index in count:
		var angle_tick := posmod(phase + index * (ANGLE_TICKS / count), ANGLE_TICKS)
		var motif_command: Dictionary = base["commands"][0].duplicate(true)
		motif_command["center_radius"] = ORBIT_RADIUS
		motif_command["center_angle_tick"] = angle_tick
		motif_command["scale_num"] = int(motif_command["scale_num"]) * 1
		motif_command["scale_den"] = int(motif_command["scale_den"]) * 3
		if facing == &"outward":
			motif_command["rotation_tick"] = posmod(int(motif_command["rotation_tick"]) + angle_tick, ANGLE_TICKS)
		elif facing == &"tangent":
			motif_command["rotation_tick"] = posmod(int(motif_command["rotation_tick"]) + angle_tick + 30, ANGLE_TICKS)
		motif_command["group_key"] = group_key
		motif_command["cyclic_index"] = index
		commands.append(motif_command)
		anchors.append({
			"anchor_key": StringName("%s:%02d" % [String(group_key), index]),
			"group_key": group_key,
			"lane_id": &"orbit",
			"cyclic_index": index,
			"radius": ORBIT_RADIUS,
			"angle_tick": angle_tick,
			"semantic_role": &"cyclic",
		})
	commands.append({
		"kind": &"orbit_signature",
		"count": count,
		"phase_tick": phase,
		"radius": ORBIT_RADIUS,
		"group_key": group_key,
		"semantic_role": &"orbit",
	})
	state["metrics"]["motifs"] = int(state["metrics"]["motifs"]) - 1 + count
	state["metrics"]["segments"] = (
		int(state["metrics"]["segments"])
		- _motif_segments(StringName(child.parameters()["motif_id"]))
		+ count * _motif_segments(StringName(child.parameters()["motif_id"]))
		+ SealMotifLibraryModel.ORBIT_RING_SEGMENTS
		+ count
	)
	_consume_work(state, count * 2 + 1, path)
	return {"commands": commands, "anchors": anchors, "metadata": base.get("metadata", [])}


static func _compile_boundary(program: SealProgram, state: Dictionary, path: String) -> Dictionary:
	var result := _compile_node(program.child_at(0), state, path + ".0")
	var shape := StringName(program.parameters()["shape"])
	result["commands"].append({
		"kind": &"boundary",
		"shape": shape,
		"radius": BOUNDARY_RADIUS,
		"rotation_tick": 0,
		"ink_id": &"white",
		"semantic_role": &"boundary",
	})
	state["metrics"]["segments"] = int(state["metrics"]["segments"]) + (
		SealMotifLibraryModel.CIRCLE_SEGMENTS
		if shape == &"circle"
		else SealMotifLibraryModel.TRIANGLE_SEGMENTS
	)
	if shape == &"triangle":
		var group_key := StringName(
			"boundary_" + _canonical_result_key(result).sha256_text().substr(0, 20)
		)
		for index in 3:
			result["anchors"].append({
				"anchor_key": StringName("%s:%02d" % [String(group_key), index]),
				"group_key": group_key,
				"lane_id": &"boundary",
				"cyclic_index": index,
				"radius": BOUNDARY_RADIUS,
				"angle_tick": index * 40,
				"semantic_role": &"cyclic",
			})
	_consume_work(state, 1 + (3 if shape == &"triangle" else 0), path)
	return result


static func _compile_compose(program: SealProgram, state: Dictionary, path: String) -> Dictionary:
	var core := _compile_node(program.child_at(0), state, path + ".0")
	var field := _compile_node(program.child_at(1), state, path + ".1")
	if not state["errors"].is_empty():
		return {"commands": [], "anchors": [], "metadata": []}
	if _is_bare_motif_result(field):
		field = _lift_bare_field(field)
	core = _center_transform(core, 1, 3, 0, "core")
	field = _center_transform(field, 9, 10, 0, "field")
	var commands: Array = core["commands"] + field["commands"]
	var anchors: Array = core["anchors"] + field["anchors"]
	var metadata: Array = core.get("metadata", []) + field.get("metadata", [])
	var center_key := StringName(
		"compose_center_"
		+ _canonical_result_key({
			"commands": commands,
			"anchors": anchors,
		}).sha256_text().substr(0, 20)
	)
	anchors.append({
		"anchor_key": center_key,
		"group_key": center_key,
		"lane_id": &"core",
		"cyclic_index": 0,
		"radius": 0,
		"angle_tick": 0,
		"semantic_role": &"center",
	})
	commands.append({
		"kind": &"compose_signature",
		"core_scale_num": 1,
		"core_scale_den": 3,
		"field_scale_num": 9,
		"field_scale_den": 10,
		"semantic_role": &"compose",
	})
	_consume_work(state, commands.size() + anchors.size(), path)
	return {"commands": commands, "anchors": anchors, "metadata": metadata}


static func _compile_circuit(program: SealProgram, state: Dictionary, path: String) -> Dictionary:
	var result := _compile_node(program.child_at(0), state, path + ".0")
	var parameters := program.parameters()
	var target_group := StringName(parameters["target_group_key"])
	var group: Array = []
	for anchor in result["anchors"]:
		if StringName(anchor.get("group_key", &"")) == target_group and StringName(anchor.get("semantic_role", &"")) == &"cyclic":
			group.append(anchor)
	group.sort_custom(func(a, b) -> bool: return int(a["cyclic_index"]) < int(b["cyclic_index"]))
	if group.size() < 2:
		state["errors"].append("missing_circuit_group:%s:%s" % [path, String(target_group)])
		return {"commands": [], "anchors": [], "metadata": []}
	var topology := StringName(parameters["topology"])
	var step := int(parameters["step"])
	if topology == &"star" and (step >= group.size() or step <= 1):
		state["errors"].append("invalid_star_step:%s:%d/%d" % [path, step, group.size()])
		return {"commands": [], "anchors": [], "metadata": []}
	var edge_pairs: Array = []
	if topology == &"spokes":
		var center_key := StringName(parameters.get("center_anchor_key", &""))
		var center = null
		for anchor in result["anchors"]:
			if StringName(anchor.get("anchor_key", &"")) == center_key and StringName(anchor.get("semantic_role", &"")) == &"center":
				center = anchor
				break
		if center == null:
			state["errors"].append("missing_center_anchor:%s" % path)
			return {"commands": [], "anchors": [], "metadata": []}
		for anchor in group:
			edge_pairs.append([center, anchor])
	else:
		var edge_step := 1 if topology == &"adjacent" else step
		for index in group.size():
			edge_pairs.append([group[index], group[(index + edge_step) % group.size()]])
	var seen_edges: Dictionary = {}
	for pair in edge_pairs:
		var first: Dictionary = pair[0]
		var second: Dictionary = pair[1]
		var first_key := String(first["anchor_key"])
		var second_key := String(second["anchor_key"])
		var first_is_lower := first_key < second_key
		var lower_key := first_key if first_is_lower else second_key
		var upper_key := second_key if first_is_lower else first_key
		var edge_key := "%s|%s" % [lower_key, upper_key]
		if seen_edges.has(edge_key):
			continue
		seen_edges[edge_key] = true
		var lower_anchor: Dictionary = first if first_is_lower else second
		var upper_anchor: Dictionary = second if first_is_lower else first
		result["commands"].append({
			"kind": &"edge",
			"from_radius": int(lower_anchor["radius"]),
			"from_angle_tick": int(lower_anchor["angle_tick"]),
			"to_radius": int(upper_anchor["radius"]),
			"to_angle_tick": int(upper_anchor["angle_tick"]),
			"ink_id": &"white",
			"semantic_role": &"circuit",
		})
	result["metadata"].append({
		"kind": &"circuit",
		"target_group_key": target_group,
		"topology": topology,
		"step": step,
		"edge_count": seen_edges.size(),
	})
	state["metrics"]["segments"] = int(state["metrics"]["segments"]) + seen_edges.size()
	_consume_work(
		state,
		result["anchors"].size() + edge_pairs.size() + seen_edges.size(),
		path
	)
	return result


static func _compile_concentric(program: SealProgram, state: Dictionary, path: String) -> Dictionary:
	var motifs_before := int(state["metrics"]["motifs"])
	var segments_before := int(state["metrics"]["segments"])
	var base := _compile_node(program.child_at(0), state, path + ".0")
	var child_motifs := int(state["metrics"]["motifs"]) - motifs_before
	var child_segments := int(state["metrics"]["segments"]) - segments_before
	var parameters := program.parameters()
	var count := int(parameters["count"])
	var scale_num := int(parameters["scale_num"])
	var scale_den := int(parameters["scale_den"])
	var phase_step := int(parameters["phase_step_tick"])
	var commands: Array = []
	var anchors: Array = []
	var metadata: Array = []
	var current_num := 1
	var current_den := 1
	for index in count:
		var layer := _center_transform(base, current_num, current_den, index * phase_step, "concentric_%d" % index)
		commands.append_array(layer["commands"])
		anchors.append_array(layer["anchors"])
		metadata.append_array(layer.get("metadata", []))
		current_num *= scale_num
		current_den *= scale_den
	commands.append({
		"kind": &"concentric_signature",
		"count": count,
		"scale_num": scale_num,
		"scale_den": scale_den,
		"phase_step_tick": phase_step,
		"semantic_role": &"concentric",
	})
	state["metrics"]["motifs"] = motifs_before + child_motifs * count
	state["metrics"]["segments"] = segments_before + child_segments * count
	_consume_work(state, commands.size() + anchors.size(), path)
	return {"commands": commands, "anchors": anchors, "metadata": metadata}


static func _is_bare_motif_result(result: Dictionary) -> bool:
	var commands: Array = result.get("commands", [])
	return (
		commands.size() == 1
		and StringName(commands[0].get("kind", &"")) == &"motif"
		and int(commands[0].get("center_radius", -1)) == 0
		and result.get("anchors", []).is_empty()
	)


static func _lift_bare_field(result: Dictionary) -> Dictionary:
	var lifted := {
		"commands": result.get("commands", []).duplicate(true),
		"anchors": result.get("anchors", []).duplicate(true),
		"metadata": result.get("metadata", []).duplicate(true),
	}
	var command: Dictionary = lifted["commands"][0]
	command["center_radius"] = ORBIT_RADIUS
	command["center_angle_tick"] = 0
	return lifted


static func _center_transform(
	result: Dictionary,
	scale_num: int,
	scale_den: int,
	rotation_tick: int,
	group_prefix: String
) -> Dictionary:
	var commands: Array = []
	for source in result.get("commands", []):
		var command: Dictionary = source.duplicate(true)
		var kind := StringName(command.get("kind", &""))
		if command.has("center_radius"):
			command["center_radius"] = _scaled_int(int(command["center_radius"]), scale_num, scale_den)
			command["center_angle_tick"] = posmod(int(command.get("center_angle_tick", 0)) + rotation_tick, ANGLE_TICKS)
		if command.has("rotation_tick"):
			command["rotation_tick"] = posmod(int(command["rotation_tick"]) + rotation_tick, ANGLE_TICKS)
		if command.has("radius"):
			command["radius"] = _scaled_int(int(command["radius"]), scale_num, scale_den)
		if kind == &"edge":
			command["from_radius"] = _scaled_int(int(command["from_radius"]), scale_num, scale_den)
			command["to_radius"] = _scaled_int(int(command["to_radius"]), scale_num, scale_den)
			command["from_angle_tick"] = posmod(int(command["from_angle_tick"]) + rotation_tick, ANGLE_TICKS)
			command["to_angle_tick"] = posmod(int(command["to_angle_tick"]) + rotation_tick, ANGLE_TICKS)
		if command.has("phase_tick"):
			command["phase_tick"] = posmod(int(command["phase_tick"]) + rotation_tick, ANGLE_TICKS)
		if command.has("scale_num") and command.has("scale_den"):
			var ratio := _reduced_ratio(int(command["scale_num"]) * scale_num, int(command["scale_den"]) * scale_den)
			command["scale_num"] = ratio.x
			command["scale_den"] = ratio.y
		if command.has("group_key"):
			command["group_key"] = StringName("%s|%s" % [group_prefix, String(command["group_key"])])
		if command.has("target_group_key"):
			command["target_group_key"] = StringName("%s|%s" % [group_prefix, String(command["target_group_key"])])
		if command.has("center_anchor_key") and String(command["center_anchor_key"]) != "":
			command["center_anchor_key"] = StringName("%s|%s" % [group_prefix, String(command["center_anchor_key"])])
		commands.append(command)
	var anchors: Array = []
	for source in result.get("anchors", []):
		var anchor: Dictionary = source.duplicate(true)
		var old_group := String(anchor.get("group_key", ""))
		var old_key := String(anchor.get("anchor_key", ""))
		anchor["group_key"] = StringName("%s|%s" % [group_prefix, old_group])
		anchor["anchor_key"] = StringName("%s|%s" % [group_prefix, old_key])
		anchor["radius"] = _scaled_int(int(anchor.get("radius", 0)), scale_num, scale_den)
		anchor["angle_tick"] = posmod(int(anchor.get("angle_tick", 0)) + rotation_tick, ANGLE_TICKS)
		anchors.append(anchor)
	var metadata: Array = []
	for source in result.get("metadata", []):
		var entry: Dictionary = source.duplicate(true)
		if entry.has("target_group_key"):
			entry["target_group_key"] = StringName(
				"%s|%s" % [group_prefix, String(entry["target_group_key"])]
			)
		if entry.has("center_anchor_key") and String(entry["center_anchor_key"]) != "":
			entry["center_anchor_key"] = StringName(
				"%s|%s" % [group_prefix, String(entry["center_anchor_key"])]
			)
		metadata.append(entry)
	return {"commands": commands, "anchors": anchors, "metadata": metadata}


static func _canonical_result_key(result: Dictionary) -> String:
	var command_keys: Array[String] = []
	for command in result.get("commands", []):
		command_keys.append(SealRenderPlanModel.stable_dictionary_key(command))
	command_keys.sort()
	var anchor_keys: Array[String] = []
	for anchor in result.get("anchors", []):
		anchor_keys.append(SealRenderPlanModel.stable_dictionary_key(anchor))
	anchor_keys.sort()
	var framed_commands: Array[String] = []
	for key in command_keys:
		framed_commands.append(_length_frame(key))
	var framed_anchors: Array[String] = []
	for key in anchor_keys:
		framed_anchors.append(_length_frame(key))
	return "C[%s]A[%s]" % ["".join(framed_commands), "".join(framed_anchors)]


static func _length_frame(value: String) -> String:
	return "%d:%s" % [value.length(), value]


static func _stable_unique(
	values: Array,
	key_callable: Callable,
	state: Dictionary,
	path: String
) -> Array:
	var keyed: Array = []
	for value in values:
		keyed.append({"key": key_callable.call(value), "value": value})
	var comparisons := 0
	keyed.sort_custom(func(a, b) -> bool:
		comparisons += 1
		return String(a["key"]) < String(b["key"])
	)
	_consume_work(state, keyed.size() + comparisons, path)
	var result: Array = []
	var previous_key := ""
	var has_previous := false
	for entry in keyed:
		var key := String(entry["key"])
		if has_previous and key == previous_key:
			continue
		result.append(entry["value"])
		previous_key = key
		has_previous = true
	return result


static func _bounds_radius(commands: Array) -> int:
	var bounds := 1
	for command in commands:
		var kind := StringName(command.get("kind", &""))
		match kind:
			&"motif":
				var extent := _scaled_int(
					MOTIF_EXTENT,
					int(command.get("scale_num", 1)),
					maxi(int(command.get("scale_den", 1)), 1)
				)
				bounds = maxi(bounds, int(command.get("center_radius", 0)) + extent)
			&"boundary":
				bounds = maxi(bounds, int(command.get("radius", 0)))
			&"edge":
				bounds = maxi(bounds, maxi(int(command.get("from_radius", 0)), int(command.get("to_radius", 0))))
	return bounds + 32


static func _consume_work(state: Dictionary, amount: int, path: String) -> void:
	state["metrics"]["work"] = int(state["metrics"]["work"]) + maxi(amount, 0)
	var limit := int(state["limits"].get("max_work", 0))
	if int(state["metrics"]["work"]) > limit and state["errors"].is_empty():
		state["errors"].append("limit_work:%s:%d>%d" % [path, state["metrics"]["work"], limit])


static func _scaled_int(value: int, numerator: int, denominator: int) -> int:
	if denominator <= 0:
		return 0
	var product := value * numerator
	var half := denominator >> 1
	@warning_ignore("integer_division")
	return (product + half) / denominator


static func _reduced_ratio(numerator: int, denominator: int) -> Vector2i:
	var divisor := _greatest_common_divisor(abs(numerator), abs(denominator))
	return Vector2i(numerator / divisor, denominator / divisor)


static func _greatest_common_divisor(first: int, second: int) -> int:
	var a := maxi(first, 1)
	var b := maxi(second, 1)
	while b != 0:
		var remainder := a % b
		a = b
		b = remainder
	return maxi(a, 1)


static func _motif_segments(motif_id: StringName) -> int:
	return SealMotifLibraryModel.segment_count(motif_id)
