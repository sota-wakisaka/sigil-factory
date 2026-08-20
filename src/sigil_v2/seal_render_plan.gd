class_name SealRenderPlan
extends RefCounted

const FORMAT_REVISION := 0

var _commands: Array = []
var _anchors: Array = []
var _fx_commands: Array = []
var _diagnostic_metadata: Array = []
var _bounds_radius := 1
var _metrics: Dictionary = {}

var commands: Array:
	get:
		return _commands.duplicate(true)
	set(_value):
		push_error("SealRenderPlan is immutable")
var anchors: Array:
	get:
		return _anchors.duplicate(true)
	set(_value):
		push_error("SealRenderPlan is immutable")
var fx_commands: Array:
	get:
		return _fx_commands.duplicate(true)
	set(_value):
		push_error("SealRenderPlan is immutable")
var diagnostic_metadata: Array:
	get:
		return _diagnostic_metadata.duplicate(true)
	set(_value):
		push_error("SealRenderPlan is immutable")
var bounds_radius: int:
	get:
		return _bounds_radius
	set(_value):
		push_error("SealRenderPlan is immutable")
var metrics: Dictionary:
	get:
		return _metrics.duplicate(true)
	set(_value):
		push_error("SealRenderPlan is immutable")


func _init(
	initial_commands: Array = [],
	initial_anchors: Array = [],
	initial_fx_commands: Array = [],
	initial_bounds_radius: int = 1,
	initial_metrics: Dictionary = {},
	initial_diagnostic_metadata: Array = []
) -> void:
	_commands = initial_commands.duplicate(true)
	_anchors = initial_anchors.duplicate(true)
	_fx_commands = initial_fx_commands.duplicate(true)
	_bounds_radius = maxi(initial_bounds_radius, 1)
	_metrics = initial_metrics.duplicate(true)
	_diagnostic_metadata = initial_diagnostic_metadata.duplicate(true)


func copy() -> SealRenderPlan:
	return SealRenderPlan.new(
		_commands,
		_anchors,
		_fx_commands,
		_bounds_radius,
		_metrics,
		_diagnostic_metadata
	)


func command_snapshot() -> String:
	var command_keys: Array[String] = []
	for command in _commands:
		command_keys.append(stable_dictionary_key(command))
	command_keys.sort()
	var anchor_keys: Array[String] = []
	for anchor in _anchors:
		anchor_keys.append(stable_dictionary_key(anchor))
	anchor_keys.sort()
	return "R%d|C[%s]|A[%s]|B%d" % [
		FORMAT_REVISION,
		_frame_sequence(command_keys),
		_frame_sequence(anchor_keys),
		_bounds_radius,
	]


func semantic_signature() -> String:
	var values: Array[String] = []
	for command in _commands:
		var kind := String(command.get("kind", ""))
		match kind:
			"motif":
				values.append("m:%s:%s:%d:%d" % [
					String(command.get("motif_id", "")),
					String(command.get("ink_id", "")),
					int(command.get("center_radius", 0)),
					int(command.get("center_angle_tick", 0)),
				])
			"boundary":
				values.append("b:%s" % String(command.get("shape", "")))
			"orbit_signature":
				values.append("o:%d:%d" % [
					int(command.get("count", 0)),
					int(command.get("phase_tick", 0)),
				])
			"compose_signature":
				values.append("p")
			"edge":
				values.append("e:%d:%d:%d:%d" % [
					int(command.get("from_radius", 0)),
					int(command.get("from_angle_tick", 0)),
					int(command.get("to_radius", 0)),
					int(command.get("to_angle_tick", 0)),
				])
			"concentric_signature":
				values.append("n:%d:%d" % [
					int(command.get("count", 0)),
					int(command.get("phase_step_tick", 0)),
				])
	values.sort()
	return "|".join(values)


static func stable_dictionary_key(value: Dictionary) -> String:
	var keys: Array = value.keys()
	keys.sort_custom(func(a, b) -> bool: return String(a) < String(b))
	var parts: Array[String] = []
	for key in keys:
		parts.append(_frame(String(key)) + _frame(_stable_value(value[key])))
	return "".join(parts)


static func _stable_value(value) -> String:
	if value is StringName or value is String:
		return "s" + _frame(String(value))
	if value is int:
		return "i%d" % value
	if value is bool:
		return "b1" if value else "b0"
	if value is Vector2i:
		return "v%d,%d" % [value.x, value.y]
	return "x" + _frame(str(value))


static func _frame_sequence(values: Array[String]) -> String:
	var framed: Array[String] = []
	for value in values:
		framed.append(_frame(value))
	return "".join(framed)


static func _frame(value: String) -> String:
	return "%d:%s" % [value.length(), value]
