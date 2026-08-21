class_name GlyphModel
extends RefCounted

const GlyphProductionContextModel := preload("res://src/domain/glyph_production_context.gd")

var components: Array[GlyphComponentModel] = []
var combine_children: Array = []
var combine_origin := Vector2.ZERO
var combine_connection_mode: StringName
var production_context: GlyphProductionContextModel

const MIN_COMBINE_CHILDREN := 2
const MAX_COMBINE_CHILDREN := 8
const CONNECTION_RADIAL := &"radial"
const CONNECTION_PAIRWISE := &"pairwise"
const CONNECTION_NONE := &"none"
const COMBINE_CONNECTION_MODES := [CONNECTION_RADIAL, CONNECTION_PAIRWISE, CONNECTION_NONE]


func _init(
	initial_components: Array[GlyphComponentModel] = [],
	initial_production_context: GlyphProductionContextModel = null,
	initial_combine_children: Array = [],
	initial_combine_origin = Vector2.ZERO,
	initial_combine_connection_mode: StringName = CONNECTION_RADIAL
) -> void:
	combine_origin = GlyphComponentModel.normalized_position(Vector2(initial_combine_origin))
	combine_connection_mode = initial_combine_connection_mode
	production_context = (
		initial_production_context.copy()
		if initial_production_context != null
		else GlyphProductionContextModel.new()
	)
	for child in initial_combine_children:
		combine_children.append(child.copy() if child is GlyphModel else child)
	for component in initial_components:
		components.append(component.copy() if component is GlyphComponentModel else component)
	if not combine_children.is_empty():
		_rebuild_components_from_children()


static func combine(
	first: GlyphModel,
	second: GlyphModel,
	connection_mode: StringName = CONNECTION_RADIAL
) -> GlyphModel:
	return combine_many([first, second], connection_mode)


static func combine_many(
	glyphs: Array,
	connection_mode: StringName = CONNECTION_RADIAL
) -> GlyphModel:
	var children: Array = []
	var contexts: Array = []
	for glyph_value in glyphs:
		if glyph_value is GlyphModel:
			var glyph: GlyphModel = glyph_value
			children.append(glyph.copy())
			contexts.append(glyph.production_context)
		else:
			children.append(glyph_value)
	children.sort_custom(
		func(a, b) -> bool:
			if not a is GlyphModel or not b is GlyphModel:
				return a is GlyphModel
			return _canonical_child_less(a, b)
	)
	return GlyphModel.new(
		[],
		GlyphProductionContextModel.merge(contexts),
		children,
		Vector2.ZERO,
		connection_mode
	)


static func radial_repeat(glyph: GlyphModel, count: int) -> GlyphModel:
	if glyph == null or count < MIN_COMBINE_CHILDREN or count > MAX_COMBINE_CHILDREN:
		return null
	if 360 % count != 0:
		return null
	var unique_copies: Array = []
	var seen_serializations: Dictionary = {}
	var angle_step := int(360 / count)
	for index in count:
		var repeated := glyph.rotated_degrees(index * angle_step)
		var serialization := repeated.canonical_serialization()
		if seen_serializations.has(serialization):
			continue
		seen_serializations[serialization] = true
		unique_copies.append(repeated)
	# A rotationally symmetric Glyph is a valid no-op repeat. Keep one canonical
	# copy instead of manufacturing an invalid group of identical components.
	if unique_copies.size() == 1:
		return unique_copies[0]
	return combine_many(unique_copies, CONNECTION_NONE)


func canonical_keys() -> Array[String]:
	var keys: Array[String] = []
	for component in components:
		keys.append(component.canonical_key())
	keys.sort()
	return keys


func canonical_serialization() -> String:
	if combine_children.is_empty():
		var keys := canonical_keys()
		if keys.is_empty():
			return "E"
		if keys.size() == 1:
			return "P(%s)" % _frame(keys[0])
		return "L[%s]" % _frame_sequence(keys)
	var child_serializations: Array[String] = []
	for child in combine_children:
		child_serializations.append(child.canonical_serialization())
	child_serializations.sort_custom(
		func(a: String, b: String) -> bool:
			return _canonical_serialization_less(a, b)
	)
	var origin_serialization := "%s,%s" % [
		GlyphComponentModel.coordinate_key(combine_origin.x),
		GlyphComponentModel.coordinate_key(combine_origin.y),
	]
	var combine_prefix: String = {
		CONNECTION_RADIAL: "C",
		CONNECTION_PAIRWISE: "M",
		CONNECTION_NONE: "R",
	}.get(combine_connection_mode, "?")
	return "%s(%s;%s)" % [
		combine_prefix,
		_frame(origin_serialization),
		_frame_sequence(child_serializations),
	]


func canonical_hash() -> String:
	return canonical_serialization().sha256_text()


func structure_validation_errors() -> PackedStringArray:
	return _structure_validation_errors("root", {})


func _structure_validation_errors(path: String, active_ancestors: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var instance_key := get_instance_id()
	if active_ancestors.has(instance_key):
		errors.append("cyclic_structure:%s" % path)
		return errors
	active_ancestors[instance_key] = true
	if combine_children.is_empty():
		if components.size() != 1:
			errors.append("primitive_arity:%s:%d" % [path, components.size()])
		else:
			var component_value = components[0]
			if not component_value is GlyphComponentModel:
				errors.append("invalid_component:%s" % path)
				active_ancestors.erase(instance_key)
				return errors
			var component: GlyphComponentModel = component_value
			if component.primitive_id == &"":
				errors.append("missing_primitive_id:%s" % path)
			if component.color_id == &"":
				errors.append("missing_color_id:%s" % path)
			if component.scale_step < 1:
				errors.append("invalid_scale:%s:%d" % [path, component.scale_step])
			if (
				component.scale_x_percent < 1
				or component.scale_y_percent < 1
				or component.scale_x_percent > 1600
				or component.scale_y_percent > 1600
			):
				errors.append("invalid_stretch:%s:%d,%d" % [
					path,
					component.scale_x_percent,
					component.scale_y_percent,
				])
	else:
		if not combine_connection_mode in COMBINE_CONNECTION_MODES:
			errors.append("invalid_combine_connection_mode:%s:%s" % [path, combine_connection_mode])
		if (
			combine_children.size() < MIN_COMBINE_CHILDREN
			or combine_children.size() > MAX_COMBINE_CHILDREN
		):
			errors.append("combine_arity:%s:%d" % [path, combine_children.size()])
		for child_index in combine_children.size():
			var child_value = combine_children[child_index]
			if not child_value is GlyphModel:
				errors.append("invalid_child:%s.%d" % [path, child_index])
				continue
			var child: GlyphModel = child_value
			errors.append_array(child._structure_validation_errors(
				"%s.%d" % [path, child_index],
				active_ancestors
			))
	if path == "root" and has_complete_overlap():
		errors.append("complete_overlap:%s" % ",".join(complete_overlap_primitive_ids()))
	active_ancestors.erase(instance_key)
	return errors


func is_structure_valid() -> bool:
	return structure_validation_errors().is_empty()


static func _canonical_child_less(first: GlyphModel, second: GlyphModel) -> bool:
	return _canonical_serialization_less(
		first.canonical_serialization(),
		second.canonical_serialization()
	)


static func _canonical_serialization_less(first: String, second: String) -> bool:
	var first_hash := first.sha256_text()
	var second_hash := second.sha256_text()
	if first_hash != second_hash:
		return first_hash < second_hash
	return first < second


static func _frame_sequence(values: Array[String]) -> String:
	var framed_values: Array[String] = []
	for value in values:
		framed_values.append(_frame(value))
	return ",".join(framed_values)


static func _frame(value: String) -> String:
	return "%d:%s" % [value.length(), value]


func complete_overlap_primitive_ids() -> Array[StringName]:
	var seen: Dictionary = {}
	var overlapping: Array[StringName] = []
	for component_value in components:
		if not component_value is GlyphComponentModel:
			continue
		var component: GlyphComponentModel = component_value
		var key := component.canonical_key()
		if seen.has(key):
			if not overlapping.has(component.primitive_id):
				overlapping.append(component.primitive_id)
		else:
			seen[key] = true
	overlapping.sort()
	return overlapping


func has_complete_overlap() -> bool:
	return not complete_overlap_primitive_ids().is_empty()


func rotate(steps: int) -> void:
	var normalized_steps := posmod(steps, 4)
	if not combine_children.is_empty():
		combine_origin = _rotate_position(combine_origin, normalized_steps)
	for component in components:
		component.position = _rotate_position(component.position, normalized_steps)
		component.rotate_degrees_by(normalized_steps * 90)
	for child in combine_children:
		child.rotate(normalized_steps)


func rotate_degrees(degrees: int) -> void:
	var normalized_degrees := posmod(degrees, 360)
	if normalized_degrees % 90 == 0:
		rotate(int(normalized_degrees / 90))
		return
	if not combine_children.is_empty():
		combine_origin = _rotate_position_degrees(combine_origin, normalized_degrees)
	for component in components:
		component.position = _rotate_position_degrees(component.position, normalized_degrees)
		component.rotate_degrees_by(normalized_degrees)
	for child in combine_children:
		child.rotate_degrees(normalized_degrees)


func rotated_degrees(degrees: int) -> GlyphModel:
	var result := copy()
	result.rotate_degrees(degrees)
	return result


func _rotate_position(position: Vector2, steps: int) -> Vector2:
	match posmod(steps, 4):
		1:
			return Vector2(-position.y, position.x)
		2:
			return Vector2(-position.x, -position.y)
		3:
			return Vector2(position.y, -position.x)
	return Vector2(position)


func _rotate_position_degrees(position: Vector2, degrees: int) -> Vector2:
	return GlyphComponentModel.normalized_position(
		position.rotated(deg_to_rad(float(degrees)))
	)


func translate(offset: Vector2i) -> void:
	if not combine_children.is_empty():
		combine_origin = GlyphComponentModel.normalized_position(combine_origin + Vector2(offset))
	for component in components:
		component.position = GlyphComponentModel.normalized_position(component.position + Vector2(offset))
	for child in combine_children:
		child.translate(offset)


func translated(offset: Vector2i) -> GlyphModel:
	var result := copy()
	result.translate(offset)
	return result


func stretch_percent(x_percent: int, y_percent: int) -> void:
	var factors := Vector2(float(x_percent) / 100.0, float(y_percent) / 100.0)
	if not combine_children.is_empty():
		combine_origin = GlyphComponentModel.normalized_position(combine_origin * factors)
	for component in components:
		component.position = GlyphComponentModel.normalized_position(component.position * factors)
		component.stretch_percent(x_percent, y_percent)
	for child in combine_children:
		child.stretch_percent(x_percent, y_percent)


func stretched_percent(x_percent: int, y_percent: int) -> GlyphModel:
	var result := copy()
	result.stretch_percent(x_percent, y_percent)
	return result


func recolor(color_id: StringName) -> void:
	for component in components:
		component.color_id = color_id
	for child in combine_children:
		child.recolor(color_id)


func copy() -> GlyphModel:
	return GlyphModel.new(
		components,
		production_context,
		combine_children,
		combine_origin,
		combine_connection_mode
	)


func _rebuild_components_from_children() -> void:
	components.clear()
	for child_value in combine_children:
		if not child_value is GlyphModel:
			continue
		var child: GlyphModel = child_value
		for component in child.components:
			components.append(component.copy() if component is GlyphComponentModel else component)
