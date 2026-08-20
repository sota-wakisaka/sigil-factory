class_name LegacyGlyphLabContent
extends RefCounted

const GlyphModel := preload("res://src/domain/glyph.gd")
const GlyphComponentModel := preload("res://src/domain/glyph_component.gd")


static func fixtures() -> Array[Dictionary]:
	var golem: GlyphModel = _combine([
		_leaf(&"ring", Vector2i.ZERO, 0, &"blue"),
		_leaf(&"spike", Vector2i.ZERO, 0, &"blue"),
	])

	var cardinal: GlyphModel = _combine([
		_combine([
			_leaf(&"spike", Vector2i(0, -4), 3, &"white"),
			_leaf(&"spike", Vector2i(0, 4), 1, &"white"),
		]),
		_combine([
			_leaf(&"spike", Vector2i(-4, 0), 2, &"white"),
			_leaf(&"spike", Vector2i(4, 0), 0, &"white"),
		]),
	])

	var three_axes: GlyphModel = _combine([
		cardinal,
		_combine([
			_leaf(&"ring", Vector2i(-3, -3), 0, &"blue"),
			_leaf(&"ring", Vector2i(3, 3), 2, &"blue"),
		]),
	])

	var four_petals: GlyphModel = _four_petal_field()

	var nested_core: GlyphModel = _combine([
		_leaf(&"ring", Vector2i.ZERO, 1, &"blue"),
		_leaf(&"branch", Vector2i.ZERO, 0, &"red"),
	])
	var nested_ward: GlyphModel = GlyphModel.combine(nested_core, four_petals)

	var grand_seal: GlyphModel = _combine([
		_triad(Vector2i(0, -5), 3),
		_triad(Vector2i(5, 0), 0),
		_triad(Vector2i(0, 5), 1),
		_triad(Vector2i(-5, 0), 2),
	])

	return [
		_fixture(1, "MVP巨像", golem, "2素材 // 合成1", "現在のMVP上位シジル"),
		_fixture(2, "四方尖陣", cardinal, "4素材 // 合成3", "90°回転と移動で四方向へ配置"),
		_fixture(3, "六印結界", three_axes, "6素材 // 合成5", "既存構造へ環素材の対を追加"),
		_fixture(4, "四葉結界", four_petals, "8素材 // 合成7", "環と棘の小合成を四方向へ反復"),
		_fixture(5, "二重核結界", nested_ward, "10素材 // 合成9", "中心核と四葉結界をさらに合成"),
		_fixture(6, "十二印大陣", grand_seal, "12素材 // 合成11", "三素材の小陣を四方向へ積層"),
	]


static func _four_petal_field() -> GlyphModel:
	return _combine([
		_petal(Vector2i(0, -5), Vector2i(0, -3), 3),
		_petal(Vector2i(5, 0), Vector2i(3, 0), 0),
		_petal(Vector2i(0, 5), Vector2i(0, 3), 1),
		_petal(Vector2i(-5, 0), Vector2i(-3, 0), 2),
	])


static func _petal(outer_position: Vector2i, inner_position: Vector2i, rotation: int) -> GlyphModel:
	return GlyphModel.combine(
		_leaf(&"ring", outer_position, rotation, &"blue"),
		_leaf(&"spike", inner_position, rotation, &"white")
	)


static func _triad(center: Vector2i, rotation: int) -> GlyphModel:
	var tangent := Vector2i(1, 0)
	if posmod(rotation, 2) == 0:
		tangent = Vector2i(0, 1)
	return _combine([
		_leaf(&"ring", center - tangent, rotation, &"blue"),
		_leaf(&"spike", center, rotation, &"white"),
		_leaf(&"branch", center + tangent, rotation, &"red"),
	])


static func _leaf(
	primitive_id: StringName,
	position: Vector2i,
	rotation_step: int,
	color_id: StringName
) -> GlyphModel:
	return GlyphModel.new([
		GlyphComponentModel.new(
			primitive_id,
			position,
			rotation_step,
			1,
			color_id
		),
	])


static func _combine(values: Array) -> GlyphModel:
	assert(not values.is_empty())
	var layer := values.duplicate()
	while layer.size() > 1:
		var next_layer: Array = []
		var index := 0
		while index < layer.size():
			if index + 1 < layer.size():
				next_layer.append(GlyphModel.combine(layer[index], layer[index + 1]))
			else:
				next_layer.append(layer[index])
			index += 2
		layer = next_layer
	return layer[0]


static func _fixture(
	id: int,
	label: String,
	glyph,
	structure: String,
	description: String
) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"glyph": glyph,
		"structure": structure,
		"description": description,
		"leaf_count": glyph.components.size(),
		"combine_count": _combine_count(glyph),
		"depth": _combine_depth(glyph),
	}


static func _combine_count(glyph) -> int:
	if glyph == null or glyph.combine_children.is_empty():
		return 0
	var count := 1
	for child in glyph.combine_children:
		count += _combine_count(child)
	return count


static func _combine_depth(glyph) -> int:
	if glyph == null or glyph.combine_children.is_empty():
		return 0
	var depth := 0
	for child in glyph.combine_children:
		depth = maxi(depth, _combine_depth(child))
	return depth + 1
