class_name SigilLabRegisteredGlyphs
extends RefCounted

const MeaningGlyphsModel := preload("res://src/domain/meaning_glyphs.gd")
const GlyphModel := preload("res://src/domain/glyph.gd")

const NOMINAL_SIZE_PERCENT := MeaningGlyphsModel.NOMINAL_SIZE_PERCENT
const EYE := MeaningGlyphsModel.EYE
const CROSS := MeaningGlyphsModel.CROSS
const TARGET := MeaningGlyphsModel.TARGET
const STAR := MeaningGlyphsModel.STAR
const IDS := MeaningGlyphsModel.IDS
const SOURCE_GRAPH_PATHS := {
	EYE: "res://experiments/sigil_lab/registered/eye.json",
	CROSS: "res://experiments/sigil_lab/registered/cross.json",
	TARGET: "res://experiments/sigil_lab/registered/target.json",
	STAR: "res://experiments/sigil_lab/registered/star.json",
}


static func has(glyph_id: StringName) -> bool:
	return MeaningGlyphsModel.has(glyph_id)


static func label(glyph_id: StringName) -> String:
	return MeaningGlyphsModel.label(glyph_id)


static func source_graph_path(glyph_id: StringName) -> String:
	return SOURCE_GRAPH_PATHS.get(glyph_id, "")


static func glyph(glyph_id: StringName) -> GlyphModel:
	return MeaningGlyphsModel.glyph(glyph_id)
