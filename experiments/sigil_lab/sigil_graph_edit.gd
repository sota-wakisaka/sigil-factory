class_name SigilLabGraphEdit
extends GraphEdit

const INPUT_HOTZONE_SIZE := Vector2(56.0, 28.0)
const DISTANCE_EPSILON := 0.001


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
	if not Rect2(
		port_center - INPUT_HOTZONE_SIZE * 0.5,
		INPUT_HOTZONE_SIZE
	).has_point(mouse_position):
		return false
	var candidate_distance := mouse_position.distance_squared_to(port_center)
	var candidate_key := _port_key(graph_node, false, in_port)
	# GraphEdit normally checks input hotzones before output hotzones. When nodes
	# are close together, a wide input target can therefore steal a click made
	# directly on another node's output. Only the closest visible port wins.
	for child in get_children():
		var other_node := child as GraphNode
		if other_node == null:
			continue
		for output_port in other_node.get_output_port_count():
			var output_center := (
				other_node.position
				+ other_node.get_output_port_position(output_port)
			)
			if _port_precedes_candidate(
				mouse_position.distance_squared_to(output_center),
				_port_key(other_node, true, output_port),
				candidate_distance,
				candidate_key
			):
				return false
		for other_input_port in other_node.get_input_port_count():
			if other_node == graph_node and other_input_port == in_port:
				continue
			var input_center := (
				other_node.position
				+ other_node.get_input_port_position(other_input_port)
			)
			if _port_precedes_candidate(
				mouse_position.distance_squared_to(input_center),
				_port_key(other_node, false, other_input_port),
				candidate_distance,
				candidate_key
			):
				return false
	return true


static func _port_precedes_candidate(
	distance: float,
	key: String,
	candidate_distance: float,
	candidate_key: String
) -> bool:
	if distance < candidate_distance - DISTANCE_EPSILON:
		return true
	return absf(distance - candidate_distance) <= DISTANCE_EPSILON and key < candidate_key


static func _port_key(node: GraphNode, is_output: bool, port: int) -> String:
	return "%s:%s:%d" % [node.name, "out" if is_output else "in", port]
