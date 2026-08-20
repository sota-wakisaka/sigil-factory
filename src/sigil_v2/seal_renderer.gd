class_name SealRenderer
extends RefCounted

const SealMotifLibraryModel := preload("res://src/sigil_v2/seal_motif_library.gd")

const WHITE_INK := Color(0.82, 0.9, 1.0, 0.98)
const BLUE_INK := Color(0.28, 0.78, 1.0, 0.98)
const RED_INK := Color(1.0, 0.42, 0.48, 0.98)
const GUIDE_INK := Color(0.42, 0.66, 0.86, 0.46)
const FX_INK := Color(0.34, 0.72, 1.0, 0.16)
const CIRCUIT_FULL_DETAIL_MIN_LOD := 56


static func draw(
	canvas: CanvasItem,
	plan,
	rect: Rect2,
	lod_size: int,
	presentation: StringName = &"operational",
	state: StringName = &"current",
	animation_progress: float = 1.0,
	grayscale: bool = false
) -> void:
	if canvas == null or plan == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	draw_snapshot(
		canvas,
		plan.commands,
		plan.bounds_radius,
		rect,
		lod_size,
		presentation,
		state,
		animation_progress,
		grayscale
	)


static func draw_snapshot(
	canvas: CanvasItem,
	commands: Array,
	bounds_radius: int,
	rect: Rect2,
	lod_size: int,
	presentation: StringName = &"operational",
	state: StringName = &"current",
	animation_progress: float = 1.0,
	grayscale: bool = false
) -> void:
	if canvas == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var center := rect.get_center()
	var visual_radius := minf(rect.size.x, rect.size.y) * 0.43
	var unit_scale := visual_radius / float(maxi(bounds_radius, 1))
	var hypothetical := state == &"hypothetical"
	var progress := clampf(animation_progress, 0.0, 1.0)
	var semantic_opacity := 0.62 if presentation == &"editing" else 1.0

	if presentation == &"ceremonial" and lod_size >= 113:
		_draw_ceremonial_scaffold(canvas, commands, center, visual_radius, hypothetical, progress)
	_draw_orbit_skeletons(canvas, commands, center, unit_scale, lod_size, hypothetical, grayscale)
	if circuit_uses_compact_proxy(lod_size):
		_draw_circuit_diagnostics(canvas, commands, center, unit_scale, hypothetical, grayscale)

	for command in commands:
		var kind := StringName(command.get("kind", &""))
		if not _command_visible(kind, presentation, progress):
			continue
		match kind:
			&"edge":
				if circuit_uses_full_edges(lod_size):
					_draw_edge(canvas, command, center, unit_scale, hypothetical, grayscale, semantic_opacity)
			&"boundary":
				_draw_boundary(canvas, command, center, unit_scale, hypothetical, grayscale, semantic_opacity)
			&"motif":
				_draw_motif(canvas, command, center, unit_scale, lod_size, hypothetical, grayscale, semantic_opacity)

	_draw_attribute_register(canvas, commands, rect, lod_size, hypothetical, grayscale)


static func circuit_uses_compact_proxy(lod_size: int) -> bool:
	return lod_size < CIRCUIT_FULL_DETAIL_MIN_LOD


static func circuit_uses_full_edges(lod_size: int) -> bool:
	return lod_size >= CIRCUIT_FULL_DETAIL_MIN_LOD


static func _draw_ceremonial_scaffold(
	canvas: CanvasItem,
	commands: Array,
	center: Vector2,
	radius: float,
	hypothetical: bool,
	progress: float
) -> void:
	if progress < 0.72:
		return
	var alpha := remap(progress, 0.72, 1.0, 0.0, 1.0)
	var color := Color(FX_INK.r, FX_INK.g, FX_INK.b, FX_INK.a * alpha)
	_draw_arc_path(canvas, center, radius * 1.035, color, 1.0, hypothetical, 64)
	var tick_count := clampi(commands.size(), 6, 24)
	for index in tick_count:
		var angle := float(index) * TAU / float(tick_count) - PI * 0.5
		var from := center + Vector2.RIGHT.rotated(angle) * radius * 1.01
		var to := center + Vector2.RIGHT.rotated(angle) * radius * 1.06
		canvas.draw_line(from, to, color, 1.0, true)


static func _command_visible(kind: StringName, presentation: StringName, progress: float) -> bool:
	if presentation != &"ceremonial":
		return true
	var threshold: float = float({
		&"motif": 0.18,
		&"compose_signature": 0.28,
		&"orbit_signature": 0.38,
		&"boundary": 0.48,
		&"edge": 0.64,
		&"circuit_signature": 0.64,
		&"concentric_signature": 0.72,
	}.get(kind, 0.0))
	return progress >= threshold


static func _draw_edge(
	canvas: CanvasItem,
	command: Dictionary,
	center: Vector2,
	unit_scale: float,
	hypothetical: bool,
	grayscale: bool,
	opacity: float
) -> void:
	var from := center + _polar_point(int(command["from_radius"]), int(command["from_angle_tick"])) * unit_scale
	var to := center + _polar_point(int(command["to_radius"]), int(command["to_angle_tick"])) * unit_scale
	var color := _ink_color(StringName(command.get("ink_id", &"white")), grayscale, 0.58 * opacity)
	_draw_segment(canvas, from, to, color, maxf(0.85, unit_scale * 1.3), hypothetical)


static func _draw_boundary(
	canvas: CanvasItem,
	command: Dictionary,
	center: Vector2,
	unit_scale: float,
	hypothetical: bool,
	grayscale: bool,
	opacity: float
) -> void:
	var radius := float(command["radius"]) * unit_scale
	var color := _ink_color(StringName(command.get("ink_id", &"white")), grayscale, 0.82 * opacity)
	var width := maxf(1.0, unit_scale * 2.3)
	if StringName(command["shape"]) == &"circle":
		_draw_arc_path(canvas, center, radius, color, width, hypothetical, 64)
	else:
		var points := PackedVector2Array()
		for index in 3:
			points.append(center + _polar_point(radius, index * 40))
		points.append(points[0])
		_draw_polyline(canvas, points, color, width, hypothetical)


static func _draw_motif(
	canvas: CanvasItem,
	command: Dictionary,
	center: Vector2,
	unit_scale: float,
	lod_size: int,
	hypothetical: bool,
	grayscale: bool,
	opacity: float
) -> void:
	var motif_id := StringName(command["motif_id"])
	var motif_center := center + _polar_point(
		int(command.get("center_radius", 0)),
		int(command.get("center_angle_tick", 0))
	) * unit_scale
	var rotation := _tick_angle(int(command.get("rotation_tick", 0)))
	var scale := unit_scale * float(command.get("scale_num", 1)) / float(maxi(int(command.get("scale_den", 1)), 1))
	var color := _ink_color(StringName(command.get("ink_id", &"white")), grayscale, opacity)
	var width := maxf(1.0, unit_scale * (2.25 if lod_size >= 80 else 2.8))
	if lod_size <= 40 and int(command.get("center_radius", 0)) > 0:
		var mark_radius := maxf(1.4, scale * 54.0)
		_draw_motif_proxy(canvas, motif_id, motif_center, rotation, mark_radius, color, hypothetical)
		return
	for path in SealMotifLibraryModel.paths(motif_id):
		var transformed := PackedVector2Array()
		for point in path["points"]:
			transformed.append(motif_center + point.rotated(rotation) * scale)
		if bool(path.get("closed", false)) and not transformed.is_empty():
			transformed.append(transformed[0])
		_draw_polyline(canvas, transformed, color, width, hypothetical)


static func _draw_motif_proxy(
	canvas: CanvasItem,
	motif_id: StringName,
	center: Vector2,
	rotation: float,
	radius: float,
	color: Color,
	hypothetical: bool
) -> void:
	match motif_id:
		&"crescent":
			_draw_arc_path(canvas, center, radius, color, 1.0, hypothetical, 12, 0.45, TAU - 0.45)
		&"fang":
			var direction := Vector2.UP.rotated(rotation)
			var normal := Vector2(-direction.y, direction.x)
			var points := PackedVector2Array([
				center + direction * radius,
				center - direction * radius * 0.7 + normal * radius * 0.65,
				center - direction * radius * 0.7 - normal * radius * 0.65,
				center + direction * radius,
			])
			_draw_polyline(canvas, points, color, 1.0, hypothetical)
		_:
			var direction := Vector2.UP.rotated(rotation)
			_draw_segment(canvas, center - direction * radius, center + direction * radius, color, 1.0, hypothetical)


static func _draw_orbit_skeletons(
	canvas: CanvasItem,
	commands: Array,
	center: Vector2,
	unit_scale: float,
	lod_size: int,
	hypothetical: bool,
	grayscale: bool
) -> void:
	var ring_color := _ink_color(&"white", grayscale, 0.28 if lod_size >= 80 else 0.46)
	var spoke_color := _ink_color(&"white", grayscale, 0.5 if lod_size >= 80 else 0.7)
	for command in commands:
		if StringName(command.get("kind", &"")) != &"orbit_signature":
			continue
		var count := int(command["count"])
		var phase := int(command["phase_tick"])
		var radius := float(command["radius"]) * unit_scale
		_draw_arc_path(
			canvas,
			center,
			radius,
			ring_color,
			1.0,
			hypothetical,
			SealMotifLibraryModel.ORBIT_RING_SEGMENTS
		)
		for index in count:
			var angle_tick := phase + index * (120 / count)
			var direction := _polar_point(1.0, angle_tick).normalized()
			_draw_segment(
				canvas,
				center + direction * radius * (0.82 if lod_size <= 48 else 0.9),
				center + direction * radius * 1.04,
				spoke_color,
				1.0,
				hypothetical
			)


static func _draw_circuit_diagnostics(
	canvas: CanvasItem,
	commands: Array,
	center: Vector2,
	unit_scale: float,
	hypothetical: bool,
	grayscale: bool
) -> void:
	var color := _ink_color(&"white", grayscale, 0.78)
	for command in commands:
		if (
			StringName(command.get("kind", &"")) != &"edge"
			or StringName(command.get("semantic_role", &"")) != &"circuit"
		):
			continue
		var from := center + _polar_point(
			int(command.get("from_radius", 0)),
			int(command.get("from_angle_tick", 0))
		) * unit_scale
		var to := center + _polar_point(
			int(command.get("to_radius", 0)),
			int(command.get("to_angle_tick", 0))
		) * unit_scale
		_draw_segment(canvas, from, to, color, 1.0, hypothetical)


static func _draw_attribute_register(
	canvas: CanvasItem,
	commands: Array,
	rect: Rect2,
	lod_size: int,
	hypothetical: bool,
	grayscale: bool
) -> void:
	var inks: Array[StringName] = []
	for command in commands:
		if StringName(command.get("kind", &"")) != &"motif":
			continue
		var ink := StringName(command.get("ink_id", &"white"))
		if not inks.has(ink):
			inks.append(ink)
	inks.sort()
	if inks.is_empty():
		return
	var marker_radius := clampf(float(lod_size) * 0.018, 1.35, 3.8)
	var gap := maxf(1.5, marker_radius * 1.2)
	var padding := maxf(1.5, marker_radius * 0.8)
	var rail_width := marker_radius * 2.0 * float(inks.size()) + gap * float(maxi(inks.size() - 1, 0)) + padding * 2.0
	var rail_height := marker_radius * 2.0 + padding * 2.0
	var edge_padding := maxf(1.5, float(lod_size) * 0.012)
	var rail := Rect2(
		rect.end - Vector2(rail_width + edge_padding, rail_height + edge_padding),
		Vector2(rail_width, rail_height)
	)
	canvas.draw_rect(rail, Color(0.008, 0.018, 0.032, 0.94), true)
	var outline := PackedVector2Array([
		rail.position,
		Vector2(rail.end.x, rail.position.y),
		rail.end,
		Vector2(rail.position.x, rail.end.y),
		rail.position,
	])
	_draw_polyline(canvas, outline, _ink_color(&"white", grayscale, 0.46), 1.0, hypothetical)
	for index in inks.size():
		var position := rail.position + Vector2(
			padding + marker_radius + float(index) * (marker_radius * 2.0 + gap),
			rail_height * 0.5
		)
		var ink: StringName = inks[index]
		var color := _ink_color(ink, grayscale, 0.92)
		match ink:
			&"blue":
				canvas.draw_circle(position, marker_radius, color, true)
			&"red":
				canvas.draw_line(position + Vector2(-marker_radius, marker_radius), position + Vector2(marker_radius, -marker_radius), color, 1.0, true)
				canvas.draw_line(position + Vector2(-marker_radius * 0.2, marker_radius), position + Vector2(marker_radius, -marker_radius * 0.2), color, 1.0, true)
			_:
				canvas.draw_circle(position, marker_radius, color, false, 1.0, true)


static func _draw_arc_path(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	color: Color,
	width: float,
	hypothetical: bool,
	segments: int,
	start_angle: float = 0.0,
	end_angle: float = TAU
) -> void:
	var points := PackedVector2Array()
	for index in segments + 1:
		var ratio := float(index) / float(segments)
		var angle := lerpf(start_angle, end_angle, ratio)
		points.append(center + Vector2.RIGHT.rotated(angle) * radius)
	_draw_polyline(canvas, points, color, width, hypothetical)


static func _draw_polyline(
	canvas: CanvasItem,
	points: PackedVector2Array,
	color: Color,
	width: float,
	hypothetical: bool
) -> void:
	if points.size() < 2:
		return
	for index in points.size() - 1:
		_draw_segment(canvas, points[index], points[index + 1], color, width, hypothetical)


static func _draw_segment(
	canvas: CanvasItem,
	from: Vector2,
	to: Vector2,
	color: Color,
	width: float,
	hypothetical: bool
) -> void:
	if not hypothetical:
		canvas.draw_line(from, to, color, width, true)
		return
	for index in 5:
		if index % 2 == 1:
			continue
		var start := from.lerp(to, float(index) / 5.0)
		var end := from.lerp(to, float(index + 1) / 5.0)
		canvas.draw_line(start, end, color, width, true)


static func _polar_point(radius, angle_tick: int) -> Vector2:
	return Vector2.UP.rotated(_tick_angle(angle_tick)) * float(radius)


static func _tick_angle(angle_tick: int) -> float:
	return float(posmod(angle_tick, 120)) * TAU / 120.0


static func _ink_color(ink_id: StringName, grayscale: bool, opacity: float) -> Color:
	var color := WHITE_INK
	if not grayscale:
		match ink_id:
			&"blue":
				color = BLUE_INK
			&"red":
				color = RED_INK
	return Color(color.r, color.g, color.b, color.a * opacity)
