class_name SigilLab
extends Control

const SigilGraphModel := preload("res://experiments/sigil_lab/sigil_graph.gd")
const SigilPreviewModel := preload("res://experiments/sigil_lab/sigil_preview.gd")
const GlyphModel := preload("res://src/domain/glyph.gd")

const MAIN_MENU_SCENE := "res://src/main_menu.tscn"

const PORT_COLOR := Color(0.3, 0.82, 1.0, 1.0)
const NODE_NAMES := {
	&"source": "素材",
	&"rotate": "回転",
	&"move": "移動",
	&"scale": "変形",
	&"repeat": "反復",
	&"color": "着色",
	&"combine": "合成",
	&"output": "完成",
}
const MOVE_OPTIONS := [
	Vector2i(0, -4),
	Vector2i(4, 0),
	Vector2i(0, 4),
	Vector2i(-4, 0),
]

var graph = SigilGraphModel.new()
var node_serial := 0
var node_controls: Dictionary = {}
var node_previews: Dictionary = {}
var option_controls: Dictionary = {}

var graph_edit: GraphEdit
var output_preview
var small_previews: Array = []
var status_label: Label
var stats_label: Label
var output_button: GraphNode
var menu_button: Button
var structure_button: Button


func _ready() -> void:
	_build_ui()
	_load_eye_template()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.008, 0.018, 0.032, 1.0), true)
	for index in 8:
		var y := 80.0 + float(index) * 104.0
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.12, 0.26, 0.38, 0.07), 1.0)


func add_lab_node(kind: StringName, config: Dictionary = {}, position: Vector2 = Vector2.ZERO) -> StringName:
	return _add_node(kind, config, position)


func connect_lab_nodes(from_node: StringName, to_node: StringName, to_port: int = 0) -> bool:
	return _connect_nodes(from_node, 0, to_node, to_port)


func clear_workspace() -> void:
	_clear_workspace()


func load_cardinal_template() -> void:
	_load_eye_template()


func load_eye_template() -> void:
	_load_eye_template()


func load_repeat_template() -> void:
	_load_repeat_template()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)
	page.add_child(_build_header())
	page.add_child(_build_palette())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	page.add_child(body)

	graph_edit = GraphEdit.new()
	graph_edit.name = "Graph"
	graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_edit.custom_minimum_size.x = 820.0
	graph_edit.right_disconnects = true
	graph_edit.connection_lines_curvature = 0.34
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	body.add_child(graph_edit)
	body.add_child(_build_output_panel())


func _build_header() -> Control:
	var toolbar := HBoxContainer.new()
	toolbar.custom_minimum_size.y = 42.0
	toolbar.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "SIGIL LAB // MVP Glyph Editor"
	title.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0))
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)

	var template_button := Button.new()
	template_button.text = "目の印"
	template_button.tooltip_text = "丸を横へ変形して作る基本テンプレート"
	template_button.custom_minimum_size = Vector2(86, 34)
	template_button.pressed.connect(_load_eye_template)
	toolbar.add_child(template_button)

	var repeat_button := Button.new()
	repeat_button.text = "六花"
	repeat_button.tooltip_text = "移動した三角を60°ずつ放射反復するテンプレート"
	repeat_button.custom_minimum_size = Vector2(76, 34)
	repeat_button.pressed.connect(_load_repeat_template)
	toolbar.add_child(repeat_button)

	var clear_button := Button.new()
	clear_button.text = "クリア"
	clear_button.tooltip_text = "完成ノード以外を削除する"
	clear_button.custom_minimum_size = Vector2(76, 34)
	clear_button.pressed.connect(_clear_workspace)
	toolbar.add_child(clear_button)

	menu_button = Button.new()
	menu_button.text = "← MENU"
	menu_button.tooltip_text = "メインメニューへ戻る"
	menu_button.custom_minimum_size = Vector2(96, 34)
	menu_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	)
	toolbar.add_child(menu_button)
	return toolbar


func _build_palette() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 42.0
	bar.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = "追加"
	label.custom_minimum_size.x = 42.0
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.52, 0.72, 0.88))
	bar.add_child(label)
	for definition in [
		["○", SigilGraphModel.SOURCE, {"primitive_id": &"circle"}, "丸 // 基本図形"],
		["△", SigilGraphModel.SOURCE, {"primitive_id": &"triangle"}, "三角 // 基本図形"],
		["□", SigilGraphModel.SOURCE, {"primitive_id": &"square"}, "四角 // 基本図形"],
		["↻", SigilGraphModel.ROTATE, {"degrees": 45}, "中心を基準に1°単位で回転"],
		["↔", SigilGraphModel.MOVE, {"offset": Vector2i(0, -4)}, "上下左右へ移動"],
		["↔↕", SigilGraphModel.SCALE, {"x_percent": 150, "y_percent": 100}, "横・縦を別々に拡大縮小"],
		["×N", SigilGraphModel.REPEAT, {"count": 6}, "中心のまわりへ等角度で放射反復"],
		["●", SigilGraphModel.COLOR, {"color_id": &"blue"}, "白・青・赤へ着色"],
		["⊕", SigilGraphModel.COMBINE, {}, "2〜8個のGlyphを中心結合・相互結合"],
	]:
		var button := Button.new()
		button.text = definition[0]
		button.tooltip_text = definition[3]
		button.custom_minimum_size = Vector2(48, 34)
		button.pressed.connect(_add_from_palette.bind(definition[1], definition[2]))
		bar.add_child(button)
	var instruction := Label.new()
	instruction.text = "出力から入力へドラッグ // 右クリックで切断 // ×でノード削除"
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	instruction.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instruction.add_theme_color_override("font_color", Color(0.42, 0.6, 0.74))
	bar.add_child(instruction)
	return bar


func _build_output_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 330.0
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var title := Label.new()
	title.text = "完成シジル"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.66, 0.86, 1.0))
	column.add_child(title)

	structure_button = Button.new()
	structure_button.text = "階層"
	structure_button.tooltip_text = "編集補助 // 合成グループの範囲だけを点線で表示"
	structure_button.toggle_mode = true
	structure_button.toggled.connect(set_structure_overlay)
	column.add_child(structure_button)

	output_preview = SigilPreviewModel.new()
	output_preview.custom_minimum_size = Vector2(310, 310)
	column.add_child(output_preview)

	var lod_row := HBoxContainer.new()
	lod_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lod_row.add_theme_constant_override("separation", 8)
	for lod in [104, 56, 36]:
		var preview = SigilPreviewModel.new()
		preview.custom_minimum_size = Vector2(lod, lod)
		small_previews.append(preview)
		lod_row.add_child(preview)
	column.add_child(lod_row)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(0.58, 0.8, 0.96))
	column.add_child(status_label)

	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_color_override("font_color", Color(0.44, 0.64, 0.78))
	column.add_child(stats_label)
	return panel


func set_structure_overlay(visible: bool) -> void:
	output_preview.set_show_structure(visible)
	for preview in small_previews:
		preview.set_show_structure(visible)
	for preview in node_previews.values():
		preview.set_show_structure(visible)


func _add_from_palette(kind: StringName, config: Dictionary) -> void:
	var column := node_serial % 3
	var row := int(node_serial / 3) % 4
	_add_node(kind, config, Vector2(40 + column * 210, 100 + row * 170))


func _add_node(kind: StringName, config: Dictionary, position: Vector2) -> StringName:
	node_serial += 1
	var node_id := StringName("%s_%d" % [kind, node_serial])
	if not graph.add_node(node_id, kind, config):
		_set_status(_error_text(graph.last_error), true)
		return &""
	_create_graph_node(node_id, kind, position)
	_refresh_all()
	return node_id


func _create_graph_node(node_id: StringName, kind: StringName, position: Vector2) -> void:
	var node := GraphNode.new()
	node.name = String(node_id)
	node.title = NODE_NAMES.get(kind, String(kind))
	node.position_offset = position
	node.resizable = false

	var preview = SigilPreviewModel.new()
	preview.custom_minimum_size = Vector2(108, 86)
	preview.set_show_structure(structure_button != null and structure_button.button_pressed)
	node_previews[node_id] = preview

	match kind:
		SigilGraphModel.SOURCE:
			node.add_child(preview)
			node.set_slot(0, false, 0, PORT_COLOR, true, 0, PORT_COLOR)
			var option := _source_option(node_id)
			node.add_child(option)
			option_controls[node_id] = option
		SigilGraphModel.ROTATE, SigilGraphModel.MOVE, SigilGraphModel.SCALE, SigilGraphModel.REPEAT, SigilGraphModel.COLOR:
			node.add_child(preview)
			node.set_slot(0, true, 0, PORT_COLOR, true, 0, PORT_COLOR)
			var option := _setting_option(node_id, kind)
			node.add_child(option)
			option_controls[node_id] = option
		SigilGraphModel.COMBINE:
			for input_index in SigilGraphModel.MAX_COMBINE_INPUTS:
				var input_label := Label.new()
				input_label.text = str(input_index + 1)
				input_label.custom_minimum_size = Vector2(108, 28)
				input_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				node.add_child(input_label)
				node.set_slot(input_index, true, 0, PORT_COLOR, false, 0, PORT_COLOR)
			node.add_child(preview)
			node.set_slot(
				SigilGraphModel.MAX_COMBINE_INPUTS,
				false,
				0,
				PORT_COLOR,
				true,
				0,
				PORT_COLOR
			)
			var combine_option := _combine_option(node_id)
			node.get_titlebar_hbox().add_child(combine_option)
			option_controls[node_id] = combine_option
		SigilGraphModel.OUTPUT:
			node.add_child(preview)
			node.set_slot(0, true, 0, PORT_COLOR, false, 0, PORT_COLOR)

	if kind != SigilGraphModel.OUTPUT:
		var remove_button := Button.new()
		remove_button.text = "×"
		remove_button.tooltip_text = "このノードと接続を削除"
		remove_button.flat = true
		remove_button.custom_minimum_size = Vector2(26, 24)
		remove_button.pressed.connect(_remove_node.bind(node_id))
		node.get_titlebar_hbox().add_child(remove_button)

	node_controls[node_id] = node
	graph_edit.add_child(node)


func _source_option(node_id: StringName) -> OptionButton:
	var option := OptionButton.new()
	for label in ["丸", "三角", "四角"]:
		option.add_item(label)
	var primitive := StringName(graph.node_config(node_id).get("primitive_id", &"circle"))
	option.select([&"circle", &"triangle", &"square"].find(primitive))
	option.item_selected.connect(func(index: int) -> void:
		graph.set_node_config(node_id, {"primitive_id": [&"circle", &"triangle", &"square"][index]})
		_refresh_all()
	)
	return option


func _setting_option(node_id: StringName, kind: StringName) -> Control:
	if kind == SigilGraphModel.ROTATE:
		var angle := SpinBox.new()
		angle.min_value = 0.0
		angle.max_value = 359.0
		angle.step = 1.0
		angle.suffix = "°"
		angle.allow_greater = false
		angle.allow_lesser = false
		angle.custom_minimum_size = Vector2(108, 34)
		angle.tooltip_text = "中心を基準に回転 // 0〜359°"
		angle.value = float(graph.node_config(node_id).get("degrees", 0))
		angle.value_changed.connect(func(value: float) -> void:
			graph.set_node_config(node_id, {"degrees": roundi(value)})
			_refresh_all()
		)
		return angle
	if kind == SigilGraphModel.SCALE:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(144, 34)
		row.tooltip_text = "横 / 縦 // 25〜400%"
		var config := graph.node_config(node_id)
		for axis in ["x_percent", "y_percent"]:
			var value := SpinBox.new()
			value.min_value = 25.0
			value.max_value = 400.0
			value.step = 25.0
			value.suffix = "%"
			value.custom_minimum_size = Vector2(70, 34)
			value.value = float(config.get(axis, 100))
			value.value_changed.connect(_on_scale_value_changed.bind(node_id, StringName(axis)))
			row.add_child(value)
		return row
	if kind == SigilGraphModel.REPEAT:
		var repeat_option := OptionButton.new()
		for count in SigilGraphModel.REPEAT_COUNTS:
			repeat_option.add_item("%d回" % count)
		repeat_option.custom_minimum_size = Vector2(108, 34)
		repeat_option.tooltip_text = "元のシジルを含む反復数 // 中心原点のまわりへ等角度配置"
		var count := int(graph.node_config(node_id).get("count", 6))
		repeat_option.select(maxi(SigilGraphModel.REPEAT_COUNTS.find(count), 0))
		repeat_option.item_selected.connect(func(index: int) -> void:
			graph.set_node_config(node_id, {"count": SigilGraphModel.REPEAT_COUNTS[index]})
			_refresh_all()
		)
		return repeat_option
	var option := OptionButton.new()
	match kind:
		SigilGraphModel.MOVE:
			for label in ["↑4", "→4", "↓4", "←4"]:
				option.add_item(label)
			var current_offset: Vector2i = graph.node_config(node_id).get("offset", MOVE_OPTIONS[0])
			option.select(maxi(MOVE_OPTIONS.find(current_offset), 0))
			option.item_selected.connect(func(index: int) -> void:
				graph.set_node_config(node_id, {"offset": MOVE_OPTIONS[index]})
				_refresh_all()
			)
		SigilGraphModel.COLOR:
			for label in ["白", "青", "赤"]:
				option.add_item(label)
			var color_id := StringName(graph.node_config(node_id).get("color_id", &"blue"))
			option.select(maxi([&"white", &"blue", &"red"].find(color_id), 0))
			option.item_selected.connect(func(index: int) -> void:
				graph.set_node_config(node_id, {"color_id": [&"white", &"blue", &"red"][index]})
				_refresh_all()
			)
	return option


func _on_scale_value_changed(value: float, node_id: StringName, axis: StringName) -> void:
	var next_config := graph.node_config(node_id)
	next_config[axis] = roundi(value)
	if graph.set_node_config(node_id, next_config):
		_refresh_all()


func _combine_option(node_id: StringName) -> OptionButton:
	var option := OptionButton.new()
	option.add_item("中心結合")
	option.add_item("相互結合")
	option.custom_minimum_size = Vector2(92, 24)
	option.tooltip_text = "合成線 // 中心結合または重複を除いた相互結合"
	var mode := StringName(graph.node_config(node_id).get(
		"connection_mode",
		GlyphModel.CONNECTION_RADIAL
	))
	option.select(1 if mode == GlyphModel.CONNECTION_PAIRWISE else 0)
	option.item_selected.connect(func(index: int) -> void:
		graph.set_node_config(node_id, {
			"connection_mode": (
				GlyphModel.CONNECTION_PAIRWISE
				if index == 1
				else GlyphModel.CONNECTION_RADIAL
			),
		})
		_refresh_all()
	)
	return option


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	_connect_nodes(from_node, from_port, to_node, to_port)


func _connect_nodes(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> bool:
	if not graph.connect_nodes(from_node, from_port, to_node, to_port):
		_set_status(_error_text(graph.last_error), true)
		return false
	graph_edit.connect_node(from_node, from_port, to_node, to_port)
	_refresh_all()
	return true


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if graph.disconnect_nodes(from_node, from_port, to_node, to_port):
		graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
		_refresh_all()


func _remove_node(node_id: StringName) -> void:
	if graph.node_kind(node_id) == SigilGraphModel.OUTPUT:
		return
	if not graph.remove_node(node_id):
		return
	var node = node_controls.get(node_id)
	if node != null:
		node.queue_free()
	node_controls.erase(node_id)
	node_previews.erase(node_id)
	option_controls.erase(node_id)
	graph_edit.clear_connections()
	for connection in graph.connections:
		graph_edit.connect_node(connection["from"], connection["from_port"], connection["to"], connection["to_port"])
	_refresh_all()


func _clear_workspace() -> void:
	for node in node_controls.values():
		node.queue_free()
	node_controls.clear()
	node_previews.clear()
	option_controls.clear()
	graph_edit.clear_connections()
	graph = SigilGraphModel.new()
	node_serial = 0
	var output_id := _add_node(SigilGraphModel.OUTPUT, {}, Vector2(810, 280))
	output_button = node_controls.get(output_id)
	_refresh_all()


func _load_eye_template() -> void:
	_clear_workspace()
	var pupil := _add_node(SigilGraphModel.SOURCE, {"primitive_id": &"circle"}, Vector2(30, 180))
	var outline := _add_node(SigilGraphModel.SOURCE, {"primitive_id": &"circle"}, Vector2(30, 390))
	var stretch := _add_node(
		SigilGraphModel.SCALE,
		{"x_percent": 250, "y_percent": 100},
		Vector2(230, 390)
	)
	var combine_root := _add_node(SigilGraphModel.COMBINE, {}, Vector2(480, 250))
	var output_id := graph.output_node_id()

	_connect_nodes(outline, 0, stretch, 0)
	_connect_nodes(pupil, 0, combine_root, 0)
	_connect_nodes(stretch, 0, combine_root, 1)
	_connect_nodes(combine_root, 0, output_id, 0)
	_refresh_all()


func _load_repeat_template() -> void:
	_clear_workspace()
	var petal := _add_node(
		SigilGraphModel.SOURCE,
		{"primitive_id": &"triangle"},
		Vector2(30, 210)
	)
	var move := _add_node(
		SigilGraphModel.MOVE,
		{"offset": Vector2i(0, -4)},
		Vector2(220, 210)
	)
	var repeat := _add_node(
		SigilGraphModel.REPEAT,
		{"count": 6},
		Vector2(410, 210)
	)
	var center := _add_node(
		SigilGraphModel.SOURCE,
		{"primitive_id": &"circle"},
		Vector2(220, 470)
	)
	var combine := _add_node(SigilGraphModel.COMBINE, {}, Vector2(620, 285))
	var output_id := graph.output_node_id()
	_connect_nodes(petal, 0, move, 0)
	_connect_nodes(move, 0, repeat, 0)
	_connect_nodes(repeat, 0, combine, 0)
	_connect_nodes(center, 0, combine, 1)
	_connect_nodes(combine, 0, output_id, 0)
	_refresh_all()


func _refresh_all() -> void:
	for node_id in node_controls:
		var result := graph.evaluate(node_id)
		var glyph = result.get("glyph") if bool(result.get("ok", false)) else null
		node_previews[node_id].set_glyph(glyph, graph.node_kind(node_id) == SigilGraphModel.OUTPUT)
		var node: GraphNode = node_controls[node_id]
		node.title = "%s %s" % [NODE_NAMES.get(graph.node_kind(node_id), String(node_id)), "◆" if glyph != null else "◇"]

	var output_result := graph.evaluate_output()
	var output_glyph = output_result.get("glyph") if bool(output_result.get("ok", false)) else null
	output_preview.set_glyph(output_glyph, true)
	for preview in small_previews:
		preview.set_glyph(output_glyph)
	if output_glyph != null:
		_set_status("完成 // 配線と設定を変更して比較", false)
		stats_label.text = "素材 %d // 合成 %d" % [
			output_glyph.components.size(),
			_combine_count(output_glyph),
		]
	else:
		_set_status(_error_text(StringName(output_result.get("error", &"missing_input"))), true)
		stats_label.text = "出力ノードまで接続してください"


func _set_status(text: String, error: bool) -> void:
	if status_label == null:
		return
	status_label.text = text
	status_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.54, 0.48) if error else Color(0.58, 0.8, 0.96)
	)


static func _combine_count(glyph) -> int:
	if glyph == null or glyph.combine_children.is_empty():
		return 0
	var count := 1
	for child in glyph.combine_children:
		count += _combine_count(child)
	return count


static func _error_text(error: StringName) -> String:
	return {
		&"missing_input": "配線待ち // 入力が不足しています",
		&"missing_output": "完成ノードがありません",
		&"input_occupied": "入力は接続済み // 右クリックで切断",
		&"cycle": "循環する配線は作れません",
		&"invalid_direction": "出力から入力へ接続してください",
		&"invalid_glyph": "完全重複する素材は合成できません",
		&"invalid_repeat": "反復できません // 中心から離した図形を使ってください",
	}.get(error, "操作できません // %s" % error)
