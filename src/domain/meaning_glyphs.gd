class_name MeaningGlyphs
extends RefCounted

const GlyphModel := preload("res://src/domain/glyph.gd")
const GlyphComponentModel := preload("res://src/domain/glyph_component.gd")

const NOMINAL_SIZE_PERCENT := 100
const EYE := &"eye"
const CROSS := &"cross"
const TARGET := &"target"
const STAR := &"star"
const COMPASS := &"compass"
const IDS := [EYE, CROSS, TARGET, STAR, COMPASS]
const LABELS := {
	EYE: "目",
	CROSS: "十字",
	TARGET: "的",
	STAR: "星",
	COMPASS: "方位",
}


static func has(glyph_id: StringName) -> bool:
	return glyph_id in IDS


static func label(glyph_id: StringName) -> String:
	return LABELS.get(glyph_id, String(glyph_id))


static func glyph(glyph_id: StringName) -> GlyphModel:
	match glyph_id:
		EYE:
			return _eye()
		CROSS:
			return _cross()
		TARGET:
			return _target()
		STAR:
			return _star()
		COMPASS:
			return _compass()
	return null


static func _eye() -> GlyphModel:
	var circle := GlyphModel.new([GlyphComponentModel.new(&"circle")])
	return GlyphModel.combine_many(
		[
			circle.stretched_percent(50, 50),
			circle.stretched_percent(NOMINAL_SIZE_PERCENT, 50),
		],
		GlyphModel.CONNECTION_SIMPLE
	)


static func _cross() -> GlyphModel:
	var square := GlyphModel.new([GlyphComponentModel.new(&"square")])
	return GlyphModel.combine_many(
		[
			square.stretched_percent(NOMINAL_SIZE_PERCENT, 25),
			square.stretched_percent(25, NOMINAL_SIZE_PERCENT),
		],
		GlyphModel.CONNECTION_SIMPLE
	)


static func _target() -> GlyphModel:
	var circle := GlyphModel.new([GlyphComponentModel.new(&"circle")])
	return GlyphModel.combine_many(
		[circle, circle.stretched_percent(50, 50)],
		GlyphModel.CONNECTION_SIMPLE
	)


static func _star() -> GlyphModel:
	var triangle := GlyphModel.new([GlyphComponentModel.new(&"triangle")])
	return GlyphModel.combine_many(
		[triangle, triangle.rotated_degrees(180)],
		GlyphModel.CONNECTION_SIMPLE
	)


static func _compass() -> GlyphModel:
	var cross := _cross()
	return GlyphModel.combine_many(
		[cross, cross.rotated_degrees(45)],
		GlyphModel.CONNECTION_SIMPLE
	)
