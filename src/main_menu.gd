class_name MainMenu
extends Control

const FACTORY_PROTOTYPE_SCENE := "res://experiments/factory_prototype/factory_prototype.tscn"
const SIGIL_LAB_SCENE := "res://experiments/sigil_lab/sigil_lab.tscn"

var factory_button: Button
var sigil_lab_button: Button


func _ready() -> void:
	_build_ui()
	factory_button.grab_focus()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.006, 0.014, 0.026, 1.0), true)
	var center := size * 0.5
	for radius in [160.0, 280.0, 420.0]:
		draw_arc(center, radius, 0.0, TAU, 96, Color(0.20, 0.58, 0.76, 0.055), 1.0)
	for index in 12:
		var angle := TAU * float(index) / 12.0
		draw_line(
			center + Vector2.from_angle(angle) * 130.0,
			center + Vector2.from_angle(angle) * 460.0,
			Color(0.20, 0.58, 0.76, 0.035),
			1.0
		)


func open_factory_prototype() -> void:
	get_tree().change_scene_to_file(FACTORY_PROTOTYPE_SCENE)


func open_sigil_lab() -> void:
	get_tree().change_scene_to_file(SIGIL_LAB_SCENE)


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820.0, 430.0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_bottom", 36)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var title := Label.new()
	title.text = "SIGIL FACTORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "魔導工場を構築し、形を生産する"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.50, 0.66, 0.76))
	column.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12.0
	column.add_child(spacer)

	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 18)
	column.add_child(choices)

	factory_button = _menu_card(
		"工場プロトタイプ",
		"○ △ □ が点在する広域工場",
		"固定素材から中央の召喚器へ"
	)
	factory_button.name = "FactoryPrototypeButton"
	factory_button.pressed.connect(open_factory_prototype)
	choices.add_child(factory_button)

	sigil_lab_button = _menu_card(
		"SIGIL LAB",
		"ノードを自由に接続する編集室",
		"意味グリフの作成とJSON出力"
	)
	sigil_lab_button.name = "SigilLabButton"
	sigil_lab_button.pressed.connect(open_sigil_lab)
	choices.add_child(sigil_lab_button)

	factory_button.focus_neighbor_right = factory_button.get_path_to(sigil_lab_button)
	sigil_lab_button.focus_neighbor_left = sigil_lab_button.get_path_to(factory_button)

	var hint := Label.new()
	hint.text = "← → で選択  /  Enterで開く"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.38, 0.52, 0.62))
	column.add_child(hint)


func _menu_card(title: String, description: String, detail: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(340.0, 168.0)
	button.text = "%s\n\n%s\n%s" % [title, description, detail]
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _card_style(Color(0.08, 0.15, 0.20, 0.94), Color(0.18, 0.42, 0.56)))
	button.add_theme_stylebox_override("hover", _card_style(Color(0.09, 0.20, 0.27, 0.98), Color(0.28, 0.72, 0.91)))
	button.add_theme_stylebox_override("focus", _card_style(Color(0.09, 0.20, 0.27, 0.98), Color(0.72, 0.92, 1.0)))
	button.add_theme_stylebox_override("pressed", _card_style(Color(0.06, 0.28, 0.36, 1.0), Color(0.72, 0.92, 1.0)))
	return button


static func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.045, 0.068, 0.97)
	style.border_color = Color(0.18, 0.42, 0.56, 0.9)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


static func _card_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	return style
