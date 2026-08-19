class_name MvpContent
extends RefCounted

const FactoryNodeModel := preload("res://src/factory/factory_node.gd")
const FactoryLineModel := preload("res://src/factory/factory_line.gd")
const FactorySimulation := preload("res://src/factory/factory_simulation.gd")
const SigilRecipeModel := preload("res://src/domain/sigil_recipe.gd")
const GlyphComponentModel := preload("res://src/domain/glyph_component.gd")
const GlyphModel := preload("res://src/domain/glyph.gd")
const UnitSpecModel := preload("res://src/battle/unit_spec.gd")
const ThreatEventModel := preload("res://src/battle/threat_event.gd")
const BattleSimulation := preload("res://src/battle/battle_simulation.gd")

const PLAN_SCOUT := &"scout"
const PLAN_SENTINEL := &"sentinel"
const PLAN_GOLEM := &"golem"
const PLAN_EMPTY := &"empty"
const FACTORY_MANA_MAX := 100


static func build_battle() -> BattleSimulation:
	var battle := BattleSimulation.new()
	for spec in unit_specs():
		battle.add_spec(spec)
	battle.set_schedule(threat_schedule())
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


static func threat_schedule() -> Array[ThreatEventModel]:
	var events: Array[ThreatEventModel] = []
	# One battle tick represents 0.2 seconds. A standard encounter lasts three minutes.
	for tick in range(100, 300, 30):
		events.append(ThreatEventModel.new(tick, &"raider", 1, "襲撃兵"))
	for tick in range(300, 570, 30):
		events.append(ThreatEventModel.new(tick, &"swarm", 4, "群体兵", &"center", tick == 300))
	for tick in range(570, 780, 42):
		events.append(ThreatEventModel.new(tick, &"brute", 1, "装甲兵", &"center", tick == 570))
	for tick in range(780, 901, 30):
		events.append(ThreatEventModel.new(tick, &"brute", 1, "最終装甲兵", &"center", tick == 780))
		events.append(ThreatEventModel.new(tick + 8, &"swarm", 5, "最終群体兵"))
	return events


static func build_factory(plan_id: StringName) -> FactorySimulation:
	var simulation := FactorySimulation.new()
	for recipe in recipes():
		simulation.add_recipe(recipe)

	match plan_id:
		PLAN_EMPTY:
			_build_empty_factory(simulation)
		PLAN_SENTINEL:
			_build_sentinel_factory(simulation)
		PLAN_GOLEM:
			_build_golem_factory(simulation)
		_:
			_build_scout_factory(simulation)
	return simulation


static func recipes() -> Array[SigilRecipeModel]:
	return [
		SigilRecipeModel.new(
			&"open_ring",
			GlyphModel.new([
				GlyphComponentModel.new(&"ring"),
			]),
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
	]


static func layout_for_plan(plan_id: StringName) -> Dictionary:
	match plan_id:
		PLAN_EMPTY:
			return {
				&"ring_source": Vector2(180, 190),
				&"summoner": Vector2(640, 190),
			}
		PLAN_SENTINEL:
			return {
				&"ring_source": Vector2(90, 190),
				&"rotator": Vector2(280, 190),
				&"colorizer": Vector2(470, 190),
				&"summoner": Vector2(680, 190),
			}
		PLAN_GOLEM:
			return {
				&"ring_source": Vector2(80, 110),
				&"spike_source": Vector2(80, 280),
				&"combiner": Vector2(300, 195),
				&"colorizer": Vector2(500, 195),
				&"summoner": Vector2(700, 195),
			}
		_:
			return {
				&"ring_source": Vector2(150, 190),
				&"summoner": Vector2(650, 190),
			}


static func plan_name(plan_id: StringName) -> String:
	match plan_id:
		PLAN_EMPTY:
			return "EMPTY WORKSHOP"
		PLAN_SENTINEL:
			return "AZURE SENTINEL"
		PLAN_GOLEM:
			return "BOUND GOLEM"
		_:
			return "OPEN-RING SCOUT"


static func plan_description(plan_id: StringName) -> String:
	match plan_id:
		PLAN_EMPTY:
			return "構築練習 // 環素材の出力を召喚器へ接続"
		PLAN_SENTINEL:
			return "対群体 // 3体同時攻撃・中速"
		PLAN_GOLEM:
			return "対装甲 // 高耐久・低速・長工程"
		_:
			return "初動 // 高速生産・短寿命"


static func sigil_name(recipe_id: StringName) -> String:
	match recipe_id:
		&"open_ring":
			return "斥候シジル"
		&"azure_guard":
			return "衛兵シジル"
		&"bound_colossus":
			return "巨像シジル"
		_:
			return String(recipe_id)


static func recipe_id_for_plan(plan_id: StringName) -> StringName:
	match plan_id:
		PLAN_SENTINEL:
			return &"azure_guard"
		PLAN_GOLEM:
			return &"bound_colossus"
		_:
			return &"open_ring"


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
	simulation.add_node(_source(&"ring_source", &"ring", 18))
	simulation.add_node(FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER))
	simulation.connect_nodes(FactoryLineModel.new(&"line_1", &"ring_source", &"summoner", 0, 3))


static func _build_empty_factory(simulation: FactorySimulation) -> void:
	simulation.add_node(_source(&"ring_source", &"ring", 18))
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


static func _source(id: StringName, primitive_id: StringName, interval: int) -> FactoryNodeModel:
	return FactoryNodeModel.new(
		id,
		FactoryNodeModel.NodeKind.SOURCE,
		{"primitive_id": primitive_id, "interval_ticks": interval}
	)
