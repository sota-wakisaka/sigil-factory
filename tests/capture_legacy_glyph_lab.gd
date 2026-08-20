extends SceneTree


func _initialize() -> void:
	var options := _user_options()
	var width := int(options.get("width", "1280"))
	var height := int(options.get("height", "720"))
	var fixture_index := clampi(int(options.get("fixture", "6")) - 1, 0, 5)
	var output := String(options.get("output", "res://.seal-lab-qa/legacy-glyph-lab.png"))

	var capture_viewport := SubViewport.new()
	capture_viewport.size = Vector2i(width, height)
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_viewport)
	var scene: PackedScene = load("res://experiments/seal_lab/legacy_glyph_lab.tscn")
	var lab = scene.instantiate()
	capture_viewport.add_child(lab)
	await process_frame
	await process_frame
	lab.select_fixture(fixture_index)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := capture_viewport.get_texture().get_image()
	var error := image.save_png(output)
	if error == OK:
		print("Legacy Glyph Lab capture: %s (%dx%d)" % [output, image.get_width(), image.get_height()])
	else:
		printerr("Legacy Glyph Lab capture failed: %s" % error)
	quit(0 if error == OK else 1)


func _user_options() -> Dictionary:
	var result: Dictionary = {}
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--") or not "=" in argument:
			continue
		var parts := argument.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1]
	return result
