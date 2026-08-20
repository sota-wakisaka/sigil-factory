class_name SealProgram
extends RefCounted

enum Op {
	MOTIF,
	ORBIT,
	BOUNDARY,
	COMPOSE,
	CIRCUIT,
	CONCENTRIC,
}

var _op: Op
var _parameters: Dictionary = {}
var _children: Array = []

var op: Op:
	get:
		return _op
	set(_value):
		push_error("SealProgram is immutable")


func _init(initial_op: Op, parameters: Dictionary = {}, children: Array = []) -> void:
	_op = initial_op
	_parameters = parameters.duplicate(true)
	_children = children.duplicate()


static func motif(
	motif_id: StringName,
	orientation_tick: int = 0,
	ink_id: StringName = &"white"
) -> SealProgram:
	return SealProgram.new(Op.MOTIF, {
		"motif_id": motif_id,
		"orientation_tick": posmod(orientation_tick, 120),
		"ink_id": ink_id,
	})


static func orbit(
	child: SealProgram,
	count: int,
	phase_tick: int = 0,
	facing: StringName = &"outward"
) -> SealProgram:
	return SealProgram.new(Op.ORBIT, {
		"count": count,
		"phase_tick": posmod(phase_tick, 120),
		"facing": facing,
	}, [child])


static func boundary(shape: StringName, child: SealProgram) -> SealProgram:
	return SealProgram.new(Op.BOUNDARY, {"shape": shape}, [child])


static func compose(core: SealProgram, field: SealProgram) -> SealProgram:
	return SealProgram.new(Op.COMPOSE, {}, [core, field])


static func circuit(
	child: SealProgram,
	target_group_key: StringName,
	topology: StringName,
	step: int = 1,
	center_anchor_key: StringName = &""
) -> SealProgram:
	return SealProgram.new(Op.CIRCUIT, {
		"target_group_key": target_group_key,
		"center_anchor_key": center_anchor_key,
		"topology": topology,
		"step": step,
	}, [child])


static func concentric(
	child: SealProgram,
	count: int,
	scale_num: int = 3,
	scale_den: int = 4,
	phase_step_tick: int = 10
) -> SealProgram:
	return SealProgram.new(Op.CONCENTRIC, {
		"count": count,
		"scale_num": scale_num,
		"scale_den": scale_den,
		"phase_step_tick": posmod(phase_step_tick, 120),
	}, [child])


func parameters() -> Dictionary:
	return _parameters.duplicate(true)


func child_count() -> int:
	return _children.size()


func child_at(index: int):
	if index < 0 or index >= _children.size():
		return null
	return _children[index]


func children() -> Array:
	return _children.duplicate()


func stable_serialization() -> String:
	return _stable_serialization_guarded({"active": {}, "remaining": 64})


func _stable_serialization_guarded(state: Dictionary) -> String:
	if int(state["remaining"]) <= 0:
		return "INVALID_LIMIT"
	var instance_key := get_instance_id()
	var active: Dictionary = state["active"]
	if active.has(instance_key):
		return "INVALID_CYCLE"
	if _children.size() > 2:
		return "INVALID_ARITY"
	state["remaining"] = int(state["remaining"]) - 1
	active[instance_key] = true
	var parameter_keys: Array = _parameters.keys()
	parameter_keys.sort_custom(func(a, b) -> bool: return String(a) < String(b))
	var serialized_parameters: Array[String] = []
	for key in parameter_keys:
		serialized_parameters.append(_frame(String(key)) + _frame(_stable_value(_parameters[key])))
	var serialized_children: Array[String] = []
	for child in _children:
		if child is SealProgram:
			serialized_children.append(_frame(child._stable_serialization_guarded(state)))
		else:
			serialized_children.append(_frame("INVALID"))
	active.erase(instance_key)
	return "S%d{%s}[%s]" % [_op, "".join(serialized_parameters), "".join(serialized_children)]


static func orbit_group_key(
	child: SealProgram,
	count: int,
	phase_tick: int = 0,
	facing: StringName = &"outward"
) -> StringName:
	var source := "orbit|%d|%d|%s|%s" % [
		count,
		posmod(phase_tick, 120),
		String(facing),
		child.stable_serialization() if child != null else "INVALID",
	]
	return StringName("orbit_" + source.sha256_text().substr(0, 20))


static func _stable_value(value) -> String:
	if value is StringName or value is String:
		return "s" + _frame(String(value))
	if value is int:
		return "i%d" % value
	if value is bool:
		return "b1" if value else "b0"
	return "x" + _frame(str(value))


static func _frame(value: String) -> String:
	return "%d:%s" % [value.length(), value]
