class_name FactorySettingOption
extends OptionButton

signal option_preview_requested(index: int)
signal option_preview_cleared

const FactoryNodeModel := preload("res://src/factory/factory_node.gd")

var visual_kind := -1
var visual_index := -1
var icon_cache: Dictionary = {}
var preview_index := -1


func _ready() -> void:
	item_selected.connect(_on_visual_item_selected)
	var popup := get_popup()
	popup.add_theme_constant_override("icon_max_width", 24)
	popup.id_focused.connect(_on_popup_id_focused)
	popup.window_input.connect(_on_popup_window_input)
	popup.popup_hide.connect(_clear_option_preview)


func configure_visual(kind: int, selected_index: int, detail: String) -> void:
	if kind != visual_kind or selected_index != visual_index:
		_clear_option_preview()
	visual_kind = kind
	visual_index = selected_index
	tooltip_text = detail if selected_index >= 0 else "%s // 候補を再選択" % detail
	_refresh_item_icons()


func _on_visual_item_selected(index: int) -> void:
	_clear_option_preview()
	visual_index = index


func _on_popup_id_focused(item_id: int) -> void:
	var popup := get_popup()
	var index := popup.get_item_index(item_id)
	if index < 0 and item_id >= 0 and item_id < item_count:
		index = item_id
	_request_option_preview(index)


func _on_popup_window_input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	var motion := event as InputEventMouseMotion
	var index := popup_item_index_at(motion.position)
	if index < 0:
		_clear_option_preview()
		return
	_request_option_preview(index)


func popup_item_index_at(at_position: Vector2) -> int:
	var popup := get_popup()
	if item_count <= 0:
		return -1
	var panel := popup.get_theme_stylebox("panel")
	var top_margin := maxf(panel.get_content_margin(SIDE_TOP), 0.0)
	var bottom_margin := maxf(panel.get_content_margin(SIDE_BOTTOM), 0.0)
	var content_height := float(popup.size.y) - top_margin - bottom_margin
	if content_height <= 0.0 or at_position.y < top_margin or at_position.y >= top_margin + content_height:
		return -1
	var index := int(floor((at_position.y - top_margin) / (content_height / float(item_count))))
	return index if index >= 0 and index < item_count else -1


func _request_option_preview(index: int) -> void:
	if index < 0 or index >= item_count or index == preview_index:
		return
	preview_index = index
	option_preview_requested.emit(index)


func _clear_option_preview() -> void:
	if preview_index < 0:
		return
	preview_index = -1
	option_preview_cleared.emit()


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
			var direction := rotation_direction_for_index(index)
			var endpoint := Vector2(12, 12) + Vector2(direction) * 8.0
			var normal := Vector2(-direction.y, direction.x)
			var arrow_left := endpoint - Vector2(direction) * 3.5 + normal * 2.5
			var arrow_right := endpoint - Vector2(direction) * 3.5 - normal * 2.5
			body = (
				"<circle cx='12' cy='12' r='9' fill='none' stroke='#294d66' stroke-width='1.2'/>"
				+ "<circle cx='12' cy='12' r='2' fill='#66d6ff'/>"
				+ "<path d='M12 12 L%.1f %.1f M%.1f %.1f L%.1f %.1f L%.1f %.1f' fill='none' stroke='#66d6ff' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'/>" % [
					endpoint.x, endpoint.y,
					arrow_left.x, arrow_left.y,
					endpoint.x, endpoint.y,
					arrow_right.x, arrow_right.y,
				]
			)
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


func rotation_direction_for_index(index: int) -> Vector2i:
	return [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT][clampi(index, 0, 2)]
