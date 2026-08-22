extends SceneTree


func _initialize() -> void:
	var options := _user_options()
	var width := int(options.get("width", "1280"))
	var height := int(options.get("height", "720"))
	var scene_id := String(options.get("scene", "factory"))
	var scene_path := (
		"res://src/main_menu.tscn"
		if scene_id == "menu"
		else "res://experiments/factory_prototype/factory_prototype.tscn"
	)
	var output := String(
		options.get(
			"output",
			"res://.factory-prototype-qa/%s.png" % scene_id
		)
	)
	var output_directory := ProjectSettings.globalize_path(output.get_base_dir())
	DirAccess.make_dir_recursive_absolute(output_directory)

	var capture_viewport := SubViewport.new()
	capture_viewport.size = Vector2i(width, height)
	capture_viewport.gui_embed_subwindows = true
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_viewport)

	var scene: PackedScene = load(scene_path)
	var view := scene.instantiate()
	capture_viewport.add_child(view)
	await process_frame
	await process_frame
	if scene_id == "factory":
		var requested_flow_time := -1.0
		if options.has("flow_time"):
			requested_flow_time = float(options["flow_time"])
			view.flow_time_override = 0.0
		var fixture := String(options.get("fixture", ""))
		if fixture == "circle_summon":
			view.connect_material_to_summoner(&"circle_01")
		elif fixture == "meaning_deposits":
			view.factory_graph.zoom = 0.2
			view._center_initial_view()
		elif fixture == "meaning_target":
			view.flow_time_override = 0.0
			view.select_input(0)
			view.select_target(&"eye")
			view.connect_output_to_input(&"eye_vein", &"summoner_center", 0)
			view.flow_time_override = view.summoner_arrival_time(0, 0) + 0.001
			view.process_transport_at(view.flow_time_override)
		elif fixture == "three_inputs":
			view.connect_material_to_summoner(&"circle_01", 0)
			view.connect_material_to_summoner(&"triangle_01", 1)
			view.connect_material_to_summoner(&"square_01", 2)
		elif fixture == "relay_route":
			var relay = view.place_relay_at(Vector2(3800.0, 2980.0))
			view.connect_output_to_input(&"circle_01", StringName(relay.name), 0)
			view.connect_output_to_input(StringName(relay.name), &"summoner_center", 0)
		elif fixture == "rotation_route":
			view.select_input(2)
			view.select_target(&"diamond")
			var rotation = view.place_rotation_at(Vector2(3900.0, 2450.0), 45)
			view.connect_output_to_input(&"square_01", StringName(rotation.name), 0)
			view.connect_output_to_input(StringName(rotation.name), &"summoner_center", 2)
		elif fixture == "rotation_settings":
			var rotation = view.place_rotation_at(Vector2(3900.0, 2450.0), 45)
			view.open_rotation_settings(StringName(rotation.name), Vector2(620.0, 330.0))
		elif fixture == "relay_settings":
			var relay = view.place_relay_at(Vector2(3900.0, 2450.0))
			view.open_relay_settings(StringName(relay.name), Vector2(620.0, 330.0))
		elif fixture == "scale_settings":
			var scale = view.place_scale_at(Vector2(3900.0, 2450.0), 200, 50)
			view.open_scale_settings(StringName(scale.name), Vector2(620.0, 330.0))
		elif fixture == "move_settings":
			var move_node = view.place_move_at(Vector2(3900.0, 2450.0), Vector2i(0, -3))
			view.open_move_settings(StringName(move_node.name), Vector2(620.0, 330.0))
		elif fixture == "repeat_settings":
			var move_node = view.place_move_at(Vector2(3500.0, 2450.0), Vector2i(4, 0))
			var repeat_node = view.place_repeat_at(Vector2(3900.0, 2450.0), 6)
			view.connect_output_to_input(&"triangle_01", StringName(move_node.name), 0)
			view.connect_output_to_input(StringName(move_node.name), StringName(repeat_node.name), 0)
			view.open_repeat_settings(StringName(repeat_node.name), Vector2(620.0, 330.0))
		elif fixture == "combine_settings":
			var horizontal = view.place_scale_at(Vector2(3450.0, 2300.0), 100, 25)
			var vertical = view.place_scale_at(Vector2(3450.0, 2700.0), 25, 100)
			var combine_node = view.place_combine_at(Vector2(3900.0, 2500.0))
			view.connect_output_to_input(&"square_01", StringName(horizontal.name), 0)
			view.connect_output_to_input(&"square_01", StringName(vertical.name), 0)
			view.connect_output_to_input(StringName(horizontal.name), StringName(combine_node.name), 0)
			view.connect_output_to_input(StringName(vertical.name), StringName(combine_node.name), 4)
			view.open_combine_settings(StringName(combine_node.name), Vector2(620.0, 330.0))
		elif fixture == "line_settings":
			view.connect_material_to_summoner(&"circle_01", 0)
			var connection = view._connection_to_input(&"summoner_center", 0)
			view.open_line_settings(connection, Vector2(620.0, 330.0))
		if requested_flow_time >= 0.0:
			view.flow_time_override = requested_flow_time
		if options.has("hover_line_input"):
			var hover_input := int(options["hover_line_input"])
			for connection in view.factory_graph.get_connection_list():
				if (
					StringName(connection["to_node"]) != StringName(view.summoner_node.name)
					or int(connection["to_port"]) != hover_input
				):
					continue
				var from_node_id := StringName(connection["from_node"])
				var start: Vector2 = view.directional_output_position(
					from_node_id,
					view.factory_graph
				)
				var finish: Vector2 = view.directional_input_position(
					hover_input,
					view.factory_graph
				)
				var hover := InputEventMouseMotion.new()
				hover.position = start.lerp(finish, 0.5)
				view.factory_graph.gui_input.emit(hover)
				break
	await process_frame
	RenderingServer.force_draw(false)

	var image := capture_viewport.get_texture().get_image()
	if image == null:
		printerr("Factory Prototype capture requires a rendering driver")
		quit(1)
		return
	var error := image.save_png(output)
	if error == OK:
		print("Factory Prototype capture: %s (%dx%d)" % [output, image.get_width(), image.get_height()])
	else:
		printerr("Factory Prototype capture failed: %s" % error)
	view.queue_free()
	await process_frame
	capture_viewport.queue_free()
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
