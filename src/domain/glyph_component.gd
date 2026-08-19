class_name GlyphComponentModel
extends RefCounted

var primitive_id: StringName
var position: Vector2i
var rotation_step: int
var scale_step: int
var color_id: StringName


func _init(
	initial_primitive_id: StringName,
	initial_position: Vector2i = Vector2i.ZERO,
	initial_rotation_step: int = 0,
	initial_scale_step: int = 1,
	initial_color_id: StringName = &"white"
) -> void:
	primitive_id = initial_primitive_id
	position = initial_position
	rotation_step = posmod(initial_rotation_step, 4)
	scale_step = initial_scale_step
	color_id = initial_color_id


func canonical_key() -> String:
	return "p%s|%d,%d|%d|%d|c%s" % [
		_frame(String(primitive_id)),
		position.x,
		position.y,
		posmod(rotation_step, 4),
		scale_step,
		_frame(String(color_id)),
	]


static func _frame(value: String) -> String:
	return "%d:%s" % [value.length(), value]


func copy() -> GlyphComponentModel:
	return GlyphComponentModel.new(
		primitive_id,
		position,
		rotation_step,
		scale_step,
		color_id
	)
