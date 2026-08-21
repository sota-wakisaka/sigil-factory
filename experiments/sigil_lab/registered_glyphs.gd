class_name SigilLabRegisteredGlyphs
extends RefCounted

const GlyphModel := preload("res://src/domain/glyph.gd")
const GlyphComponentModel := preload("res://src/domain/glyph_component.gd")

const CROSS := &"cross"
const IDS := [CROSS]
const LABELS := {
	CROSS: "十字",
}
const SOURCE_GRAPH_PATHS := {
	CROSS: "res://experiments/sigil_lab/registered/cross.json",
}


static func has(glyph_id: StringName) -> bool:
	return glyph_id in IDS


static func label(glyph_id: StringName) -> String:
	return LABELS.get(glyph_id, String(glyph_id))


static func source_graph_path(glyph_id: StringName) -> String:
	return SOURCE_GRAPH_PATHS.get(glyph_id, "")


static func glyph(glyph_id: StringName) -> GlyphModel:
	match glyph_id:
		CROSS:
			return _cross()
	return null


static func _cross() -> GlyphModel:
	var square := GlyphModel.new([GlyphComponentModel.new(&"square")])
	return GlyphModel.combine_many(
		[
			square.stretched_percent(200, 50),
			square.stretched_percent(50, 200),
		],
		GlyphModel.CONNECTION_SIMPLE
	)
