class_name SigilLabGraphEdit
extends GraphEdit

const NODE_KIND_META := &"sigil_lab_kind"
const OUTPUT_KIND := &"output"
const COMPLETION_DROP_MARGIN := 8.0


func completion_hotzone_contains(node: GraphNode, mouse_position: Vector2) -> bool:
	if node == null or StringName(node.get_meta(NODE_KIND_META, &"")) != OUTPUT_KIND:
		return false
	var scaled_size := node.size * node.scale
	return Rect2(node.position, scaled_size).grow(COMPLETION_DROP_MARGIN).has_point(mouse_position)


func _is_in_input_hotzone(in_node: Object, in_port: int, mouse_position: Vector2) -> bool:
	var graph_node := in_node as GraphNode
	if graph_node != null and completion_hotzone_contains(graph_node, mouse_position):
		return true
	if graph_node == null or in_port < 0 or in_port >= graph_node.get_input_port_count():
		return false
	var grab_distance := Vector2(
		float(get_theme_constant("port_grab_distance_horizontal")),
		float(get_theme_constant("port_grab_distance_vertical"))
	)
	var port_position: Vector2 = (
		graph_node.position
		+ graph_node.get_input_port_position(in_port) * graph_node.scale
	)
	return Rect2(port_position - grab_distance, grab_distance * 2.0).has_point(mouse_position)
