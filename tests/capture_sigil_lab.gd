extends SceneTree

const SigilGraphModel := preload("res://experiments/sigil_lab/sigil_graph.gd")
const GlyphModel := preload("res://src/domain/glyph.gd")


func _initialize() -> void:
	var options := _user_options()
	var width := int(options.get("width", "1280"))
	var height := int(options.get("height", "720"))
	var output := String(options.get("output", "res://.sigil-lab-qa/sigil-lab.png"))
	var capture_viewport := SubViewport.new()
	capture_viewport.size = Vector2i(width, height)
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_viewport)
	var scene: PackedScene = load("res://experiments/sigil_lab/sigil_lab.tscn")
	var lab = scene.instantiate()
	capture_viewport.add_child(lab)
	await process_frame
	var fixture := String(options.get("fixture", ""))
	if fixture == "post_combine_move":
		_build_post_combine_move_fixture(lab)
	elif fixture == "coincident_child":
		_build_coincident_child_fixture(lab)
	elif fixture == "triangle":
		_build_triangle_fixture(lab)
	elif fixture == "transform_order":
		_build_transform_order_fixture(lab)
	elif fixture == "repeat":
		lab.load_repeat_template()
	elif fixture == "distribution":
		lab.load_distribution_template()
	elif fixture == "export":
		lab.export_button.pressed.emit()
	await process_frame
	await process_frame
	# Headless runs do not always emit frame_post_draw. Force the pending canvas
	# commands so QA capture cannot wait forever on a display-only signal.
	RenderingServer.force_draw(false)
	var image := capture_viewport.get_texture().get_image()
	if image == null:
		printerr("Sigil Lab capture requires a rendering driver")
		quit(1)
		return
	var error := image.save_png(output)
	if error == OK:
		print("Sigil Lab capture: %s (%dx%d)" % [output, image.get_width(), image.get_height()])
	else:
		printerr("Sigil Lab capture failed: %s" % error)
	quit(0 if error == OK else 1)


func _build_post_combine_move_fixture(lab) -> void:
	lab.clear_workspace()
	var circle: StringName = lab.add_lab_node(SigilGraphModel.SOURCE, {"primitive_id": &"circle"}, Vector2(30, 170))
	var triangle: StringName = lab.add_lab_node(SigilGraphModel.SOURCE, {"primitive_id": &"triangle"}, Vector2(30, 400))
	var left: StringName = lab.add_lab_node(SigilGraphModel.MOVE, {"offset": Vector2i(-3, 0)}, Vector2(200, 170))
	var right: StringName = lab.add_lab_node(SigilGraphModel.MOVE, {"offset": Vector2i(3, 0)}, Vector2(200, 400))
	var combine: StringName = lab.add_lab_node(SigilGraphModel.COMBINE, {}, Vector2(400, 245))
	var group_move: StringName = lab.add_lab_node(SigilGraphModel.MOVE, {"offset": Vector2i(0, -4)}, Vector2(610, 280))
	var output_id: StringName = lab.graph.output_node_id()
	lab.connect_lab_nodes(circle, left)
	lab.connect_lab_nodes(triangle, right)
	lab.connect_lab_nodes(left, combine, 0)
	lab.connect_lab_nodes(right, combine, 1)
	lab.connect_lab_nodes(combine, group_move)
	lab.connect_lab_nodes(group_move, output_id)


func _build_coincident_child_fixture(lab) -> void:
	lab.clear_workspace()
	var circle: StringName = lab.add_lab_node(SigilGraphModel.SOURCE, {"primitive_id": &"circle"}, Vector2(30, 170))
	var circle_move: StringName = lab.add_lab_node(SigilGraphModel.MOVE, {"offset": Vector2i(0, 4)}, Vector2(210, 170))
	var triangle: StringName = lab.add_lab_node(SigilGraphModel.SOURCE, {"primitive_id": &"triangle"}, Vector2(210, 410))
	var combine: StringName = lab.add_lab_node(SigilGraphModel.COMBINE, {}, Vector2(450, 240))
	var output_id: StringName = lab.graph.output_node_id()
	lab.connect_lab_nodes(circle, circle_move)
	lab.connect_lab_nodes(circle_move, combine, 0)
	lab.connect_lab_nodes(triangle, combine, 1)
	lab.connect_lab_nodes(combine, output_id)


func _build_triangle_fixture(lab) -> void:
	lab.clear_workspace()
	var combine: StringName = lab.add_lab_node(
		SigilGraphModel.COMBINE,
		{"connection_mode": GlyphModel.CONNECTION_PAIRWISE},
		Vector2(610, 245)
	)
	var output_id: StringName = lab.graph.output_node_id()
	for input_index in 3:
		var y := 85.0 + float(input_index) * 205.0
		var source: StringName = lab.add_lab_node(
			SigilGraphModel.SOURCE,
			{"primitive_id": &"triangle"},
			Vector2(20, y)
		)
		var move: StringName = lab.add_lab_node(
			SigilGraphModel.MOVE,
			{"offset": Vector2i(0, -4)},
			Vector2(190, y)
		)
		var rotate: StringName = lab.add_lab_node(
			SigilGraphModel.ROTATE,
			{"degrees": input_index * 120},
			Vector2(380, y)
		)
		lab.connect_lab_nodes(source, move)
		lab.connect_lab_nodes(move, rotate)
		lab.connect_lab_nodes(rotate, combine, input_index)
	lab.connect_lab_nodes(combine, output_id)


func _build_transform_order_fixture(lab) -> void:
	lab.clear_workspace()
	var square: StringName = lab.add_lab_node(
		SigilGraphModel.SOURCE,
		{"primitive_id": &"square"},
		Vector2(90, 250)
	)
	var stretch: StringName = lab.add_lab_node(
		SigilGraphModel.SCALE,
		{"x_percent": 200, "y_percent": 100},
		Vector2(300, 250)
	)
	var rotate: StringName = lab.add_lab_node(
		SigilGraphModel.ROTATE,
		{"degrees": 45},
		Vector2(540, 250)
	)
	var output_id: StringName = lab.graph.output_node_id()
	lab.connect_lab_nodes(square, stretch)
	lab.connect_lab_nodes(stretch, rotate)
	lab.connect_lab_nodes(rotate, output_id)


func _user_options() -> Dictionary:
	var result: Dictionary = {}
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--") or not "=" in argument:
			continue
		var parts := argument.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1]
	return result
