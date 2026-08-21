extends SceneTree

const SigilGraphModel := preload("res://experiments/sigil_lab/sigil_graph.gd")
const GlyphModel := preload("res://src/domain/glyph.gd")
const GlyphComponentModel := preload("res://src/domain/glyph_component.gd")
const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")

var failures := 0


func _initialize() -> void:
	_test_graph_evaluation()
	_test_basic_primitives_and_stretch()
	_test_eight_way_combine()
	_test_free_angle_triangle()
	_test_post_combine_move()
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


func _test_connection_guards() -> void:
	var graph = SigilGraphModel.new()
	graph.add_node(&"source", SigilGraphModel.SOURCE)
	graph.add_node(&"first", SigilGraphModel.ROTATE)
	graph.add_node(&"second", SigilGraphModel.ROTATE)
	graph.add_node(&"output", SigilGraphModel.OUTPUT)
	_expect(graph.connect_nodes(&"source", 0, &"first", 0), "first input should accept a source")
	_expect(not graph.connect_nodes(&"source", 0, &"first", 0) and graph.last_error == &"input_occupied", "occupied inputs should reject replacement without disconnect")
	_expect(graph.connect_nodes(&"first", 0, &"second", 0), "second processor should connect downstream")
	_expect(not graph.connect_nodes(&"second", 0, &"first", 0) and graph.last_error == &"input_occupied", "occupied input should remain protected before cycle evaluation")
	graph.disconnect_nodes(&"source", 0, &"first", 0)
	_expect(not graph.connect_nodes(&"second", 0, &"first", 0) and graph.last_error == &"cycle", "cycles should be rejected")
	_expect(not graph.add_node(&"other_output", SigilGraphModel.OUTPUT) and graph.last_error == &"output_exists", "only one completion node should exist")


func _test_owned_results() -> void:
	var graph = SigilGraphModel.new()
	graph.add_node(&"source", SigilGraphModel.SOURCE, {"primitive_id": &"circle"})
	graph.add_node(&"color", SigilGraphModel.COLOR, {"color_id": &"blue"})
	graph.add_node(&"output", SigilGraphModel.OUTPUT)
	graph.connect_nodes(&"source", 0, &"color", 0)
	graph.connect_nodes(&"color", 0, &"output", 0)
	var first := graph.evaluate_output()
	first["glyph"].recolor(&"red")
	var second := graph.evaluate_output()
	_expect(second["glyph"].components[0].color_id == &"blue", "returned Glyph mutations must not alter graph evaluation")
	graph.set_node_config(&"color", {"color_id": &"white"})
	_expect(graph.evaluate_output()["glyph"].components[0].color_id == &"white", "setting changes should immediately change output")


func _test_lab_scene() -> void:
	var scene: PackedScene = load("res://experiments/sigil_lab/sigil_lab.tscn")
	var lab = scene.instantiate()
	root.add_child(lab)
	await process_frame
	await process_frame
	_expect(lab.name == "SigilLab", "Sigil Lab scene should use the consistent product term")
	_expect(lab.graph_edit != null and lab.graph_edit.visible, "Sigil Lab should expose a connectable GraphEdit")
	_expect(lab.node_controls.size() == 5, "default eye template should stay readable and editable")
	var combine_id: StringName = &""
	for node_id in lab.graph.nodes:
		if lab.graph.node_kind(node_id) == SigilGraphModel.COMBINE:
			combine_id = node_id
			break
	_expect(combine_id != &"" and lab.graph.input_count(combine_id) == 8, "Lab Combine nodes should expose eight inputs")
	_expect(lab.option_controls[combine_id] is OptionButton and lab.option_controls[combine_id].item_count == 2, "Lab Combine should expose radial and pairwise modes")
	if lab.option_controls[combine_id] is OptionButton:
		var combine_option: OptionButton = lab.option_controls[combine_id]
		combine_option.select(1)
		combine_option.item_selected.emit(1)
		_expect(lab.graph.node_config(combine_id)["connection_mode"] == GlyphModel.CONNECTION_PAIRWISE, "changing the Combine option should update the graph output mode")
	var free_rotate: StringName = lab.add_lab_node(SigilGraphModel.ROTATE, {"degrees": 120}, Vector2(40, 40))
	_expect(lab.option_controls[free_rotate] is SpinBox, "Lab rotation should use a free-angle numeric control")
	if lab.option_controls[free_rotate] is SpinBox:
		var angle_control: SpinBox = lab.option_controls[free_rotate]
		_expect(angle_control.min_value == 0.0 and angle_control.max_value == 359.0 and angle_control.step == 1.0, "free-angle control should cover 0–359° in one-degree steps")
	var free_scale: StringName = lab.add_lab_node(SigilGraphModel.SCALE, {"x_percent": 200, "y_percent": 75}, Vector2(40, 40))
	var scale_control: Control = lab.option_controls[free_scale]
	_expect(scale_control.find_children("*", "SpinBox", true, false).size() == 2, "Lab stretch should expose independent horizontal and vertical controls")
	var output: Dictionary = lab.graph.evaluate_output()
	_expect(output["ok"] and output["glyph"].components.size() == 2, "default eye template should combine two basic circles")
	_expect(output["glyph"].combine_children.size() == 2, "default eye template should preserve its reusable two-part group")
	var has_ellipse := false
	for component in output["glyph"].components:
		if component.scale_x_percent == 250 and component.scale_y_percent == 100:
			has_ellipse = true
	_expect(has_ellipse, "default eye template should derive its outer ellipse from a stretched circle")
	_expect(lab.output_preview.glyph.canonical_serialization() == output["glyph"].canonical_serialization(), "large preview should show the actual graph output")
	lab.clear_workspace()
	await process_frame
	_expect(lab.graph.nodes.size() == 1 and not lab.graph.evaluate_output()["ok"], "clear should retain only an empty completion node")
	lab.load_cardinal_template()
	await process_frame
	_expect(lab.graph.evaluate_output()["ok"], "eye template should be reloadable after clearing")
	lab.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: " + message)
