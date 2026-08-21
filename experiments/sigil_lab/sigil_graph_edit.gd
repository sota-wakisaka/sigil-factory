class_name SigilLabGraphEdit
extends GraphEdit

const INPUT_HOTZONE_SIZE := Vector2(24.0, 18.0)


func _is_in_input_hotzone(in_node: Object, in_port: int, mouse_position: Vector2) -> bool:
	var graph_node := in_node as GraphNode
	if graph_node == null or in_port < 0 or in_port >= graph_node.get_input_port_count():
		return false
	# Match the documented GraphEdit coordinate contract, but keep the target
	# close to the visible dot. Godot's wider default can overlap a nearby
	# node's output and start a connection from the wrong endpoint.
	var port_center: Vector2 = (
		graph_node.position
		+ graph_node.get_input_port_position(in_port)
	)
	return Rect2(
		port_center - INPUT_HOTZONE_SIZE * 0.5,
		INPUT_HOTZONE_SIZE
	).has_point(mouse_position)
