class_name MvpContent
extends RefCounted

const FactoryNodeModel := preload("res://src/factory/factory_node.gd")
const FactoryLineModel := preload("res://src/factory/factory_line.gd")
const FactorySimulation := preload("res://src/factory/factory_simulation.gd")
const SigilRecipeModel := preload("res://src/domain/sigil_recipe.gd")
const GlyphComponentModel := preload("res://src/domain/glyph_component.gd")
const GlyphModel := preload("res://src/domain/glyph.gd")

const PLAN_SCOUT := &"scout"
const PLAN_SENTINEL := &"sentinel"
const PLAN_GOLEM := &"golem"


static func build_factory(plan_id: StringName) -> FactorySimulation:
	var simulation := FactorySimulation.new()
	for recipe in recipes():
		simulation.add_recipe(recipe)

	match plan_id:
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
			GlyphModel.new([
				GlyphComponentModel.new(&"ring", Vector2i.ZERO, 0, 1, &"blue"),
				GlyphComponentModel.new(&"spike", Vector2i.ZERO, 0, 1, &"blue"),
			]),
			&"golem"
		),
	]


static func layout_for_plan(plan_id: StringName) -> Dictionary:
	match plan_id:
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
		PLAN_SENTINEL:
			return "AZURE SENTINEL"
		PLAN_GOLEM:
			return "BOUND GOLEM"
		_:
			return "OPEN-RING SCOUT"


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


static func _build_scout_factory(simulation: FactorySimulation) -> void:
	simulation.add_node(_source(&"ring_source", &"ring", 3))
	simulation.add_node(FactoryNodeModel.new(&"summoner", FactoryNodeModel.NodeKind.SUMMONER))
	simulation.connect_nodes(FactoryLineModel.new(&"line_1", &"ring_source", &"summoner", 0, 3))


static func _build_sentinel_factory(simulation: FactorySimulation) -> void:
	simulation.add_node(_source(&"ring_source", &"ring", 3))
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
	simulation.add_node(_source(&"ring_source", &"ring", 4))
	simulation.add_node(_source(&"spike_source", &"spike", 6))
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

