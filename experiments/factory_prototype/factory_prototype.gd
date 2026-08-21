class_name FactoryPrototype
extends Control

const FactoryLandmarkVisualModel := preload("res://experiments/factory_prototype/factory_landmark.gd")

const MENU_SCENE := "res://src/main_menu.tscn"
const PLAYFIELD_SIZE := Vector2(2600.0, 1800.0)
const SUMMONER_POSITION := Vector2(1210.0, 790.0)
const PORT_COLOR := Color(0.28, 0.78, 1.0, 1.0)
const MATERIAL_LAYOUT := [
	{ "id": &"circle_northwest", "kind": &"circle", "position": Vector2(430.0, 300.0) },
	{ "id": &"circle_southeast", "kind": &"circle", "position": Vector2(1950.0, 1270.0) },
	{ "id": &"triangle_northeast", "kind": &"triangle", "position": Vector2(1880.0, 260.0) },
	{ "id": &"triangle_southwest", "kind": &"triangle", "position": Vector2(390.0, 1300.0) },
	{ "id": &"square_west", "kind": &"square", "position": Vector2(250.0, 790.0) },
	{ "id": &"square_east", "kind": &"square", "position": Vector2(2150.0, 760.0) },
]

var factory_graph: GraphEdit
var summoner_node: GraphNode
var material_nodes: Array[GraphNode] = []
var status_label: Label


func _ready() -> void:
	_build_ui()
	_place_landmarks()
	call_deferred("_center_initial_view")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.005, 0.014, 0.024, 1.0), true)


func return_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func fixed_landmark_count() -> int:
	return material_nodes.size() + (1 if summoner_node != null else 0)


func material_kind_counts() -> Dictionary:
	var counts := { &"circle": 0, &"triangle": 0, &"square": 0 }
	for node in material_nodes:
		var kind := StringName(node.get_meta("landmark_kind", &""))
		if counts.has(kind):
			counts[kind] = int(counts[kind]) + 1
	return counts


func all_landmarks_locked() -> bool:
	if summoner_node == null or summoner_node.draggable:
		return false
	for node in material_nodes:
		if node.draggable:
			return false
	return true


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)

	var toolbar := HBoxContainer.new()
	toolbar.custom_minimum_size.y = 42.0
	toolbar.add_theme_constant_override("separation", 8)
	page.add_child(toolbar)

	var back := Button.new()
	back.name = "BackButton"
	back.text = "← メニュー"
	back.custom_minimum_size = Vector2(112.0, 34.0)
	back.pressed.connect(return_to_menu)
	toolbar.add_child(back)

	var title := Label.new()
	title.text = "FACTORY PROTOTYPE // 固定素材地帯"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.76, 0.91, 1.0))
	toolbar.add_child(title)

	status_label = Label.new()
	status_label.text = "広域盤面 2600 × 1800  //  素材地点 6  //  中央召喚器 1"
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.44, 0.68, 0.78))
	toolbar.add_child(status_label)

	factory_graph = GraphEdit.new()
	factory_graph.name = "FactoryGraph"
	factory_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	factory_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	factory_graph.custom_minimum_size = Vector2(900.0, 620.0)
	factory_graph.right_disconnects = true
	factory_graph.connection_lines_curvature = 0.12
	factory_graph.minimap_enabled = true
	factory_graph.zoom = 0.72
	page.add_child(factory_graph)

	var footer := Label.new()
	footer.text = "ドラッグ: 盤面移動  /  ホイール: ズーム  /  固定素材と召喚器は移動不可"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.40, 0.58, 0.66))
	page.add_child(footer)


func _place_landmarks() -> void:
	for entry in MATERIAL_LAYOUT:
		var node := _make_material_node(
			StringName(entry["id"]),
			StringName(entry["kind"]),
			Vector2(entry["position"])
		)
		material_nodes.append(node)
		factory_graph.add_child(node)

	summoner_node = _make_summoner_node()
	factory_graph.add_child(summoner_node)


func _make_material_node(node_id: StringName, kind: StringName, world_position: Vector2) -> GraphNode:
	var node := GraphNode.new()
	node.name = String(node_id)
	node.title = "%s素材 // 固定" % _kind_label(kind)
	node.position_offset = world_position
	node.draggable = false
	node.resizable = false
	node.set_meta("landmark_kind", kind)
	node.set_meta("fixed_landmark", true)

	var visual = FactoryLandmarkVisualModel.new()
	visual.configure(kind)
	node.add_child(visual)
	node.set_slot(0, false, 0, PORT_COLOR, true, 0, PORT_COLOR)
	return node


func _make_summoner_node() -> GraphNode:
	var node := GraphNode.new()
	node.name = "summoner_center"
	node.title = "召喚器 // 工場中心 // 固定"
	node.position_offset = SUMMONER_POSITION
	node.draggable = false
	node.resizable = false
	node.set_meta("landmark_kind", &"summoner")
	node.set_meta("fixed_landmark", true)

	var visual = FactoryLandmarkVisualModel.new()
	visual.configure(&"summoner")
	node.add_child(visual)
	node.set_slot(0, true, 0, PORT_COLOR, false, 0, PORT_COLOR)
	return node


func _center_initial_view() -> void:
	if factory_graph == null:
		return
	var summoner_center := SUMMONER_POSITION + Vector2(100.0, 105.0)
	factory_graph.scroll_offset = summoner_center * factory_graph.zoom - factory_graph.size * 0.5


static func _kind_label(kind: StringName) -> String:
	return {
		&"circle": "丸",
		&"triangle": "三角",
		&"square": "四角",
	}.get(kind, String(kind))
