class_name LegacyGlyphLab
extends Control

const LegacyContentModel := preload("res://experiments/seal_lab/legacy_glyph_lab_content.gd")
const LegacyGlyphViewModel := preload("res://experiments/seal_lab/legacy_glyph_view.gd")

const MAIN_MENU_SCENE := "res://src/main_menu.tscn"
const V2_LAB_SCENE := "res://experiments/seal_lab/seal_lab.tscn"

var fixtures: Array[Dictionary] = []
var selected_index := 5
var catalog_buttons: Array[Button] = []
var catalog_views: Array = []
var large_view
var lod_views: Array = []
var status_label: Label
var structure_label: Label
var description_label: Label
var menu_button: Button
var v2_button: Button


func _ready() -> void:
	fixtures = LegacyContentModel.fixtures()
	_build_ui()
	_select_fixture(selected_index)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.008, 0.018, 0.032, 1.0), true)
	for index in 8:
		var y := 80.0 + float(index) * 104.0
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.12, 0.26, 0.38, 0.07), 1.0)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event: InputEventKey = event
	if key_event.keycode >= KEY_1 and key_event.keycode <= KEY_6:
		_select_fixture(int(key_event.keycode - KEY_1))
		get_viewport().set_input_as_handled()


func select_fixture(index: int) -> void:
	_select_fixture(index)


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)
	page.add_child(_build_toolbar())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	page.add_child(body)
	body.add_child(_build_catalog())
	body.add_child(_build_large_preview())
	body.add_child(_build_readout())


func _build_toolbar() -> Control:
	var toolbar := HBoxContainer.new()
	toolbar.custom_minimum_size.y = 44.0
	toolbar.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "SEAL LAB // MVP方式の複雑化"
	title.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0))
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)

	v2_button = Button.new()
	v2_button.text = "V2 LAB"
	v2_button.tooltip_text = "放射幾何V2の作例へ"
	v2_button.custom_minimum_size = Vector2(92, 36)
	v2_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(V2_LAB_SCENE)
	)
	toolbar.add_child(v2_button)

	menu_button = Button.new()
	menu_button.text = "← MENU"
	menu_button.tooltip_text = "メインメニューへ戻る"
	menu_button.custom_minimum_size = Vector2(96, 36)
	menu_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	)
	toolbar.add_child(menu_button)
	return toolbar


func _build_catalog() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 250.0
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	panel.add_child(list)

	var heading := Label.new()
	heading.text = "素材数を増やした実例"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color(0.62, 0.82, 0.98))
	list.add_child(heading)

	for index in fixtures.size():
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 76.0
		row.add_theme_constant_override("separation", 6)
		var view = LegacyGlyphViewModel.new()
		view.custom_minimum_size = Vector2(70, 70)
		view.configure(fixtures[index]["glyph"], index == selected_index)
		catalog_views.append(view)
		row.add_child(view)

		var button := Button.new()
		button.text = "%d  %s\n%s" % [
			fixtures[index]["id"],
			fixtures[index]["label"],
			fixtures[index]["structure"],
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "%s // キー%d" % [fixtures[index]["description"], index + 1]
		button.pressed.connect(_select_fixture.bind(index))
		catalog_buttons.append(button)
		row.add_child(button)
		list.add_child(row)
	return panel


func _build_large_preview() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 560.0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(0.62, 0.84, 1.0))
	column.add_child(status_label)

	large_view = LegacyGlyphViewModel.new()
	large_view.custom_minimum_size = Vector2(470, 470)
	large_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(large_view)

	var note := Label.new()
	note.text = "MVPと同じGlyphModel / GlyphPainter // 外周と接続線も自動生成"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color(0.42, 0.6, 0.74))
	column.add_child(note)
	return panel


func _build_readout() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 330.0
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var heading := Label.new()
	heading.text = "同じGlyphの表示サイズ"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color(0.62, 0.82, 0.98))
	column.add_child(heading)

	var lod_row := HBoxContainer.new()
	lod_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lod_row.add_theme_constant_override("separation", 6)
	for lod in [160, 88, 48]:
		var view = LegacyGlyphViewModel.new()
		view.custom_minimum_size = Vector2(lod, lod)
		lod_views.append(view)
		lod_row.add_child(view)
	column.add_child(lod_row)

	structure_label = Label.new()
	structure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	structure_label.add_theme_color_override("font_color", Color(0.74, 0.88, 1.0))
	column.add_child(structure_label)

	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.add_theme_color_override("font_color", Color(0.52, 0.7, 0.84))
	column.add_child(description_label)

	var rules := Label.new()
	rules.text = "使用規則\n\n素材: 環 / 棘 / 枝\n加工: 移動 / 90°回転 / 着色\n構造: 2入力Combineのみ\n描画: 合成円と接続線を自動生成"
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.add_theme_color_override("font_color", Color(0.46, 0.62, 0.74))
	column.add_child(rules)
	return panel


func _select_fixture(index: int) -> void:
	selected_index = clampi(index, 0, fixtures.size() - 1)
	for catalog_index in catalog_buttons.size():
		catalog_buttons[catalog_index].button_pressed = catalog_index == selected_index
		catalog_views[catalog_index].set_selected(catalog_index == selected_index)
	var fixture := fixtures[selected_index]
	large_view.configure(fixture["glyph"], true)
	for view in lod_views:
		view.configure(fixture["glyph"])
	status_label.text = "%02d // %s" % [fixture["id"], fixture["label"]]
	structure_label.text = "素材 %d // 合成 %d // 深度 %d" % [
		fixture["leaf_count"],
		fixture["combine_count"],
		fixture["depth"],
	]
	description_label.text = fixture["description"]
