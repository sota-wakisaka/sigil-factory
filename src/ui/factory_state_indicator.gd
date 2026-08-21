class_name FactoryStateIndicator
extends Control

var state: StringName = &"pending"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_HELP
	queue_redraw()


func configure(message: String) -> void:
	tooltip_text = message
	if "構築可能" in message:
		state = &"ready"
	elif message.begins_with("Ⅱ"):
		state = &"paused"
	elif "未接続" in message or "配線待ち" in message:
		state = &"pending"
	else:
		state = &"changed"
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	match state:
		&"ready":
			var color := Color(0.38, 1.0, 0.62)
			draw_circle(center, 10.0, Color(0.02, 0.09, 0.055, 0.92))
			draw_arc(center, 10.0, 0.0, TAU, 24, color, 1.8, true)
			draw_line(center + Vector2(-5, 0), center + Vector2(-1, 4), color, 2.0, true)
			draw_line(center + Vector2(-1, 4), center + Vector2(6, -5), color, 2.0, true)
		&"paused":
			var color := Color(0.42, 0.8, 1.0)
			draw_arc(center, 10.0, 0.0, TAU, 24, color, 1.8, true)
			draw_line(center + Vector2(-3.5, -5), center + Vector2(-3.5, 5), color, 2.3, true)
			draw_line(center + Vector2(3.5, -5), center + Vector2(3.5, 5), color, 2.3, true)
		&"changed":
			var color := Color(1.0, 0.78, 0.3)
			var diamond := PackedVector2Array([
				center + Vector2(0, -9), center + Vector2(9, 0),
				center + Vector2(0, 9), center + Vector2(-9, 0), center + Vector2(0, -9),
			])
			draw_polyline(diamond, color, 1.8, true)
			draw_circle(center, 2.5, color)
		_:
			var color := Color(1.0, 0.72, 0.24)
			draw_circle(center + Vector2(-8, 0), 3.5, Color(0.02, 0.05, 0.08), true)
			draw_arc(center + Vector2(-8, 0), 3.5, 0.0, TAU, 16, color, 1.4, true)
			draw_circle(center + Vector2(8, 0), 3.5, Color(0.02, 0.05, 0.08), true)
			draw_arc(center + Vector2(8, 0), 3.5, 0.0, TAU, 16, color, 1.4, true)
			draw_dashed_line(center + Vector2(-4, 0), center + Vector2(4, 0), color, 1.5, 3.0)
