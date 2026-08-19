class_name FactorySelectionIndicator
extends Control

const FactoryNodeModel := preload("res://src/factory/factory_node.gd")

const ACTIVE_COLOR := Color(1.0, 0.78, 0.3, 0.96)
const IDLE_COLOR := Color(0.34, 0.5, 0.62, 0.66)

var selected := false
var node_kind := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_HELP
	queue_redraw()


func configure(next_selected: bool, next_kind: int, title: String) -> void:
	selected = next_selected
	node_kind = next_kind
	tooltip_text = title if selected else "設備を選択すると設定を変更できます"
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	if not selected:
		_draw_idle_target(center)
		return
	match node_kind:
		FactoryNodeModel.NodeKind.SOURCE:
			_draw_hex(center, Vector2(21, 15), ACTIVE_COLOR)
			draw_circle(center, 4.0, ACTIVE_COLOR)
		FactoryNodeModel.NodeKind.COMBINER:
			_draw_hex(center, Vector2(23, 17), ACTIVE_COLOR)
			draw_arc(center + Vector2(-6, 0), 7.0, 0.0, TAU, 20, ACTIVE_COLOR, 1.6, true)
			draw_arc(center + Vector2(6, 0), 7.0, 0.0, TAU, 20, ACTIVE_COLOR, 1.6, true)
		FactoryNodeModel.NodeKind.SUMMONER:
			draw_arc(center, 19.0, 0.0, TAU, 28, ACTIVE_COLOR, 2.0, true)
			draw_arc(center, 12.0, 0.0, TAU, 24, Color(ACTIVE_COLOR, 0.56), 1.2, true)
		_:
			var points := PackedVector2Array([
				center + Vector2(-19, -14), center + Vector2(19, -14),
				center + Vector2(24, -9), center + Vector2(24, 9),
				center + Vector2(19, 14), center + Vector2(-19, 14),
				center + Vector2(-24, 9), center + Vector2(-24, -9),
			])
			draw_colored_polygon(points, Color(0.06, 0.1, 0.15, 0.9))
			draw_polyline(PackedVector2Array(Array(points) + [points[0]]), ACTIVE_COLOR, 2.0, true)
			draw_circle(center, 4.0, ACTIVE_COLOR)


func _draw_idle_target(center: Vector2) -> void:
	draw_arc(center, 10.0, 0.0, TAU, 24, IDLE_COLOR, 1.2, true)
	draw_circle(center, 2.0, IDLE_COLOR)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + direction * 13.0, center + direction * 20.0, IDLE_COLOR, 1.2, true)


func _draw_hex(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(-radius.x * 0.72, -radius.y),
		center + Vector2(radius.x * 0.72, -radius.y),
		center + Vector2(radius.x, 0),
		center + Vector2(radius.x * 0.72, radius.y),
		center + Vector2(-radius.x * 0.72, radius.y),
		center + Vector2(-radius.x, 0),
	])
	draw_colored_polygon(points, Color(0.06, 0.1, 0.15, 0.9))
	draw_polyline(PackedVector2Array(Array(points) + [points[0]]), color, 2.0, true)
