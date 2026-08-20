class_name FactorySettingOption
extends OptionButton

const FactoryNodeModel := preload("res://src/factory/factory_node.gd")

var visual_kind := -1
var visual_index := -1


func _ready() -> void:
	item_selected.connect(_on_visual_item_selected)
	queue_redraw()


func configure_visual(kind: int, selected_index: int, detail: String) -> void:
	visual_kind = kind
	visual_index = selected_index
	tooltip_text = detail if selected_index >= 0 else "設定可能な設備を選択"
	queue_redraw()


func _on_visual_item_selected(index: int) -> void:
	visual_index = index
	queue_redraw()


func _draw() -> void:
	if disabled or visual_index < 0:
		return
	var center := Vector2(22.0, size.y * 0.5)
	var color := Color(0.4, 0.84, 1.0)
	match visual_kind:
		FactoryNodeModel.NodeKind.SOURCE:
			if visual_index == 0:
				draw_arc(center, 8.0, 0.0, TAU, 24, color, 2.0, true)
			else:
				var points := PackedVector2Array([
					center + Vector2(0, -9), center + Vector2(7, 7), center,
					center + Vector2(-7, 7), center + Vector2(0, -9),
				])
				draw_polyline(points, color, 2.0, true)
		FactoryNodeModel.NodeKind.ROTATOR:
			draw_arc(center, 8.0, -0.4, TAU - 0.8, 20, color, 2.0, true)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(7, -5), center + Vector2(11, -4), center + Vector2(8, 0),
			]), color)
		FactoryNodeModel.NodeKind.COLORIZER:
			var swatches := [Color(0.25, 0.68, 1.0), Color(1.0, 0.3, 0.28), Color(0.92, 0.95, 1.0)]
			color = swatches[clampi(visual_index, 0, swatches.size() - 1)]
			draw_circle(center, 8.0, color)
			draw_arc(center, 9.5, 0.0, TAU, 24, Color(0.7, 0.86, 1.0), 1.2, true)
