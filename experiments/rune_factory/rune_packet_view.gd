class_name RunePacketView
extends Control

const RunePacketModel := preload("res://src/rune/rune_packet.gd")

enum DisplayMode { STRIP, BOARD, NODE }

var packet
var removed_packet
var display_mode := DisplayMode.STRIP
var show_empty_slots := false
var show_catalog := false
var opacity := 1.0
var preview_direction := Vector2i.ZERO


func configure(
	next_packet,
	next_mode: DisplayMode = DisplayMode.STRIP,
	next_removed = null,
	next_preview_direction: Vector2i = Vector2i.ZERO
) -> void:
	packet = next_packet.copy() if next_packet != null else RunePacketModel.empty()
	removed_packet = next_removed.copy() if next_removed != null else RunePacketModel.empty()
	display_mode = next_mode
	preview_direction = next_preview_direction
	custom_minimum_size = _minimum_size_for_mode()
	queue_redraw()


func _minimum_size_for_mode() -> Vector2:
	match display_mode:
		DisplayMode.BOARD:
			return Vector2(342.0, 230.0)
		DisplayMode.NODE:
			return Vector2(112.0, 112.0)
		_:
			return Vector2(280.0, 40.0)


func _draw() -> void:
	if packet == null:
		return
	match display_mode:
		DisplayMode.BOARD:
			_draw_board()
		DisplayMode.NODE:
			_draw_node_packet()
		_:
			_draw_strip()


func _draw_strip() -> void:
	var ids: Array[int] = packet.rune_ids_expanded()
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


func _draw_board() -> void:
	var center := size * 0.5
	var step := minf((size.x - 28.0) / 8.0, (size.y - 20.0) / 8.0)
	var highlighted_sinks := {}
	if preview_direction != Vector2i.ZERO:
		for id in removed_packet.rune_ids_expanded():
			var destination: Vector2i = RunePacketModel.coord_for_id(id) + preview_direction
			highlighted_sinks[destination] = int(highlighted_sinks.get(destination, 0)) + 1

	# A faint orthogonal scaffold makes every one-cell move visually literal.
	for y in range(-RunePacketModel.SINK_RING_RADIUS, RunePacketModel.SINK_RING_RADIUS + 1):
		for x in range(-RunePacketModel.SINK_RING_RADIUS, RunePacketModel.SINK_RING_RADIUS + 1):
			var coord := Vector2i(x, y)
			if not RunePacketModel.is_display_coord(coord):
				continue
			for delta: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var neighbor: Vector2i = coord + delta
				if RunePacketModel.is_display_coord(neighbor):
					draw_line(
						center + Vector2(coord) * step,
						center + Vector2(neighbor) * step,
						Color(0.30, 0.55, 0.64, 0.16),
						1.0
					)

	for y in range(-RunePacketModel.SINK_RING_RADIUS, RunePacketModel.SINK_RING_RADIUS + 1):
		for x in range(-RunePacketModel.SINK_RING_RADIUS, RunePacketModel.SINK_RING_RADIUS + 1):
			var coord := Vector2i(x, y)
			if not RunePacketModel.is_display_coord(coord):
				continue
			var slot_center := center + Vector2(coord) * step
			var rune_id := RunePacketModel.rune_id_for_coord(coord)
			if rune_id < 0:
				_draw_sink(slot_center, step * 0.31, int(highlighted_sinks.get(coord, 0)))
				continue
			var amount: int = packet.count_for(rune_id)
			var removed_amount: int = removed_packet.count_for(rune_id)
			if amount > 0:
				_draw_rune_chip(slot_center, step * 0.42, rune_id, amount, opacity)
			elif removed_amount > 0:
				_draw_removed_chip(slot_center, step * 0.42, rune_id, removed_amount)
			elif show_catalog:
				_draw_rune_chip(slot_center, step * 0.37, rune_id, 1, 0.56)
			else:
				draw_circle(slot_center, step * 0.12, Color(RunePacketModel.RUNE_COLOR, 0.26), false, 1.0)


func _draw_sink(center: Vector2, radius: float, removed_count: int) -> void:
	var alpha := 0.98 if removed_count > 0 else 0.54
	draw_circle(center, radius, Color(0.09, 0.025, 0.035, 0.72), true)
	var cross := radius * 0.58
	draw_line(center - Vector2.ONE * cross, center + Vector2.ONE * cross, Color(RunePacketModel.SINK_COLOR, alpha), 1.7)
	draw_line(center + Vector2(-cross, cross), center + Vector2(cross, -cross), Color(RunePacketModel.SINK_COLOR, alpha), 1.7)
	if removed_count > 1:
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(radius * 0.45, -radius * 0.45),
			str(removed_count),
			HORIZONTAL_ALIGNMENT_LEFT,
			10.0,
			8,
			Color(1.0, 0.84, 0.86)
		)


func _draw_node_packet() -> void:
	var center := size * 0.5
	var ids: Array[int] = packet.rune_ids_expanded()
	if ids.is_empty():
		draw_circle(center, 8.0, Color(0.28, 0.60, 0.72, 0.34), false, 1.2)
		return
	var orbit_radius := 23.0 if ids.size() > 1 else 0.0
	for index in ids.size():
		var angle := -PI * 0.5 + TAU * float(index) / float(ids.size())
		var chip_center := center + Vector2.from_angle(angle) * orbit_radius
		_draw_rune_chip(chip_center, 10.0 if ids.size() <= 4 else 8.0, ids[index], 1, opacity)


func _draw_rune_chip(center: Vector2, radius: float, rune_id: int, amount: int, alpha: float) -> void:
	var color := RunePacketModel.rune_color(rune_id)
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
