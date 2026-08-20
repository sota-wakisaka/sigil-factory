class_name GlyphComponentModel
extends RefCounted

var primitive_id: StringName
const POSITION_PRECISION := 1000

var position: Vector2
var rotation_step: int
var rotation_degrees: int
var scale_step: int
var color_id: StringName


func _init(
	initial_primitive_id: StringName,
	initial_position = Vector2.ZERO,
	initial_rotation_step: int = 0,
	initial_scale_step: int = 1,
	initial_color_id: StringName = &"white",
	initial_rotation_degrees = null
) -> void:
	primitive_id = initial_primitive_id
	position = normalized_position(Vector2(initial_position))
	set_rotation_degrees(
		initial_rotation_step * 90
		if initial_rotation_degrees == null
		else int(initial_rotation_degrees)
	)
	scale_step = initial_scale_step
	color_id = initial_color_id


func canonical_key() -> String:
	return "p%s|%s,%s|%d|%d|c%s" % [
		_frame(String(primitive_id)),
		coordinate_key(position.x),
		coordinate_key(position.y),
		rotation_degrees,
		scale_step,
		_frame(String(color_id)),
	]


func set_rotation_degrees(value: int) -> void:
	rotation_degrees = posmod(value, 360)
	rotation_step = int(rotation_degrees / 90) if rotation_degrees % 90 == 0 else 0


func rotate_degrees_by(value: int) -> void:
	set_rotation_degrees(rotation_degrees + value)


static func normalized_position(value: Vector2) -> Vector2:
	return Vector2(
		_normalized_coordinate(value.x),
		_normalized_coordinate(value.y)
	)


static func coordinate_key(value: float) -> String:
	var units := roundi(value * float(POSITION_PRECISION))
	if units % POSITION_PRECISION == 0:
		return str(int(units / POSITION_PRECISION))
	var sign_text := "-" if units < 0 else ""
	var absolute_units := absi(units)
	var result := "%s%d.%03d" % [
		sign_text,
		int(absolute_units / POSITION_PRECISION),
		absolute_units % POSITION_PRECISION,
	]
	while result.ends_with("0"):
		result = result.substr(0, result.length() - 1)
	return result


static func _normalized_coordinate(value: float) -> float:
	var normalized := snappedf(value, 1.0 / float(POSITION_PRECISION))
	return 0.0 if is_zero_approx(normalized) else normalized


static func _frame(value: String) -> String:
	return "%d:%s" % [value.length(), value]


func copy() -> GlyphComponentModel:
	return GlyphComponentModel.new(
		primitive_id,
		position,
		rotation_step,
		scale_step,
		color_id,
		rotation_degrees
	)
