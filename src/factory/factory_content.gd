class_name FactoryContent
extends RefCounted

const FactoryNodeModel := preload("res://src/factory/factory_node.gd")
const FactoryLineModel := preload("res://src/factory/factory_line.gd")
const FactorySimulation := preload("res://src/factory/factory_simulation.gd")
const SigilRecipeModel := preload("res://src/domain/sigil_recipe.gd")
const GlyphComponentModel := preload("res://src/domain/glyph_component.gd")
const GlyphModel := preload("res://src/domain/glyph.gd")
const MeaningGlyphsModel := preload("res://src/domain/meaning_glyphs.gd")

const PLAN_SCOUT := &"scout"
const PLAN_SENTINEL := &"sentinel"
const PLAN_VIGIL := &"vigil"
const PLAN_STELLAR := &"stellar"
const PLAN_GOLEM := &"golem"
const PLAN_FORTRESS := &"fortress"
const PLAN_EMPTY := &"empty"
const FACTORY_MANA_MAX := 100


static func build_factory(plan_id: StringName) -> FactorySimulation:
	var simulation := FactorySimulation.new()
	var recipe_set := recipes()
	var content_validation := validate_recipe_set(recipe_set)
	assert(
		content_validation["ok"],
		"Invalid factory recipe content: %s" % ", ".join(content_validation["errors"])
	)
	for recipe in recipe_set:
		simulation.add_recipe(recipe)

	match plan_id:
		PLAN_EMPTY:
			_build_empty_factory(simulation)
		PLAN_SENTINEL:
			_build_sentinel_factory(simulation)
		PLAN_VIGIL:
			_build_vigil_factory(simulation)
		PLAN_STELLAR:
			_build_stellar_factory(simulation)
		PLAN_GOLEM:
			_build_golem_factory(simulation)
		PLAN_FORTRESS:
			_build_fortress_factory(simulation)
		_:
			_build_scout_factory(simulation)
	return simulation


static func validate_recipe_set(candidate_recipes: Array[SigilRecipeModel]) -> Dictionary:
	var registry := FactorySimulation.new()
	var errors := PackedStringArray()
	for recipe_index in candidate_recipes.size():
		var recipe: SigilRecipeModel = candidate_recipes[recipe_index]
		var result := registry.recipe_registration_result(recipe)
		if result["ok"]:
			registry.add_recipe(recipe)
			continue
		var recipe_label := "<null>"
		if recipe != null:
			recipe_label = String(recipe.id) if recipe.id != &"" else "<empty>"
		for error in result["errors"]:
			errors.append("recipe[%d]=%s:%s" % [recipe_index, recipe_label, error])
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"accepted_count": registry.recipes.size(),
	}


static func recipes() -> Array[SigilRecipeModel]:
	return [
		SigilRecipeModel.new(
			&"watchful_eye",
			MeaningGlyphsModel.glyph(MeaningGlyphsModel.EYE),
			&"scout"
		),
		SigilRecipeModel.new(
			&"azure_guard",
			GlyphModel.new([
				GlyphComponentModel.new(&"ring", Vector2i.ZERO, 1, 1, &"blue"),
			]),
			&"sentinel"
		),
		SigilRecipeModel.new(
			&"stellar_sentinel",
			MeaningGlyphsModel.glyph(MeaningGlyphsModel.STAR),
			&"sentinel"
		),
		SigilRecipeModel.new(
			&"vigil_cross",
			GlyphModel.combine(
				MeaningGlyphsModel.glyph(MeaningGlyphsModel.EYE),
				MeaningGlyphsModel.glyph(MeaningGlyphsModel.CROSS),
				GlyphModel.CONNECTION_SIMPLE
			),
			&"sentinel"
		),
		SigilRecipeModel.new(
			&"bound_colossus",
			GlyphModel.combine(
				GlyphModel.new([
					GlyphComponentModel.new(&"ring", Vector2i.ZERO, 0, 1, &"blue"),
				]),
				GlyphModel.new([
					GlyphComponentModel.new(&"spike", Vector2i.ZERO, 0, 1, &"blue"),
				])
			),
			&"golem"
		),
		SigilRecipeModel.new(
			&"fortress_compass",
			GlyphModel.combine(
				MeaningGlyphsModel.glyph(MeaningGlyphsModel.TARGET),
				MeaningGlyphsModel.glyph(MeaningGlyphsModel.COMPASS),
				GlyphModel.CONNECTION_SIMPLE
			),
			&"golem"
		),
	]


static func layout_for_plan(plan_id: StringName) -> Dictionary:
	match plan_id:
		PLAN_EMPTY:
			return {
				&"ring_source": Vector2(105, 195),
				&"summoner": Vector2(410, 195),
			}
		PLAN_SENTINEL:
			return {
				&"ring_source": Vector2(85, 70),
				&"rotator": Vector2(220, 95),
				&"colorizer": Vector2(325, 145),
				&"summoner": Vector2(410, 195),
			}
		PLAN_VIGIL:
			return {
				&"eye_source": Vector2(85, 90),
				&"cross_source": Vector2(85, 300),
				&"combiner": Vector2(260, 195),
				&"summoner": Vector2(410, 195),
			}
		PLAN_STELLAR:
			return {
				&"star_source": Vector2(105, 195),
				&"summoner": Vector2(410, 195),
			}
		PLAN_GOLEM:
			return {
				&"ring_source": Vector2(70, 70),
				&"spike_source": Vector2(70, 320),
				&"combiner": Vector2(220, 195),
				&"colorizer": Vector2(325, 195),
				&"summoner": Vector2(410, 195),
			}
		PLAN_FORTRESS:
			return {
				&"target_source": Vector2(85, 90),
				&"compass_source": Vector2(85, 300),
				&"combiner": Vector2(260, 195),
				&"summoner": Vector2(410, 195),
			}
		_:
			return {
				&"ring_source": Vector2(105, 195),
				&"summoner": Vector2(410, 195),
			}


static func plan_name(plan_id: StringName) -> String:
	match plan_id:
		PLAN_EMPTY:
			return "手組み工場"
		PLAN_SENTINEL:
			return "蒼環の衛兵"
		PLAN_VIGIL:
			return "警戒十字の衛兵"
		PLAN_STELLAR:
			return "星印の衛兵"
		PLAN_GOLEM:
			return "結合の巨像"
		PLAN_FORTRESS:
			return "要塞方位の巨像"
		_:
			return "目の斥候"


static func plan_description(plan_id: StringName) -> String:
	match plan_id:
		PLAN_EMPTY:
			return "構築練習 // 目の出力を召喚器へ接続"
		PLAN_SENTINEL:
			return "環 // 回転・着色の直列加工"
		PLAN_VIGIL:
			return "目＋十字 // 2素材の単純結合"
		PLAN_STELLAR:
			return "星 // 単一素材の短工程"
		PLAN_GOLEM:
			return "環＋棘 // 結合後に着色"
		PLAN_FORTRESS:
			return "的＋方位 // 2素材の単純結合"
		_:
			return "目 // 単一素材の短工程"


static func sigil_name(recipe_id: StringName) -> String:
	match recipe_id:
		&"watchful_eye":
			return "目シジル"
		&"azure_guard":
			return "衛兵シジル"
		&"stellar_sentinel":
			return "星衛兵シジル"
		&"vigil_cross":
			return "警戒十字シジル"
		&"bound_colossus":
			return "巨像シジル"
		&"fortress_compass":
			return "要塞方位シジル"
		_:
			return String(recipe_id)


static func recipe_factory_trait(recipe_id: StringName) -> String:
	match recipe_id:
		&"watchful_eye":
			return "単一素材・短工程"
		&"azure_guard":
			return "回転・着色の直列加工"
		&"vigil_cross":
			return "2素材・単純結合"
		&"stellar_sentinel":
			return "単一素材・中頻度"
		&"bound_colossus":
			return "2素材・結合後加工"
		&"fortress_compass":
			return "2素材・単純結合"
	return ""


static func default_recipe_id_for_unit(unit_id: StringName) -> StringName:
	match unit_id:
		&"sentinel":
			return &"vigil_cross"
		&"golem":
			return &"fortress_compass"
		_:
			return &"watchful_eye"


static func unit_name(unit_id: StringName) -> String:
	match unit_id:
		&"sentinel":
			return "衛兵"
		&"golem":
			return "巨像"
		_:
			return "斥候"


static func recipe_id_for_plan(plan_id: StringName) -> StringName:
	match plan_id:
		PLAN_SENTINEL:
			return &"azure_guard"
		PLAN_VIGIL:
			return &"vigil_cross"
		PLAN_STELLAR:
			return &"stellar_sentinel"
		PLAN_GOLEM:
			return &"bound_colossus"
		PLAN_FORTRESS:
			return &"fortress_compass"
		_:
			return &"watchful_eye"


static func node_name(kind: FactoryNodeModel.NodeKind) -> String:
	match kind:
		FactoryNodeModel.NodeKind.SOURCE:
			return "素材源"
		FactoryNodeModel.NodeKind.ROTATOR:
			return "回転器"
		FactoryNodeModel.NodeKind.TRANSLATOR:
			return "移動器"
		FactoryNodeModel.NodeKind.COLORIZER:
			return "着色器"
		FactoryNodeModel.NodeKind.COMBINER:
			return "合成器"
		FactoryNodeModel.NodeKind.SUMMONER:
			return "召喚器"
	return "設備"


static func node_mana_cost(kind: FactoryNodeModel.NodeKind) -> int:
	match kind:
		FactoryNodeModel.NodeKind.SOURCE:
			return 20
		FactoryNodeModel.NodeKind.COMBINER:
			return 20
		FactoryNodeModel.NodeKind.SUMMONER:
			return 20
		_:
			return 15


static func source_interval_for_glyph(glyph_id: StringName) -> int:
	if glyph_id == &"ring" or glyph_id == MeaningGlyphsModel.EYE:
		return 18
	if glyph_id == &"spike":
		return 54
	if glyph_id == MeaningGlyphsModel.CROSS:
		return 22
	if glyph_id == MeaningGlyphsModel.TARGET or glyph_id == MeaningGlyphsModel.COMPASS:
		return 54
	if glyph_id == MeaningGlyphsModel.STAR:
		return 36
	return 18


static func _build_scout_factory(simulation: FactorySimulation) -> void:
	simulation.add_node(_meaning_source(&"ring_source", MeaningGlyphsModel.EYE, source_interval_for_glyph(MeaningGlyphsModel.EYE)))
	simulation.add_node(FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER))
	simulation.connect_nodes(FactoryLineModel.new(&"line_1", &"ring_source", &"summoner", 0, 3))


static func _build_empty_factory(simulation: FactorySimulation) -> void:
	simulation.add_node(_meaning_source(&"ring_source", MeaningGlyphsModel.EYE, source_interval_for_glyph(MeaningGlyphsModel.EYE)))
	simulation.add_node(FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER))


static func _build_sentinel_factory(simulation: FactorySimulation) -> void:
	simulation.add_node(_source(&"ring_source", &"ring", source_interval_for_glyph(&"ring")))
	simulation.add_node(FactoryNodeModel.new(
		&"rotator",
		FactoryNodeModel.NodeKind.ROTATOR,
		{"steps": 1, "processing_ticks": 2}
	))
	simulation.add_node(FactoryNodeModel.new(
		&"colorizer",
		FactoryNodeModel.NodeKind.COLORIZER,
		{"color_id": "blue", "processing_ticks": 2}
	))
	simulation.add_node(FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER))
	simulation.connect_nodes(FactoryLineModel.new(&"line_1", &"ring_source", &"rotator", 0, 2))
	simulation.connect_nodes(FactoryLineModel.new(&"line_2", &"rotator", &"colorizer", 0, 2))
	simulation.connect_nodes(FactoryLineModel.new(&"line_3", &"colorizer", &"summoner", 0, 2))


static func _build_vigil_factory(simulation: FactorySimulation) -> void:
	simulation.add_node(_meaning_source(&"eye_source", MeaningGlyphsModel.EYE, source_interval_for_glyph(MeaningGlyphsModel.EYE)))
	simulation.add_node(_meaning_source(&"cross_source", MeaningGlyphsModel.CROSS, source_interval_for_glyph(MeaningGlyphsModel.CROSS)))
	simulation.add_node(FactoryNodeModel.new(
		&"combiner",
		FactoryNodeModel.NodeKind.COMBINER,
		{
			"processing_ticks": 3,
			"connection_mode": GlyphModel.CONNECTION_SIMPLE,
		}
	))
	simulation.add_node(FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER))
	simulation.connect_nodes(FactoryLineModel.new(&"line_eye", &"eye_source", &"combiner", 0, 2))
	simulation.connect_nodes(FactoryLineModel.new(&"line_cross", &"cross_source", &"combiner", 1, 2))
	simulation.connect_nodes(FactoryLineModel.new(&"line_summon", &"combiner", &"summoner", 0, 2))


static func _build_stellar_factory(simulation: FactorySimulation) -> void:
	simulation.add_node(_meaning_source(&"star_source", MeaningGlyphsModel.STAR, source_interval_for_glyph(MeaningGlyphsModel.STAR)))
	simulation.add_node(FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER))
	simulation.connect_nodes(FactoryLineModel.new(&"line_1", &"star_source", &"summoner", 0, 3))


static func _build_golem_factory(simulation: FactorySimulation) -> void:
	simulation.add_node(_source(&"ring_source", &"ring", source_interval_for_glyph(&"ring")))
	simulation.add_node(_source(&"spike_source", &"spike", source_interval_for_glyph(&"spike")))
	simulation.add_node(FactoryNodeModel.new(
		&"combiner",
		FactoryNodeModel.NodeKind.COMBINER,
		{"processing_ticks": 3}
	))
	simulation.add_node(FactoryNodeModel.new(
		&"colorizer",
		FactoryNodeModel.NodeKind.COLORIZER,
		{"color_id": "blue", "processing_ticks": 2}
	))
	simulation.add_node(FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER))
	simulation.connect_nodes(FactoryLineModel.new(&"line_ring", &"ring_source", &"combiner", 0, 2))
	simulation.connect_nodes(FactoryLineModel.new(&"line_spike", &"spike_source", &"combiner", 1, 2))
	simulation.connect_nodes(FactoryLineModel.new(&"line_color", &"combiner", &"colorizer", 0, 2))
	simulation.connect_nodes(FactoryLineModel.new(&"line_summon", &"colorizer", &"summoner", 0, 2))


static func _build_fortress_factory(simulation: FactorySimulation) -> void:
	simulation.add_node(_meaning_source(&"target_source", MeaningGlyphsModel.TARGET, source_interval_for_glyph(MeaningGlyphsModel.TARGET)))
	simulation.add_node(_meaning_source(&"compass_source", MeaningGlyphsModel.COMPASS, source_interval_for_glyph(MeaningGlyphsModel.COMPASS)))
	simulation.add_node(FactoryNodeModel.new(
		&"combiner",
		FactoryNodeModel.NodeKind.COMBINER,
		{
			"processing_ticks": 4,
			"connection_mode": GlyphModel.CONNECTION_SIMPLE,
		}
	))
	simulation.add_node(FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER))
	simulation.connect_nodes(FactoryLineModel.new(&"line_target", &"target_source", &"combiner", 0, 2))
	simulation.connect_nodes(FactoryLineModel.new(&"line_compass", &"compass_source", &"combiner", 1, 2))
	simulation.connect_nodes(FactoryLineModel.new(&"line_summon", &"combiner", &"summoner", 0, 2))


static func _source(id: StringName, primitive_id: StringName, interval: int) -> FactoryNodeModel:
	return FactoryNodeModel.new(
		id,
		FactoryNodeModel.NodeKind.SOURCE,
		{"primitive_id": primitive_id, "interval_ticks": interval}
	)


static func _meaning_source(id: StringName, glyph_id: StringName, interval: int) -> FactoryNodeModel:
	return FactoryNodeModel.new(
		id,
		FactoryNodeModel.NodeKind.SOURCE,
		{"meaning_glyph_id": glyph_id, "interval_ticks": interval}
	)
