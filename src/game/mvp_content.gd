class_name MvpContent
extends RefCounted

const FactoryNodeModel := preload("res://src/factory/factory_node.gd")
const FactoryLineModel := preload("res://src/factory/factory_line.gd")
const FactorySimulation := preload("res://src/factory/factory_simulation.gd")
const SigilRecipeModel := preload("res://src/domain/sigil_recipe.gd")
const GlyphComponentModel := preload("res://src/domain/glyph_component.gd")
const GlyphModel := preload("res://src/domain/glyph.gd")
const MeaningGlyphsModel := preload("res://src/domain/meaning_glyphs.gd")
const UnitSpecModel := preload("res://src/battle/unit_spec.gd")
const ThreatEventModel := preload("res://src/battle/threat_event.gd")
const BattleSimulation := preload("res://src/battle/battle_simulation.gd")

const PLAN_SCOUT := &"scout"
const PLAN_SENTINEL := &"sentinel"
const PLAN_VIGIL := &"vigil"
const PLAN_GOLEM := &"golem"
const PLAN_FORTRESS := &"fortress"
const PLAN_EMPTY := &"empty"
const FACTORY_MANA_MAX := 100
const ROUTE_SWARM := &"swarm_route"
const ROUTE_MIXED := &"mixed_route"
const ROUTE_ARMORED := &"armored_route"
const ROUTE_IDS := [ROUTE_SWARM, ROUTE_MIXED, ROUTE_ARMORED]


static func build_battle(route_id: StringName = ROUTE_MIXED) -> BattleSimulation:
	var battle := BattleSimulation.new()
	for spec in unit_specs():
		battle.add_spec(spec)
	battle.set_schedule(threat_schedule(route_id))
	return battle


static func unit_specs() -> Array[UnitSpecModel]:
	return [
		UnitSpecModel.new(&"scout", 36.0, 8.0, 4, 7.5, 30.0, 0.0, 1, &"", 1.0, 480),
		UnitSpecModel.new(&"sentinel", 90.0, 9.0, 5, 4.5, 65.0, 2.0, 3, &"swarm", 1.8, 720),
		UnitSpecModel.new(&"golem", 260.0, 38.0, 7, 3.0, 44.0, 6.0, 1, &"brute", 1.8, 960),
		UnitSpecModel.new(&"raider", 55.0, 8.0, 5, 6.0, 28.0, 1.0, 1, &"", 1.0, 600),
		UnitSpecModel.new(&"swarm", 24.0, 7.0, 3, 8.0, 24.0, 0.0, 1, &"golem", 5.0, 520),
		UnitSpecModel.new(&"brute", 190.0, 24.0, 7, 3.2, 40.0, 5.0, 1, &"", 1.0, 900),
	]


static func threat_schedule(route_id: StringName = ROUTE_MIXED) -> Array[ThreatEventModel]:
	match route_id:
		ROUTE_SWARM:
			return _swarm_route_schedule()
		ROUTE_ARMORED:
			return _armored_route_schedule()
	return _mixed_route_schedule()


static func _mixed_route_schedule() -> Array[ThreatEventModel]:
	var events: Array[ThreatEventModel] = []
	# One battle tick represents 0.2 seconds. A standard encounter lasts three minutes.
	for tick in range(100, 300, 30):
		events.append(ThreatEventModel.new(tick, &"raider", 1, "襲撃兵"))
	for tick in range(300, 570, 30):
		events.append(ThreatEventModel.new(tick, &"swarm", 4, "群体兵", &"center", tick == 300))
	for tick in range(570, 780, 42):
		events.append(ThreatEventModel.new(tick, &"brute", 1, "装甲兵", &"center", tick == 570))
	for tick in range(780, 893, 30):
		events.append(ThreatEventModel.new(tick, &"brute", 1, "最終装甲兵", &"center", tick == 780))
		events.append(ThreatEventModel.new(tick + 8, &"swarm", 5, "最終群体兵"))
	return events


static func _swarm_route_schedule() -> Array[ThreatEventModel]:
	var events: Array[ThreatEventModel] = []
	for tick in range(100, 280, 30):
		events.append(ThreatEventModel.new(tick, &"raider", 1, "襲撃兵"))
	for tick in range(280, 700, 30):
		events.append(ThreatEventModel.new(tick, &"swarm", 4, "群体兵", &"center", tick == 280))
	for tick in range(700, 901, 30):
		events.append(ThreatEventModel.new(tick, &"swarm", 5, "最終群体兵", &"center", tick == 700))
		if tick % 60 == 40:
			events.append(ThreatEventModel.new(tick + 8, &"brute", 1, "護衛装甲兵"))
	return events


static func _armored_route_schedule() -> Array[ThreatEventModel]:
	var events: Array[ThreatEventModel] = []
	for tick in range(100, 280, 30):
		events.append(ThreatEventModel.new(tick, &"raider", 1, "襲撃兵"))
	for tick in range(280, 460, 45):
		events.append(ThreatEventModel.new(tick, &"swarm", 3, "群体兵", &"center", tick == 280))
	for tick in range(460, 901, 34):
		events.append(ThreatEventModel.new(tick, &"brute", 1, "装甲兵", &"center", tick == 460))
	return events


static func route_name(route_id: StringName) -> String:
	match route_id:
		ROUTE_SWARM:
			return "群体の道"
		ROUTE_ARMORED:
			return "装甲の道"
	return "混成の道"


static func route_description(route_id: StringName) -> String:
	match route_id:
		ROUTE_SWARM:
			return "群体中心 // 0:56から長い群体波"
		ROUTE_ARMORED:
			return "装甲中心 // 1:32から装甲波"
	return "混成 // 0:20 襲撃 → 1:00 群体 → 1:54 装甲"


static func build_factory(plan_id: StringName) -> FactorySimulation:
	var simulation := FactorySimulation.new()
	var recipe_set := recipes()
	var content_validation := validate_recipe_set(recipe_set)
	assert(
		content_validation["ok"],
		"Invalid MVP recipe content: %s" % ", ".join(content_validation["errors"])
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
			return "EMPTY WORKSHOP"
		PLAN_SENTINEL:
			return "AZURE SENTINEL"
		PLAN_VIGIL:
			return "VIGIL-CROSS SENTINEL"
		PLAN_GOLEM:
			return "BOUND GOLEM"
		PLAN_FORTRESS:
			return "FORTRESS-COMPASS GOLEM"
		_:
			return "WATCHFUL-EYE SCOUT"


static func plan_description(plan_id: StringName) -> String:
	match plan_id:
		PLAN_EMPTY:
			return "構築練習 // 環素材の出力を召喚器へ接続"
		PLAN_SENTINEL:
			return "対群体 // 3体同時攻撃・中速"
		PLAN_VIGIL:
			return "目＋十字 // 単純結合で対群体衛兵を生産"
		PLAN_GOLEM:
			return "対装甲 // 高耐久・低速・長工程"
		PLAN_FORTRESS:
			return "的＋方位 // 単純結合で対装甲巨像を生産"
		_:
			return "目印 // 高速生産・短寿命"


static func sigil_name(recipe_id: StringName) -> String:
	match recipe_id:
		&"watchful_eye":
			return "斥候シジル"
		&"azure_guard":
			return "衛兵シジル"
		&"vigil_cross":
			return "警戒十字シジル"
		&"bound_colossus":
			return "巨像シジル"
		&"fortress_compass":
			return "要塞方位シジル"
		_:
			return String(recipe_id)


static func recipe_id_for_plan(plan_id: StringName) -> StringName:
	match plan_id:
		PLAN_SENTINEL:
			return &"azure_guard"
		PLAN_VIGIL:
			return &"vigil_cross"
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


static func _build_scout_factory(simulation: FactorySimulation) -> void:
	simulation.add_node(_meaning_source(&"ring_source", MeaningGlyphsModel.EYE, 18))
	simulation.add_node(FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER))
	simulation.connect_nodes(FactoryLineModel.new(&"line_1", &"ring_source", &"summoner", 0, 3))


static func _build_empty_factory(simulation: FactorySimulation) -> void:
	simulation.add_node(_meaning_source(&"ring_source", MeaningGlyphsModel.EYE, 18))
	simulation.add_node(FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER))


static func _build_sentinel_factory(simulation: FactorySimulation) -> void:
	simulation.add_node(_source(&"ring_source", &"ring", 22))
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
	simulation.add_node(_meaning_source(&"eye_source", MeaningGlyphsModel.EYE, 22))
	simulation.add_node(_meaning_source(&"cross_source", MeaningGlyphsModel.CROSS, 22))
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


static func _build_golem_factory(simulation: FactorySimulation) -> void:
	simulation.add_node(_source(&"ring_source", &"ring", 36))
	simulation.add_node(_source(&"spike_source", &"spike", 54))
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
	simulation.add_node(_meaning_source(&"target_source", MeaningGlyphsModel.TARGET, 54))
	simulation.add_node(_meaning_source(&"compass_source", MeaningGlyphsModel.COMPASS, 54))
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
