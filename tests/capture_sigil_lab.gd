extends SceneTree

const SigilGraphModel := preload("res://experiments/sigil_lab/sigil_graph.gd")


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
	if options.get("fixture", "") == "post_combine_move":
		_build_post_combine_move_fixture(lab)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := capture_viewport.get_texture().get_image()
	var error := image.save_png(output)
	if error == OK:
		print("Sigil Lab capture: %s (%dx%d)" % [output, image.get_width(), image.get_height()])
	else:
		printerr("Sigil Lab capture failed: %s" % error)
	quit(0 if error == OK else 1)


func _build_post_combine_move_fixture(lab) -> void:
	lab.clear_workspace()
	var ring: StringName = lab.add_lab_node(SigilGraphModel.SOURCE, {"primitive_id": &"ring"}, Vector2(30, 170))
	var spike: StringName = lab.add_lab_node(SigilGraphModel.SOURCE, {"primitive_id": &"spike"}, Vector2(30, 400))
	var left: StringName = lab.add_lab_node(SigilGraphModel.MOVE, {"offset": Vector2i(-3, 0)}, Vector2(200, 170))
	var right: StringName = lab.add_lab_node(SigilGraphModel.MOVE, {"offset": Vector2i(3, 0)}, Vector2(200, 400))
	var combine: StringName = lab.add_lab_node(SigilGraphModel.COMBINE, {}, Vector2(400, 245))
	var group_move: StringName = lab.add_lab_node(SigilGraphModel.MOVE, {"offset": Vector2i(0, -4)}, Vector2(610, 280))
	var output_id: StringName = lab.graph.output_node_id()
	lab.connect_lab_nodes(ring, left)
	lab.connect_lab_nodes(spike, right)
	lab.connect_lab_nodes(left, combine, 0)
	lab.connect_lab_nodes(right, combine, 1)
	lab.connect_lab_nodes(combine, group_move)
	lab.connect_lab_nodes(group_move, output_id)


func _user_options() -> Dictionary:
	var result: Dictionary = {}
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--") or not "=" in argument:
			continue
		var parts := argument.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1]
	return result
