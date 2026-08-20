extends SceneTree

const SealProgramModel := preload("res://src/sigil_v2/seal_program.gd")
const SealCompilerModel := preload("res://src/sigil_v2/seal_compiler.gd")
const SealLimitsModel := preload("res://src/sigil_v2/seal_limits.gd")
const SealMotifLibraryModel := preload("res://src/sigil_v2/seal_motif_library.gd")
const SealLabContentModel := preload("res://experiments/seal_lab/seal_lab_content.gd")

var failures := 0


func _initialize() -> void:
	_test_all_lab_fixtures_compile_deterministically()
	_test_learning_pairs_change_only_the_expected_semantics()
	_test_circuit_connects_only_its_selected_group()
	_test_circuit_canonicalizes_equivalent_visible_edges()
	_test_compose_lifts_a_bare_field_to_the_outer_lane()
	_test_program_and_plan_accessors_do_not_alias_state()
	_test_limits_reject_invalid_programs_atomically()
	_test_metrics_match_renderer_geometry()
	_test_lab_signatures_are_pairwise_distinct()
	if failures == 0:
		print("All Sigil V2 tests passed.")
	quit(failures)


func _test_all_lab_fixtures_compile_deterministically() -> void:
	var fixtures := SealLabContentModel.fixtures()
	_expect(fixtures.size() == 10, "Seal Lab should contain MVP 9 plus one hero seal")
	for fixture in fixtures:
		var limits := SealLimitsModel.profile(bool(fixture["hero"]))
		for state_name in ["current", "hypothetical"]:
			var first := SealCompilerModel.compile(fixture[state_name], limits)
			var second := SealCompilerModel.compile(fixture[state_name], limits)
			_expect(first["ok"], "fixture %s %s should compile: %s" % [fixture["id"], state_name, first["errors"]])
			_expect(second["ok"], "fixture %s %s should compile twice" % [fixture["id"], state_name])
			if not first["ok"] or not second["ok"]:
				continue
			_expect(
				first["plan"].command_snapshot() == second["plan"].command_snapshot(),
				"fixture %s %s should produce a deterministic command and anchor snapshot" % [fixture["id"], state_name]
			)
			_expect(first["metrics"] == second["metrics"], "fixture compile metrics should be deterministic")
			if not fixture["hero"]:
				_expect(int(first["metrics"]["max_depth"]) <= 4, "MVP fixtures should stay within AST depth 4")
				_expect(int(first["metrics"]["max_repeat_nesting"]) <= 1, "MVP fixtures should use at most one repeat layer")
				_expect(int(first["metrics"]["motifs"]) <= 7, "MVP fixtures should expand to at most seven motifs")
			else:
				_expect(int(first["metrics"]["max_depth"]) <= 6, "hero fixture should stay within AST depth 6")
				_expect(int(first["metrics"]["max_repeat_nesting"]) <= 2, "hero fixture should use at most two repeat layers")
		var current := SealCompilerModel.compile(fixture["current"], limits)
		var hypothetical := SealCompilerModel.compile(fixture["hypothetical"], limits)
		if current["ok"] and hypothetical["ok"]:
			_expect(
				current["plan"].command_snapshot() != hypothetical["plan"].command_snapshot(),
				"fixture %s should compare a real one-setting alternative" % fixture["id"]
			)


func _test_learning_pairs_change_only_the_expected_semantics() -> void:
	var fixtures := SealLabContentModel.fixtures()
	var plans: Array = []
	for fixture in fixtures:
		var result := SealCompilerModel.compile(fixture["current"], SealLimitsModel.profile(bool(fixture["hero"])))
		plans.append(result["plan"] if result["ok"] else null)
	if plans.any(func(value) -> bool: return value == null):
		_expect(false, "learning pair tests require all fixture plans")
		return
	_expect(_count_kind(plans[0], &"boundary") == 0, "motif lesson should not contain a boundary")
	_expect(_count_kind(plans[3], &"boundary") == 1, "circle lesson should add one boundary")
	_expect(_first_value(plans[3], &"boundary", "shape") == &"circle", "lesson 4 should use a circle")
	_expect(_first_value(plans[4], &"boundary", "shape") == &"triangle", "lesson 5 should use a triangle")
	_expect(_first_value(plans[5], &"orbit_signature", "count") == 3, "lesson 6 should teach a threefold orbit")
	_expect(_first_value(plans[6], &"orbit_signature", "count") == 3, "lesson 7 should retain the known threefold field")
	_expect(_first_value(plans[7], &"orbit_signature", "count") == 4, "lesson 8 should change only the orbit count")
	_expect(_first_value(plans[7], &"orbit_signature", "phase_tick") == 0, "lesson 8 should retain zero phase")
	_expect(_first_value(plans[8], &"orbit_signature", "phase_tick") == 15, "lesson 9 should introduce the half-slot phase")


func _test_circuit_connects_only_its_selected_group() -> void:
	var hero := SealLabContentModel.fixtures()[9]
	var current := SealCompilerModel.compile(hero["current"], SealLimitsModel.profile(true))
	_expect(current["ok"], "hero circuit should compile")
	if not current["ok"]:
		return
	_expect(current["plan"].diagnostic_metadata.size() == 3, "three concentric layers should retain three diagnostic Circuit entries")
	_expect(_count_kind(current["plan"], &"edge") == 18, "six-point star across three lanes should create eighteen unique edges")
	var edge_radii: Dictionary = {}
	for command in current["plan"].commands:
		if StringName(command.get("kind", &"")) != &"edge":
			continue
		_expect(
			int(command["from_radius"]) == int(command["to_radius"]),
			"circuit edges should never cross concentric anchor groups"
		)
		edge_radii[int(command["from_radius"])] = true
	_expect(edge_radii.size() == 3, "concentric circuit should expose exactly three separate lanes")
	var metadata_groups: Dictionary = {}
	for entry in current["plan"].diagnostic_metadata:
		metadata_groups[StringName(entry["target_group_key"])] = true
	_expect(metadata_groups.size() == 3, "each concentric Circuit diagnostic should identify its transformed lane")


func _test_circuit_canonicalizes_equivalent_visible_edges() -> void:
	var branch := SealProgramModel.motif(&"branch", 0, &"blue")
	var orbit := SealProgramModel.orbit(branch, 6, 0, &"outward")
	var group := SealProgramModel.orbit_group_key(branch, 6, 0, &"outward")
	var star_two := SealCompilerModel.compile(
		SealProgramModel.circuit(orbit, group, &"star", 2),
		SealLimitsModel.profile(true)
	)
	var star_four := SealCompilerModel.compile(
		SealProgramModel.circuit(orbit, group, &"star", 4),
		SealLimitsModel.profile(true)
	)
	var adjacent := SealCompilerModel.compile(
		SealProgramModel.circuit(orbit, group, &"adjacent", 1),
		SealLimitsModel.profile(true)
	)
	var reverse_adjacent := SealCompilerModel.compile(
		SealProgramModel.circuit(orbit, group, &"star", 5),
		SealLimitsModel.profile(true)
	)
	_expect(star_two["ok"] and star_four["ok"], "equivalent six-point stars should compile")
	_expect(adjacent["ok"] and reverse_adjacent["ok"], "equivalent adjacent circuits should compile")
	if star_two["ok"] and star_four["ok"]:
		_expect(
			star_two["plan"].command_snapshot() == star_four["plan"].command_snapshot(),
			"star steps two and four should canonicalize to the same visible edge set"
		)
		var wrapped_two := SealCompilerModel.compile(
			SealProgramModel.boundary(
				&"triangle",
				SealProgramModel.circuit(orbit, group, &"star", 2)
			),
			SealLimitsModel.profile(true)
		)
		var wrapped_four := SealCompilerModel.compile(
			SealProgramModel.boundary(
				&"triangle",
				SealProgramModel.circuit(orbit, group, &"star", 4)
			),
			SealLimitsModel.profile(true)
		)
		_expect(wrapped_two["ok"] and wrapped_four["ok"], "equivalent stars wrapped by Boundary should compile")
		if wrapped_two["ok"] and wrapped_four["ok"]:
			_expect(
				wrapped_two["plan"].command_snapshot() == wrapped_four["plan"].command_snapshot(),
				"Boundary should derive anchor identity from canonical child geometry"
			)
			_expect(
				_anchor_snapshot(wrapped_two["plan"]) == _anchor_snapshot(wrapped_four["plan"]),
				"Boundary anchors should ignore equivalent Circuit operation metadata"
			)
		var core := SealProgramModel.motif(&"crescent")
		var composed_two := SealCompilerModel.compile(
			SealProgramModel.compose(core, SealProgramModel.circuit(orbit, group, &"star", 2)),
			SealLimitsModel.profile(true)
		)
		var composed_four := SealCompilerModel.compile(
			SealProgramModel.compose(core, SealProgramModel.circuit(orbit, group, &"star", 4)),
			SealLimitsModel.profile(true)
		)
		_expect(composed_two["ok"] and composed_four["ok"], "equivalent stars wrapped by Compose should compile")
		if composed_two["ok"] and composed_four["ok"]:
			_expect(
				composed_two["plan"].command_snapshot() == composed_four["plan"].command_snapshot(),
				"Compose should derive center anchor identity from canonical child geometry"
			)
			_expect(
				_anchor_snapshot(composed_two["plan"]) == _anchor_snapshot(composed_four["plan"]),
				"Compose anchors should ignore equivalent Circuit operation metadata"
			)
	if adjacent["ok"] and reverse_adjacent["ok"]:
		_expect(
			adjacent["plan"].command_snapshot() == reverse_adjacent["plan"].command_snapshot(),
			"reverse adjacent traversal should canonicalize to the same visible edge set"
		)


func _test_compose_lifts_a_bare_field_to_the_outer_lane() -> void:
	var fixture := SealLabContentModel.fixtures()[6]
	var limits := SealLimitsModel.profile(false)
	var current := SealCompilerModel.compile(fixture["current"], limits)
	var swapped := SealCompilerModel.compile(fixture["hypothetical"], limits)
	_expect(current["ok"] and swapped["ok"], "Compose lane exchange fixtures should compile")
	if not current["ok"] or not swapped["ok"]:
		return
	_expect(_motif_radius(current["plan"], &"crescent") == 0, "current core Motif should remain centered")
	_expect(_motif_radius(current["plan"], &"fang") == 522, "current Orbit field should occupy the outer lane")
	_expect(_motif_radius(swapped["plan"], &"fang") == 193, "swapped Orbit should move into the core lane")
	_expect(_motif_radius(swapped["plan"], &"crescent") == 522, "a bare swapped field Motif should lift into the outer lane")


func _test_program_and_plan_accessors_do_not_alias_state() -> void:
	var child := SealProgramModel.motif(&"crescent")
	var program := SealProgramModel.boundary(&"circle", child)
	var serialization := program.stable_serialization()
	var parameters := program.parameters()
	parameters["shape"] = &"triangle"
	var children := program.children()
	children.clear()
	var child_parameters: Dictionary = program.child_at(0).parameters()
	child_parameters["ink_id"] = &"red"
	_expect(program.stable_serialization() == serialization, "Program accessors should not alias stored parameters or child arrays")

	var result := SealCompilerModel.compile(program, SealLimitsModel.profile(false))
	_expect(result["ok"], "alias test Program should compile")
	if not result["ok"]:
		return
	var snapshot: String = result["plan"].command_snapshot()
	var commands: Array = result["plan"].commands
	commands[0]["kind"] = &"corrupt"
	var anchors: Array = result["plan"].anchors
	anchors.clear()
	var metrics: Dictionary = result["plan"].metrics
	metrics["segments"] = 999999
	_expect(result["plan"].command_snapshot() == snapshot, "RenderPlan accessors should return owned copies")


func _test_limits_reject_invalid_programs_atomically() -> void:
	var deep = SealProgramModel.motif(&"crescent")
	for index in 4:
		deep = SealProgramModel.boundary(&"circle" if index % 2 == 0 else &"triangle", deep)
	var deep_result := SealCompilerModel.compile(deep, SealLimitsModel.profile(false))
	_expect(not deep_result["ok"], "MVP profile should reject AST depth five")
	_expect(deep_result["plan"] == null, "rejected depth should not expose a partial plan")

	var branch := SealProgramModel.motif(&"branch", 0, &"blue")
	var orbit := SealProgramModel.orbit(branch, 6, 0, &"outward")
	var missing_group := SealProgramModel.circuit(orbit, &"missing", &"star", 2)
	var group_result := SealCompilerModel.compile(missing_group, SealLimitsModel.profile(true))
	_expect(not group_result["ok"], "Circuit should reject a missing target group")
	_expect(group_result["plan"] == null, "missing group should not return a partial child plan")

	var invalid_step := SealProgramModel.circuit(
		orbit,
		SealProgramModel.orbit_group_key(branch, 6, 0, &"outward"),
		&"star",
		6
	)
	var step_result := SealCompilerModel.compile(invalid_step, SealLimitsModel.profile(true))
	_expect(not step_result["ok"], "Circuit should reject a star step outside its selected group")

	var invalid_scale := SealProgramModel.concentric(branch, 3, 999999999, 1000000000, 10)
	var scale_result := SealCompilerModel.compile(invalid_scale, SealLimitsModel.profile(true))
	_expect(not scale_result["ok"] and scale_result["plan"] == null, "Concentric should reject scales outside the fixed rational vocabulary")

	var cyclic := SealProgramModel.boundary(&"circle", branch)
	cyclic._children = [cyclic]
	var cycle_result := SealCompilerModel.compile(cyclic, SealLimitsModel.profile(true))
	_expect(not cycle_result["ok"] and cycle_result["plan"] == null, "cycle preflight should fail without recursive compilation")
	_expect("INVALID_CYCLE" in cyclic.stable_serialization(), "diagnostic serialization should terminate on a cycle")
	cyclic._children.clear()

	var oversized = SealProgramModel.motif(&"crescent")
	for _index in 100:
		oversized = SealProgramModel.boundary(&"circle", oversized)
	var bounded_limits := SealLimitsModel.profile(true)
	bounded_limits["max_depth"] = 200
	bounded_limits["max_nodes"] = 10
	var oversized_result := SealCompilerModel.compile(oversized, bounded_limits)
	_expect(not oversized_result["ok"], "preflight should reject an oversized restored tree")
	_expect(int(oversized_result["metrics"]["nodes"]) == 11, "preflight should stop immediately after the node cap")


func _test_metrics_match_renderer_geometry() -> void:
	for fixture in SealLabContentModel.fixtures():
		var result := SealCompilerModel.compile(
			fixture["current"],
			SealLimitsModel.profile(bool(fixture["hero"]))
		)
		if not result["ok"]:
			continue
		_expect(
			int(result["metrics"]["segments"]) == _expected_segments(result["plan"]),
			"fixture %s segment metrics should match emitted renderer geometry" % fixture["id"]
		)
		var exact_limits := SealLimitsModel.profile(bool(fixture["hero"]))
		exact_limits["max_work"] = int(result["metrics"]["work"])
		exact_limits["max_segments"] = int(result["metrics"]["segments"])
		_expect(
			SealCompilerModel.compile(fixture["current"], exact_limits)["ok"],
			"fixture %s should fit exact work and segment budgets" % fixture["id"]
		)
		var short_work_limits := exact_limits.duplicate(true)
		short_work_limits["max_work"] = int(result["metrics"]["work"]) - 1
		_expect(
			not SealCompilerModel.compile(fixture["current"], short_work_limits)["ok"],
			"fixture %s should fail one work below its measured cost" % fixture["id"]
		)
		var short_segment_limits := exact_limits.duplicate(true)
		short_segment_limits["max_segments"] = int(result["metrics"]["segments"]) - 1
		_expect(
			not SealCompilerModel.compile(fixture["current"], short_segment_limits)["ok"],
			"fixture %s should fail one segment below renderer geometry" % fixture["id"]
		)


func _test_lab_signatures_are_pairwise_distinct() -> void:
	var signatures: Dictionary = {}
	for fixture in SealLabContentModel.fixtures():
		var result := SealCompilerModel.compile(fixture["current"], SealLimitsModel.profile(bool(fixture["hero"])))
		if not result["ok"]:
			continue
		var signature: String = result["plan"].semantic_signature()
		_expect(not signatures.has(signature), "fixture %s should not collapse into fixture %s" % [fixture["id"], signatures.get(signature, "")])
		signatures[signature] = fixture["id"]
	_expect(signatures.size() == 10, "all ten fixture semantics should remain distinct")


func _count_kind(plan, kind: StringName) -> int:
	var count := 0
	for command in plan.commands:
		if StringName(command.get("kind", &"")) == kind:
			count += 1
	return count


func _first_value(plan, kind: StringName, key: String):
	for command in plan.commands:
		if StringName(command.get("kind", &"")) == kind:
			return command.get(key)
	return null


func _motif_radius(plan, motif_id: StringName) -> int:
	for command in plan.commands:
		if (
			StringName(command.get("kind", &"")) == &"motif"
			and StringName(command.get("motif_id", &"")) == motif_id
		):
			return int(command.get("center_radius", -1))
	return -1


func _expected_segments(plan) -> int:
	var total := 0
	for command in plan.commands:
		match StringName(command.get("kind", &"")):
			&"motif":
				total += SealMotifLibraryModel.segment_count(
					StringName(command.get("motif_id", &""))
				)
			&"boundary":
				total += (
					SealMotifLibraryModel.CIRCLE_SEGMENTS
					if StringName(command.get("shape", &"")) == &"circle"
					else SealMotifLibraryModel.TRIANGLE_SEGMENTS
				)
			&"orbit_signature":
				total += SealMotifLibraryModel.ORBIT_RING_SEGMENTS + int(command.get("count", 0))
			&"edge":
				total += 1
	return total


func _anchor_snapshot(plan) -> Array[String]:
	var values: Array[String] = []
	for anchor in plan.anchors:
		values.append(plan.stable_dictionary_key(anchor))
	values.sort()
	return values


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: " + message)
