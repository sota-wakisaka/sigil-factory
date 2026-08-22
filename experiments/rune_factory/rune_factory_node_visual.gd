class_name RuneFactoryNodeVisual
extends Control

const RunePacketModel := preload("res://src/rune/rune_packet.gd")
const RunePacketViewModel := preload("res://experiments/rune_factory/rune_packet_view.gd")

var node_kind: StringName = &"relay"
var packet: RunePacket
var config: Dictionary = {}
var packet_view: RunePacketView


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_packet_view()


func configure(next_kind: StringName, next_packet: RunePacket = null, next_config: Dictionary = {}) -> void:
	node_kind = next_kind
	packet = next_packet.copy() if next_packet != null else RunePacketModel.empty()
	config = next_config.duplicate(true)
	custom_minimum_size = Vector2.ONE * (176.0 if node_kind == &"summoner" else 122.0)
	_ensure_packet_view()
	packet_view.configure(packet, RunePacketViewModel.DisplayMode.NODE)
	queue_redraw()


func body_radius() -> float:
	var local_size := size if size.x > 0.0 and size.y > 0.0 else custom_minimum_size
	return minf(local_size.x, local_size.y) * (0.39 if node_kind == &"summoner" else 0.40)


func _ensure_packet_view() -> void:
	if packet_view != null:
		return
	packet_view = RunePacketViewModel.new()
	packet_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	packet_view.set_anchors_preset(Control.PRESET_CENTER)
	packet_view.position = Vector2(-56.0, -56.0)
	packet_view.size = Vector2(112.0, 112.0)
	add_child(packet_view)


func _draw() -> void:
	var center := size * 0.5
	var radius := body_radius()
	var accent := _accent_color()
	draw_circle(center, radius, Color(0.008, 0.043, 0.061, 0.97), true)
	draw_arc(center, radius, 0.0, TAU, 64, Color(accent, 0.86), 1.7, true)
	if node_kind == &"summoner":
		_draw_summoner(center, radius, accent)
	elif node_kind == &"shift":
		_draw_shift(center, radius, accent)
	elif node_kind == &"attune":
		_draw_attune(center, radius)
	elif node_kind == &"extract":
		_draw_extract(center, radius, accent)
	elif node_kind == &"merge":
		_draw_merge(center, radius, accent)
	elif node_kind == &"relay":
		_draw_relay(center, radius, accent)
	elif node_kind == &"source":
		for tick in 12:
			var angle := TAU * float(tick) / 12.0
			var direction := Vector2.from_angle(angle)
			draw_line(center + direction * radius * 0.88, center + direction * radius, Color(accent, 0.52), 1.0)


func _draw_summoner(center: Vector2, radius: float, accent: Color) -> void:
	for scale in [0.78, 0.48, 0.22]:
		draw_arc(center, radius * scale, 0.0, TAU, 64, Color(accent, 0.55), 1.0)
	for index in 6:
		var direction := Vector2.from_angle(-PI * 0.5 + TAU * float(index) / 6.0)
		draw_line(center + direction * radius * 0.48, center + direction * radius * 0.78, Color(accent, 0.48), 1.0)
	packet_view.visible = false


func _draw_shift(center: Vector2, radius: float, accent: Color) -> void:
	var direction := Vector2(config.get("direction", Vector2i.RIGHT)).normalized()
	var tangent := Vector2(-direction.y, direction.x)
	var start := center - direction * radius * 0.30
	var finish := center + direction * radius * 0.34
	draw_line(start, finish, accent, 2.2)
	draw_colored_polygon(PackedVector2Array([
		finish + direction * 5.0,
		finish - direction * 5.0 + tangent * 4.0,
		finish - direction * 5.0 - tangent * 4.0,
	]), accent)
	packet_view.modulate.a = 0.35


func _draw_attune(center: Vector2, radius: float) -> void:
	for attribute_index in RunePacketModel.ATTRIBUTE_COUNT:
		var angle := -PI * 0.5 + TAU * float(attribute_index) / 3.0
		var direction := Vector2.from_angle(angle)
		var point := center + direction * radius * 0.58
		draw_circle(point, 5.0, RunePacketModel.attribute_color(attribute_index), true)
		var next_direction := Vector2.from_angle(angle + TAU / 3.0)
		draw_arc(center, radius * 0.58, angle + 0.18, angle + TAU / 3.0 - 0.18, 12, Color(0.76, 0.92, 1.0, 0.62), 1.2)
		draw_circle(center + next_direction * radius * 0.58, 1.7, Color(0.76, 0.92, 1.0, 0.78), true)
	packet_view.modulate.a = 0.28


func _draw_extract(center: Vector2, radius: float, accent: Color) -> void:
	draw_line(center + Vector2(0.0, -radius * 0.45), center, accent, 1.8)
	draw_line(center, center + Vector2(-radius * 0.42, radius * 0.34), accent, 1.8)
	draw_line(center, center + Vector2(radius * 0.42, radius * 0.34), accent, 1.8)
	draw_circle(center, 3.2, accent, true)
	packet_view.modulate.a = 0.26


func _draw_merge(center: Vector2, radius: float, accent: Color) -> void:
	for index in 4:
		var angle := -PI * 0.75 + PI * 0.5 * float(index)
		var point := center + Vector2.from_angle(angle) * radius * 0.55
		draw_line(point, center, Color(accent, 0.58), 1.2)
		draw_circle(point, 3.0, accent, true)
	draw_circle(center, 5.0, Color(0.006, 0.025, 0.035, 1.0), true)
	draw_arc(center, 5.0, 0.0, TAU, 20, accent, 1.5)
	packet_view.modulate.a = 0.25


func _draw_relay(center: Vector2, radius: float, accent: Color) -> void:
	for index in 4:
		var direction := Vector2.from_angle(TAU * float(index) / 4.0)
		draw_line(center + direction * 10.0, center + direction * radius * 0.52, Color(accent, 0.78), 1.4)
		draw_circle(center + direction * radius * 0.60, 2.4, accent, true)
	packet_view.modulate.a = 0.42


func _accent_color() -> Color:
	if node_kind == &"source" and packet != null and not packet.is_empty():
		var ids := packet.rune_ids_expanded()
		if not ids.is_empty():
			return RunePacketModel.attribute_color(RunePacketModel.attribute_for_id(ids[0]))
	if node_kind == &"summoner":
		return Color(0.82, 0.66, 1.0)
	if node_kind == &"extract":
		return Color(1.0, 0.68, 0.36)
	if node_kind == &"merge":
		return Color(0.72, 0.56, 1.0)
	return Color(0.38, 0.82, 1.0)

