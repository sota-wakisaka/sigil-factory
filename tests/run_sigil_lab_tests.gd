extends SceneTree

const SigilGraphModel := preload("res://experiments/sigil_lab/sigil_graph.gd")

var failures := 0


func _initialize() -> void:
	_test_graph_evaluation()
	_test_connection_guards()
	_test_owned_results()
	await _test_lab_scene()
	if failures == 0:
		print("All Sigil Lab tests passed.")
	quit(failures)


func _test_graph_evaluation() -> void:
	var graph = SigilGraphModel.new()
	_expect(graph.add_node(&"ring", SigilGraphModel.SOURCE, {"primitive_id": &"ring"}), "ring source should be accepted")
	_expect(graph.add_node(&"spike", SigilGraphModel.SOURCE, {"primitive_id": &"spike"}), "spike source should be accepted")
	_expect(graph.add_node(&"move", SigilGraphModel.MOVE, {"offset": Vector2i(0, -4)}), "move node should be accepted")
	_expect(graph.add_node(&"rotate", SigilGraphModel.ROTATE, {"steps": 1}), "rotate node should be accepted")
	_expect(graph.add_node(&"combine", SigilGraphModel.COMBINE), "combine node should be accepted")
	_expect(graph.add_node(&"output", SigilGraphModel.OUTPUT), "output node should be accepted")
	_expect(graph.connect_nodes(&"ring", 0, &"move", 0), "ring should connect to move")
	_expect(graph.connect_nodes(&"spike", 0, &"rotate", 0), "spike should connect to rotate")
	_expect(graph.connect_nodes(&"move", 0, &"combine", 0), "move should connect to combine A")
	_expect(graph.connect_nodes(&"rotate", 0, &"combine", 1), "rotate should connect to combine B")
	_expect(graph.connect_nodes(&"combine", 0, &"output", 0), "combine should connect to output")
	var result := graph.evaluate_output()
	_expect(result["ok"], "complete graph should produce a valid sigil")
	_expect(result["glyph"].components.size() == 2, "output should contain both source materials")
	_expect(result["glyph"].components[0].position == Vector2i(0, -4) or result["glyph"].components[1].position == Vector2i(0, -4), "move should be folded into the output Glyph")
	_expect(result["glyph"].components[0].rotation_step == 1 or result["glyph"].components[1].rotation_step == 1, "rotation should be folded into the output Glyph")


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
	graph.add_node(&"source", SigilGraphModel.SOURCE, {"primitive_id": &"ring"})
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
	_expect(lab.node_controls.size() >= 10, "default four-direction template should expose editable nodes")
	var output: Dictionary = lab.graph.evaluate_output()
	_expect(output["ok"] and output["glyph"].components.size() == 4, "default template should produce a four-material sigil")
	_expect(lab.output_preview.glyph.canonical_serialization() == output["glyph"].canonical_serialization(), "large preview should show the actual graph output")
	lab.clear_workspace()
	await process_frame
	_expect(lab.graph.nodes.size() == 1 and not lab.graph.evaluate_output()["ok"], "clear should retain only an empty completion node")
	lab.load_cardinal_template()
	await process_frame
	_expect(lab.graph.evaluate_output()["ok"], "template should be reloadable after clearing")
	lab.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: " + message)
