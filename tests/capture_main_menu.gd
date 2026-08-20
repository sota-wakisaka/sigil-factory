extends SceneTree


func _initialize() -> void:
	var output := "C:/Users/sotaw/AppData/Local/Temp/sigil-factory-main-menu.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: PackedScene = load("res://src/main_menu.tscn")
	viewport.add_child(scene.instantiate())
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var error := image.save_png(output)
	if error == OK:
		print("Main menu capture: %s" % output)
	else:
		printerr("Main menu capture failed: %s" % error)
	quit(0 if error == OK else 1)
