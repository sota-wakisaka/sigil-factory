extends SceneTree

const RuneFactoryScene := preload("res://experiments/rune_factory/rune_factory_prototype.tscn")


func _initialize() -> void:
	var options := _user_options()
	var width := int(options.get("width", "1536"))
	var height := int(options.get("height", "900"))
	var output := String(options.get("output", "res://.rune-factory-qa/overview.png"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(width, height)
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var factory = RuneFactoryScene.instantiate()
	viewport.add_child(factory)
	await process_frame
	await process_frame
	factory.flow_time_override = 0.0
	var shift = factory.place_processor(&"shift", Vector2(4500.0, 2350.0))
	var shift_id := StringName(shift.name)
	factory.connect_nodes(&"source_red_1", 0, shift_id, 0)
	factory.node_menu_node_id = shift_id
	factory._preview_node_menu_item(103)
	factory.flow_time_override = 0.9
	await process_frame
	RenderingServer.force_draw(false)
	var image := viewport.get_texture().get_image()
	if image == null:
		printerr("Rune Factory capture requires a rendering driver")
		quit(1)
		return
	var error := image.save_png(output)
	if error == OK:
		print("Rune Factory capture: %s (%dx%d)" % [output, image.get_width(), image.get_height()])
	else:
		printerr("Rune Factory capture failed: %s" % error)
	factory.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame
	quit(0 if error == OK else 1)


func _user_options() -> Dictionary:
	var result: Dictionary = {}
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--") or not "=" in argument:
			continue
		var parts := argument.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1]
	return result
