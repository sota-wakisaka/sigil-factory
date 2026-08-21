class_name StageThreatTimeline
extends Control

const MvpContent := preload("res://src/game/mvp_content.gd")
const ThreatIconPainter := preload("res://src/ui/threat_icon_painter.gd")
const ENCOUNTER_TICKS := 900
const LANE_IDS: Array[StringName] = [&"raider", &"swarm", &"brute"]
const LANE_COLORS := {
	&"raider": Color(0.42, 0.78, 1.0, 1.0),
	&"swarm": Color(0.82, 0.58, 1.0, 1.0),
	&"brute": Color(1.0, 0.68, 0.34, 1.0),
}

var route_id: StringName = MvpContent.ROUTE_MIXED
var route_number := 1


func configure(next_route_id: StringName, next_route_number: int) -> void:
	route_id = next_route_id
	route_number = maxi(next_route_number, 1)
	var counts := PackedStringArray()
	for unit_id in LANE_IDS:
		counts.append("%s %d波" % [_unit_label(unit_id), lane_event_count(unit_id)])
	tooltip_text = "%s // %s" % [MvpContent.route_description(route_id), " / ".join(counts)]
	queue_redraw()


func marker_count() -> int:
	return MvpContent.major_threat_events(route_id).size()


func event_count() -> int:
	return MvpContent.threat_schedule(route_id).size()


func lane_event_count(unit_id: StringName) -> int:
	var count := 0
	for event in MvpContent.threat_schedule(route_id):
		if event.unit_id == unit_id:
			count += 1
	return count


func _draw() -> void:
	var muted := Color(0.35, 0.44, 0.56, 0.72)
	var start_x := 68.0
	var finish_x := size.x - 24.0
	var top := 20.0
	var lane_gap := 27.0
	var axis_y := top + lane_gap * float(LANE_IDS.size()) + 9.0
	for lane_index in LANE_IDS.size():
		var unit_id := LANE_IDS[lane_index]
		var lane_y := top + lane_gap * float(lane_index)
		var lane_color: Color = LANE_COLORS[unit_id]
		ThreatIconPainter.draw_enemy(self, Vector2(28, lane_y), unit_id, lane_color, 0.72)
		draw_line(Vector2(start_x, lane_y), Vector2(finish_x, lane_y), Color(muted, 0.42), 1.0, true)
	for event in MvpContent.threat_schedule(route_id):
		var lane_index := LANE_IDS.find(event.unit_id)
		if lane_index < 0:
			continue
		var lane_y := top + lane_gap * float(lane_index)
		var x := lerpf(start_x, finish_x, float(event.tick) / float(ENCOUNTER_TICKS))
		var pulse_height := minf(5.0 + float(event.count) * 1.7, 13.0)
		var lane_color: Color = LANE_COLORS[event.unit_id]
		draw_line(Vector2(x, lane_y - pulse_height), Vector2(x, lane_y + pulse_height), Color(lane_color, 0.88), 2.0, true)
		if event.is_major_change:
			var diamond := PackedVector2Array([
				Vector2(x, lane_y - pulse_height - 5.0),
				Vector2(x + 3.0, lane_y - pulse_height - 2.0),
				Vector2(x, lane_y - pulse_height + 1.0),
				Vector2(x - 3.0, lane_y - pulse_height - 2.0),
			])
			draw_colored_polygon(diamond, lane_color)
	draw_line(Vector2(start_x, axis_y), Vector2(finish_x, axis_y), muted, 2.0, true)
	for fraction in [0.0, 1.0 / 3.0, 2.0 / 3.0, 1.0]:
		var x := lerpf(start_x, finish_x, fraction)
		draw_line(Vector2(x, axis_y - 5), Vector2(x, axis_y + 5), muted, 1.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(start_x - 12, axis_y + 20), "0:00", HORIZONTAL_ALIGNMENT_LEFT, 50, 11, muted)
	draw_string(ThemeDB.fallback_font, Vector2(finish_x - 38, axis_y + 20), "3:00", HORIZONTAL_ALIGNMENT_RIGHT, 50, 11, muted)
	var durability := roundi((MvpContent.route_durability_multiplier(route_number) - 1.0) * 100.0)
	if durability > 0:
		draw_string(ThemeDB.fallback_font, Vector2(size.x - 112, 17), "+%d%%" % durability, HORIZONTAL_ALIGNMENT_RIGHT, 72, 12, Color(0.92, 0.72, 0.34))


func _unit_label(unit_id: StringName) -> String:
	match unit_id:
		&"swarm":
			return "群体"
		&"brute":
			return "装甲"
	return "襲撃"
