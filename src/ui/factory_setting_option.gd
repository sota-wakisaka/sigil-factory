class_name FactorySettingOption
extends OptionButton

const FactoryNodeModel := preload("res://src/factory/factory_node.gd")

var visual_kind := -1
var visual_index := -1
var icon_cache: Dictionary = {}


func _ready() -> void:
	item_selected.connect(_on_visual_item_selected)
	get_popup().add_theme_constant_override("icon_max_width", 24)


func configure_visual(kind: int, selected_index: int, detail: String) -> void:
	visual_kind = kind
	visual_index = selected_index
	tooltip_text = detail if selected_index >= 0 else "設定可能な設備を選択"
	_refresh_item_icons()


func _on_visual_item_selected(index: int) -> void:
	visual_index = index


func _refresh_item_icons() -> void:
	for index in item_count:
		set_item_icon(index, _setting_icon(visual_kind, index))


func _setting_icon(kind: int, index: int) -> Texture2D:
	var key := "%d:%d" % [kind, index]
	if icon_cache.has(key):
		return icon_cache[key]
	var body := ""
	match kind:
		FactoryNodeModel.NodeKind.SOURCE:
			body = (
				"<path d='M17.5 17.5 A8 8 0 1 1 17.5 6.5' fill='none' stroke='#66d6ff' stroke-width='2.4' stroke-linecap='round'/>"
				if index == 0
				else "<path d='M12 3 L20 20 L12 15 L4 20 Z' fill='none' stroke='#66d6ff' stroke-width='2' stroke-linejoin='round'/>"
			)
		FactoryNodeModel.NodeKind.ROTATOR:
			body = "<path d='M18 8 A7 7 0 1 0 19 15 M18 8 L18 3 L22 7' fill='none' stroke='#66d6ff' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'/>"
		FactoryNodeModel.NodeKind.COLORIZER:
			var colors := ["#40adff", "#ff4d48", "#edf4ff"]
			body = "<circle cx='12' cy='12' r='8' fill='%s' stroke='#9edcff' stroke-width='1.5'/>" % colors[clampi(index, 0, colors.size() - 1)]
		_:
			return null
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24'>%s</svg>" % body
	var image := Image.new()
	if image.load_svg_from_string(svg, 1.0) != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	icon_cache[key] = texture
	return texture
