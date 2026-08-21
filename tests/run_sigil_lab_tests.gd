extends SceneTree

const SigilGraphModel := preload("res://experiments/sigil_lab/sigil_graph.gd")
const RegisteredGlyphsModel := preload("res://experiments/sigil_lab/registered_glyphs.gd")
const GlyphModel := preload("res://src/domain/glyph.gd")
const GlyphComponentModel := preload("res://src/domain/glyph_component.gd")
const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")

var failures := 0


func _initialize() -> void:
	_test_graph_evaluation()
	_test_basic_primitives_and_stretch()
	_test_registered_meaning_glyphs()
	_test_line_free_combine_requires_simple_mode()
	_test_pure_transform_composition()
	_test_radial_repeat()
	_test_direct_output_distribution()
	_test_eight_way_combine()
	_test_free_angle_triangle()
	_test_post_combine_move()
	_test_hidden_structure_overlay()
	_test_connection_guards()
	_test_owned_results()
	await _test_lab_scene()
	if failures == 0:
		print("All Sigil Lab tests passed.")
	quit(failures)


func _test_graph_evaluation() -> void:
	var graph = SigilGraphModel.new()
	_expect(graph.add_node(&"circle", SigilGraphModel.SOURCE, {"primitive_id": &"circle"}), "circle source should be accepted")
	_expect(graph.add_node(&"triangle", SigilGraphModel.SOURCE, {"primitive_id": &"triangle"}), "triangle source should be accepted")
	_expect(graph.add_node(&"move", SigilGraphModel.MOVE, {"offset": Vector2i(0, -4)}), "move node should be accepted")
	_expect(graph.add_node(&"rotate", SigilGraphModel.ROTATE, {"steps": 1}), "rotate node should be accepted")
	_expect(graph.add_node(&"combine", SigilGraphModel.COMBINE), "combine node should be accepted")
	_expect(graph.add_node(&"output", SigilGraphModel.OUTPUT), "output node should be accepted")
	_expect(graph.connect_nodes(&"circle", 0, &"move", 0), "circle should connect to move")
	_expect(graph.connect_nodes(&"triangle", 0, &"rotate", 0), "triangle should connect to rotate")
	_expect(graph.connect_nodes(&"move", 0, &"combine", 0), "move should connect to combine A")
	_expect(graph.connect_nodes(&"rotate", 0, &"combine", 1), "rotate should connect to combine B")
	_expect(graph.connect_nodes(&"combine", 0, &"output", 0), "combine should connect to output")
	var result := graph.evaluate_output()
	_expect(result["ok"], "complete graph should produce a valid sigil")
	_expect(result["glyph"].components.size() == 2, "output should contain both source materials")
	_expect(result["glyph"].components[0].position == Vector2(0, -4) or result["glyph"].components[1].position == Vector2(0, -4), "move should be folded into the output Glyph")
	_expect(result["glyph"].components[0].rotation_step == 1 or result["glyph"].components[1].rotation_step == 1, "rotation should be folded into the output Glyph")


func _test_basic_primitives_and_stretch() -> void:
	var graph = SigilGraphModel.new()
	_expect(SigilGraphModel.PRIMITIVES == [&"circle", &"triangle", &"square"], "Lab sources should expose only basic geometry")
	_expect(not graph.add_node(&"legacy", SigilGraphModel.SOURCE, {"primitive_id": &"ring"}), "Lab should not expose legacy semantic primitives")
	graph.add_node(&"circle", SigilGraphModel.SOURCE, {"primitive_id": &"circle"})
	graph.add_node(&"stretch", SigilGraphModel.SCALE, {"x_percent": 250, "y_percent": 75})
	graph.add_node(&"output", SigilGraphModel.OUTPUT)
	graph.connect_nodes(&"circle", 0, &"stretch", 0)
	graph.connect_nodes(&"stretch", 0, &"output", 0)
	var result := graph.evaluate_output()
	_expect(result["ok"], "a basic circle should support independent horizontal and vertical scaling")
	if result["ok"]:
		var component = result["glyph"].components[0]
		_expect(component.primitive_id == &"circle", "stretch should preserve the source primitive")
		_expect(component.scale_x_percent == 250 and component.scale_y_percent == 75, "stretch should fold both axes into the canonical component")
		_expect("|a250,75" in component.canonical_key(), "anisotropic scale should be part of matching identity")


func _test_registered_meaning_glyphs() -> void:
	var expected_canonicals := {
		RegisteredGlyphsModel.EYE: "S(3:0,0;39:P(33:p6:circle|0,0|0|1|c5:white|a50,50),40:P(34:p6:circle|0,0|0|1|c5:white|a100,50))",
		RegisteredGlyphsModel.CROSS: "S(3:0,0;40:P(34:p6:square|0,0|0|1|c5:white|a100,25),40:P(34:p6:square|0,0|0|1|c5:white|a25,100))",
		RegisteredGlyphsModel.TARGET: "S(3:0,0;39:P(33:p6:circle|0,0|0|1|c5:white|a50,50),32:P(26:p6:circle|0,0|0|1|c5:white))",
		RegisteredGlyphsModel.STAR: "S(3:0,0;34:P(28:p8:triangle|0,0|0|1|c5:white),35:P(29:p8:triangle|0,0|60|1|c5:white))",
		RegisteredGlyphsModel.COMPASS: "S(3:0,0;96:S(3:0,0;40:P(34:p6:square|0,0|0|1|c5:white|a100,25),40:P(34:p6:square|0,0|0|1|c5:white|a25,100)),98:S(3:0,0;41:P(35:p6:square|0,0|45|1|c5:white|a100,25),41:P(35:p6:square|0,0|45|1|c5:white|a25,100)))",
	}
	var seen_canonicals: Dictionary = {}
	_expect(RegisteredGlyphsModel.IDS.size() == 5, "the initial meaning-Glyph set should stay intentionally small")
	for glyph_id in RegisteredGlyphsModel.IDS:
		var glyph := RegisteredGlyphsModel.glyph(glyph_id)
		_expect(glyph != null, "%s should be available as a registered meaning Glyph" % glyph_id)
		if glyph == null:
			continue
		var expected_canonical: String = expected_canonicals[glyph_id]
		_expect(glyph.canonical_serialization() == expected_canonical, "%s should preserve its authored canonical structure" % glyph_id)
		_expect(glyph.combine_connection_mode == GlyphModel.CONNECTION_SIMPLE, "%s should use line-free Simple Combine" % glyph_id)
		_expect(GlyphPainterModel.combine_visuals(glyph, 1.0, false)["connections"].is_empty(), "%s should not invent connector lines" % glyph_id)
		var maximum_size_percent := 0
		for component in glyph.components:
			maximum_size_percent = maxi(
				maximum_size_percent,
				maxi(component.scale_x_percent, component.scale_y_percent)
			)
		_expect(maximum_size_percent == RegisteredGlyphsModel.NOMINAL_SIZE_PERCENT, "%s should share the registered Glyph nominal size" % glyph_id)
		_expect(not seen_canonicals.has(expected_canonical), "%s should remain visually and canonically distinct" % glyph_id)
		seen_canonicals[expected_canonical] = true
		var graph_text := FileAccess.get_file_as_string(
			RegisteredGlyphsModel.source_graph_path(glyph_id)
		)
		var graph_document = JSON.parse_string(graph_text)
		_expect(graph_document is Dictionary, "%s should retain its authored Lab graph" % glyph_id)
		if graph_document is Dictionary:
			_expect(graph_document["canonical_glyph"] == expected_canonical, "%s graph and registry entry should share one identity" % glyph_id)
			_expect(graph_document["nodes"].size() >= 4 and graph_document["connections"].size() >= 4, "%s graph should retain its complete construction" % glyph_id)
	var graph = SigilGraphModel.new()
	_expect(graph.add_node(&"cross", SigilGraphModel.REGISTERED, {"glyph_id": RegisteredGlyphsModel.CROSS}), "a registered Cross source should be accepted")
	_expect(graph.add_node(&"rotate", SigilGraphModel.ROTATE, {"degrees": 45}), "registered Glyphs should accept downstream transforms")
	_expect(graph.add_node(&"output", SigilGraphModel.OUTPUT), "registered Glyphs should connect to completion")
	graph.connect_nodes(&"cross", 0, &"rotate", 0)
	graph.connect_nodes(&"rotate", 0, &"output", 0)
	var rotated := graph.evaluate_output()
	_expect(rotated["ok"] and rotated["glyph"].components.size() == 2, "the registered Cross should remain a reusable two-part Glyph")
	_expect(not graph.add_node(&"unknown", SigilGraphModel.REGISTERED, {"glyph_id": &"unknown"}), "unknown registered Glyph IDs should fail closed")


func _test_line_free_combine_requires_simple_mode() -> void:
	var graph = SigilGraphModel.new()
	graph.add_node(&"square_a", SigilGraphModel.SOURCE, {"primitive_id": &"square"})
	graph.add_node(&"square_b", SigilGraphModel.SOURCE, {"primitive_id": &"square"})
	graph.add_node(&"horizontal", SigilGraphModel.SCALE, {"x_percent": 200, "y_percent": 50})
	graph.add_node(&"vertical", SigilGraphModel.SCALE, {"x_percent": 50, "y_percent": 200})
	graph.add_node(&"combine", SigilGraphModel.COMBINE, {"connection_mode": GlyphModel.CONNECTION_RADIAL})
	graph.add_node(&"output", SigilGraphModel.OUTPUT)
	graph.connect_nodes(&"square_a", 0, &"horizontal", 0)
	graph.connect_nodes(&"square_b", 0, &"vertical", 0)
	graph.connect_nodes(&"horizontal", 0, &"combine", 0)
	graph.connect_nodes(&"vertical", 0, &"combine", 1)
	graph.connect_nodes(&"combine", 0, &"output", 0)
	var availability := graph.combine_mode_availability(&"combine")
	_expect(availability["complete"], "two centered Cross parts should make Combine mode availability decidable")
	_expect(availability["modes"][GlyphModel.CONNECTION_SIMPLE], "Simple Combine should remain available for centered parts")
	_expect(not availability["modes"][GlyphModel.CONNECTION_RADIAL], "Radial Combine should be disabled when it draws no line")
	_expect(not availability["modes"][GlyphModel.CONNECTION_PAIRWISE], "Pairwise Combine should be disabled when it draws no line")
	_expect(not graph.evaluate_output()["ok"], "a stale line mode should not silently produce a line-free Combine")
	_expect(graph.enforce_combine_connection_modes() == [&"combine"], "line-free inputs should normalize the editor node to Simple Combine")
	_expect(graph.node_config(&"combine")["connection_mode"] == GlyphModel.CONNECTION_SIMPLE, "the normalized Cross should explicitly retain Simple Combine")
	_expect(graph.evaluate_output()["ok"], "the same Cross should evaluate after selecting Simple Combine")
	_expect(not graph.set_node_config(&"combine", {"connection_mode": GlyphModel.CONNECTION_RADIAL}), "a user should not be able to reselect an invisible Radial Combine")
	_expect(graph.last_error == &"connection_mode_requires_visible_lines", "the rejected line mode should explain why Simple Combine is required")


func _test_pure_transform_composition() -> void:
	var source := GlyphModel.new([GlyphComponentModel.new(&"square")])
	var stretched := source.stretched_percent(200, 100)
	var rotated := stretched.rotated_degrees(45)
	var source_component: GlyphComponentModel = source.components[0]
	var stretched_component: GlyphComponentModel = stretched.components[0]
	var rotated_component: GlyphComponentModel = rotated.components[0]
	_expect(
		source_component.scale_x_percent == 100
		and source_component.scale_y_percent == 100
		and source_component.rotation_degrees == 0,
		"a transform should not mutate its input Glyph"
	)
	_expect(
		stretched_component.scale_x_percent == 200
		and stretched_component.scale_y_percent == 100
		and stretched_component.rotation_degrees == 0,
		"stretch should return a new anisotropic Glyph before rotation"
	)
	_expect(
		rotated_component.scale_x_percent == 200
		and rotated_component.scale_y_percent == 100
		and rotated_component.rotation_degrees == 45,
		"rotation should preserve the stretched rectangle and rotate it as a whole"
	)
	_expect(
		source.canonical_serialization() != stretched.canonical_serialization()
		and stretched.canonical_serialization() != rotated.canonical_serialization(),
		"each pure transform stage should produce its own canonical Glyph data"
	)
	var rectangle_points := GlyphPainterModel.basic_outline_points(
		Vector2.ZERO,
		10.0,
		5.0,
		PI * 0.25,
		PI * 0.25,
		4
	)
	var long_edge := rectangle_points[0].distance_to(rectangle_points[1])
	var short_edge := rectangle_points[1].distance_to(rectangle_points[2])
	_expect(
		long_edge > short_edge * 1.9,
		"drawing should stretch the square into a rectangle before rotating the complete outline"
	)


func _test_radial_repeat() -> void:
	var graph = SigilGraphModel.new()
	graph.add_node(&"triangle", SigilGraphModel.SOURCE, {"primitive_id": &"triangle"})
	graph.add_node(&"move", SigilGraphModel.MOVE, {"offset": Vector2i(0, -4)})
	graph.add_node(&"repeat", SigilGraphModel.REPEAT, {"count": 6})
	graph.add_node(&"output", SigilGraphModel.OUTPUT)
	graph.connect_nodes(&"triangle", 0, &"move", 0)
	graph.connect_nodes(&"move", 0, &"repeat", 0)
	graph.connect_nodes(&"repeat", 0, &"output", 0)
	var result := graph.evaluate_output()
	_expect(result["ok"], "a moved basic shape should repeat around the shared origin")
	if result["ok"]:
		var glyph = result["glyph"]
		_expect(glyph.components.size() == 6, "repeat count should include the original and five rotated copies")
		_expect(glyph.combine_children.size() == 6, "each repeated copy should remain a reusable child group")
		_expect(glyph.combine_connection_mode == GlyphModel.CONNECTION_NONE, "repeat should not invent visible connector lines")
		_expect(GlyphPainterModel.combine_visuals(glyph, 1.0, false)["connections"].is_empty(), "hidden repeat grouping should leave only repeated geometry")
		var positions: Dictionary = {}
		for component in glyph.components:
			positions[component.canonical_key()] = true
			_expect(absf(component.position.length() - 4.0) < 0.002, "each repeat should stay on the same radius")
		_expect(positions.size() == 6, "six-way repeat should create six distinct canonical placements")
	_expect(not graph.add_node(&"invalid_repeat", SigilGraphModel.REPEAT, {"count": 7}), "non-integral degree partitions should be rejected")
	var centered := SigilGraphModel.new()
	centered.add_node(&"circle", SigilGraphModel.SOURCE, {"primitive_id": &"circle"})
	centered.add_node(&"repeat", SigilGraphModel.REPEAT, {"count": 6})
	centered.add_node(&"output", SigilGraphModel.OUTPUT)
	centered.connect_nodes(&"circle", 0, &"repeat", 0)
	centered.connect_nodes(&"repeat", 0, &"output", 0)
	var centered_result := centered.evaluate_output()
	_expect(centered_result["ok"], "rotationally identical centered copies should normalize to a valid no-op")
	if centered_result["ok"]:
		_expect(centered_result["glyph"].components.size() == 1, "a no-op repeat should keep one visible component")
		_expect(centered_result["glyph"].combine_children.is_empty(), "a no-op repeat should not invent an invisible Combine layer")

	var rectangle := GlyphModel.new([GlyphComponentModel.new(
		&"square",
		Vector2.ZERO,
		0,
		1,
		&"white",
		0,
		200,
		100
	)])
	var repeated_rectangle := GlyphModel.radial_repeat(rectangle, 4)
	_expect(repeated_rectangle != null, "a centered anisotropic rectangle should support rotational repeat")
	if repeated_rectangle != null:
		_expect(repeated_rectangle.components.size() == 2, "repeat should retain only the two distinct crossed rectangle orientations")
		_expect(repeated_rectangle.structure_validation_errors().is_empty(), "normalized repeated orientations should remain structurally valid")


func _test_direct_output_distribution() -> void:
	var graph = SigilGraphModel.new()
	graph.add_node(&"source", SigilGraphModel.SOURCE, {"primitive_id": &"square"})
	graph.add_node(&"up", SigilGraphModel.MOVE, {"offset": Vector2i(0, -4)})
	graph.add_node(&"right", SigilGraphModel.MOVE, {"offset": Vector2i(4, 0)})
	graph.add_node(&"combine", SigilGraphModel.COMBINE)
	graph.add_node(&"output", SigilGraphModel.OUTPUT)
	_expect(graph.connect_nodes(&"source", 0, &"up", 0), "source output should connect directly to its first branch")
	_expect(graph.connect_nodes(&"source", 0, &"right", 0), "the same source output should connect directly to another branch")
	_expect(graph.connect_nodes(&"up", 0, &"combine", 0), "first branch should reconnect to Combine")
	_expect(graph.connect_nodes(&"right", 0, &"combine", 1), "second branch should reconnect to Combine")
	_expect(graph.connect_nodes(&"combine", 0, &"output", 0), "direct branches should reach output")
	var result := graph.evaluate_output()
	_expect(result["ok"] and result["glyph"].components.size() == 2, "direct output branches should evaluate as independent Glyph copies")
	if result["ok"]:
		var positions: Array = []
		for component in result["glyph"].components:
			positions.append(component.position)
		_expect(positions.has(Vector2(0, -4)) and positions.has(Vector2(4, 0)), "each direct branch should keep its own transform")


func _test_eight_way_combine() -> void:
	var graph = SigilGraphModel.new()
	graph.add_node(&"combine", SigilGraphModel.COMBINE, {"connection_mode": GlyphModel.CONNECTION_PAIRWISE})
	graph.add_node(&"output", SigilGraphModel.OUTPUT)
	for input_index in SigilGraphModel.MAX_COMBINE_INPUTS:
		var source_id := StringName("source_%d" % input_index)
		var move_id := StringName("move_%d" % input_index)
		var rotate_id := StringName("rotate_%d" % input_index)
		graph.add_node(source_id, SigilGraphModel.SOURCE, {
			"primitive_id": [&"circle", &"triangle", &"square"][input_index % 3],
		})
		graph.add_node(move_id, SigilGraphModel.MOVE, {"offset": Vector2i(0, -4)})
		graph.add_node(rotate_id, SigilGraphModel.ROTATE, {"degrees": input_index * 45})
		_expect(graph.connect_nodes(source_id, 0, move_id, 0), "eight-way source should connect to its cardinal move node")
		_expect(graph.connect_nodes(move_id, 0, rotate_id, 0), "each branch should rotate around the shared center")
		_expect(graph.connect_nodes(rotate_id, 0, &"combine", input_index), "each of the eight Combine ports should accept one input")
	_expect(graph.connect_nodes(&"combine", 0, &"output", 0), "eight-way Combine should connect to output")
	var result := graph.evaluate_output()
	_expect(result["ok"], "eight connected inputs should produce a valid sigil")
	_expect(result["glyph"].combine_children.size() == 8, "eight-way Combine should preserve all children in one level")


func _test_free_angle_triangle() -> void:
	var graph = SigilGraphModel.new()
	graph.add_node(&"combine", SigilGraphModel.COMBINE, {"connection_mode": GlyphModel.CONNECTION_PAIRWISE})
	graph.add_node(&"output", SigilGraphModel.OUTPUT)
	for input_index in 3:
		var source_id := StringName("triangle_source_%d" % input_index)
		var move_id := StringName("triangle_move_%d" % input_index)
		var rotate_id := StringName("triangle_rotate_%d" % input_index)
		graph.add_node(source_id, SigilGraphModel.SOURCE, {"primitive_id": &"triangle"})
		graph.add_node(move_id, SigilGraphModel.MOVE, {"offset": Vector2i(0, -4)})
		graph.add_node(rotate_id, SigilGraphModel.ROTATE, {"degrees": input_index * 120})
		graph.connect_nodes(source_id, 0, move_id, 0)
		graph.connect_nodes(move_id, 0, rotate_id, 0)
		graph.connect_nodes(rotate_id, 0, &"combine", input_index)
	graph.connect_nodes(&"combine", 0, &"output", 0)
	var result := graph.evaluate_output()
	_expect(result["ok"], "cardinal movement plus free-angle rotation should form a triangle")
	if result["ok"]:
		_expect(result["glyph"].combine_connection_mode == GlyphModel.CONNECTION_PAIRWISE, "Lab should preserve the selected pairwise connection mode")
		_expect(GlyphPainterModel.combine_visuals(result["glyph"])["connections"].size() == 3, "pairwise triangle should connect each child without a center spoke")
		var positions: Array[String] = []
		for component in result["glyph"].components:
			positions.append("%s,%s" % [
				GlyphComponentModel.coordinate_key(component.position.x),
				GlyphComponentModel.coordinate_key(component.position.y),
			])
		positions.sort()
		_expect(positions == ["-3.464,2", "0,-4", "3.464,2"], "120° rotations should place the three points symmetrically")
		_expect(not graph.add_node(&"diagonal", SigilGraphModel.MOVE, {"offset": Vector2i(3, 3)}), "a single Move node should reject diagonal movement")


func _test_post_combine_move() -> void:
	var graph = SigilGraphModel.new()
	graph.add_node(&"circle", SigilGraphModel.SOURCE, {"primitive_id": &"circle"})
	graph.add_node(&"triangle", SigilGraphModel.SOURCE, {"primitive_id": &"triangle"})
	graph.add_node(&"left", SigilGraphModel.MOVE, {"offset": Vector2i(-2, 0)})
	graph.add_node(&"right", SigilGraphModel.MOVE, {"offset": Vector2i(2, 0)})
	graph.add_node(&"combine", SigilGraphModel.COMBINE)
	graph.add_node(&"group_move", SigilGraphModel.MOVE, {"offset": Vector2i(0, -4)})
	graph.add_node(&"output", SigilGraphModel.OUTPUT)
	graph.connect_nodes(&"circle", 0, &"left", 0)
	graph.connect_nodes(&"triangle", 0, &"right", 0)
	graph.connect_nodes(&"left", 0, &"combine", 0)
	graph.connect_nodes(&"right", 0, &"combine", 1)
	graph.connect_nodes(&"combine", 0, &"group_move", 0)
	graph.connect_nodes(&"group_move", 0, &"output", 0)
	var result := graph.evaluate_output()
	_expect(result["ok"], "a moved completed group should remain a valid Lab output")
	_expect(result["glyph"].combine_origin == Vector2(0, -4), "Lab Move should carry the completed Combine center with it")


func _test_hidden_structure_overlay() -> void:
	var first := GlyphModel.new([GlyphComponentModel.new(&"circle", Vector2(-3, 0))])
	var second := GlyphModel.new([GlyphComponentModel.new(&"square", Vector2(3, 0))])
	var combined := GlyphModel.combine(first, second, GlyphModel.CONNECTION_RADIAL)
	var final_visuals := GlyphPainterModel.combine_visuals(combined, 1.0, false)
	var editing_visuals := GlyphPainterModel.combine_visuals(combined, 1.0, true)
	_expect(final_visuals["circles"].is_empty(), "finished Lab art should not contain automatic hierarchy circles")
	_expect(final_visuals["connections"].size() == 2, "hiding hierarchy should preserve deliberately selected connection geometry")
	_expect(editing_visuals["circles"].size() == 1, "editing overlay should still reveal the Combine group boundary")


func _test_connection_guards() -> void:
	var graph = SigilGraphModel.new()
	graph.add_node(&"source", SigilGraphModel.SOURCE)
	graph.add_node(&"first", SigilGraphModel.ROTATE)
	graph.add_node(&"second", SigilGraphModel.ROTATE)
	graph.add_node(&"output", SigilGraphModel.OUTPUT)
	_expect(graph.connect_nodes(&"source", 0, &"first", 0), "first input should accept a source")
	_expect(not graph.connect_nodes(&"source", 0, &"first", 0) and graph.last_error == &"input_occupied", "occupied inputs should reject replacement without disconnect")
	_expect(graph.connect_nodes(&"source", 0, &"second", 0), "ordinary outputs should support direct branching")
	graph.disconnect_nodes(&"source", 0, &"second", 0)
	_expect(graph.connect_nodes(&"first", 0, &"second", 0), "second processor should connect downstream")
	_expect(not graph.connect_nodes(&"second", 0, &"first", 0) and graph.last_error == &"input_occupied", "occupied input should remain protected before cycle evaluation")
	graph.disconnect_nodes(&"source", 0, &"first", 0)
	_expect(not graph.connect_nodes(&"second", 0, &"first", 0) and graph.last_error == &"cycle", "cycles should be rejected")
	_expect(not graph.add_node(&"other_output", SigilGraphModel.OUTPUT) and graph.last_error == &"output_exists", "only one completion node should exist")


func _test_owned_results() -> void:
	var graph = SigilGraphModel.new()
	graph.add_node(&"source", SigilGraphModel.SOURCE, {"primitive_id": &"circle"})
	graph.add_node(&"scale", SigilGraphModel.SCALE, {"x_percent": 200, "y_percent": 100})
	graph.add_node(&"output", SigilGraphModel.OUTPUT)
	graph.connect_nodes(&"source", 0, &"scale", 0)
	graph.connect_nodes(&"scale", 0, &"output", 0)
	var first := graph.evaluate_output()
	first["glyph"].stretch_percent(200, 200)
	var second := graph.evaluate_output()
	_expect(second["glyph"].components[0].scale_x_percent == 200, "returned Glyph mutations must not alter graph evaluation")
	graph.set_node_config(&"scale", {"x_percent": 150, "y_percent": 100})
	_expect(graph.evaluate_output()["glyph"].components[0].scale_x_percent == 150, "setting changes should immediately change output")


func _test_lab_scene() -> void:
	var scene: PackedScene = load("res://experiments/sigil_lab/sigil_lab.tscn")
	var lab = scene.instantiate()
	root.add_child(lab)
	await process_frame
	await process_frame
	_expect(lab.name == "SigilLab", "Sigil Lab scene should use the consistent product term")
	_expect(lab.graph_edit != null and lab.graph_edit.visible, "Sigil Lab should expose a connectable GraphEdit")
	_expect(not lab.export_dialog.visible, "graph export dialog should stay hidden when the Lab opens")
	_expect(lab.node_controls.size() == 5, "default eye template should stay readable and editable")
	_expect(not lab.structure_button.button_pressed and not lab.output_preview.show_structure, "finished preview should hide hierarchy by default")
	lab.structure_button.button_pressed = true
	lab.structure_button.toggled.emit(true)
	_expect(lab.output_preview.show_structure, "hierarchy toggle should reveal the editing overlay on demand")
	lab.structure_button.button_pressed = false
	lab.structure_button.toggled.emit(false)
	var combine_id: StringName = &""
	for node_id in lab.graph.nodes:
		if lab.graph.node_kind(node_id) == SigilGraphModel.COMBINE:
			combine_id = node_id
			break
	_expect(combine_id != &"" and lab.graph.input_count(combine_id) == 8, "Lab Combine nodes should expose eight inputs")
	_expect(lab.option_controls[combine_id] is OptionButton and lab.option_controls[combine_id].item_count == 3, "Lab Combine should expose simple, radial, and pairwise modes")
	if lab.option_controls[combine_id] is OptionButton:
		var combine_option: OptionButton = lab.option_controls[combine_id]
		_expect(combine_option.selected == 0, "the centered eye template should normalize to Simple Combine")
		_expect(combine_option.is_item_disabled(1) and combine_option.is_item_disabled(2), "line-free inputs should disable radial and pairwise choices")
	var free_rotate: StringName = lab.add_lab_node(SigilGraphModel.ROTATE, {"degrees": 120}, Vector2(40, 40))
	_expect(lab.option_controls[free_rotate] is SpinBox, "Lab rotation should use a free-angle numeric control")
	if lab.option_controls[free_rotate] is SpinBox:
		var angle_control: SpinBox = lab.option_controls[free_rotate]
		_expect(angle_control.min_value == 0.0 and angle_control.max_value == 359.0 and angle_control.step == 1.0, "free-angle control should cover 0–359° in one-degree steps")
	var free_scale: StringName = lab.add_lab_node(SigilGraphModel.SCALE, {"x_percent": 200, "y_percent": 75}, Vector2(40, 40))
	var scale_control: Control = lab.option_controls[free_scale]
	_expect(scale_control.find_children("*", "SpinBox", true, false).size() == 2, "Lab stretch should expose independent horizontal and vertical controls")
	var free_repeat: StringName = lab.add_lab_node(SigilGraphModel.REPEAT, {"count": 6}, Vector2(40, 40))
	_expect(lab.option_controls[free_repeat] is OptionButton and lab.option_controls[free_repeat].item_count == 6, "Lab repeat should expose all exact equal-angle counts")
	var registered_cross: StringName = lab.add_lab_node(SigilGraphModel.REGISTERED, {"glyph_id": RegisteredGlyphsModel.CROSS}, Vector2(40, 40))
	_expect(lab.option_controls[registered_cross] is OptionButton and lab.option_controls[registered_cross].item_count == 5, "all authored meaning Glyphs should be reusable from one compact palette node")
	if lab.option_controls[registered_cross] is OptionButton:
		var registered_option: OptionButton = lab.option_controls[registered_cross]
		_expect(registered_option.get_item_text(0) == "目" and registered_option.get_item_text(4) == "方位", "meaning-Glyph choices should follow the documented learning order")
	_expect(not SigilGraphModel.NODE_KINDS.has(&"distribute"), "Distributor should be removed from the Lab grammar")
	_expect(not SigilGraphModel.NODE_KINDS.has(&"color"), "color processing should be omitted from the Lab grammar")
	var output: Dictionary = lab.graph.evaluate_output()
	_expect(output["ok"] and output["glyph"].components.size() == 2, "default eye template should combine two basic circles")
	_expect(output["glyph"].combine_children.size() == 2, "default eye template should preserve its reusable two-part group")
	var has_ellipse := false
	for component in output["glyph"].components:
		if component.scale_x_percent == 250 and component.scale_y_percent == 100:
			has_ellipse = true
	_expect(has_ellipse, "default eye template should derive its outer ellipse from a stretched circle")
	_expect(lab.output_preview.glyph.canonical_serialization() == output["glyph"].canonical_serialization(), "large preview should show the actual graph output")
	var export_document: String = lab.export_graph_text()
	var export_data = JSON.parse_string(export_document)
	_expect(not export_document.is_empty() and export_data is Dictionary, "completed Lab graphs should export as JSON text")
	if export_data is Dictionary:
		_expect(export_data["format"] == "sigil_lab_graph" and int(export_data["version"]) == 1, "export should identify its stable graph format version")
		_expect(export_data["canonical_glyph"] == output["glyph"].canonical_serialization(), "export should include the exact completed Glyph identity")
		_expect(export_data["nodes"].size() == 9 and export_data["connections"].size() == 4, "export should preserve every node on the canvas, including registered Glyph work")
		var exported_source_found := false
		for exported_node in export_data["nodes"]:
			_expect(exported_node["position"] is Array and exported_node["position"].size() == 2, "exported nodes should preserve their editor positions")
			if exported_node["kind"] == "source":
				exported_source_found = true
				_expect(exported_node["config"]["primitive_id"] is String, "StringName settings should become portable JSON strings")
		_expect(exported_source_found, "export should retain basic source nodes")
	_expect(export_document == lab.export_graph_text(), "unchanged Lab graphs should produce byte-stable export text")
	_expect(not lab.export_button.disabled, "text export should be enabled for a completed Sigil")
	lab.export_button.pressed.emit()
	await process_frame
	_expect(lab.export_dialog.visible and lab.export_text.text == export_document, "text export button should open the completed JSON in a selectable dialog")
	lab.export_dialog.hide()
	lab.clear_workspace()
	await process_frame
	_expect(lab.graph.nodes.size() == 1 and not lab.graph.evaluate_output()["ok"], "clear should retain only an empty completion node")
	_expect(lab.export_graph_text().is_empty() and lab.export_button.disabled, "incomplete graphs should not export misleading text")
	lab.load_cardinal_template()
	await process_frame
	_expect(lab.graph.evaluate_output()["ok"], "eye template should be reloadable after clearing")
	lab.load_repeat_template()
	await process_frame
	var repeat_output: Dictionary = lab.graph.evaluate_output()
	_expect(repeat_output["ok"] and repeat_output["glyph"].components.size() == 7, "six-flower template should combine six repeated triangles with one basic circle")
	lab.load_distribution_template()
	await process_frame
	var distribution_output: Dictionary = lab.graph.evaluate_output()
	_expect(distribution_output["ok"] and distribution_output["glyph"].components.size() == 4, "branching template should send one square output directly into four independent moves")
	_expect(lab.graph.connections.size() == 9, "direct fan-out should retain all four source lines in the model")
	_expect(lab.graph_edit.get_connection_list().size() == 9, "direct fan-out should retain all four source lines in GraphEdit")

	# Reproduce the reported Cross graph. Completion must accept a drop anywhere
	# on its body, not only on the small input dot.
	lab.clear_workspace()
	var cross_source: StringName = lab.add_lab_node(
		SigilGraphModel.SOURCE,
		{"primitive_id": &"square"},
		Vector2(40, 220)
	)
	var cross_horizontal: StringName = lab.add_lab_node(
		SigilGraphModel.SCALE,
		{"x_percent": 200, "y_percent": 50},
		Vector2(220, 140)
	)
	var cross_vertical: StringName = lab.add_lab_node(
		SigilGraphModel.SCALE,
		{"x_percent": 50, "y_percent": 200},
		Vector2(220, 330)
	)
	var cross_combine: StringName = lab.add_lab_node(
		SigilGraphModel.COMBINE,
		{},
		Vector2(440, 200)
	)
	var cross_output: StringName = lab.graph.output_node_id()
	await process_frame
	await _drag_graph_connection(lab, cross_source, cross_horizontal)
	await _drag_graph_connection(lab, cross_source, cross_vertical)
	await _drag_graph_connection(lab, cross_horizontal, cross_combine, 0, 0)
	await _drag_graph_connection(lab, cross_vertical, cross_combine, 0, 1)
	var cross_result: Dictionary = lab.graph.evaluate(cross_combine)
	_expect(cross_result["ok"] and cross_result["glyph"].components.size() == 2, "two stretched squares should form a valid Cross intermediate Glyph")
	var output_node: GraphNode = lab.node_controls[cross_output]
	_expect(
		StringName(output_node.name) == cross_output,
		"workspace reset should preserve the model ID as the GraphNode name"
	)
	_expect(lab.completion_buttons[cross_combine] is Button, "each result node should expose an explicit completion action")
	lab.completion_buttons[cross_combine].pressed.emit()
	await process_frame
	_expect(lab.graph.evaluate_output()["ok"], "the explicit completion action should finish the Cross without port dragging")
	_expect(not lab.export_graph_text().is_empty() and not lab.export_button.disabled, "a completed Cross should be available for text export")
	lab.free()


func _drag_graph_connection(
	lab,
	from_node_id: StringName,
	to_node_id: StringName,
	from_port: int = 0,
	to_port: int = 0
) -> void:
	var from_node: GraphNode = lab.node_controls[from_node_id]
	var to_node: GraphNode = lab.node_controls[to_node_id]
	var from_position := (
		from_node.global_position
		+ from_node.get_output_port_position(from_port) * from_node.scale
	)
	var to_position := (
		to_node.global_position
		+ to_node.get_input_port_position(to_port) * to_node.scale
		+ Vector2(18.0, 6.0)
	)
	_send_mouse_motion(from_position, Vector2.ZERO, false)
	_send_mouse_button(from_position, true)
	await process_frame
	_send_mouse_motion(to_position, to_position - from_position, true)
	await process_frame
	_send_mouse_button(to_position, false)
	await process_frame


func _send_mouse_motion(position: Vector2, relative: Vector2, dragging: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if dragging else 0
	root.push_input(event, true)


func _send_mouse_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: " + message)
