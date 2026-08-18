class_name GlyphModel
extends RefCounted

var components: Array[GlyphComponentModel] = []


func _init(initial_components: Array[GlyphComponentModel] = []) -> void:
	for component in initial_components:
		components.append(component.copy())


func canonical_keys() -> Array[String]:
	var keys: Array[String] = []
	for component in components:
		keys.append(component.canonical_key())
	keys.sort()
	return keys


func copy() -> GlyphModel:
	return GlyphModel.new(components)

