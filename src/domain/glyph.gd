class_name GlyphModel
extends RefCounted

const GlyphProductionContextModel := preload("res://src/domain/glyph_production_context.gd")

var components: Array[GlyphComponentModel] = []
var combine_children: Array = []
var production_context: GlyphProductionContextModel


func _init(
	initial_components: Array[GlyphComponentModel] = [],
	initial_production_context: GlyphProductionContextModel = null,
	initial_combine_children: Array = []
) -> void:
	production_context = (
		initial_production_context.copy()
		if initial_production_context != null
		else GlyphProductionContextModel.new()
	)
	for child in initial_combine_children:
		combine_children.append(child.copy())
	for component in initial_components:
		components.append(component.copy())
	if not combine_children.is_empty():
		_rebuild_components_from_children()


static func combine(first: GlyphModel, second: GlyphModel) -> GlyphModel:
	var children: Array = [first.copy(), second.copy()]
	children.sort_custom(
		func(a: GlyphModel, b: GlyphModel) -> bool:
			return a.canonical_serialization() < b.canonical_serialization()
	)
	return GlyphModel.new(
		[],
		GlyphProductionContextModel.merge([
			first.production_context,
			second.production_context,
		]),
		children
	)


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
			return "P(%s)" % keys[0]
		return "L[%s]" % ",".join(keys)
	var child_serializations := PackedStringArray()
	for child in combine_children:
		child_serializations.append(child.canonical_serialization())
	child_serializations.sort()
	return "C(%s)" % ",".join(child_serializations)


func canonical_hash() -> String:
	return canonical_serialization().sha256_text()


func complete_overlap_primitive_ids() -> Array[StringName]:
	var seen: Dictionary = {}
	var overlapping: Array[StringName] = []
	for component in components:
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
	for component in components:
		component.rotation_step = posmod(component.rotation_step + steps, 4)
	for child in combine_children:
		child.rotate(steps)


func translate(offset: Vector2i) -> void:
	for component in components:
		component.position += offset
	for child in combine_children:
		child.translate(offset)


func recolor(color_id: StringName) -> void:
	for component in components:
		component.color_id = color_id
	for child in combine_children:
		child.recolor(color_id)


func copy() -> GlyphModel:
	return GlyphModel.new(components, production_context, combine_children)


func _rebuild_components_from_children() -> void:
	components.clear()
	for child in combine_children:
		for component in child.components:
			components.append(component.copy())
