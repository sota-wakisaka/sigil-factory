class_name SealLab
extends Control

const SealCompilerModel := preload("res://src/sigil_v2/seal_compiler.gd")
const SealLimitsModel := preload("res://src/sigil_v2/seal_limits.gd")
const SealLabContentModel := preload("res://experiments/seal_lab/seal_lab_content.gd")
const SealLabViewModel := preload("res://experiments/seal_lab/seal_view.gd")

var fixtures: Array[Dictionary] = []
var compiled_fixtures: Array[Dictionary] = []
var catalog_buttons: Array[Button] = []
var catalog_views: Array = []
var large_views: Array = []
var small_views: Array = []
var selected_index := 9
var large_presentation: StringName = &"ceremonial"
var grayscale := false
var animation_progress := 1.0

var mode_buttons: Dictionary = {}
var grayscale_button: Button
var progress_slider: HSlider
var status_label: Label


func _ready() -> void:
	fixtures = SealLabContentModel.fixtures()
	_compile_fixtures()
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
	if key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
		_select_fixture(int(key_event.keycode - KEY_1))
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_0:
		_select_fixture(9)
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_R:
		_replay_animation()
		get_viewport().set_input_as_handled()


func select_fixture(index: int) -> void:
	_select_fixture(index)


func set_grayscale(enabled: bool) -> void:
	grayscale = enabled
	if grayscale_button != null:
		grayscale_button.set_pressed_no_signal(enabled)
	for view in catalog_views:
		view.set_grayscale(enabled)
	for entry in large_views:
		entry["view"].set_grayscale(enabled)
	for entry in small_views:
		entry["view"].set_grayscale(enabled)


func set_large_presentation(value: StringName) -> void:
	if not value in [&"operational", &"editing", &"ceremonial"]:
		return
	large_presentation = value
	for mode in mode_buttons:
		mode_buttons[mode].button_pressed = StringName(mode) == value
	for entry in large_views:
		entry["view"].set_presentation(value)


func set_animation_progress(value: float) -> void:
	animation_progress = clampf(value, 0.0, 1.0)
	if progress_slider != null and not is_equal_approx(progress_slider.value, animation_progress):
		progress_slider.set_value_no_signal(animation_progress)
	for entry in large_views:
		entry["view"].set_animation_progress(animation_progress)
	for entry in small_views:
		if StringName(entry["presentation"]) == &"ceremonial":
			entry["view"].set_animation_progress(animation_progress)


func _compile_fixtures() -> void:
	compiled_fixtures.clear()
	for fixture in fixtures:
		var limits := SealLimitsModel.profile(bool(fixture.get("hero", false)))
		var current := SealCompilerModel.compile(fixture["current"], limits)
		var hypothetical := SealCompilerModel.compile(fixture["hypothetical"], limits)
		compiled_fixtures.append({
			"current": current,
			"hypothetical": hypothetical,
		})


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
	body.add_child(_build_large_comparison())
	body.add_child(_build_lod_matrix())


func _build_toolbar() -> Control:
	var toolbar := HBoxContainer.new()
	toolbar.custom_minimum_size.y = 44.0
	toolbar.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "SEAL LAB // 放射幾何 V2"
	title.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0))
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)

	for definition in [
		[&"operational", "⚙", "意味線を即時表示"],
		[&"editing", "◇", "編集時の抑制表示"],
		[&"ceremonial", "◎", "完成演出表示"],
	]:
		var button := Button.new()
		button.text = definition[1]
		button.tooltip_text = definition[2]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(42, 36)
		var mode: StringName = definition[0]
		button.pressed.connect(set_large_presentation.bind(mode))
		toolbar.add_child(button)
		mode_buttons[mode] = button

	grayscale_button = Button.new()
	grayscale_button.text = "◐"
	grayscale_button.tooltip_text = "色を使わず形と属性刻みを確認"
	grayscale_button.toggle_mode = true
	grayscale_button.custom_minimum_size = Vector2(42, 36)
	grayscale_button.toggled.connect(func(enabled: bool) -> void:
		set_grayscale(enabled)
	)
	toolbar.add_child(grayscale_button)

	var replay := Button.new()
	replay.text = "↻"
	replay.tooltip_text = "生成順を再生"
	replay.custom_minimum_size = Vector2(42, 36)
	replay.pressed.connect(_replay_animation)
	toolbar.add_child(replay)

	progress_slider = HSlider.new()
	progress_slider.min_value = 0.0
	progress_slider.max_value = 1.0
	progress_slider.step = 0.01
	progress_slider.value = 1.0
	progress_slider.custom_minimum_size.x = 120.0
	progress_slider.tooltip_text = "生成進捗"
	progress_slider.value_changed.connect(func(value: float) -> void:
		set_animation_progress(value)
	)
	toolbar.add_child(progress_slider)
	return toolbar


func _build_catalog() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 184.0
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	for index in fixtures.size():
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 54.0
		row.add_theme_constant_override("separation", 5)
		var view = SealLabViewModel.new()
		view.custom_minimum_size = Vector2(48, 48)
		var result: Dictionary = compiled_fixtures[index]["current"]
		view.configure(
			result.get("plan"),
			32,
			&"operational",
			&"current",
			1.0,
			grayscale,
			index == selected_index
		)
		catalog_views.append(view)
		row.add_child(view)
		var button := Button.new()
		var tier_dots := "•".repeat(int(fixtures[index]["tier"]) + 1)
		button.text = "%02d  %s  %s" % [fixtures[index]["id"], fixtures[index]["label"], tier_dots]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "%s // キー %s" % [fixtures[index]["label"], "0" if index == 9 else str(index + 1)]
		button.pressed.connect(_select_fixture.bind(index))
		catalog_buttons.append(button)
		row.add_child(button)
		list.add_child(row)
	return panel


func _build_large_comparison() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 548.0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(0.58, 0.78, 0.94))
	column.add_child(status_label)
	var headings := HBoxContainer.new()
	headings.add_theme_constant_override("separation", 8)
	for heading in ["━━━━  CURRENT", "┄ ┄ ┄  HYPOTHETICAL"]:
		var label := Label.new()
		label.text = heading
		label.custom_minimum_size.x = 256.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.66, 0.82, 0.96))
		headings.add_child(label)
	column.add_child(headings)
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 8)
	for state_name in [&"current", &"hypothetical"]:
		var view = SealLabViewModel.new()
		view.custom_minimum_size = Vector2(256, 256)
		large_views.append({"view": view, "state": state_name})
		pair.add_child(view)
	column.add_child(pair)
	var note := Label.new()
	note.text = "意味線は同一文法 // 未確定側に正解表示なし"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color(0.42, 0.58, 0.7))
	column.add_child(note)
	return panel


func _build_lod_matrix() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 380.0
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := Label.new()
	title.text = "LOD // 80 + 32"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.62, 0.82, 0.98))
	column.add_child(title)
	for presentation_value in [&"operational", &"editing", &"ceremonial"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var marker := Label.new()
		marker.text = {&"operational": "⚙", &"editing": "◇", &"ceremonial": "◎"}[presentation_value]
		marker.tooltip_text = String(presentation_value)
		marker.custom_minimum_size.x = 24.0
		marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(marker)
		for state_value in [&"current", &"hypothetical"]:
			for lod in [80, 32]:
				var view = SealLabViewModel.new()
				view.custom_minimum_size = Vector2(lod + 12, lod + 12)
				small_views.append({
					"view": view,
					"state": state_value,
					"presentation": presentation_value,
					"lod": lod,
				})
				row.add_child(view)
		column.add_child(row)
	return panel


func _select_fixture(index: int) -> void:
	selected_index = clampi(index, 0, fixtures.size() - 1)
	_bind_selected_views()


func _bind_selected_views() -> void:
	if compiled_fixtures.is_empty() or selected_index < 0 or selected_index >= compiled_fixtures.size():
		return
	for index in catalog_buttons.size():
		catalog_buttons[index].button_pressed = index == selected_index
		catalog_views[index].set_selected(index == selected_index)
	var selected := compiled_fixtures[selected_index]
	var fixture := fixtures[selected_index]
	if status_label != null:
		var current_result: Dictionary = selected["current"]
		status_label.text = "%02d // %s // %s" % [
			fixture["id"],
			fixture["label"],
			"READY" if current_result.get("ok", false) else "INVALID",
		]
	for entry in large_views:
		var state_value: StringName = entry["state"]
		var result: Dictionary = selected[String(state_value)]
		entry["view"].configure(
			result.get("plan"),
			256,
			large_presentation,
			state_value,
			animation_progress,
			grayscale
		)
	for entry in small_views:
		var state_value: StringName = entry["state"]
		var result: Dictionary = selected[String(state_value)]
		entry["view"].configure(
			result.get("plan"),
			int(entry["lod"]),
			StringName(entry["presentation"]),
			state_value,
			animation_progress,
			grayscale
		)


func _replay_animation() -> void:
	if large_presentation != &"ceremonial":
		set_large_presentation(&"ceremonial")
	set_animation_progress(0.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(set_animation_progress, 0.0, 1.0, 1.0)
