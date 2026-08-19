class_name SigilRecipeModel
extends RefCounted

var id: StringName
var glyph: GlyphModel
var unit_id: StringName


func _init(
	initial_id: StringName,
	initial_glyph: GlyphModel,
	initial_unit_id: StringName
) -> void:
	id = initial_id
	glyph = initial_glyph.copy() if initial_glyph != null else null
	unit_id = initial_unit_id


func copy() -> SigilRecipeModel:
	return SigilRecipeModel.new(id, glyph, unit_id)
