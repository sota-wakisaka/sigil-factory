class_name StageThreatTimeline
extends Control

const MvpContent := preload("res://src/game/mvp_content.gd")
const ThreatIconPainter := preload("res://src/ui/threat_icon_painter.gd")
const ENCOUNTER_TICKS := 900

var route_id: StringName = MvpContent.ROUTE_MIXED
var route_number := 1


func configure(next_route_id: StringName, next_route_number: int) -> void:
	route_id = next_route_id
	route_number = maxi(next_route_number, 1)
	tooltip_text = MvpContent.route_description(route_id)
	queue_redraw()


func marker_count() -> int:
	return _markers().size()


func _draw() -> void:
	var accent := Color(0.38, 0.82, 1.0, 1.0)
	var muted := Color(0.35, 0.44, 0.56, 0.72)
	var start := Vector2(38, 58)
	var finish := Vector2(size.x - 38, 58)
	draw_line(start, finish, muted, 2.0, true)
	for fraction in [0.0, 1.0 / 3.0, 2.0 / 3.0, 1.0]:
		var x := lerpf(start.x, finish.x, fraction)
		draw_line(Vector2(x, 52), Vector2(x, 64), muted, 1.0, true)
	for marker in _markers():
		var x := lerpf(start.x, finish.x, float(marker["tick"]) / float(ENCOUNTER_TICKS))
		var center := Vector2(x, 32)
		draw_line(Vector2(x, 47), Vector2(x, 58), Color(accent, 0.65), 1.0, true)
		ThreatIconPainter.draw_enemy(self, center, marker["kind"], accent, 0.82)
	draw_string(ThemeDB.fallback_font, Vector2(start.x - 12, 86), "0:00", HORIZONTAL_ALIGNMENT_LEFT, 50, 11, muted)
	draw_string(ThemeDB.fallback_font, Vector2(finish.x - 38, 86), "3:00", HORIZONTAL_ALIGNMENT_RIGHT, 50, 11, muted)
	var durability := roundi((MvpContent.route_durability_multiplier(route_number) - 1.0) * 100.0)
	if durability > 0:
		draw_string(ThemeDB.fallback_font, Vector2(size.x - 112, 17), "+%d%%" % durability, HORIZONTAL_ALIGNMENT_RIGHT, 72, 12, Color(0.92, 0.72, 0.34))


func _markers() -> Array[Dictionary]:
	match route_id:
		MvpContent.ROUTE_SWARM:
			return [
				{"tick": 100, "kind": &"raider"},
				{"tick": 280, "kind": &"swarm"},
				{"tick": 700, "kind": &"swarm"},
			]
		MvpContent.ROUTE_ARMORED:
			return [
				{"tick": 100, "kind": &"raider"},
				{"tick": 280, "kind": &"swarm"},
				{"tick": 460, "kind": &"brute"},
			]
	return [
		{"tick": 100, "kind": &"raider"},
		{"tick": 300, "kind": &"swarm"},
		{"tick": 570, "kind": &"brute"},
		{"tick": 780, "kind": &"brute"},
	]
