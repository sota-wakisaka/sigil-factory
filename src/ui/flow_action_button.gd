class_name FlowActionButton
extends Button

@export_enum("start", "pause", "resume", "cancel") var action_kind := "pause":
	set(value):
		action_kind = value
		queue_redraw()


func configure_action(next_kind: String, caption: String, detail: String) -> void:
	action_kind = next_kind
	text = caption
	tooltip_text = detail
	queue_redraw()


func _draw() -> void:
	var color := Color(0.38, 0.82, 1.0)
	if action_kind == "start" or action_kind == "resume":
		color = Color(0.38, 1.0, 0.62)
	elif action_kind == "cancel":
		color = Color(1.0, 0.42, 0.34)
	if disabled:
		color = Color(color, 0.35)
	var center := Vector2(22.0, size.y * 0.5)
	draw_circle(center, 11.0, Color(0.02, 0.055, 0.08, 0.9))
	draw_arc(center, 11.0, 0.0, TAU, 24, color, 1.6, true)
	match action_kind:
		"start":
			_draw_play(center, color)
		"pause":
			draw_line(center + Vector2(-3.5, -5), center + Vector2(-3.5, 5), color, 2.5, true)
			draw_line(center + Vector2(3.5, -5), center + Vector2(3.5, 5), color, 2.5, true)
		"resume":
			_draw_play(center - Vector2(1, 0), color)
			var check_center := center + Vector2(8, -8)
			draw_circle(check_center, 4.5, Color(0.02, 0.09, 0.055), true)
			draw_line(check_center + Vector2(-2.2, 0), check_center + Vector2(-0.4, 2), color, 1.4, true)
			draw_line(check_center + Vector2(-0.4, 2), check_center + Vector2(2.8, -2.4), color, 1.4, true)
		"cancel":
			draw_line(center + Vector2(-4, -4), center + Vector2(4, 4), color, 2.2, true)
			draw_line(center + Vector2(-4, 4), center + Vector2(4, -4), color, 2.2, true)


func _draw_play(center: Vector2, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(-3.5, -5.5),
		center + Vector2(5.0, 0),
		center + Vector2(-3.5, 5.5),
	])
	draw_colored_polygon(points, color)
