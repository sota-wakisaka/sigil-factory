class_name RouteChoiceButton
extends Button

const MvpContent := preload("res://src/game/mvp_content.gd")

@export var route_id: StringName


func _ready() -> void:
	toggle_mode = true
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "%s // %s" % [
		MvpContent.route_name(route_id),
		MvpContent.route_description(route_id),
	]
	queue_redraw()


func set_route_selected(selected: bool) -> void:
	set_pressed_no_signal(selected)
	queue_redraw()


func _draw() -> void:
	var accent := Color(0.4, 0.86, 1.0, 1.0) if button_pressed else Color(0.48, 0.58, 0.7, 1.0)
	var panel := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	draw_rect(panel, Color(0.035, 0.055, 0.085, 0.98), true)
	draw_rect(panel, accent, false, 2.0 if button_pressed else 1.0)
	var formation := _formation()
	var spacing := 32.0
	var start_x := size.x * 0.5 - spacing * float(formation.size() - 1) * 0.5
	for index in formation.size():
		_draw_enemy(Vector2(start_x + spacing * index, 42.0), formation[index], accent)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(12, size.y - 22),
		MvpContent.route_name(route_id).replace("の道", ""),
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x - 24,
		16,
		accent
	)


func _formation() -> Array[StringName]:
	match route_id:
		MvpContent.ROUTE_SWARM:
			return [&"swarm", &"swarm", &"swarm", &"brute"]
		MvpContent.ROUTE_ARMORED:
			return [&"swarm", &"brute", &"brute", &"brute"]
	return [&"raider", &"swarm", &"brute"]


func _draw_enemy(center: Vector2, kind: StringName, color: Color) -> void:
	match kind:
		&"swarm":
			for offset in [Vector2(-5, 3), Vector2(0, -5), Vector2(5, 3)]:
				draw_circle(center + offset, 3.0, color)
		&"brute":
			var points := PackedVector2Array([
				center + Vector2(-8, -7), center + Vector2(8, -7),
				center + Vector2(6, 6), center + Vector2(0, 10), center + Vector2(-6, 6),
			])
			draw_polyline(points, color, 2.0, true)
			draw_line(points[points.size() - 1], points[0], color, 2.0, true)
		_:
			var points := PackedVector2Array([
				center + Vector2(0, -9), center + Vector2(9, 7), center + Vector2(-9, 7), center + Vector2(0, -9),
			])
			draw_polyline(points, color, 2.0, true)
