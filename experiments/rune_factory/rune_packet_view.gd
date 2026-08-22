class_name RunePacketView
extends Control

const RunePacketModel := preload("res://src/rune/rune_packet.gd")

enum DisplayMode { STRIP, WHEELS, NODE }

var packet: RunePacket
var removed_packet: RunePacket
var display_mode := DisplayMode.STRIP
var show_empty_slots := false
var show_catalog := false
var opacity := 1.0


func configure(
	next_packet: RunePacket,
	next_mode: DisplayMode = DisplayMode.STRIP,
	next_removed: RunePacket = null
) -> void:
	packet = next_packet.copy() if next_packet != null else RunePacketModel.empty()
	removed_packet = next_removed.copy() if next_removed != null else RunePacketModel.empty()
	display_mode = next_mode
	custom_minimum_size = _minimum_size_for_mode()
	queue_redraw()


func _minimum_size_for_mode() -> Vector2:
	match display_mode:
		DisplayMode.WHEELS:
			return Vector2(342.0, 122.0)
		DisplayMode.NODE:
			return Vector2(112.0, 112.0)
		_:
			return Vector2(280.0, 40.0)


func _draw() -> void:
	if packet == null:
		return
	match display_mode:
		DisplayMode.WHEELS:
			_draw_wheels()
		DisplayMode.NODE:
			_draw_node_packet()
		_:
			_draw_strip()


func _draw_strip() -> void:
	var ids := packet.rune_ids_expanded()
	var slot_count := RunePacketModel.MAX_RUNES
	var gap := 4.0
	var diameter := minf(30.0, (size.x - gap * float(slot_count - 1)) / float(slot_count))
	var start_x := (size.x - (diameter * slot_count + gap * (slot_count - 1))) * 0.5 + diameter * 0.5
	for slot_index in slot_count:
		var center := Vector2(start_x + float(slot_index) * (diameter + gap), size.y * 0.5)
		if slot_index < ids.size():
			_draw_rune_chip(center, diameter * 0.5, ids[slot_index], 1, opacity)
		elif show_empty_slots:
			draw_circle(center, diameter * 0.34, Color(0.22, 0.42, 0.50, 0.18), false, 1.0)


func _draw_wheels() -> void:
	var wheel_radius := minf(43.0, size.y * 0.38)
	var usable_width := size.x - 18.0
	for attribute_index in RunePacketModel.ATTRIBUTE_COUNT:
		var center := Vector2(
			9.0 + usable_width * (float(attribute_index) + 0.5) / 3.0,
			size.y * 0.54
		)
		var color := RunePacketModel.attribute_color(attribute_index)
		draw_circle(center, wheel_radius, Color(0.006, 0.028, 0.042, 0.94), true)
		draw_arc(center, wheel_radius, 0.0, TAU, 48, Color(color, 0.64), 1.5)
		draw_circle(center, 7.0, Color(0.40, 0.09, 0.13, 0.88), true)
		draw_line(center + Vector2(-4.0, -4.0), center + Vector2(4.0, 4.0), Color(1.0, 0.55, 0.60, 0.88), 1.4)
		draw_line(center + Vector2(4.0, -4.0), center + Vector2(-4.0, 4.0), Color(1.0, 0.55, 0.60, 0.88), 1.4)
		for position_index in RunePacketModel.RUNES_PER_ATTRIBUTE:
			# Preserve the 3x3 board address in the circular UI: top stays top,
			# corners stay diagonal, and a move always points at its visible destination.
			var angle: float = Vector2(RunePacketModel.POSITION_COORDS[position_index]).angle()
			var slot_center := center + Vector2.from_angle(angle) * wheel_radius * 0.68
			var amount := packet.count_for(attribute_index, position_index)
			var removed_amount := removed_packet.count_for(attribute_index, position_index)
			if amount > 0:
				_draw_rune_chip(
					slot_center,
					10.5,
					RunePacketModel.rune_id(attribute_index, position_index),
					amount,
					opacity
				)
			elif removed_amount > 0:
				_draw_removed_chip(slot_center, 10.5, RunePacketModel.rune_id(attribute_index, position_index), removed_amount)
			elif show_catalog:
				_draw_rune_chip(
					slot_center,
					9.2,
					RunePacketModel.rune_id(attribute_index, position_index),
					1,
					0.52
				)
			else:
				draw_circle(slot_center, 3.0, Color(color, 0.26), false, 1.0)
		var label: String = str(RunePacketModel.ATTRIBUTE_LABELS[attribute_index])
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-12.0, wheel_radius + 17.0),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			24.0,
			12,
			Color(color, 0.92)
		)


func _draw_node_packet() -> void:
	var center := size * 0.5
	var ids := packet.rune_ids_expanded()
	if ids.is_empty():
		draw_circle(center, 8.0, Color(0.28, 0.60, 0.72, 0.34), false, 1.2)
		return
	var orbit_radius := 23.0 if ids.size() > 1 else 0.0
	for index in ids.size():
		var angle := -PI * 0.5 + TAU * float(index) / float(ids.size())
		var chip_center := center + Vector2.from_angle(angle) * orbit_radius
		_draw_rune_chip(chip_center, 10.0 if ids.size() <= 4 else 8.0, ids[index], 1, opacity)


func _draw_rune_chip(center: Vector2, radius: float, rune_id: int, amount: int, alpha: float) -> void:
	var attribute_index := RunePacketModel.attribute_for_id(rune_id)
	var color := RunePacketModel.attribute_color(attribute_index)
	draw_circle(center, radius, Color(0.008, 0.035, 0.052, 0.96 * alpha), true)
	draw_circle(center, radius, Color(color, 0.88 * alpha), false, maxf(1.0, radius * 0.13))
	var symbol := RunePacketModel.rune_symbol(rune_id)
	var font_size := maxi(8, roundi(radius * 1.16))
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-radius, float(font_size) * 0.34),
		symbol,
		HORIZONTAL_ALIGNMENT_CENTER,
		radius * 2.0,
		font_size,
		Color(0.88, 0.96, 1.0, alpha)
	)
	if amount > 1:
		var badge_center := center + Vector2(radius * 0.72, -radius * 0.72)
		draw_circle(badge_center, maxf(5.0, radius * 0.38), Color(color, alpha), true)
		draw_string(
			ThemeDB.fallback_font,
			badge_center + Vector2(-5.0, 3.2),
			str(amount),
			HORIZONTAL_ALIGNMENT_CENTER,
			10.0,
			8,
			Color(0.01, 0.03, 0.04, alpha)
		)


func _draw_removed_chip(center: Vector2, radius: float, rune_id: int, amount: int) -> void:
	_draw_rune_chip(center, radius, rune_id, amount, 0.26)
	var cross := radius * 0.55
	draw_line(center - Vector2.ONE * cross, center + Vector2.ONE * cross, Color(1.0, 0.38, 0.42, 0.92), 1.7)
	draw_line(center + Vector2(-cross, cross), center + Vector2(cross, -cross), Color(1.0, 0.38, 0.42, 0.92), 1.7)
