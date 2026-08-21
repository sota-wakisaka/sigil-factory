class_name FactoryBoard
extends Control

signal summon_produced(unit_id: StringName)
signal selection_changed
signal factory_changed

const MvpContent := preload("res://src/game/mvp_content.gd")
const FactoryNodeModel := preload("res://src/factory/factory_node.gd")
const FactoryLineModel := preload("res://src/factory/factory_line.gd")
const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")
const GlyphTooltipModel := preload("res://src/ui/glyph_tooltip.gd")
const GlyphComparisonTooltipModel := preload("res://src/ui/glyph_comparison_tooltip.gd")
const GlyphComponentModel := preload("res://src/domain/glyph_component.gd")
const MeaningGlyphsModel := preload("res://src/domain/meaning_glyphs.gd")

const PANEL_COLOR := Color(0.035, 0.055, 0.085, 0.96)
const NODE_COLOR := Color(0.08, 0.12, 0.18, 1.0)
const NODE_BORDER := Color(0.38, 0.62, 0.82, 0.9)
const LINE_COLOR := Color(0.24, 0.48, 0.68, 0.75)
const GLYPH_COLOR := Color(0.35, 0.86, 1.0, 1.0)
const SELECTED_COLOR := Color(1.0, 0.78, 0.3, 1.0)
const WARNING_COLOR := Color(1.0, 0.38, 0.28, 1.0)
const WAITING_COLOR := Color(1.0, 0.72, 0.24, 1.0)
const MATCH_COLOR := Color(0.36, 1.0, 0.58, 1.0)
const PRODUCTION_INCREASE_COLOR := Color(0.3, 0.86, 0.94, 1.0)
const SOURCE_OPTION_LABELS := ["環", "棘", "目", "十字", "的", "星", "方位"]
const SOURCE_OPTION_IDS := [
	&"ring", &"spike",
	MeaningGlyphsModel.EYE, MeaningGlyphsModel.CROSS, MeaningGlyphsModel.TARGET,
	MeaningGlyphsModel.STAR, MeaningGlyphsModel.COMPASS,
]
const SOURCE_OPTION_INTERVALS := [18, 54, 18, 30, 32, 36, 48]
const COMBINE_OPTION_LABELS := ["中心", "相互", "単純"]
const COMBINE_OPTION_IDS := [
	GlyphModel.CONNECTION_RADIAL,
	GlyphModel.CONNECTION_PAIRWISE,
	GlyphModel.CONNECTION_SIMPLE,
]
const PRODUCTION_DECREASE_COLOR := Color(1.0, 0.7, 0.28, 1.0)
const PRODUCTION_COMPARISON_COLOR := Color(0.42, 0.58, 0.7, 0.88)
const EDIT_ADDED_COLOR := Color(0.24, 0.9, 0.92, 0.96)
const EDIT_CHANGED_COLOR := Color(1.0, 0.72, 0.24, 0.96)
const EDIT_REMOVED_COLOR := Color(1.0, 0.34, 0.3, 0.92)
const NODE_HALF_SIZE := Vector2(48, 30)
const REFERENCE_SIZE := Vector2(820, 395)
const PORT_RADIUS := 7.0
const FACTORY_LINE_WIDTH := 2.0
const TRANSPORT_GLYPH_HALO_RADIUS := 13.0
const MIN_PREDICTED_LINE_GLYPH_LENGTH := 112.0
const PRODUCTION_PREVIEW_TICKS := 160
const PRODUCTION_TICK_SECONDS := 0.2
const PRODUCTION_TIMELINE_WIDTH := 48.0
const FLOW_WARNING_HOLD_TICKS := 5
const INTERACTION_LEGEND_TOOLTIPS := [
	"ドラッグ // 設備を移動",
	"出力 → 入力 // 順にクリック",
	"右クリック // 配線を切断",
]

var plan_id: StringName = MvpContent.PLAN_SCOUT
var simulation: FactorySimulation
var node_positions: Dictionary = {}
var observed_event_count := 0
var observed_failure_count := 0
var editing := false
var pending_plan_id: StringName
var preview_simulation: FactorySimulation
var preview_node_positions: Dictionary = {}
var interaction_enabled := false
var selected_node_id: StringName = &""
var hovered_node_id: StringName = &""
var hovered_node_glyph_id: StringName = &""
var hovered_output_node_id: StringName = &""
var hovered_input_node_id: StringName = &""
var hovered_input_port := -1
var hovered_input_glyph_node_id: StringName = &""
var hovered_input_glyph_port := -1
var hovered_line_id: StringName = &""
var hovered_interaction_legend_index := -1
var dragging_node := false
var drag_snapshot_pending := false
var drag_offset := Vector2.ZERO
var placement_blocked := false
var blocked_placement_position := Vector2.ZERO
var connecting_from_node_id: StringName = &""
var connection_cursor := Vector2.ZERO
var connection_serial := 1
var node_serial := 1
var connection_message := ""
var flow_warning_message := ""
var flow_warning_hold_ticks := 0
var undo_history: Array[Dictionary] = []
var cached_production_preview := ""
var cached_production_counts: Dictionary = {}
var cached_production_event_offsets: Dictionary = {}
var cached_production_discarded := 0
var cached_production_valid := false
var cached_validation_errors: Array[String] = []
var cached_node_output_glyphs: Dictionary = {}
var factory_revision := 0
var setting_option_preview_cache: Dictionary = {}
var production_comparison_active := false
var production_comparison_baseline: Dictionary = {}
var tooltip_glyph: GlyphModel
var tooltip_target_glyph: GlyphModel
var tooltip_title := ""
var tooltip_context := ""
var tooltip_comparison_name := ""
var tooltip_candidate_label := "工場出力"
var run_upgrades: Array[StringName] = []
var last_corrupt_discard_count := 0


func _ready() -> void:
	mouse_exited.connect(_clear_node_hover)
	configure(plan_id)


func configure(next_plan_id: StringName) -> void:
	clear_production_comparison_baseline()
	plan_id = next_plan_id
	simulation = MvpContent.build_factory(plan_id)
	_apply_run_upgrades(simulation)
	node_positions = MvpContent.layout_for_plan(plan_id)
	observed_event_count = 0
	observed_failure_count = 0
	editing = false
	preview_simulation = null
	selected_node_id = &""
	hovered_node_id = &""
	hovered_node_glyph_id = &""
	hovered_output_node_id = &""
	hovered_input_node_id = &""
	hovered_input_port = -1
	hovered_input_glyph_node_id = &""
	hovered_input_glyph_port = -1
	hovered_line_id = &""
	hovered_interaction_legend_index = -1
	dragging_node = false
	drag_snapshot_pending = false
	placement_blocked = false
	connecting_from_node_id = &""
	connection_message = ""
	flow_warning_message = ""
	flow_warning_hold_ticks = 0
	undo_history.clear()
	_refresh_production_preview()
	selection_changed.emit()
	queue_redraw()


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	if not enabled:
		dragging_node = false
		drag_snapshot_pending = false
		placement_blocked = false
		selected_node_id = &""
		hovered_node_id = &""
		hovered_node_glyph_id = &""
		hovered_output_node_id = &""
		hovered_input_node_id = &""
		hovered_input_port = -1
		hovered_input_glyph_node_id = &""
		hovered_input_glyph_port = -1
		hovered_line_id = &""
		hovered_interaction_legend_index = -1
		connecting_from_node_id = &""
	selection_changed.emit()
	queue_redraw()


func move_node(node_id: StringName, local_position: Vector2) -> bool:
	var positions := _display_positions()
	if not interaction_enabled or not positions.has(node_id):
		return false
	var clamped_local := _clamped_node_position(local_position)
	if not placement_is_valid(node_id, clamped_local):
		placement_blocked = true
		blocked_placement_position = clamped_local
		queue_redraw()
		return false
	placement_blocked = false
	positions[node_id] = _reference_position(clamped_local)
	queue_redraw()
	return true


func placement_is_valid(node_id: StringName, local_position: Vector2) -> bool:
	var positions := _display_positions()
	if not positions.has(node_id):
		return false
	var clamped_position := _clamped_node_position(local_position)
	if _placement_intersects_hud(clamped_position):
		return false
	return _reference_position_is_available(_reference_position(clamped_position), positions, node_id)


func _clamped_node_position(local_position: Vector2) -> Vector2:
	var margin := NODE_HALF_SIZE + Vector2(8, 8)
	return Vector2(
		clampf(local_position.x, margin.x, size.x - margin.x),
		clampf(local_position.y, margin.y, size.y - margin.y)
	)


func _placement_intersects_hud(local_position: Vector2) -> bool:
	var node_rect := Rect2(local_position - NODE_HALF_SIZE - Vector2(5, 5), NODE_HALF_SIZE * 2.0 + Vector2(10, 10))
	var reserved := [
		Rect2(Vector2(size.x - 320.0, 0), Vector2(320.0, 72.0)),
		Rect2(Vector2(0, size.y - 48.0), Vector2(300.0, 48.0)),
	]
	if editing:
		reserved.append(Rect2(Vector2.ZERO, Vector2(430.0, 62.0)))
	for reserved_rect in reserved:
		if node_rect.intersects(reserved_rect):
			return true
	return false


func node_local_position(node_id: StringName) -> Vector2:
	return _scaled_position(_display_positions().get(node_id, Vector2.ZERO))


func add_node_from_palette(template_id: StringName) -> StringName:
	if not interaction_enabled:
		return &""
	var kind := FactoryNodeModel.NodeKind.SOURCE
	var config := {}
	var prefix := "node"
	match template_id:
		&"ring_source":
			prefix = "ring_source"
			config = {"primitive_id": "ring", "interval_ticks": 18}
		&"spike_source":
			prefix = "spike_source"
			config = {"primitive_id": "spike", "interval_ticks": 54}
		&"meaning_source":
			prefix = "meaning_source"
			config = {"meaning_glyph_id": MeaningGlyphsModel.EYE, "interval_ticks": 18}
		&"rotator":
			prefix = "rotator"
			kind = FactoryNodeModel.NodeKind.ROTATOR
			config = {"steps": 1, "processing_ticks": 2}
		&"colorizer":
			prefix = "colorizer"
			kind = FactoryNodeModel.NodeKind.COLORIZER
			config = {"color_id": "blue", "processing_ticks": 2}
		&"combiner":
			prefix = "combiner"
			kind = FactoryNodeModel.NodeKind.COMBINER
			config = {
				"processing_ticks": 3,
				"connection_mode": GlyphModel.CONNECTION_RADIAL,
			}
		&"summoner":
			prefix = "summoner"
			kind = FactoryNodeModel.NodeKind.SUMMONER
		_:
			return &""
	var display_simulation := _display_simulation()
	if kind == FactoryNodeModel.NodeKind.SUMMONER and _summoner_count(display_simulation) >= 1:
		connection_message = "召喚器を追加できません: 現MVPは1基までです"
		queue_redraw()
		return &""
	var node_cost := MvpContent.node_mana_cost(kind)
	if mana_used(display_simulation) + node_cost > MvpContent.FACTORY_MANA_MAX:
		connection_message = "設備を追加できません: 魔力不足（必要%d / 空き%d）" % [
			node_cost,
			mana_available(display_simulation),
		]
		queue_redraw()
		return &""
	if not _push_undo_snapshot():
		return &""
	var next_serial := node_serial
	var node_id := StringName("%s_user_%d" % [prefix, next_serial])
	while display_simulation.nodes.has(node_id):
		next_serial += 1
		node_id = StringName("%s_user_%d" % [prefix, next_serial])
	var new_node := FactoryNodeModel.new(node_id, kind, config)
	_apply_node_upgrades(new_node)
	var registration := display_simulation.node_registration_result(new_node)
	if not registration["ok"]:
		undo_history.pop_back()
		connection_message = "設備を追加できません: 設備データが不正です（%s）" % ", ".join(registration["errors"])
		queue_redraw()
		return &""
	node_serial = next_serial + 1
	display_simulation.add_node(new_node)
	_display_positions()[node_id] = _next_palette_reference_position(_display_positions())
	selected_node_id = node_id
	connection_message = "%sを追加しました" % MvpContent.node_name(kind)
	_refresh_production_preview()
	selection_changed.emit()
	queue_redraw()
	return node_id


func _next_palette_reference_position(positions: Dictionary) -> Vector2:
	var candidates := [
		Vector2(650, 125), Vector2(650, 275), Vector2(735, 195),
		Vector2(520, 70), Vector2(520, 320), Vector2(260, 70),
		Vector2(260, 320), Vector2(105, 195),
	]
	for candidate in candidates:
		if _reference_position_is_available(candidate, positions):
			return candidate
	return Vector2(735, 320)


func _reference_position_is_available(candidate: Vector2, positions: Dictionary, ignored_id: StringName = &"") -> bool:
	for existing_id in positions:
		if existing_id == ignored_id:
			continue
		var existing_position: Vector2 = positions[existing_id]
		if absf(candidate.x - existing_position.x) < 85.0 and absf(candidate.y - existing_position.y) < 75.0:
			return false
	return true


func remove_factory_node(node_id: StringName) -> bool:
	if not interaction_enabled or node_id == &"":
		return false
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.nodes.has(node_id):
		return false
	if not _push_undo_snapshot():
		return false
	var discarded_now := display_simulation.discard_all_work_in_progress() if editing else 0
	if not display_simulation.remove_node(node_id):
		var snapshot: Dictionary = undo_history.pop_back()
		_restore_undo_snapshot(snapshot)
		return false
	_clear_node_hover()
	_display_positions().erase(node_id)
	if selected_node_id == node_id:
		selected_node_id = &""
	if connecting_from_node_id == node_id:
		connecting_from_node_id = &""
	connection_message = (
		"設備を削除しました（%s）" % pending_discard_notice()
		if discarded_now > 0
		else "設備を削除しました"
	)
	_refresh_production_preview()
	selection_changed.emit()
	queue_redraw()
	return true


func remove_selected_node() -> bool:
	return remove_factory_node(selected_node_id)


func undo() -> bool:
	if not interaction_enabled or undo_history.is_empty():
		return false
	var snapshot: Dictionary = undo_history.pop_back()
	if editing:
		preview_simulation = snapshot["simulation"]
		preview_node_positions = snapshot["positions"]
		pending_plan_id = snapshot.get("plan_id", pending_plan_id)
	else:
		simulation = snapshot["simulation"]
		node_positions = snapshot["positions"]
		plan_id = snapshot.get("plan_id", plan_id)
		observed_event_count = simulation.summon_events.size()
		observed_failure_count = simulation.summon_failure_events.size()
	_clear_node_hover()
	selected_node_id = &""
	connecting_from_node_id = &""
	connection_message = "元に戻しました"
	_refresh_production_preview()
	selection_changed.emit()
	queue_redraw()
	return true


func validation_result() -> Dictionary:
	var result := _display_simulation().validate_graph()
	if mana_used(_display_simulation()) > MvpContent.FACTORY_MANA_MAX:
		result["ok"] = false
		result["errors"].append("mana_exceeded")
	result["message"] = _validation_message(result["errors"])
	return result


func mana_used(source_simulation: FactorySimulation = null) -> int:
	var target_simulation := source_simulation if source_simulation != null else _display_simulation()
	if target_simulation == null:
		return 0
	var total := 0
	for node in target_simulation.nodes.values():
		total += MvpContent.node_mana_cost(node.kind)
	return total


func mana_available(source_simulation: FactorySimulation = null) -> int:
	return maxi(MvpContent.FACTORY_MANA_MAX - mana_used(source_simulation), 0)


func mana_fill_ratio(source_simulation: FactorySimulation = null) -> float:
	return clampf(float(mana_used(source_simulation)) / float(MvpContent.FACTORY_MANA_MAX), 0.0, 1.0)


func palette_availability(template_id: StringName) -> Dictionary:
	if not interaction_enabled:
		return {"available": false, "reason": &"locked"}
	var kind := FactoryNodeModel.NodeKind.SOURCE
	match template_id:
		&"ring_source", &"spike_source", &"meaning_source":
			kind = FactoryNodeModel.NodeKind.SOURCE
		&"rotator":
			kind = FactoryNodeModel.NodeKind.ROTATOR
		&"colorizer":
			kind = FactoryNodeModel.NodeKind.COLORIZER
		&"combiner":
			kind = FactoryNodeModel.NodeKind.COMBINER
		&"summoner":
			kind = FactoryNodeModel.NodeKind.SUMMONER
		_:
			return {"available": false, "reason": &"unknown"}
	var display_simulation := _display_simulation()
	if kind == FactoryNodeModel.NodeKind.SUMMONER and _summoner_count(display_simulation) >= 1:
		return {"available": false, "reason": &"summoner_limit"}
	if mana_used(display_simulation) + MvpContent.node_mana_cost(kind) > MvpContent.FACTORY_MANA_MAX:
		return {"available": false, "reason": &"mana"}
	return {"available": true, "reason": &""}


func goal_equipment_present(template_id: StringName) -> bool:
	var display_simulation := _display_simulation()
	if display_simulation == null:
		return false
	for node: FactoryNodeModel in display_simulation.nodes.values():
		match template_id:
			&"ring_source":
				if node.kind == FactoryNodeModel.NodeKind.SOURCE and StringName(node.config.get("primitive_id", "")) == &"ring":
					return true
			&"spike_source":
				if node.kind == FactoryNodeModel.NodeKind.SOURCE and StringName(node.config.get("primitive_id", "")) == &"spike":
					return true
			&"meaning_source":
				if node.kind == FactoryNodeModel.NodeKind.SOURCE and MeaningGlyphsModel.has(StringName(node.config.get("meaning_glyph_id", ""))):
					return true
			&"rotator":
				if node.kind == FactoryNodeModel.NodeKind.ROTATOR:
					return true
			&"colorizer":
				if node.kind == FactoryNodeModel.NodeKind.COLORIZER:
					return true
			&"combiner":
				if node.kind == FactoryNodeModel.NodeKind.COMBINER:
					return true
			&"summoner":
				if node.kind == FactoryNodeModel.NodeKind.SUMMONER:
					return true
	return false


func can_undo() -> bool:
	return interaction_enabled and not undo_history.is_empty()


func mana_status_text() -> String:
	return "魔力 %d/%d // 空き%d" % [
		mana_used(),
		MvpContent.FACTORY_MANA_MAX,
		mana_available(),
	]


func _summoner_count(source_simulation: FactorySimulation) -> int:
	var count := 0
	for node in source_simulation.nodes.values():
		count += int(node.kind == FactoryNodeModel.NodeKind.SUMMONER)
	return count


func set_run_upgrades(upgrades: Array[StringName]) -> void:
	run_upgrades = upgrades.duplicate()


func is_guided_connection_pending() -> bool:
	var display_simulation := _display_simulation()
	return (
		display_plan_id() == MvpContent.PLAN_EMPTY
		and display_simulation != null
		and display_simulation.lines.is_empty()
		and connecting_from_node_id == &""
		and display_simulation.nodes.has(&"ring_source")
		and display_simulation.nodes.has(&"summoner")
	)


func _source_option_index(node: FactoryNodeModel) -> int:
	var primitive_id := StringName(node.config.get("primitive_id", ""))
	if primitive_id != &"":
		return SOURCE_OPTION_IDS.find(primitive_id)
	var meaning_glyph_id := StringName(node.config.get("meaning_glyph_id", ""))
	return SOURCE_OPTION_IDS.find(meaning_glyph_id)


func selected_node_details() -> Dictionary:
	var display_simulation := _display_simulation()
	if selected_node_id == &"" or display_simulation == null or not display_simulation.nodes.has(selected_node_id):
		return {"selected": false, "kind": -1, "title": "設備を選択", "options": PackedStringArray(), "selected_index": -1}
	var node: FactoryNodeModel = display_simulation.nodes[selected_node_id]
	var options := PackedStringArray()
	var selected_index := -1
	match node.kind:
		FactoryNodeModel.NodeKind.SOURCE:
			options = PackedStringArray(SOURCE_OPTION_LABELS)
			selected_index = _source_option_index(node)
		FactoryNodeModel.NodeKind.ROTATOR:
			options = PackedStringArray(["90°", "180°", "270°"])
			var steps := int(node.config.get("steps", 0))
			selected_index = steps - 1 if steps in [1, 2, 3] else -1
		FactoryNodeModel.NodeKind.COLORIZER:
			options = PackedStringArray(["青", "赤", "白"])
			var color_id := String(node.config.get("color_id", ""))
			selected_index = ["blue", "red", "white"].find(color_id)
		FactoryNodeModel.NodeKind.COMBINER:
			options = PackedStringArray(COMBINE_OPTION_LABELS)
			var connection_mode := StringName(
				node.config.get("connection_mode", GlyphModel.CONNECTION_RADIAL)
			)
			selected_index = COMBINE_OPTION_IDS.find(connection_mode)
	return {
		"selected": true,
		"kind": node.kind,
		"title": _node_label(node),
		"options": options,
		"selected_index": selected_index,
	}


func configure_selected_node(option_index: int) -> bool:
	var display_simulation := _display_simulation()
	if not interaction_enabled or selected_node_id == &"" or not display_simulation.nodes.has(selected_node_id):
		return false
	var node: FactoryNodeModel = display_simulation.nodes[selected_node_id]
	if not _setting_option_changes_node(node, option_index):
		return false
	if not _push_undo_snapshot():
		return false
	if not _apply_setting_option(node, option_index):
		undo_history.pop_back()
		return false
	var discarded_now := display_simulation.discard_all_work_in_progress() if editing else 0
	connection_message = (
		"設備設定を変更しました（%s）" % pending_discard_notice()
		if discarded_now > 0
		else "設備設定を変更しました"
	)
	_refresh_production_preview()
	selection_changed.emit()
	queue_redraw()
	return true


func _setting_option_changes_node(node: FactoryNodeModel, option_index: int) -> bool:
	match node.kind:
		FactoryNodeModel.NodeKind.SOURCE:
			if option_index < 0 or option_index >= SOURCE_OPTION_IDS.size():
				return false
			return _source_option_index(node) != option_index or int(node.config.get("interval_ticks", 0)) < 1
		FactoryNodeModel.NodeKind.ROTATOR:
			if option_index < 0 or option_index > 2:
				return false
			return (
				int(node.config.get("steps", 0)) != option_index + 1
				or int(node.config.get("processing_ticks", 0)) < 1
			)
		FactoryNodeModel.NodeKind.COLORIZER:
			if option_index < 0 or option_index > 2:
				return false
			return (
				String(node.config.get("color_id", "")) != ["blue", "red", "white"][option_index]
				or int(node.config.get("processing_ticks", 0)) < 1
			)
		FactoryNodeModel.NodeKind.COMBINER:
			if option_index < 0 or option_index >= COMBINE_OPTION_IDS.size():
				return false
			return (
				StringName(node.config.get("connection_mode", GlyphModel.CONNECTION_RADIAL))
				!= COMBINE_OPTION_IDS[option_index]
				or int(node.config.get("processing_ticks", 0)) < 1
			)
	return false


func _apply_setting_option(node: FactoryNodeModel, option_index: int) -> bool:
	match node.kind:
		FactoryNodeModel.NodeKind.SOURCE:
			if option_index < 0 or option_index >= SOURCE_OPTION_IDS.size():
				return false
			node.config.erase("primitive_id")
			node.config.erase("meaning_glyph_id")
			if option_index <= 1:
				node.config["primitive_id"] = SOURCE_OPTION_IDS[option_index]
			else:
				node.config["meaning_glyph_id"] = SOURCE_OPTION_IDS[option_index]
			node.config["interval_ticks"] = SOURCE_OPTION_INTERVALS[option_index]
			node.source_timer = 0
			_apply_node_upgrades(node)
		FactoryNodeModel.NodeKind.ROTATOR:
			if option_index < 0 or option_index > 2:
				return false
			node.config["steps"] = option_index + 1
			node.config["processing_ticks"] = 2
			_apply_node_upgrades(node)
		FactoryNodeModel.NodeKind.COLORIZER:
			if option_index < 0 or option_index > 2:
				return false
			node.config["color_id"] = ["blue", "red", "white"][option_index]
			node.config["processing_ticks"] = 2
			_apply_node_upgrades(node)
		FactoryNodeModel.NodeKind.COMBINER:
			if option_index < 0 or option_index >= COMBINE_OPTION_IDS.size():
				return false
			node.config["connection_mode"] = COMBINE_OPTION_IDS[option_index]
			node.config["processing_ticks"] = 3
			_apply_node_upgrades(node)
		_:
			return false
	return true


func setting_option_candidate(option_index: int) -> Dictionary:
	var display_simulation := _display_simulation()
	if (
		not interaction_enabled
		or selected_node_id == &""
		or display_simulation == null
		or not display_simulation.nodes.has(selected_node_id)
	):
		return {"active": false, "glyph": null, "validity": &"inactive", "output_state": &"no_output", "errors": []}
	var selected_node: FactoryNodeModel = display_simulation.nodes[selected_node_id]
	if not _setting_option_changes_node(selected_node, option_index):
		return {"active": false, "glyph": null, "validity": &"inactive", "output_state": &"no_output", "errors": []}
	var cache_key := "%d:%s:%d" % [factory_revision, selected_node_id, option_index]
	if setting_option_preview_cache.has(cache_key):
		return _copy_setting_option_candidate(setting_option_preview_cache[cache_key])
	var duplication := display_simulation.duplicate_state_result()
	if not duplication["ok"]:
		var failed := {
			"active": true,
			"glyph": null,
			"validity": &"invalid",
			"output_state": &"no_output",
			"errors": duplication.get("errors", []).duplicate(),
		}
		setting_option_preview_cache[cache_key] = failed
		return failed.duplicate(true)
	var hypothetical: FactorySimulation = duplication["state"]
	if editing:
		hypothetical.discard_all_work_in_progress()
	var hypothetical_node: FactoryNodeModel = hypothetical.nodes[selected_node_id]
	if not _apply_setting_option(hypothetical_node, option_index):
		return {"active": false, "glyph": null, "validity": &"inactive", "output_state": &"no_output", "errors": []}
	var preview := _production_preview_for_simulation(hypothetical, PRODUCTION_PREVIEW_TICKS)
	var candidate := (
		_final_summoner_candidate_for(hypothetical, preview.get("node_outputs", {}))
		if preview.get("ok", false)
		else {"glyph": null, "state": &"missing"}
	)
	var result := {
		"active": true,
		"glyph": candidate["glyph"].copy() if GlyphPainterModel.can_draw(candidate.get("glyph")) else null,
		"validity": &"valid" if preview.get("ok", false) else &"invalid",
		"output_state": &"glyph" if GlyphPainterModel.can_draw(candidate.get("glyph")) else &"no_output",
		"errors": preview.get("errors", []).duplicate(),
	}
	setting_option_preview_cache[cache_key] = result
	return _copy_setting_option_candidate(result)


func _copy_setting_option_candidate(candidate: Dictionary) -> Dictionary:
	var glyph: GlyphModel = candidate.get("glyph")
	return {
		"active": bool(candidate.get("active", false)),
		"glyph": glyph.copy() if GlyphPainterModel.can_draw(glyph) else null,
		"validity": candidate.get("validity", &"invalid"),
		"output_state": candidate.get("output_state", &"no_output"),
		"errors": candidate.get("errors", []).duplicate(),
	}


func production_preview(ticks: int = PRODUCTION_PREVIEW_TICKS) -> Dictionary:
	return _production_preview_for_simulation(_display_simulation(), ticks)


func _production_preview_for_simulation(display_simulation: FactorySimulation, ticks: int) -> Dictionary:
	var counts := {&"scout": 0, &"sentinel": 0, &"golem": 0}
	var event_offsets := _empty_production_event_offsets()
	if display_simulation == null:
		return {"ok": false, "counts": counts, "event_offsets": event_offsets, "discarded": 0, "first_failure": {}, "node_outputs": {}, "errors": []}
	var validation := display_simulation.validate_graph()
	if not validation["ok"]:
		return {
			"ok": false,
			"counts": counts,
			"event_offsets": event_offsets,
			"discarded": 0,
			"first_failure": {},
			"node_outputs": {},
			"errors": validation["errors"].duplicate(),
		}
	var duplication := display_simulation.duplicate_state_result()
	if not duplication["ok"]:
		return {
			"ok": false,
			"counts": counts,
			"event_offsets": event_offsets,
			"discarded": 0,
			"first_failure": {},
			"node_outputs": {},
			"errors": duplication["errors"].duplicate(),
		}
	var preview: FactorySimulation = duplication["state"]
	var preview_origin_tick := preview.tick_index
	var event_start := preview.summon_events.size()
	var failure_start := preview.summon_failure_events.size()
	var discarded_start := preview.discarded_glyphs
	var node_outputs: Dictionary = {}
	for _tick in maxi(ticks, 0):
		preview.tick()
		_capture_preview_node_outputs(preview, node_outputs)
	for event_index in range(event_start, preview.summon_events.size()):
		var event: Dictionary = preview.summon_events[event_index]
		var unit_id: StringName = event["unit_id"]
		counts[unit_id] = int(counts.get(unit_id, 0)) + 1
		if not event_offsets.has(unit_id):
			event_offsets[unit_id] = PackedInt32Array()
		var offsets: PackedInt32Array = event_offsets[unit_id]
		offsets.append(int(event["tick"]) - preview_origin_tick)
		event_offsets[unit_id] = offsets
	var first_failure: Dictionary = {}
	if preview.summon_failure_events.size() > failure_start:
		first_failure = preview.summon_failure_events[failure_start].duplicate(true)
	return {
		"ok": true,
		"counts": counts,
		"event_offsets": event_offsets,
		"discarded": preview.discarded_glyphs - discarded_start,
		"first_failure": first_failure,
		"node_outputs": node_outputs,
		"errors": [],
	}


func _empty_production_event_offsets() -> Dictionary:
	return {
		&"scout": PackedInt32Array(),
		&"sentinel": PackedInt32Array(),
		&"golem": PackedInt32Array(),
	}


func production_snapshot() -> Dictionary:
	return {
		"ok": cached_production_valid,
		"horizon_ticks": PRODUCTION_PREVIEW_TICKS,
		"counts": cached_production_counts.duplicate(true),
		"event_offsets": cached_production_event_offsets.duplicate(true),
		"discarded": cached_production_discarded,
		"errors": cached_validation_errors.duplicate(),
	}


func set_production_comparison_baseline(snapshot: Dictionary) -> bool:
	clear_production_comparison_baseline()
	if (
		not editing
		or not bool(snapshot.get("ok", false))
		or int(snapshot.get("horizon_ticks", -1)) != PRODUCTION_PREVIEW_TICKS
	):
		return false
	var counts = snapshot.get("counts")
	if not counts is Dictionary:
		return false
	production_comparison_baseline = snapshot.duplicate(true)
	production_comparison_active = true
	queue_redraw()
	return true


func clear_production_comparison_baseline() -> void:
	production_comparison_active = false
	production_comparison_baseline.clear()
	queue_redraw()


func production_difference_state(unit_id: StringName) -> Dictionary:
	if not production_comparison_active:
		return {"validity": &"inactive"}
	var comparison := compare_production_snapshots(
		production_comparison_baseline,
		production_snapshot()
	)
	if comparison["validity"] != &"valid":
		var baseline_counts: Variant = production_comparison_baseline.get("counts", {})
		var before := int(baseline_counts.get(unit_id, 0)) if baseline_counts is Dictionary else 0
		return {
			"validity": &"invalid",
			"count_state": &"invalid",
			"timing_state": &"invalid",
			"before": before,
			"after": null,
			"delta": null,
		}
	var units: Dictionary = comparison["units"]
	if not units.has(unit_id):
		return {
			"validity": &"valid",
			"count_state": &"unchanged",
			"timing_state": &"unchanged",
			"before": 0,
			"after": 0,
			"delta": 0,
		}
	return units[unit_id].duplicate(true)


func compare_production_snapshots(before: Dictionary, after: Dictionary) -> Dictionary:
	var invalid_result := {
		"validity": &"invalid",
		"changed": false,
		"units": {},
		"discarded": {"state": &"invalid", "before": null, "after": null, "delta": null},
	}
	if not bool(before.get("ok", false)) or not bool(after.get("ok", false)):
		return invalid_result
	if int(before.get("horizon_ticks", -1)) != int(after.get("horizon_ticks", -2)):
		return invalid_result
	var before_counts: Variant = before.get("counts")
	var after_counts: Variant = after.get("counts")
	var before_events: Variant = before.get("event_offsets")
	var after_events: Variant = after.get("event_offsets")
	if (
		not before_counts is Dictionary
		or not after_counts is Dictionary
		or not before_events is Dictionary
		or not after_events is Dictionary
	):
		return invalid_result
	var unit_ids: Array[StringName] = []
	var sources: Array[Dictionary] = [before_counts, after_counts, before_events, after_events]
	for source in sources:
		for raw_unit_id in source:
			var unit_id := StringName(raw_unit_id)
			if not unit_ids.has(unit_id):
				unit_ids.append(unit_id)
	unit_ids.sort()
	var units := {}
	var changed := false
	for unit_id in unit_ids:
		var before_count := int(before_counts.get(unit_id, 0))
		var after_count := int(after_counts.get(unit_id, 0))
		var before_raw: Variant = before_events.get(unit_id, PackedInt32Array())
		var after_raw: Variant = after_events.get(unit_id, PackedInt32Array())
		if not before_raw is PackedInt32Array or not after_raw is PackedInt32Array:
			return invalid_result
		var before_offsets := PackedInt32Array(before_raw)
		var after_offsets := PackedInt32Array(after_raw)
		if before_offsets.size() != before_count or after_offsets.size() != after_count:
			return invalid_result
		var count_state: StringName = &"unchanged"
		if after_count > before_count:
			count_state = &"increase"
		elif after_count < before_count:
			count_state = &"decrease"
		var timing_state := production_timing_difference_state(before_offsets, after_offsets)
		if count_state != &"unchanged" or timing_state != &"unchanged":
			changed = true
		units[unit_id] = {
			"validity": &"valid",
			"count_state": count_state,
			"timing_state": timing_state,
			"before": before_count,
			"after": after_count,
			"delta": after_count - before_count,
			"before_offsets": before_offsets.duplicate(),
			"after_offsets": after_offsets.duplicate(),
		}
	var before_discarded := int(before.get("discarded", 0))
	var after_discarded := int(after.get("discarded", 0))
	var discarded_state: StringName = &"unchanged"
	if after_discarded > before_discarded:
		discarded_state = &"increase"
	elif after_discarded < before_discarded:
		discarded_state = &"decrease"
	if discarded_state != &"unchanged":
		changed = true
	return {
		"validity": &"valid",
		"changed": changed,
		"units": units,
		"discarded": {
			"state": discarded_state,
			"before": before_discarded,
			"after": after_discarded,
			"delta": after_discarded - before_discarded,
		},
	}


func production_timing_difference_state(before: PackedInt32Array, after: PackedInt32Array) -> StringName:
	if before == after:
		return &"unchanged"
	if before.is_empty() and not after.is_empty():
		return &"appeared"
	if not before.is_empty() and after.is_empty():
		return &"disappeared"
	if before.size() != after.size():
		return &"reshaped"
	var shift := after[0] - before[0]
	if shift == 0:
		return &"reshaped"
	for index in before.size():
		if after[index] - before[index] != shift:
			return &"reshaped"
	return &"earlier" if shift < 0 else &"later"


func production_discard_difference_state() -> Dictionary:
	if not production_comparison_active:
		return {"state": &"inactive"}
	var comparison := compare_production_snapshots(
		production_comparison_baseline,
		production_snapshot()
	)
	return (
		comparison["discarded"].duplicate(true)
		if comparison["validity"] == &"valid"
		else {"state": &"invalid", "before": int(production_comparison_baseline.get("discarded", 0)), "after": null, "delta": null}
	)


func _capture_preview_node_outputs(preview: FactorySimulation, outputs: Dictionary) -> void:
	for node_id in preview.nodes:
		if outputs.has(node_id):
			continue
		var node: FactoryNodeModel = preview.nodes[node_id]
		if node.output_buffer != null and node.output_buffer.structure_validation_errors().is_empty():
			outputs[node_id] = node.output_buffer.copy()
	for line in preview.lines.values():
		if outputs.has(line.from_node_id) or line.payload == null:
			continue
		if line.payload.structure_validation_errors().is_empty():
			outputs[line.from_node_id] = line.payload.copy()


func connect_nodes_interactive(from_node_id: StringName, to_node_id: StringName, to_port: int) -> Dictionary:
	if not interaction_enabled:
		return {"ok": false, "error": "locked"}
	var display_simulation := _display_simulation()
	if display_simulation == null or from_node_id == to_node_id:
		return {"ok": false, "error": "self_connection"}
	for line in display_simulation.lines.values():
		if line.from_node_id == from_node_id and line.to_node_id == to_node_id and line.to_port == to_port:
			connection_message = "接続済み"
			queue_redraw()
			return {"ok": true, "error": "already_connected", "changed": false}
	if not _push_undo_snapshot():
		return {"ok": false, "error": "undo_snapshot", "changed": false}
	var removed_line: FactoryLineModel
	for line in display_simulation.lines.values():
		if line.to_node_id == to_node_id and line.to_port == to_port:
			removed_line = line
			display_simulation.disconnect_line(line.id)
			break
	var line_id := StringName("user_line_%d" % connection_serial)
	var result := display_simulation.connect_nodes(
		FactoryLineModel.new(line_id, from_node_id, to_node_id, to_port, 2)
	)
	if result["ok"]:
		connection_serial += 1
		_apply_line_upgrades(display_simulation.lines[line_id])
		_clear_node_hover()
	if not result["ok"]:
		var snapshot: Dictionary = undo_history.pop_back()
		_restore_undo_snapshot(snapshot)
	var discarded_now := 0
	if result["ok"] and editing:
		discarded_now = display_simulation.discard_all_work_in_progress()
		if removed_line != null and removed_line.payload != null:
			display_simulation.discarded_glyphs += 1
			discarded_now += 1
	connection_message = _connection_result_text(result)
	if discarded_now > 0:
		connection_message += "（%s）" % pending_discard_notice()
	_refresh_production_preview()
	queue_redraw()
	return result


func disconnect_input(to_node_id: StringName, to_port: int) -> bool:
	if not interaction_enabled:
		return false
	var display_simulation := _display_simulation()
	for line in display_simulation.lines.values():
		if line.to_node_id == to_node_id and line.to_port == to_port:
			if not _push_undo_snapshot():
				return false
			var discarded_now := display_simulation.discard_all_work_in_progress() if editing else 0
			display_simulation.disconnect_line(line.id)
			_clear_node_hover()
			connection_message = (
				"接続を解除しました（%s）" % pending_discard_notice()
				if discarded_now > 0
				else "接続を解除しました"
			)
			_refresh_production_preview()
			queue_redraw()
			return true
	return false


func _gui_input(event: InputEvent) -> void:
	if not interaction_enabled:
		return
	if event is InputEventMouseButton and interaction_legend_index_at(event.position) >= 0:
		accept_event()
		return
	if event is InputEventMouseMotion:
		_update_pointer_hover(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var input_port := _input_port_at(event.position)
			if not input_port.is_empty() and connecting_from_node_id != &"":
				connect_nodes_interactive(connecting_from_node_id, input_port["node_id"], input_port["port"])
				connecting_from_node_id = &""
				accept_event()
				return
			var output_node_id := _output_port_at(event.position)
			if output_node_id != &"":
				connecting_from_node_id = output_node_id
				connection_cursor = event.position
				connection_message = "入力ポートを選択してください"
				accept_event()
				queue_redraw()
				return
			selected_node_id = _node_at(event.position)
			selection_changed.emit()
			dragging_node = selected_node_id != &""
			if dragging_node:
				drag_snapshot_pending = true
				placement_blocked = false
				drag_offset = node_local_position(selected_node_id) - event.position
				accept_event()
		else:
			dragging_node = false
			drag_snapshot_pending = false
			placement_blocked = false
		queue_redraw()
	elif event is InputEventMouseMotion and dragging_node:
		var target_position: Vector2 = event.position + drag_offset
		if not placement_is_valid(selected_node_id, target_position):
			placement_blocked = true
			blocked_placement_position = _clamped_node_position(target_position)
			queue_redraw()
			accept_event()
			return
		if drag_snapshot_pending:
			if not _push_undo_snapshot():
				dragging_node = false
				drag_snapshot_pending = false
				placement_blocked = false
				accept_event()
				return
			drag_snapshot_pending = false
		move_node(selected_node_id, target_position)
		accept_event()
	elif event is InputEventMouseMotion and connecting_from_node_id != &"":
		connection_cursor = event.position
		queue_redraw()
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if cancel_pending_connection():
			accept_event()
			return
		var input_port := _input_port_at(event.position)
		if not input_port.is_empty():
			disconnect_input(input_port["node_id"], input_port["port"])
			accept_event()
			return
		var line_id := _line_at(event.position)
		var display_simulation := _display_simulation()
		if line_id != &"" and display_simulation != null and display_simulation.lines.has(line_id):
			var line: FactoryLineModel = display_simulation.lines[line_id]
			disconnect_input(line.to_node_id, line.to_port)
			accept_event()


func cancel_pending_connection() -> bool:
	if connecting_from_node_id == &"":
		return false
	connecting_from_node_id = &""
	connection_cursor = Vector2.ZERO
	connection_message = "配線をキャンセルしました"
	queue_redraw()
	return true


func apply_plan(next_plan_id: StringName) -> bool:
	if not interaction_enabled or editing or next_plan_id == plan_id:
		return false
	if not _push_undo_snapshot():
		return false
	plan_id = next_plan_id
	simulation = MvpContent.build_factory(plan_id)
	_clear_node_hover()
	_apply_run_upgrades(simulation)
	node_positions = MvpContent.layout_for_plan(plan_id)
	observed_event_count = 0
	observed_failure_count = 0
	selected_node_id = &""
	connecting_from_node_id = &""
	connection_message = "テンプレートを適用しました"
	_refresh_production_preview()
	selection_changed.emit()
	queue_redraw()
	return true


func _clear_node_hover() -> void:
	if hovered_node_id == &"" and hovered_node_glyph_id == &"" and hovered_output_node_id == &"" and hovered_input_node_id == &"" and hovered_input_glyph_node_id == &"" and hovered_line_id == &"" and hovered_interaction_legend_index < 0:
		return
	hovered_node_id = &""
	hovered_node_glyph_id = &""
	hovered_output_node_id = &""
	hovered_input_node_id = &""
	hovered_input_port = -1
	hovered_input_glyph_node_id = &""
	hovered_input_glyph_port = -1
	hovered_line_id = &""
	hovered_interaction_legend_index = -1
	queue_redraw()


func _update_pointer_hover(at_position: Vector2) -> void:
	var next_legend_index := interaction_legend_index_at(at_position)
	var next_node := _node_at(at_position)
	var next_output := _output_port_at(at_position)
	var input := _input_port_at(at_position)
	var next_input_node: StringName = input.get("node_id", &"")
	var next_input_port := int(input.get("port", -1))
	var input_glyph := input_glyph_at(at_position)
	var next_input_glyph_node: StringName = input_glyph.get("node_id", &"")
	var next_input_glyph_port := int(input_glyph.get("port", -1))
	var next_node_glyph := node_glyph_at(at_position)
	if next_input_glyph_node != &"":
		next_node_glyph = &""
	if next_input_glyph_node != &"" or next_node_glyph != &"":
		next_node = &""
	var next_line := _line_at(at_position)
	if next_legend_index >= 0:
		next_node = &""
		next_node_glyph = &""
		next_output = &""
		next_input_node = &""
		next_input_port = -1
		next_input_glyph_node = &""
		next_input_glyph_port = -1
		next_line = &""
	if (
		next_node == hovered_node_id
		and next_node_glyph == hovered_node_glyph_id
		and next_output == hovered_output_node_id
		and next_input_node == hovered_input_node_id
		and next_input_port == hovered_input_port
		and next_input_glyph_node == hovered_input_glyph_node_id
		and next_input_glyph_port == hovered_input_glyph_port
		and next_line == hovered_line_id
		and next_legend_index == hovered_interaction_legend_index
	):
		return
	hovered_node_id = next_node
	hovered_node_glyph_id = next_node_glyph
	hovered_output_node_id = next_output
	hovered_input_node_id = next_input_node
	hovered_input_port = next_input_port
	hovered_input_glyph_node_id = next_input_glyph_node
	hovered_input_glyph_port = next_input_glyph_port
	hovered_line_id = next_line
	hovered_interaction_legend_index = next_legend_index
	queue_redraw()


func hovered_port_kind() -> StringName:
	if hovered_output_node_id != &"":
		return &"output"
	if hovered_input_node_id != &"":
		return &"input"
	return &"none"


func connection_preview_state() -> StringName:
	if connecting_from_node_id == &"" or hovered_input_node_id == &"":
		return &"free"
	return connection_target_state(hovered_input_node_id, hovered_input_port)


func connection_target_state(to_node_id: StringName, to_port: int) -> StringName:
	return connection_target_result(to_node_id, to_port)["state"]


func connection_target_result(to_node_id: StringName, to_port: int) -> Dictionary:
	var display_simulation := _display_simulation()
	if connecting_from_node_id == &"" or display_simulation == null:
		return {"state": &"free", "reason": &"inactive"}
	if (
		not display_simulation.nodes.has(connecting_from_node_id)
		or not display_simulation.nodes.has(to_node_id)
	):
		return {"state": &"invalid", "reason": &"missing_node"}
	if connecting_from_node_id == to_node_id:
		return {"state": &"invalid", "reason": &"self_connection"}
	var target: FactoryNodeModel = display_simulation.nodes[to_node_id]
	if to_port < 0 or to_port >= target.required_input_count():
		return {"state": &"invalid", "reason": &"invalid_port"}
	for line in display_simulation.lines.values():
		if line.from_node_id == connecting_from_node_id and line.to_node_id == to_node_id and line.to_port == to_port:
			return {"state": &"already_connected", "reason": &"already_connected"}
	for line in display_simulation.lines.values():
		if line.from_node_id == connecting_from_node_id:
			return {"state": &"invalid", "reason": &"occupied_output"}
	if _path_reaches_node(to_node_id, connecting_from_node_id, {}):
		return {"state": &"invalid", "reason": &"cycle"}
	return {"state": &"valid", "reason": &"valid"}


func connection_target_tooltip(to_node_id: StringName, to_port: int) -> String:
	var result := connection_target_result(to_node_id, to_port)
	match result["reason"]:
		&"valid": return "接続できます"
		&"already_connected": return "接続済み"
		&"occupied_output": return "出力は使用中"
		&"cycle": return "循環するため接続できません"
		&"self_connection": return "同じ設備には接続できません"
		_: return "ここには接続できません"


func connection_preview_endpoint() -> Vector2:
	if hovered_input_node_id != &"" and hovered_input_port >= 0:
		return _input_port_position(hovered_input_node_id, hovered_input_port)
	return connection_cursor


func _get_cursor_shape(at_position: Vector2) -> CursorShape:
	return cursor_shape_at(at_position)


func cursor_shape_at(at_position: Vector2) -> CursorShape:
	if connecting_from_node_id != &"":
		var connection_input := _input_port_at(at_position)
		if not connection_input.is_empty():
			var target_state := connection_target_state(
				connection_input.get("node_id", &""),
				int(connection_input.get("port", -1))
			)
			return Control.CURSOR_FORBIDDEN if target_state == &"invalid" else Control.CURSOR_POINTING_HAND
	if informational_visual_at(at_position):
		return Control.CURSOR_HELP
	if not input_glyph_at(at_position).is_empty():
		return Control.CURSOR_HELP
	if node_glyph_at(at_position) != &"":
		return Control.CURSOR_HELP
	if not interaction_enabled:
		return Control.CURSOR_ARROW
	if _output_port_at(at_position) != &"" or not _input_port_at(at_position).is_empty():
		return Control.CURSOR_POINTING_HAND
	if _line_at(at_position) != &"":
		return Control.CURSOR_POINTING_HAND
	if _node_at(at_position) != &"":
		return Control.CURSOR_DRAG
	return Control.CURSOR_ARROW


func informational_visual_at(at_position: Vector2) -> bool:
	return (
		not validation_fault_at(at_position).is_empty()
		or edit_difference_at(at_position) != &""
		or connection_feedback_badge_at(at_position)
		or flow_warning_badge_at(at_position)
		or pending_discard_badge_at(at_position)
		or work_in_progress_summary_index_at(at_position) >= 0
		or production_error_at(at_position)
		or production_discard_badge_at(at_position)
		or production_summary_unit_at(at_position) != &""
		or interaction_legend_index_at(at_position) >= 0
	)


func begin_edit() -> bool:
	clear_production_comparison_baseline()
	last_corrupt_discard_count = 0
	var runtime_errors := simulation.work_in_progress_validation_errors()
	if not runtime_errors.is_empty():
		last_corrupt_discard_count = simulation.discard_invalid_work_in_progress()
		connection_message = "破損仕掛品 %d個を廃棄して編集状態へ復旧しました" % last_corrupt_discard_count
	var duplication := simulation.duplicate_state_result()
	if not duplication["ok"]:
		editing = false
		preview_simulation = null
		interaction_enabled = false
		connection_message = "工場状態を複製できません // %s" % _validation_message(duplication["errors"])
		queue_redraw()
		return false
	editing = true
	pending_plan_id = plan_id
	preview_simulation = duplication["state"]
	preview_node_positions = node_positions.duplicate(true)
	selected_node_id = &""
	connecting_from_node_id = &""
	undo_history.clear()
	_refresh_production_preview()
	selection_changed.emit()
	queue_redraw()
	return true


func preview_plan(next_plan_id: StringName) -> bool:
	if not editing or next_plan_id == pending_plan_id:
		return false
	if not _push_undo_snapshot():
		return false
	var discarded_before_edit := simulation.discarded_glyphs
	var discarded_work_in_progress := work_in_progress_count()
	var committed_tick := simulation.tick_index
	pending_plan_id = next_plan_id
	preview_simulation = MvpContent.build_factory(pending_plan_id)
	_clear_node_hover()
	_apply_run_upgrades(preview_simulation)
	preview_simulation.discarded_glyphs = discarded_before_edit + discarded_work_in_progress
	preview_simulation.tick_index = committed_tick
	preview_node_positions = MvpContent.layout_for_plan(pending_plan_id)
	selected_node_id = &""
	_refresh_production_preview()
	selection_changed.emit()
	queue_redraw()
	return true


func commit_edit() -> void:
	if not editing:
		return
	plan_id = pending_plan_id
	simulation = preview_simulation
	node_positions = preview_node_positions
	observed_event_count = simulation.summon_events.size()
	observed_failure_count = simulation.summon_failure_events.size()
	_clear_node_hover()
	editing = false
	preview_simulation = null
	undo_history.clear()
	clear_production_comparison_baseline()
	_refresh_production_preview()
	selection_changed.emit()
	queue_redraw()


func cancel_edit() -> void:
	if not editing:
		return
	_clear_node_hover()
	editing = false
	preview_simulation = null
	preview_node_positions.clear()
	undo_history.clear()
	clear_production_comparison_baseline()
	_refresh_production_preview()
	selection_changed.emit()
	queue_redraw()


func work_in_progress_count() -> int:
	return _work_in_progress_entries(simulation).size()


func work_in_progress_summary() -> String:
	var counts := {}
	for entry in _work_in_progress_entries(simulation):
		var glyph: GlyphModel = entry["glyph"]
		var label := _glyph_type_label(glyph)
		counts[label] = int(counts.get(label, 0)) + 1
	var labels := counts.keys()
	labels.sort()
	var parts := PackedStringArray()
	for label in labels:
		parts.append("%s×%d" % [label, counts[label]])
	return "、".join(parts)


func work_in_progress_impact_summary() -> String:
	var impacts := PackedStringArray()
	for entry in _work_in_progress_entries(simulation):
		var location := String(entry["location"])
		if not impacts.has(location):
			impacts.append(location)
	impacts.sort()
	return "、".join(impacts)


func pending_discard_count() -> int:
	if not editing or preview_simulation == null or simulation == null:
		return 0
	return maxi(preview_simulation.discarded_glyphs - simulation.discarded_glyphs, 0)


func pending_discard_notice() -> String:
	var count := pending_discard_count()
	if count <= 0:
		return ""
	var summary := work_in_progress_summary()
	var notice := (
		"仕掛品%d個を廃棄予定" % count
		if summary == ""
		else "仕掛品%d個（%s）を廃棄予定" % [count, summary]
	)
	var impact_summary := work_in_progress_impact_summary()
	if impact_summary != "":
		notice += " // 影響: " + impact_summary
	return notice


func _work_in_progress_entries(source_simulation: FactorySimulation) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if source_simulation == null:
		return entries
	var node_ids := source_simulation.nodes.keys()
	node_ids.sort()
	for node_id in node_ids:
		var node: FactoryNodeModel = source_simulation.nodes[node_id]
		var node_label := _node_label(node)
		for port in node.input_buffers.size():
			var glyph = node.input_buffers[port]
			if glyph != null:
				entries.append({"glyph": glyph, "location": "%s・入力%d" % [node_label, port + 1]})
		if node.output_buffer != null:
			entries.append({"glyph": node.output_buffer, "location": "%s・出力" % node_label})
		if node.processing_glyph != null:
			entries.append({"glyph": node.processing_glyph, "location": "%s・処理中" % node_label})
	var line_ids := source_simulation.lines.keys()
	line_ids.sort()
	for line_id in line_ids:
		var line: FactoryLineModel = source_simulation.lines[line_id]
		if line.payload != null:
			var from_node: FactoryNodeModel = source_simulation.nodes[line.from_node_id]
			var to_node: FactoryNodeModel = source_simulation.nodes[line.to_node_id]
			entries.append({
				"glyph": line.payload,
				"location": "%s→%s" % [_node_label(from_node), _node_label(to_node)],
			})
	return entries


func _glyph_type_label(glyph: GlyphModel) -> String:
	var canonical := glyph.canonical_serialization()
	for meaning_glyph_id in MeaningGlyphsModel.IDS:
		if MeaningGlyphsModel.glyph(meaning_glyph_id).canonical_serialization() == canonical:
			return MeaningGlyphsModel.label(meaning_glyph_id)
	var component_labels := PackedStringArray()
	for component in glyph.components:
		var attributes := PackedStringArray([_primitive_name(component.primitive_id)])
		if component.color_id != &"white":
			attributes.append(_color_name(component.color_id))
		if component.rotation_degrees != 0:
			attributes.append("%d°" % component.rotation_degrees)
		if component.scale_step != 1:
			attributes.append("倍率%d" % component.scale_step)
		if component.position != Vector2.ZERO:
			attributes.append("位置%d,%d" % [component.position.x, component.position.y])
		component_labels.append("・".join(attributes))
	component_labels.sort()
	return "+".join(component_labels)


func _primitive_name(primitive_id: StringName) -> String:
	return {
		&"ring": "環", &"spike": "棘", &"branch": "枝",
		&"circle": "丸", &"triangle": "三角", &"square": "四角",
	}.get(primitive_id, String(primitive_id))


func _color_name(color_id: StringName) -> String:
	return {&"blue": "青", &"red": "赤", &"white": "白"}.get(color_id, String(color_id))


func advance_tick() -> void:
	if simulation == null:
		return
	simulation.tick()
	while observed_event_count < simulation.summon_events.size():
		var event := simulation.summon_events[observed_event_count]
		observed_event_count += 1
		connection_message = "召喚成功 // %s" % MvpContent.sigil_name(event["recipe_id"])
		summon_produced.emit(event["unit_id"])
	while observed_failure_count < simulation.summon_failure_events.size():
		var event := simulation.summon_failure_events[observed_failure_count]
		observed_failure_count += 1
		connection_message = _summon_failure_message(event)
	_refresh_flow_warning()
	queue_redraw()


func _summon_failure_message(event: Dictionary) -> String:
	var diagnostics: PackedStringArray = event.get("diagnostics", PackedStringArray())
	var reason := "原因不明" if diagnostics.is_empty() else " / ".join(diagnostics)
	var recipe_id: StringName = event.get("closest_recipe_id", &"")
	if recipe_id == &"":
		return "召喚失敗 // %s" % reason
	return "召喚失敗 // %sとの差分: %s" % [MvpContent.sigil_name(recipe_id), reason]


func _refresh_flow_warning() -> void:
	var warnings := PackedStringArray()
	for diagnostic in simulation.flow_diagnostics():
		var node_id: StringName = diagnostic.get("node_id", &"")
		var node_label := String(node_id)
		if simulation.nodes.has(node_id):
			node_label = _node_label(simulation.nodes[node_id])
		match diagnostic["code"]:
			&"buffer_full":
				warnings.append("入力満杯: %s" % node_label)
			&"output_blocked":
				warnings.append("出力閉塞: %s" % node_label)
			&"material_shortage":
				warnings.append("素材不足: %s" % node_label)
	if not warnings.is_empty():
		flow_warning_message = "工場警告 // " + " / ".join(warnings)
		flow_warning_hold_ticks = FLOW_WARNING_HOLD_TICKS
	elif flow_warning_hold_ticks > 0:
		flow_warning_hold_ticks -= 1
		if flow_warning_hold_ticks == 0:
			flow_warning_message = ""
	else:
		flow_warning_message = ""


func _draw() -> void:
	draw_style_box(_panel_style(), Rect2(Vector2.ZERO, size))
	var display_simulation := preview_simulation if editing else simulation
	var display_positions := preview_node_positions if editing else node_positions
	if display_simulation == null:
		return
	var focused_route := focused_downstream_route(focused_route_start_node_id(), display_simulation)
	_draw_lines(display_simulation, display_positions, focused_route)
	if is_guided_connection_pending():
		draw_dashed_line(
			_output_port_position(&"ring_source"),
			_input_port_position(&"summoner", 0),
			Color(1.0, 0.74, 0.24, 0.65),
			3.0,
			8.0
		)
	if connecting_from_node_id != &"":
		var connection_endpoint := connection_preview_endpoint()
		var connection_state := connection_preview_state()
		var connection_color: Color = {
			&"valid": MATCH_COLOR,
			&"invalid": WARNING_COLOR,
			&"already_connected": GLYPH_COLOR,
		}.get(connection_state, SELECTED_COLOR)
		draw_line(_output_port_position(connecting_from_node_id), connection_endpoint, connection_color, 3.0, true)
		if connection_state == &"invalid":
			draw_line(connection_endpoint + Vector2(-4, -4), connection_endpoint + Vector2(4, 4), WARNING_COLOR, 2.0, true)
			draw_line(connection_endpoint + Vector2(-4, 4), connection_endpoint + Vector2(4, -4), WARNING_COLOR, 2.0, true)
	_draw_nodes(display_simulation, display_positions, focused_route)
	if dragging_node and placement_blocked:
		_draw_blocked_placement()
	if editing:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.18, 0.62, 0.9, 0.055), true)
		_draw_line_edit_differences()
		_draw_node_edit_differences()
		_draw_edit_summary()
	if interaction_enabled:
		_draw_interaction_legend()
		if cached_production_valid or production_comparison_active:
			_draw_production_summary()
		if not cached_production_valid:
			_draw_production_error_badge()
		_draw_mana_meter()
	if connection_message != "":
		_draw_connection_feedback_badge()
	if not interaction_enabled and flow_warning_message != "":
		_draw_flow_warning_badge()


func _draw_lines(
	display_simulation: FactorySimulation,
	display_positions: Dictionary,
	focused_route: Dictionary = {}
) -> void:
	var focused_line_ids: Array = focused_route.get("line_ids", [])
	for line_id in display_simulation.lines:
		var line: FactoryLineModel = display_simulation.lines[line_id]
		var start := _output_port_position(line.from_node_id)
		var finish := _input_port_position(line.to_node_id, line.to_port)
		var line_color := WARNING_COLOR if display_simulation.line_flow_state(line_id) == &"buffer_full" else LINE_COLOR
		var recipe_state := line_recipe_match_state(line_id)
		if display_simulation.line_flow_state(line_id) != &"buffer_full":
			if recipe_state == &"match":
				line_color = Color(MATCH_COLOR, 0.76)
			elif recipe_state in [&"mismatch", &"invalid"]:
				line_color = Color(WARNING_COLOR, 0.76)
		if focused_line_ids.has(line_id):
			draw_line(start, finish, Color(0.34, 0.76, 1.0, 0.2), 8.0, true)
		if interaction_enabled and line_id == hovered_line_id:
			draw_line(start, finish, Color(line_color, 0.28), 12.0, true)
			var hover_normal := start.direction_to(finish).orthogonal()
			var hover_center := start.lerp(finish, 0.5)
			draw_line(hover_center - hover_normal * 6.0, hover_center + hover_normal * 6.0, Color(line_color, 0.86), 1.5, true)
		draw_line(start, finish, line_color, FACTORY_LINE_WIDTH, true)
		_draw_flow_arrow(start, finish, line_color)
		if display_simulation.line_flow_state(line_id) == &"buffer_full":
			_draw_line_blocked_marker(start.lerp(finish, 0.58))
		if line.payload != null:
			var progress := 1.0 - float(line.remaining_ticks) / float(line.travel_ticks)
			var glyph_center := start.lerp(finish, progress)
			_draw_transport_glyph(line.payload, glyph_center)
			_draw_recipe_match_marker(glyph_center, recipe_state, 11.0)
		else:
			var predicted_glyph := predicted_glyph_for_line(line_id)
			if predicted_glyph != null and line_has_preview_space(start, finish):
				var predicted_center := start.lerp(finish, 0.28)
				_draw_predicted_line_glyph(predicted_glyph, predicted_center)
				_draw_recipe_match_marker(predicted_center, recipe_state, 10.0)


func _draw_flow_arrow(start: Vector2, finish: Vector2, color: Color) -> void:
	var direction := start.direction_to(finish)
	if direction == Vector2.ZERO:
		return
	var center := start.lerp(finish, 0.5)
	var tip := center + direction * 8.0
	var wing_origin := center - direction * 5.0
	var normal := Vector2(-direction.y, direction.x) * 6.0
	draw_line(tip, wing_origin + normal, color, 1.5, true)
	draw_line(tip, wing_origin - normal, color, 1.5, true)


func _draw_transport_glyph(glyph: GlyphModel, center: Vector2) -> void:
	if not GlyphPainterModel.can_draw(glyph):
		return
	draw_circle(center, TRANSPORT_GLYPH_HALO_RADIUS, Color(0.012, 0.024, 0.038, 0.94))
	draw_arc(center, TRANSPORT_GLYPH_HALO_RADIUS, 0.0, TAU, 24, Color(0.22, 0.42, 0.56, 0.42), 1.0, true)
	_draw_mini_glyph(glyph, center, transport_glyph_draw_scale(glyph))


func _draw_predicted_line_glyph(glyph: GlyphModel, center: Vector2) -> void:
	if not GlyphPainterModel.can_draw(glyph):
		return
	draw_circle(center, 10.0, Color(0.012, 0.024, 0.038, 0.86))
	for segment in 8:
		var start_angle := float(segment) * TAU / 8.0
		draw_arc(
			center,
			10.0,
			start_angle,
			start_angle + TAU / 16.0,
			3,
			Color(0.22, 0.54, 0.68, 0.38),
			1.0,
			true
		)
	var scale := 0.68 if not glyph.combine_children.is_empty() else 1.2
	_draw_mini_glyph(glyph, center, scale, 0.64)


func line_has_preview_space(start: Vector2, finish: Vector2) -> bool:
	return start.distance_to(finish) >= MIN_PREDICTED_LINE_GLYPH_LENGTH


func transport_glyph_draw_scale(glyph: GlyphModel) -> float:
	if glyph != null and not glyph.combine_children.is_empty():
		return 0.85
	return 1.5


func _draw_nodes(
	display_simulation: FactorySimulation,
	display_positions: Dictionary,
	focused_route: Dictionary = {}
) -> void:
	var focused_node_ids: Array = focused_route.get("node_ids", [])
	var route_start_id: StringName = focused_route.get("start_node_id", &"")
	for node_id in display_simulation.nodes:
		var node: FactoryNodeModel = display_simulation.nodes[node_id]
		var center := _scaled_position(display_positions.get(node_id, Vector2.ZERO))
		var node_state := display_simulation.node_flow_state(node_id)
		var border_color := NODE_BORDER
		if node_state == &"output_blocked":
			border_color = WARNING_COLOR
		elif node_state == &"material_shortage":
			border_color = WAITING_COLOR
		if node_id == selected_node_id:
			border_color = SELECTED_COLOR
		elif node_id == hovered_node_id:
			border_color = Color(0.56, 0.86, 1.0)
		_draw_node_frame(
			node,
			center,
			border_color,
			node_id == selected_node_id or node_id == hovered_node_id,
			focused_node_ids.has(node_id)
		)
		_draw_node_warning_marker(node_state, center)
		_draw_node_validation_marker(node_id, center)
		_draw_node_activity_progress(node, center, display_simulation.tick_index > 0)
		var visible_glyph := _visible_node_active_glyph(node)
		if visible_glyph != null:
			_draw_mini_glyph(visible_glyph, center + Vector2(0, 3), node_glyph_draw_scale(visible_glyph))
		elif cached_node_output_glyphs.has(node_id):
			var predicted_glyph: GlyphModel = cached_node_output_glyphs[node_id]
			_draw_mini_glyph(
				predicted_glyph,
				center + Vector2(0, 3),
				node_glyph_draw_scale(predicted_glyph),
				0.82
			)
		else:
			var source_glyph := source_glyph_for_node(node_id)
			if source_glyph != null:
				_draw_mini_glyph(source_glyph, center + Vector2(0, 3), 1.55)
		if node_id == hovered_node_glyph_id:
			draw_arc(center + Vector2(0, 3), 18.0, 0.0, TAU, 28, Color(GLYPH_COLOR, 0.72), 2.0, true)
		_draw_node_input_glyphs(node, center)
		_draw_ports(node, center)
		_draw_node_focus_marker(node, center, node_focus_marker_kind(node_id, route_start_id))


func persistent_node_label_count() -> int:
	return 0


func _draw_blocked_placement() -> void:
	var half_size := NODE_HALF_SIZE + Vector2(7, 7)
	var rect := Rect2(blocked_placement_position - half_size, half_size * 2.0)
	draw_rect(rect, Color(WARNING_COLOR, 0.08), true)
	draw_dashed_line(rect.position, rect.end, Color(WARNING_COLOR, 0.75), 2.0, 7.0)
	draw_dashed_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Color(WARNING_COLOR, 0.75), 2.0, 7.0)
	draw_rect(rect, Color(WARNING_COLOR, 0.72), false, 2.0)


func warning_marker_symbol(flow_state: StringName) -> StringName:
	match flow_state:
		&"output_blocked": return &"cross"
		&"material_shortage": return &"half_empty"
		&"buffer_full": return &"stop"
	return &""


func _draw_node_warning_marker(flow_state: StringName, center: Vector2) -> void:
	var symbol := warning_marker_symbol(flow_state)
	if symbol == &"":
		return
	var badge_center := center + Vector2(34, -20)
	var color := WARNING_COLOR if symbol == &"cross" else WAITING_COLOR
	draw_circle(badge_center, 8.0, Color(0.025, 0.045, 0.068, 0.96))
	draw_arc(badge_center, 8.0, 0.0, TAU, 20, color, 1.6, true)
	if symbol == &"cross":
		draw_line(badge_center + Vector2(-4, -4), badge_center + Vector2(4, 4), color, 1.6, true)
		draw_line(badge_center + Vector2(-4, 4), badge_center + Vector2(4, -4), color, 1.6, true)
	else:
		draw_arc(badge_center + Vector2(-2.5, 0), 3.0, 0.0, TAU, 14, color, 1.3, true)
		draw_arc(badge_center + Vector2(3.5, 0), 3.0, 0.0, TAU, 14, Color(color, 0.28), 1.3, true)


func _draw_line_blocked_marker(center: Vector2) -> void:
	draw_circle(center, 8.0, Color(0.025, 0.045, 0.068, 0.96))
	draw_line(center + Vector2(-3, -5), center + Vector2(-3, 5), WARNING_COLOR, 2.0, true)
	draw_line(center + Vector2(3, -5), center + Vector2(3, 5), WARNING_COLOR, 2.0, true)


func flow_warning_badge_at(at_position: Vector2) -> bool:
	return not interaction_enabled and flow_warning_message != "" and at_position.distance_to(Vector2(28, size.y - 18)) <= 18.0


func _draw_flow_warning_badge() -> void:
	var center := Vector2(28, size.y - 18)
	var points := PackedVector2Array([
		center + Vector2(0, -12), center + Vector2(11, 9), center + Vector2(-11, 9),
	])
	draw_colored_polygon(points, Color(WARNING_COLOR, 0.9))
	draw_line(center + Vector2(0, -5), center + Vector2(0, 3), Color.WHITE, 2.0, true)
	draw_circle(center + Vector2(0, 6), 1.5, Color.WHITE)
	var warning_count := maxi(simulation.flow_diagnostics().size(), 1)
	draw_string(ThemeDB.fallback_font, center + Vector2(13, 5), str(warning_count), HORIZONTAL_ALIGNMENT_LEFT, 22.0, 11, WARNING_COLOR)


func connection_feedback_kind() -> StringName:
	if connection_message == "":
		return &"none"
	if "失敗" in connection_message or "できません" in connection_message or "破損" in connection_message:
		return &"error"
	if "選択してください" in connection_message:
		return &"pending"
	return &"success"


func _connection_feedback_center() -> Vector2:
	return Vector2(28, 76 if editing else 27)


func connection_feedback_badge_at(at_position: Vector2) -> bool:
	return connection_message != "" and at_position.distance_to(_connection_feedback_center()) <= 16.0


func _draw_connection_feedback_badge() -> void:
	var center := _connection_feedback_center()
	var kind := connection_feedback_kind()
	var color := WARNING_COLOR if kind == &"error" else (WAITING_COLOR if kind == &"pending" else MATCH_COLOR)
	draw_circle(center, 10.0, Color(0.025, 0.045, 0.068, 0.96))
	draw_arc(center, 10.0, 0.0, TAU, 24, color, 1.8, true)
	if kind == &"error":
		draw_line(center + Vector2(-4, -4), center + Vector2(4, 4), color, 1.8, true)
		draw_line(center + Vector2(-4, 4), center + Vector2(4, -4), color, 1.8, true)
	elif kind == &"pending":
		draw_circle(center + Vector2(-4, 0), 3.0, color)
		draw_arc(center + Vector2(5, 0), 4.0, 0.0, TAU, 16, color, 1.4, true)
		draw_line(center, center + Vector2(2, 0), color, 1.4, true)
	else:
		draw_line(center + Vector2(-5, 0), center + Vector2(-1, 4), color, 2.0, true)
		draw_line(center + Vector2(-1, 4), center + Vector2(6, -5), color, 2.0, true)


func _draw_production_summary() -> void:
	var clock_center := Vector2(size.x - 278.0, 28.0)
	draw_arc(clock_center, 9.0, 0.0, TAU, 20, Color(0.4, 0.62, 0.76, 0.78), 1.5, true)
	draw_line(clock_center, clock_center + Vector2(0, -5), Color(0.58, 0.78, 0.92), 1.5, true)
	draw_line(clock_center, clock_center + Vector2(4, 2), Color(0.58, 0.78, 0.92), 1.5, true)
	var recipe_by_unit := {}
	for recipe in MvpContent.recipes():
		recipe_by_unit[recipe.unit_id] = recipe.glyph
	var unit_order: Array[StringName] = [&"scout", &"sentinel", &"golem"]
	for index in unit_order.size():
		var unit_id := unit_order[index]
		var center := production_summary_center(index)
		var glyph: GlyphModel = recipe_by_unit.get(unit_id)
		var is_goal := production_summary_is_goal(unit_id)
		draw_circle(center, 18.0, Color(0.025, 0.055, 0.085, 0.94))
		draw_arc(
			center,
			18.0,
			0.0,
			TAU,
			28,
			MATCH_COLOR if is_goal else Color(0.3, 0.56, 0.74, 0.68),
			2.2 if is_goal else 1.0,
			true
		)
		if GlyphPainterModel.can_draw(glyph):
			var scale := 1.3 if glyph.combine_children.is_empty() else 1.15
			GlyphPainterModel.draw_glyph(self, glyph, center, scale)
		if production_comparison_active:
			_draw_production_comparison(unit_id, center)
		else:
			_draw_production_count_badge(
				center + Vector2(14, 12),
				int(cached_production_counts.get(unit_id, 0)),
				Color(0.38, 0.9, 0.68),
				false
			)
			_draw_production_timeline(
				center,
				production_event_offsets(unit_id),
				31.0,
				false,
				true
			)
	if _should_draw_production_discard_badge():
		_draw_production_discard_badge()


func _should_draw_production_discard_badge() -> bool:
	if production_comparison_active:
		var difference := production_discard_difference_state()
		if difference.get("state", &"invalid") == &"invalid":
			return int(difference.get("before", 0)) > 0
		return int(difference.get("before", 0)) > 0 or int(difference.get("after", 0)) > 0
	return cached_production_valid and cached_production_discarded > 0


func _draw_production_discard_badge() -> void:
	var warning_center := Vector2(size.x - 18.0, 28.0)
	draw_circle(warning_center, 9.0, WARNING_COLOR)
	draw_line(warning_center + Vector2(-4, -4), warning_center + Vector2(4, 4), Color.WHITE, 1.8, true)
	draw_line(warning_center + Vector2(-4, 4), warning_center + Vector2(4, -4), Color.WHITE, 1.8, true)
	var count_center := Vector2(size.x - 36.0, 28.0)
	if not production_comparison_active:
		_draw_production_count_badge(count_center, cached_production_discarded, WARNING_COLOR, false)
		return
	var difference := production_discard_difference_state()
	var before := int(difference.get("before", 0))
	var state: StringName = difference.get("state", &"invalid")
	if state == &"unchanged":
		_draw_production_count_badge(count_center, int(difference.get("after", 0)), WARNING_COLOR, false)
		return
	var before_center := count_center + Vector2(0, -12)
	var after_center := count_center + Vector2(0, 12)
	_draw_production_count_badge(before_center, before, PRODUCTION_COMPARISON_COLOR, true)
	if state == &"invalid":
		_draw_production_unknown_badge(after_center)
		return
	var after := int(difference.get("after", 0))
	var change_color := PRODUCTION_INCREASE_COLOR if state == &"increase" else PRODUCTION_DECREASE_COLOR
	_draw_production_count_badge(after_center, after, change_color, false)
	_draw_production_change_symbol(count_center, state)


func _draw_production_comparison(unit_id: StringName, center: Vector2) -> void:
	var difference := production_difference_state(unit_id)
	var before_center := center + Vector2(-14, 12)
	var after_center := center + Vector2(14, 12)
	var change_center := center + Vector2(0, 12)
	_draw_production_count_badge(
		before_center,
		int(difference.get("before", 0)),
		PRODUCTION_COMPARISON_COLOR,
		true
	)
	var validity: StringName = difference.get("validity", &"invalid")
	if validity == &"invalid":
		_draw_production_timeline(
			center,
			production_event_offsets(unit_id, true),
			29.0,
			true,
			true
		)
		_draw_production_unknown_badge(after_center)
		_draw_production_timeline(center, PackedInt32Array(), 38.0, false, false)
		return
	var count_state: StringName = difference.get("count_state", &"unchanged")
	var timing_state: StringName = difference.get("timing_state", &"unchanged")
	var change_color := PRODUCTION_COMPARISON_COLOR
	if count_state == &"increase":
		change_color = PRODUCTION_INCREASE_COLOR
	elif count_state == &"decrease":
		change_color = PRODUCTION_DECREASE_COLOR
	_draw_production_count_badge(
		after_center,
		int(difference.get("after", 0)),
		change_color,
		false
	)
	_draw_production_change_symbol(change_center, count_state)
	if count_state == &"unchanged" and timing_state == &"unchanged":
		_draw_production_timeline(center, production_event_offsets(unit_id), 34.0, false, true)
	else:
		_draw_production_timeline(
			center,
			production_event_offsets(unit_id, true),
			29.0,
			true,
			true
		)
		_draw_production_timeline(center, production_event_offsets(unit_id), 38.0, false, true)
		if count_state == &"unchanged":
			_draw_production_timing_change_symbol(
				center + Vector2(PRODUCTION_TIMELINE_WIDTH * 0.5 + 5.0, 33.5),
				timing_state
			)


func _draw_production_count_badge(center: Vector2, count: int, color: Color, is_baseline: bool) -> void:
	var radius := 7.5 if is_baseline else 8.5
	draw_circle(center, radius, Color(0.02, 0.055, 0.075, 0.76 if is_baseline else 0.96))
	draw_arc(center, radius, 0.0, TAU, 20, Color(color, 0.62 if is_baseline else 1.0), 1.0, true)
	var font_size := 9 if abs(count) >= 10 else 10
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-radius, 3.5),
		str(count),
		HORIZONTAL_ALIGNMENT_CENTER,
		radius * 2.0,
		font_size,
		Color(color, 0.72 if is_baseline else 1.0)
	)


func _draw_production_unknown_badge(center: Vector2) -> void:
	draw_circle(center, 8.5, Color(0.06, 0.035, 0.04, 0.96))
	for segment in 8:
		var start_angle := float(segment) * TAU / 8.0
		draw_arc(center, 8.5, start_angle, start_angle + TAU / 16.0, 3, WARNING_COLOR, 1.0, true)
	draw_line(center + Vector2(-3, -3), center + Vector2(3, 3), WARNING_COLOR, 1.5, true)
	draw_line(center + Vector2(-3, 3), center + Vector2(3, -3), WARNING_COLOR, 1.5, true)


func _draw_production_change_symbol(center: Vector2, count_state: StringName) -> void:
	if count_state == &"increase":
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0, -4), center + Vector2(-3, 2), center + Vector2(3, 2),
		]), PRODUCTION_INCREASE_COLOR)
	elif count_state == &"decrease":
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0, 4), center + Vector2(-3, -2), center + Vector2(3, -2),
		]), PRODUCTION_DECREASE_COLOR)
	elif count_state == &"unchanged":
		draw_line(center + Vector2(-3, -1.7), center + Vector2(3, -1.7), PRODUCTION_COMPARISON_COLOR, 1.3, true)
		draw_line(center + Vector2(-3, 1.7), center + Vector2(3, 1.7), PRODUCTION_COMPARISON_COLOR, 1.3, true)


func _draw_production_timing_change_symbol(center: Vector2, timing_state: StringName) -> void:
	if timing_state == &"earlier":
		draw_line(center + Vector2(2.5, -4), center + Vector2(-2.5, 0), PRODUCTION_COMPARISON_COLOR, 1.5, true)
		draw_line(center + Vector2(-2.5, 0), center + Vector2(2.5, 4), PRODUCTION_COMPARISON_COLOR, 1.5, true)
	elif timing_state == &"later":
		draw_line(center + Vector2(-2.5, -4), center + Vector2(2.5, 0), PRODUCTION_COMPARISON_COLOR, 1.5, true)
		draw_line(center + Vector2(2.5, 0), center + Vector2(-2.5, 4), PRODUCTION_COMPARISON_COLOR, 1.5, true)
	elif timing_state == &"reshaped":
		draw_polyline(PackedVector2Array([
			center + Vector2(-4, 1.5),
			center + Vector2(-2, -3),
			center + Vector2(0, -1.5),
			center + Vector2(2, 3),
			center + Vector2(4, 1.5),
		]), PRODUCTION_COMPARISON_COLOR, 1.5, true)


func production_event_offsets(unit_id: StringName, baseline: bool = false) -> PackedInt32Array:
	var source: Dictionary = cached_production_event_offsets
	if baseline and production_comparison_active:
		var baseline_offsets: Variant = production_comparison_baseline.get("event_offsets", {})
		if not baseline_offsets is Dictionary:
			return PackedInt32Array()
		source = baseline_offsets
	return PackedInt32Array(source.get(unit_id, PackedInt32Array()))


func _draw_production_timeline(
	center: Vector2,
	event_offsets: PackedInt32Array,
	y_offset: float,
	is_baseline: bool,
	is_valid: bool
) -> void:
	var start := center + Vector2(-PRODUCTION_TIMELINE_WIDTH * 0.5, y_offset)
	var finish := center + Vector2(PRODUCTION_TIMELINE_WIDTH * 0.5, y_offset)
	var color := Color(PRODUCTION_COMPARISON_COLOR, 0.5 if is_baseline else 0.9)
	if not is_valid:
		draw_dashed_line(start, finish, Color(WARNING_COLOR, 0.74), 1.0, 4.0)
		var invalid_center := start.lerp(finish, 0.5)
		draw_line(invalid_center + Vector2(-2.5, -2.5), invalid_center + Vector2(2.5, 2.5), WARNING_COLOR, 1.2, true)
		draw_line(invalid_center + Vector2(-2.5, 2.5), invalid_center + Vector2(2.5, -2.5), WARNING_COLOR, 1.2, true)
		return
	draw_line(start, finish, color, 1.0 if is_baseline else 1.4, true)
	draw_line(start + Vector2(0, -2), start + Vector2(0, 2), color, 1.0, true)
	draw_line(finish + Vector2(0, -2), finish + Vector2(0, 2), color, 1.0, true)
	for index in event_offsets.size():
		var ratio := clampf(float(event_offsets[index]) / float(PRODUCTION_PREVIEW_TICKS), 0.0, 1.0)
		var marker := start.lerp(finish, ratio)
		if index == 0:
			var diamond := PackedVector2Array([
				marker + Vector2(0, -3.5),
				marker + Vector2(3.5, 0),
				marker + Vector2(0, 3.5),
				marker + Vector2(-3.5, 0),
			])
			if is_baseline:
				diamond.append(diamond[0])
				draw_polyline(diamond, color, 1.0, true)
			else:
				draw_colored_polygon(diamond, color)
		else:
			draw_line(marker + Vector2(0, -2.5), marker + Vector2(0, 2.5), color, 1.0 if is_baseline else 1.4, true)


func interaction_legend_count() -> int:
	return INTERACTION_LEGEND_TOOLTIPS.size()


func interaction_legend_rect(index: int) -> Rect2:
	if index < 0 or index >= interaction_legend_count():
		return Rect2()
	return Rect2(Vector2(18.0 + index * 78.0, size.y - 33.0), Vector2(66.0, 28.0))


func interaction_legend_index_at(at_position: Vector2) -> int:
	if not interaction_enabled or dragging_node or connecting_from_node_id != &"":
		return -1
	for index in interaction_legend_count():
		if interaction_legend_rect(index).has_point(at_position):
			return index
	return -1


func interaction_legend_tooltip(index: int) -> String:
	if index < 0 or index >= interaction_legend_count():
		return ""
	return INTERACTION_LEGEND_TOOLTIPS[index]


func _draw_production_error_badge() -> void:
	var center := Vector2(size.x - 18.0, 27.0)
	draw_circle(center, 10.0, WARNING_COLOR)
	draw_line(center + Vector2(-4, -4), center + Vector2(4, 4), Color.WHITE, 1.8, true)
	draw_line(center + Vector2(-4, 4), center + Vector2(4, -4), Color.WHITE, 1.8, true)


func work_in_progress_visual_summary() -> Array[Dictionary]:
	var grouped := {}
	for entry in _work_in_progress_entries(simulation):
		var glyph: GlyphModel = entry["glyph"]
		if not GlyphPainterModel.can_draw(glyph):
			continue
		var key := glyph.canonical_serialization()
		if not grouped.has(key):
			grouped[key] = {"glyph": glyph.copy(), "count": 0}
		grouped[key]["count"] += 1
	var keys := grouped.keys()
	keys.sort()
	var result: Array[Dictionary] = []
	for key in keys:
		result.append(grouped[key])
	return result


func _draw_edit_summary() -> void:
	var pause_center := Vector2(28, 28)
	draw_circle(pause_center, 13.0, Color(0.04, 0.09, 0.14, 0.95))
	draw_arc(pause_center, 13.0, 0.0, TAU, 24, Color(0.42, 0.78, 1.0, 0.9), 1.5, true)
	draw_line(pause_center + Vector2(-4, -6), pause_center + Vector2(-4, 6), Color(0.62, 0.86, 1.0), 2.5, true)
	draw_line(pause_center + Vector2(4, -6), pause_center + Vector2(4, 6), Color(0.62, 0.86, 1.0), 2.5, true)
	var groups := work_in_progress_visual_summary()
	for index in mini(groups.size(), 6):
		var entry: Dictionary = groups[index]
		var glyph: GlyphModel = entry["glyph"]
		var center := Vector2(72.0 + index * 58.0, 28.0)
		draw_circle(center, 16.0, Color(0.025, 0.055, 0.085, 0.92))
		GlyphPainterModel.draw_glyph(self, glyph, center, 0.78 if not glyph.combine_children.is_empty() else 1.3)
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(12, 12),
			str(entry["count"]),
			HORIZONTAL_ALIGNMENT_CENTER,
			18.0,
			10,
			Color(0.76, 0.9, 1.0)
		)
	var discard_count := pending_discard_count()
	if discard_count > 0:
		var center := pending_discard_badge_center()
		var connector := pending_discard_connector()
		if not connector.is_empty():
			var start: Vector2 = connector["start"]
			var finish: Vector2 = connector["finish"]
			draw_line(start, finish, Color(WARNING_COLOR, 0.76), 1.5, true)
			draw_line(finish, finish + Vector2(-5, -3), Color(WARNING_COLOR, 0.76), 1.5, true)
			draw_line(finish, finish + Vector2(-5, 3), Color(WARNING_COLOR, 0.76), 1.5, true)
		draw_circle(center, 10.0, WARNING_COLOR)
		draw_line(center + Vector2(-4, -4), center + Vector2(4, 4), Color.WHITE, 1.8, true)
		draw_line(center + Vector2(-4, 4), center + Vector2(4, -4), Color.WHITE, 1.8, true)
		draw_string(ThemeDB.fallback_font, center + Vector2(13, 4), str(discard_count), HORIZONTAL_ALIGNMENT_LEFT, 24.0, 11, WARNING_COLOR)


func production_error_at(at_position: Vector2) -> bool:
	return interaction_enabled and not cached_production_valid and at_position.distance_to(Vector2(size.x - 18.0, 27.0)) <= 16.0


func production_discard_badge_at(at_position: Vector2) -> bool:
	return (
		interaction_enabled
		and _should_draw_production_discard_badge()
		and Rect2(Vector2(size.x - 46.0, 6.0), Vector2(44.0, 44.0)).has_point(at_position)
	)


func work_in_progress_summary_index_at(at_position: Vector2) -> int:
	if not editing:
		return -1
	var groups := work_in_progress_visual_summary()
	for index in mini(groups.size(), 6):
		if at_position.distance_to(Vector2(72.0 + index * 58.0, 28.0)) <= 22.0:
			return index
	return -1


func pending_discard_badge_center() -> Vector2:
	return Vector2(78.0 + mini(work_in_progress_visual_summary().size(), 6) * 58.0, 28.0)


func pending_discard_connector() -> Dictionary:
	if not editing or pending_discard_count() <= 0:
		return {}
	var visible_group_count := mini(work_in_progress_visual_summary().size(), 6)
	if visible_group_count <= 0:
		return {}
	var last_group_center := Vector2(72.0 + (visible_group_count - 1) * 58.0, 28.0)
	return {
		"start": last_group_center + Vector2(20, 0),
		"finish": pending_discard_badge_center() - Vector2(14, 0),
	}


func pending_discard_badge_at(at_position: Vector2) -> bool:
	return editing and pending_discard_count() > 0 and at_position.distance_to(pending_discard_badge_center()) <= 20.0


func _draw_interaction_legend() -> void:
	var y := size.y - 18.0
	var icon_color := Color(0.4, 0.68, 0.86, 0.82)
	var muted := Color(0.16, 0.28, 0.38, 0.7)
	for index in interaction_legend_count():
		var rect := interaction_legend_rect(index)
		draw_rect(rect, Color(0.025, 0.045, 0.068, 0.84), true)
		var is_hovered := index == hovered_interaction_legend_index
		draw_rect(rect, icon_color if is_hovered else muted, false, 2.2 if is_hovered else 1.0)
		if is_hovered:
			_draw_interaction_legend_hover_corners(rect, icon_color)
	var move_center := Vector2(51.0, y - 1.0)
	draw_rect(Rect2(move_center - Vector2(8, 5), Vector2(16, 10)), Color(0.08, 0.13, 0.19), true)
	draw_rect(Rect2(move_center - Vector2(8, 5), Vector2(16, 10)), icon_color, false, 1.2)
	var move_directions: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	for direction in move_directions:
		var tip: Vector2 = move_center + direction * 11.0
		draw_line(move_center + direction * 7.0, tip, icon_color, 1.4, true)
		var normal := Vector2(-direction.y, direction.x)
		draw_line(tip, tip - direction * 3.0 + normal * 2.0, icon_color, 1.2, true)
		draw_line(tip, tip - direction * 3.0 - normal * 2.0, icon_color, 1.2, true)
	var link_left := Vector2(110.0, y - 1.0)
	var link_right := Vector2(143.0, y - 1.0)
	draw_circle(link_left, 5.0, icon_color)
	draw_arc(link_right, 6.0, 0.0, TAU, 18, icon_color, 1.5, true)
	draw_line(link_left + Vector2(6, 0), link_right - Vector2(7, 0), icon_color, 1.5, true)
	draw_line(link_right - Vector2(7, 0), link_right - Vector2(11, -3), icon_color, 1.2, true)
	draw_line(link_right - Vector2(7, 0), link_right - Vector2(11, 3), icon_color, 1.2, true)
	var cut_left := Vector2(188.0, y - 1.0)
	var cut_right := Vector2(221.0, y - 1.0)
	draw_arc(cut_left, 5.0, 0.0, TAU, 18, icon_color, 1.5, true)
	draw_arc(cut_right, 5.0, 0.0, TAU, 18, icon_color, 1.5, true)
	draw_dashed_line(cut_left + Vector2(6, 0), cut_right - Vector2(6, 0), Color(0.92, 0.4, 0.34), 1.4, 3.0)
	var cut_center := cut_left.lerp(cut_right, 0.5)
	draw_line(cut_center + Vector2(-4, -4), cut_center + Vector2(4, 4), Color(0.96, 0.42, 0.36), 1.5, true)
	draw_line(cut_center + Vector2(-4, 4), cut_center + Vector2(4, -4), Color(0.96, 0.42, 0.36), 1.5, true)


func _draw_interaction_legend_hover_corners(rect: Rect2, color: Color) -> void:
	var corners := [
		{"position": rect.position, "x": 1.0, "y": 1.0},
		{"position": Vector2(rect.end.x, rect.position.y), "x": -1.0, "y": 1.0},
		{"position": Vector2(rect.position.x, rect.end.y), "x": 1.0, "y": -1.0},
		{"position": rect.end, "x": -1.0, "y": -1.0},
	]
	for corner in corners:
		var position: Vector2 = corner["position"]
		draw_line(position, position + Vector2(float(corner["x"]) * 4.0, 0), color, 2.2, true)
		draw_line(position, position + Vector2(0, float(corner["y"]) * 4.0), color, 2.2, true)


func _draw_mana_meter() -> void:
	var meter_rect := Rect2(Vector2(size.x - 276.0, 78.0), Vector2(244.0, 10.0))
	var used_ratio := mana_fill_ratio()
	var fill_color := WARNING_COLOR if mana_available() < 15 else Color(0.28, 0.66, 0.95)
	draw_rect(meter_rect, Color(0.06, 0.1, 0.15, 0.96), true)
	draw_rect(Rect2(meter_rect.position, Vector2(meter_rect.size.x * used_ratio, meter_rect.size.y)), fill_color, true)
	draw_rect(meter_rect, Color(0.38, 0.58, 0.72, 0.72), false, 1.0)
	draw_string(
		ThemeDB.fallback_font,
		meter_rect.position + Vector2(-46, 9),
		"◆",
		HORIZONTAL_ALIGNMENT_CENTER,
		36.0,
		12,
		fill_color
	)
	draw_string(
		ThemeDB.fallback_font,
		meter_rect.position + Vector2(meter_rect.size.x - 52.0, 9),
		"%d/%d" % [mana_used(), MvpContent.FACTORY_MANA_MAX],
		HORIZONTAL_ALIGNMENT_CENTER,
		52.0,
		10,
		Color(0.84, 0.92, 1.0)
	)
func node_frame_kind(node_id: StringName) -> StringName:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.nodes.has(node_id):
		return &"missing"
	match display_simulation.nodes[node_id].kind:
		FactoryNodeModel.NodeKind.SOURCE:
			return &"source_hex"
		FactoryNodeModel.NodeKind.COMBINER:
			return &"combine_hex"
		FactoryNodeModel.NodeKind.SUMMONER:
			return &"summon_circle"
		_:
			return &"processor_chamfer"


func node_edit_state(node_id: StringName) -> StringName:
	if not editing or preview_simulation == null or not preview_simulation.nodes.has(node_id):
		return &"unchanged"
	if not simulation.nodes.has(node_id):
		return &"added"
	var preview_node: FactoryNodeModel = preview_simulation.nodes[node_id]
	var committed_node: FactoryNodeModel = simulation.nodes[node_id]
	var preview_position: Vector2 = preview_node_positions.get(node_id, Vector2.ZERO)
	var committed_position: Vector2 = node_positions.get(node_id, Vector2.ZERO)
	if (
		preview_node.kind != committed_node.kind
		or preview_node.config != committed_node.config
		or not preview_position.is_equal_approx(committed_position)
	):
		return &"changed"
	return &"unchanged"


func removed_edit_node_ids() -> Array:
	var result: Array = []
	if not editing or preview_simulation == null:
		return result
	for node_id in simulation.nodes:
		if not preview_simulation.nodes.has(node_id):
			result.append(node_id)
	result.sort()
	return result


func line_edit_state(line_id: StringName) -> StringName:
	if not editing or preview_simulation == null or not preview_simulation.lines.has(line_id):
		return &"unchanged"
	if not simulation.lines.has(line_id):
		return &"added"
	var preview_line: FactoryLineModel = preview_simulation.lines[line_id]
	var committed_line: FactoryLineModel = simulation.lines[line_id]
	if (
		preview_line.from_node_id != committed_line.from_node_id
		or preview_line.to_node_id != committed_line.to_node_id
		or preview_line.to_port != committed_line.to_port
		or preview_line.travel_ticks != committed_line.travel_ticks
	):
		return &"changed"
	return &"unchanged"


func removed_edit_line_ids() -> Array:
	var result: Array = []
	if not editing or preview_simulation == null:
		return result
	for line_id in simulation.lines:
		if not preview_simulation.lines.has(line_id):
			result.append(line_id)
	result.sort()
	return result


func edit_difference_at(at_position: Vector2) -> StringName:
	if not editing or preview_simulation == null:
		return &""
	for node_id in preview_simulation.nodes:
		var state := node_edit_state(node_id)
		if state != &"unchanged" and at_position.distance_to(node_local_position(node_id) + Vector2(43, -31)) <= 12.0:
			return state
	for node_id in removed_edit_node_ids():
		var center := _scaled_position(node_positions.get(node_id, Vector2.ZERO)) + Vector2(43, -31)
		if at_position.distance_to(center) <= 12.0:
			return &"removed"
	for line_id in preview_simulation.lines:
		var state := line_edit_state(line_id)
		if state == &"unchanged":
			continue
		var line: FactoryLineModel = preview_simulation.lines[line_id]
		var center := _output_port_position(line.from_node_id).lerp(_input_port_position(line.to_node_id, line.to_port), 0.5) + Vector2(0, -10)
		if at_position.distance_to(center) <= 12.0:
			return state
	for line_id in removed_edit_line_ids():
		var endpoints := _committed_line_endpoints(simulation.lines[line_id])
		if endpoints.is_empty():
			continue
		var center: Vector2 = (endpoints["start"] as Vector2).lerp(endpoints["finish"], 0.5) + Vector2(0, -10)
		if at_position.distance_to(center) <= 12.0:
			return &"removed"
	return &""


func edit_difference_tooltip(state: StringName) -> String:
	return {
		&"added": "追加予定",
		&"changed": "変更予定",
		&"removed": "削除予定",
	}.get(state, "")


func _draw_line_edit_differences() -> void:
	for line_id in preview_simulation.lines:
		var state := line_edit_state(line_id)
		if state == &"unchanged":
			continue
		var line: FactoryLineModel = preview_simulation.lines[line_id]
		var start := _output_port_position(line.from_node_id)
		var finish := _input_port_position(line.to_node_id, line.to_port)
		var color := EDIT_ADDED_COLOR if state == &"added" else EDIT_CHANGED_COLOR
		_draw_edit_line(start, finish, color, state == &"changed")
		_draw_edit_state_badge(start.lerp(finish, 0.5) + Vector2(0, -10), state, color)
	for line_id in removed_edit_line_ids():
		var endpoints := _committed_line_endpoints(simulation.lines[line_id])
		if endpoints.is_empty():
			continue
		var removed_start: Vector2 = endpoints["start"]
		var removed_finish: Vector2 = endpoints["finish"]
		_draw_edit_line(removed_start, removed_finish, EDIT_REMOVED_COLOR, true)
		_draw_edit_state_badge(removed_start.lerp(removed_finish, 0.5) + Vector2(0, -10), &"removed", EDIT_REMOVED_COLOR)


func _draw_edit_line(start: Vector2, finish: Vector2, color: Color, dashed: bool) -> void:
	if dashed:
		draw_dashed_line(start, finish, color, 3.0, 9.0, true)
	else:
		draw_line(start, finish, color, 3.0, true)


func _committed_line_endpoints(line: FactoryLineModel) -> Dictionary:
	if not simulation.nodes.has(line.from_node_id) or not simulation.nodes.has(line.to_node_id):
		return {}
	if not node_positions.has(line.from_node_id) or not node_positions.has(line.to_node_id):
		return {}
	var from_node: FactoryNodeModel = simulation.nodes[line.from_node_id]
	var to_node: FactoryNodeModel = simulation.nodes[line.to_node_id]
	var from_center := _scaled_position(node_positions[line.from_node_id])
	var to_center := _scaled_position(node_positions[line.to_node_id])
	var direction := from_center.direction_to(to_center)
	var start := from_center + _port_boundary_offset(from_node, direction)
	var radial_direction := -direction
	var finish := to_center + _port_boundary_offset(to_node, radial_direction)
	if to_node.required_input_count() > 1:
		var tangent := Vector2(-radial_direction.y, radial_direction.x).normalized()
		finish += tangent * (-8.0 if line.to_port == 0 else 8.0)
	return {"start": start, "finish": finish}


func _draw_node_edit_differences() -> void:
	for node_id in preview_simulation.nodes:
		var state := node_edit_state(node_id)
		if state == &"unchanged":
			continue
		var center := node_local_position(node_id)
		var color := EDIT_ADDED_COLOR if state == &"added" else EDIT_CHANGED_COLOR
		_draw_edit_ring(center, color, state == &"changed")
		_draw_edit_state_badge(center + Vector2(43, -31), state, color)
	for node_id in removed_edit_node_ids():
		var center := _scaled_position(node_positions.get(node_id, Vector2.ZERO))
		_draw_edit_ring(center, EDIT_REMOVED_COLOR, true)
		_draw_edit_state_badge(center + Vector2(43, -31), &"removed", EDIT_REMOVED_COLOR)


func _draw_edit_ring(center: Vector2, color: Color, dashed: bool) -> void:
	if not dashed:
		draw_arc(center, 53.0, 0.0, TAU, 40, color, 2.0, true)
		return
	for segment in 16:
		var start_angle := float(segment) * TAU / 16.0
		draw_arc(center, 53.0, start_angle, start_angle + TAU / 32.0, 3, color, 2.0, true)


func _draw_edit_state_badge(center: Vector2, state: StringName, color: Color) -> void:
	draw_circle(center, 7.0, Color(PANEL_COLOR, 0.98))
	draw_arc(center, 7.0, 0.0, TAU, 20, color, 1.4, true)
	if state == &"added":
		draw_line(center + Vector2(-3.5, 0), center + Vector2(3.5, 0), color, 1.6, true)
		draw_line(center + Vector2(0, -3.5), center + Vector2(0, 3.5), color, 1.6, true)
	elif state == &"changed":
		var diamond := PackedVector2Array([
			center + Vector2(0, -4), center + Vector2(4, 0),
			center + Vector2(0, 4), center + Vector2(-4, 0), center + Vector2(0, -4),
		])
		draw_polyline(diamond, color, 1.4, true)
	else:
		draw_line(center + Vector2(-3, -3), center + Vector2(3, 3), color, 1.6, true)
		draw_line(center + Vector2(-3, 3), center + Vector2(3, -3), color, 1.6, true)


func _draw_node_frame(
	node: FactoryNodeModel,
	center: Vector2,
	border_color: Color,
	selected: bool,
	route_focused: bool = false
) -> void:
	var stroke := 3.0 if selected else 2.0
	if node.kind == FactoryNodeModel.NodeKind.SUMMONER:
		if route_focused:
			draw_arc(center, 43.0, 0.0, TAU, 36, Color(0.34, 0.76, 1.0, 0.2), 7.0, true)
		draw_circle(center, 40.0, NODE_COLOR)
		draw_arc(center, 40.0, 0.0, TAU, 36, border_color, stroke, true)
		draw_arc(center, 31.0, 0.0, TAU, 32, Color(border_color, 0.35), 1.0, true)
		return
	var points := PackedVector2Array()
	if node.kind == FactoryNodeModel.NodeKind.SOURCE:
		points = PackedVector2Array([
			center + Vector2(-38, -30), center + Vector2(38, -30), center + Vector2(48, 0),
			center + Vector2(38, 30), center + Vector2(-38, 30), center + Vector2(-48, 0),
		])
	elif node.kind == FactoryNodeModel.NodeKind.COMBINER:
		points = PackedVector2Array([
			center + Vector2(-32, -30), center + Vector2(32, -30), center + Vector2(48, 0),
			center + Vector2(32, 30), center + Vector2(-32, 30), center + Vector2(-48, 0),
		])
	else:
		points = PackedVector2Array([
			center + Vector2(-38, -30), center + Vector2(38, -30), center + Vector2(48, -20),
			center + Vector2(48, 20), center + Vector2(38, 30), center + Vector2(-38, 30),
			center + Vector2(-48, 20), center + Vector2(-48, -20),
		])
	if route_focused:
		var halo := points.duplicate()
		halo.append(points[0])
		draw_polyline(halo, Color(0.34, 0.76, 1.0, 0.2), 7.0, true)
	draw_colored_polygon(points, NODE_COLOR)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, border_color, stroke, true)
	_draw_node_role_mark(node, center)


func focused_route_start_node_id() -> StringName:
	if connecting_from_node_id != &"":
		return &""
	var display_simulation := _display_simulation()
	if display_simulation == null:
		return &""
	for candidate: StringName in [
		hovered_node_glyph_id,
		hovered_input_glyph_node_id,
		hovered_output_node_id,
		hovered_input_node_id,
		hovered_node_id,
	]:
		if candidate != &"" and display_simulation.nodes.has(candidate):
			return candidate
	if hovered_line_id != &"" and display_simulation.lines.has(hovered_line_id):
		var hovered_line: FactoryLineModel = display_simulation.lines[hovered_line_id]
		if (
			display_simulation.nodes.has(hovered_line.from_node_id)
			and display_simulation.nodes.has(hovered_line.to_node_id)
		):
			return hovered_line.from_node_id
	if selected_node_id != &"" and display_simulation.nodes.has(selected_node_id):
		return selected_node_id
	return &""


func focused_downstream_route(
	start_node_id: StringName,
	source_simulation: FactorySimulation = null
) -> Dictionary:
	var display_simulation := source_simulation if source_simulation != null else _display_simulation()
	if display_simulation == null or start_node_id == &"" or not display_simulation.nodes.has(start_node_id):
		return {"start_node_id": &"", "node_ids": [], "line_ids": [], "reaches_summoner": false}
	var sorted_line_ids := display_simulation.lines.keys()
	sorted_line_ids.sort_custom(_stable_id_less)
	var node_set := {}
	node_set[start_node_id] = true
	var line_set := {}
	var pending: Array[StringName] = [start_node_id]
	var reaches_summoner: bool = (
		display_simulation.nodes[start_node_id].kind == FactoryNodeModel.NodeKind.SUMMONER
	)
	while not pending.is_empty():
		var current_node_id: StringName = pending.pop_front()
		for line_id in sorted_line_ids:
			var line: FactoryLineModel = display_simulation.lines[line_id]
			if line.from_node_id != current_node_id:
				continue
			line_set[line_id] = true
			if node_set.has(line.to_node_id):
				continue
			node_set[line.to_node_id] = true
			pending.append(line.to_node_id)
			if (
				display_simulation.nodes.has(line.to_node_id)
				and display_simulation.nodes[line.to_node_id].kind == FactoryNodeModel.NodeKind.SUMMONER
			):
				reaches_summoner = true
	var node_ids: Array[StringName] = []
	for node_id in node_set:
		node_ids.append(node_id)
	node_ids.sort_custom(_stable_id_less)
	var line_ids: Array[StringName] = []
	for line_id in line_set:
		line_ids.append(line_id)
	line_ids.sort_custom(_stable_id_less)
	return {
		"start_node_id": start_node_id,
		"node_ids": node_ids,
		"line_ids": line_ids,
		"reaches_summoner": reaches_summoner,
	}


func _stable_id_less(left, right) -> bool:
	return String(left) < String(right)


func node_focus_marker_kind(node_id: StringName, route_start_id: StringName = &"") -> StringName:
	if node_id == selected_node_id:
		return &"selected"
	var focus_start := route_start_id if route_start_id != &"" else focused_route_start_node_id()
	return &"hover" if node_id == focus_start else &"none"


func _draw_node_focus_marker(
	node: FactoryNodeModel,
	center: Vector2,
	marker_kind: StringName
) -> void:
	if marker_kind == &"none":
		return
	var marker_center := center + Vector2(0, -47 if node.kind == FactoryNodeModel.NodeKind.SUMMONER else -38)
	var marker_color := SELECTED_COLOR if marker_kind == &"selected" else Color(0.56, 0.86, 1.0)
	var diamond := PackedVector2Array([
		marker_center + Vector2(0, -4.5),
		marker_center + Vector2(4.5, 0),
		marker_center + Vector2(0, 4.5),
		marker_center + Vector2(-4.5, 0),
	])
	if marker_kind == &"selected":
		draw_colored_polygon(diamond, marker_color)
	else:
		diamond.append(diamond[0])
		draw_polyline(diamond, marker_color, 1.5, true)


func _draw_node_role_mark(node: FactoryNodeModel, center: Vector2) -> void:
	var mark_center := center + Vector2(-34, -16)
	var role_state := _node_role_mark_state(node)
	match role_state.get("kind", &"none"):
		&"rotator":
			_draw_rotator_role_mark(mark_center, role_state)
		&"colorizer":
			_draw_colorizer_role_mark(mark_center, role_state)
		&"combiner":
			_draw_combiner_role_mark(mark_center, role_state)


func node_role_mark_state(node_id: StringName) -> Dictionary:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.nodes.has(node_id):
		return {"kind": &"none", "valid": false}
	return _node_role_mark_state(display_simulation.nodes[node_id])


func _node_role_mark_state(node: FactoryNodeModel) -> Dictionary:
	match node.kind:
		FactoryNodeModel.NodeKind.ROTATOR:
			var steps := int(node.config.get("steps", 0))
			var direction := rotator_role_direction(steps)
			return {
				"kind": &"rotator",
				"valid": direction != Vector2i.ZERO,
				"steps": steps,
				"direction": direction,
			}
		FactoryNodeModel.NodeKind.COLORIZER:
			var color_id := StringName(node.config.get("color_id", ""))
			var pattern := colorizer_role_pattern(color_id)
			return {
				"kind": &"colorizer",
				"valid": pattern != &"invalid",
				"color_id": color_id,
				"pattern": pattern,
			}
		FactoryNodeModel.NodeKind.COMBINER:
			var connection_mode := StringName(
				node.config.get("connection_mode", GlyphModel.CONNECTION_RADIAL)
			)
			return {
				"kind": &"combiner",
				"valid": connection_mode in COMBINE_OPTION_IDS,
				"connection_mode": connection_mode,
			}
	return {"kind": &"none", "valid": true}


func rotator_role_direction(steps: int) -> Vector2i:
	match steps:
		1:
			return Vector2i.RIGHT
		2:
			return Vector2i.DOWN
		3:
			return Vector2i.LEFT
	return Vector2i.ZERO


func colorizer_role_pattern(color_id: StringName) -> StringName:
	match color_id:
		&"blue":
			return &"filled"
		&"red":
			return &"striped"
		&"white":
			return &"hollow"
	return &"invalid"


func _draw_combiner_role_mark(center: Vector2, role_state: Dictionary) -> void:
	var color := Color(0.5, 0.76, 0.94, 0.84)
	if not role_state.get("valid", false):
		for segment in 4:
			var start_angle := float(segment) * TAU / 4.0
			draw_arc(center, 6.0, start_angle, start_angle + TAU / 8.0, 4, color, 1.4, true)
		return
	match StringName(role_state.get("connection_mode", &"")):
		GlyphModel.CONNECTION_RADIAL:
			draw_circle(center, 1.7, color)
			for endpoint in [center + Vector2(-6, -4), center + Vector2(6, -4), center + Vector2(0, 7)]:
				draw_line(center, endpoint, color, 1.4, true)
				draw_circle(endpoint, 1.6, color)
		GlyphModel.CONNECTION_PAIRWISE:
			var left := center + Vector2(-4, 0)
			var right := center + Vector2(4, 0)
			draw_arc(left, 3.2, 0.0, TAU, 14, color, 1.3, true)
			draw_arc(right, 3.2, 0.0, TAU, 14, color, 1.3, true)
			draw_line(left + Vector2(3.2, 0), right - Vector2(3.2, 0), color, 1.5, true)
		GlyphModel.CONNECTION_SIMPLE:
			draw_arc(center + Vector2(-3, 0), 4.5, 0.0, TAU, 16, color, 1.3, true)
			draw_arc(center + Vector2(3, 0), 4.5, 0.0, TAU, 16, color, 1.3, true)


func _draw_rotator_role_mark(center: Vector2, role_state: Dictionary) -> void:
	var color := Color(0.5, 0.76, 0.94, 0.84)
	if not role_state.get("valid", false):
		for segment in 4:
			var start_angle := float(segment) * TAU / 4.0
			draw_arc(center, 6.0, start_angle, start_angle + TAU / 8.0, 4, color, 1.4, true)
		return
	var direction := Vector2(role_state["direction"])
	var endpoint := center + direction * 7.0
	var normal := Vector2(-direction.y, direction.x)
	draw_circle(center, 1.8, color)
	draw_line(center, endpoint, color, 1.8, true)
	draw_line(endpoint, endpoint - direction * 3.2 + normal * 2.2, color, 1.6, true)
	draw_line(endpoint, endpoint - direction * 3.2 - normal * 2.2, color, 1.6, true)


func _draw_colorizer_role_mark(center: Vector2, role_state: Dictionary) -> void:
	var outline := Color(0.58, 0.8, 0.96, 0.82)
	var pattern: StringName = role_state.get("pattern", &"invalid")
	if pattern == &"invalid":
		for segment in 4:
			var start_angle := float(segment) * TAU / 4.0
			draw_arc(center, 5.5, start_angle, start_angle + TAU / 8.0, 4, outline, 1.3, true)
		return
	var color_id: StringName = role_state["color_id"]
	var fill := GlyphPainterModel.component_color(color_id)
	if pattern == &"hollow":
		draw_circle(center, 5.5, Color(0.055, 0.09, 0.13, 0.96))
		draw_arc(center, 5.5, 0.0, TAU, 18, fill, 1.4, true)
		draw_arc(center, 2.7, 0.0, TAU, 14, fill, 1.1, true)
		return
	draw_circle(center, 5.0, fill)
	draw_arc(center, 5.5, 0.0, TAU, 18, outline, 1.1, true)
	if pattern == &"striped":
		var stripe_color := Color(0.04, 0.07, 0.1, 0.9)
		draw_line(center + Vector2(-4, 1), center + Vector2(1, -4), stripe_color, 1.2, true)
		draw_line(center + Vector2(-1, 4), center + Vector2(4, -1), stripe_color, 1.2, true)


func node_activity_progress(node_id: StringName) -> float:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.nodes.has(node_id):
		return -1.0
	return _node_activity_progress(display_simulation.nodes[node_id])


func _node_activity_progress(node: FactoryNodeModel) -> float:
	if node.kind == FactoryNodeModel.NodeKind.SUMMONER:
		return -1.0
	if node.output_buffer != null:
		return 1.0
	if node.kind == FactoryNodeModel.NodeKind.SOURCE:
		var interval := maxi(int(node.config.get("interval_ticks", 1)), 1)
		return clampf(float(node.source_timer) / float(interval), 0.0, 1.0)
	if node.processing_glyph == null:
		return -1.0
	var processing_ticks := maxi(int(node.config.get("processing_ticks", 1)), 1)
	return clampf(
		1.0 - float(node.remaining_processing_ticks) / float(processing_ticks),
		0.0,
		1.0
	)


func _draw_node_activity_progress(
	node: FactoryNodeModel,
	center: Vector2,
	show_empty: bool
) -> void:
	var progress := _node_activity_progress(node)
	if progress < 0.0 or (progress == 0.0 and not show_empty):
		return
	var start := center + Vector2(-34.0, -22.0)
	var finish := center + Vector2(34.0, -22.0)
	draw_line(start, finish, Color(0.02, 0.035, 0.055, 0.95), 3.0, true)
	if progress > 0.0:
		draw_line(start, start.lerp(finish, progress), GLYPH_COLOR, 3.0, true)


func visible_glyph_for_node(node_id: StringName) -> GlyphModel:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.nodes.has(node_id):
		return null
	return _visible_node_glyph(display_simulation.nodes[node_id])


func display_glyph_for_node(node_id: StringName) -> GlyphModel:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.nodes.has(node_id):
		return null
	var active := _visible_node_active_glyph(display_simulation.nodes[node_id])
	if active != null:
		return active
	var predicted: GlyphModel = cached_node_output_glyphs.get(node_id)
	if GlyphPainterModel.can_draw(predicted):
		return predicted
	return source_glyph_for_node(node_id)


func node_glyph_display_state(node_id: StringName) -> StringName:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.nodes.has(node_id):
		return &"empty"
	if _visible_node_active_glyph(display_simulation.nodes[node_id]) != null:
		return &"actual"
	if GlyphPainterModel.can_draw(cached_node_output_glyphs.get(node_id)):
		return &"predicted"
	if source_glyph_for_node(node_id) != null:
		return &"source"
	return &"empty"


func node_glyph_at(at_position: Vector2) -> StringName:
	var display_simulation := _display_simulation()
	if display_simulation == null:
		return &""
	for node_id in _front_to_back_node_ids(display_simulation):
		if display_glyph_for_node(node_id) == null:
			continue
		if at_position.distance_to(node_local_position(node_id) + Vector2(0, 3)) <= 18.0:
			return node_id
	return &""


func predicted_output_glyph_for_node(node_id: StringName) -> GlyphModel:
	return cached_node_output_glyphs.get(node_id)


func final_summoner_candidate_glyph() -> GlyphModel:
	return final_summoner_candidate()["glyph"]


func final_summoner_candidate() -> Dictionary:
	return _final_summoner_candidate_for(_display_simulation(), cached_node_output_glyphs)


func _final_summoner_candidate_for(source_simulation: FactorySimulation, predicted_outputs: Dictionary) -> Dictionary:
	if source_simulation == null:
		return {"glyph": null, "state": &"missing"}
	var summoner_ids: Array = []
	for node_id in source_simulation.nodes:
		if source_simulation.nodes[node_id].kind == FactoryNodeModel.NodeKind.SUMMONER:
			summoner_ids.append(node_id)
	summoner_ids.sort()
	for summoner_id in summoner_ids:
		var summoner: FactoryNodeModel = source_simulation.nodes[summoner_id]
		for input_glyph in summoner.input_buffers:
			if GlyphPainterModel.can_draw(input_glyph):
				return {"glyph": input_glyph.copy(), "state": &"actual"}
		var line_ids := source_simulation.lines.keys()
		line_ids.sort()
		for line_id in line_ids:
			var line: FactoryLineModel = source_simulation.lines[line_id]
			if line.to_node_id != summoner_id:
				continue
			if GlyphPainterModel.can_draw(line.payload):
				return {"glyph": line.payload.copy(), "state": &"actual"}
			if predicted_outputs.has(line.from_node_id):
				var predicted = predicted_outputs[line.from_node_id]
				if GlyphPainterModel.can_draw(predicted):
					return {"glyph": predicted.copy(), "state": &"predicted"}
	return {"glyph": null, "state": &"missing"}


func source_glyph_for_node(node_id: StringName) -> GlyphModel:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.nodes.has(node_id):
		return null
	var node: FactoryNodeModel = display_simulation.nodes[node_id]
	if node.kind != FactoryNodeModel.NodeKind.SOURCE:
		return null
	var meaning_glyph_id := StringName(node.config.get("meaning_glyph_id", ""))
	if meaning_glyph_id != &"":
		return MeaningGlyphsModel.glyph(meaning_glyph_id)
	var primitive_id := StringName(node.config.get("primitive_id", ""))
	if primitive_id == &"":
		return null
	return GlyphModel.new([GlyphComponentModel.new(primitive_id)])


func _get_tooltip(at_position: Vector2) -> String:
	tooltip_glyph = null
	tooltip_target_glyph = null
	tooltip_title = ""
	tooltip_context = ""
	tooltip_comparison_name = ""
	tooltip_candidate_label = "工場出力"
	if connecting_from_node_id != &"":
		var connection_input := _input_port_at(at_position)
		if not connection_input.is_empty():
			return connection_target_tooltip(
				connection_input.get("node_id", &""),
				int(connection_input.get("port", -1))
			)
	var validation_fault := validation_fault_at(at_position)
	if not validation_fault.is_empty():
		return validation_fault
	var edit_difference := edit_difference_at(at_position)
	if edit_difference != &"":
		return edit_difference_tooltip(edit_difference)
	if connection_feedback_badge_at(at_position):
		return connection_message
	if flow_warning_badge_at(at_position):
		return flow_warning_message
	if pending_discard_badge_at(at_position):
		return pending_discard_notice()
	var work_index := work_in_progress_summary_index_at(at_position)
	if work_index >= 0:
		var work_entry: Dictionary = work_in_progress_visual_summary()[work_index]
		_set_glyph_tooltip(
			work_entry["glyph"],
			"時間停止 // 仕掛品",
			"工場内 %d個" % work_entry["count"]
		)
		return "glyph_preview"
	if production_error_at(at_position):
		return cached_production_preview
	if production_discard_badge_at(at_position):
		if production_comparison_active:
			var discard_difference := production_discard_difference_state()
			if discard_difference.get("state", &"invalid") == &"invalid":
				return "32秒予測 // 不一致Glyph %d → ?" % int(discard_difference.get("before", 0))
			return "32秒予測 // 不一致Glyph %d → %d" % [
				int(discard_difference.get("before", 0)),
				int(discard_difference.get("after", 0)),
			]
		return "32秒予測 // 不一致Glyph %d個を廃棄" % cached_production_discarded
	var summary_unit := production_summary_unit_at(at_position)
	if summary_unit != &"":
		for recipe in MvpContent.recipes():
			if recipe.unit_id != summary_unit:
				continue
			var context := "生産見込み %d体 // %s" % [
				cached_production_counts.get(summary_unit, 0),
				production_timing_tooltip(production_event_offsets(summary_unit)),
			]
			if production_comparison_active:
				var difference := production_difference_state(summary_unit)
				context = (
					"旧 %d // %s\n新 ?" % [
						int(difference.get("before", 0)),
						production_timing_tooltip(production_event_offsets(summary_unit, true)),
					]
					if difference.get("validity", &"invalid") == &"invalid"
					else "旧 %d // %s\n新 %d // %s" % [
						int(difference.get("before", 0)),
						production_timing_tooltip(production_event_offsets(summary_unit, true)),
						int(difference.get("after", 0)),
						production_timing_tooltip(production_event_offsets(summary_unit)),
					]
				)
			_set_glyph_tooltip(
				recipe.glyph,
				"32秒予測 // %s" % String(MvpContent.sigil_name(recipe.id)).trim_suffix("シジル"),
				context
			)
			return "glyph_preview"
	var legend_index := interaction_legend_index_at(at_position)
	if legend_index >= 0:
		return interaction_legend_tooltip(legend_index)
	var display_simulation := _display_simulation()
	if display_simulation == null:
		return ""
	var input_hit := input_glyph_at(at_position)
	if not input_hit.is_empty():
		var input_node: FactoryNodeModel = display_simulation.nodes[input_hit["node_id"]]
		var input_context := (
			"32秒予測の入力Glyph"
			if input_hit["state"] == &"predicted"
			else "到着済み入力Glyph"
		)
		_set_comparison_tooltip(
			input_hit["glyph"],
			"%s // 入力%d" % [_node_label(input_node), input_hit["port"] + 1],
			input_context,
			"入力Glyph"
		)
		return "glyph_comparison"
	var node_id := _node_at(at_position)
	if node_id != &"":
		var node: FactoryNodeModel = display_simulation.nodes[node_id]
		var node_glyph := display_glyph_for_node(node_id)
		var node_state := node_glyph_display_state(node_id)
		var node_context: String = {
			&"actual": "設備内の現在出力Glyph",
			&"predicted": "32秒予測の出力Glyph",
			&"source": "素材Primitive",
		}.get(node_state, "")
		if node_glyph != null:
			_set_comparison_tooltip(node_glyph, _node_label(node), node_context, "設備出力")
		if tooltip_glyph == null:
			return ""
		return "glyph_comparison" if tooltip_target_glyph != null else "glyph_preview"
	for line_id in display_simulation.lines:
		var line: FactoryLineModel = display_simulation.lines[line_id]
		var line_glyph := display_glyph_for_line(line_id)
		if line_glyph == null:
			continue
		var start := _output_port_position(line.from_node_id)
		var finish := _input_port_position(line.to_node_id, line.to_port)
		var closest := Geometry2D.get_closest_point_to_segment(at_position, start, finish)
		if at_position.distance_to(closest) > 14.0:
			continue
		var from_label := _node_label(display_simulation.nodes[line.from_node_id])
		var to_label := _node_label(display_simulation.nodes[line.to_node_id])
		var context := "輸送中Glyph" if GlyphPainterModel.can_draw(line.payload) else "32秒予測の輸送Glyph"
		_set_comparison_tooltip(line_glyph, "%s → %s" % [from_label, to_label], context, "輸送Glyph")
		return "glyph_comparison"
	return ""


func production_summary_unit_at(at_position: Vector2) -> StringName:
	if not interaction_enabled or (not cached_production_valid and not production_comparison_active):
		return &""
	var unit_order: Array[StringName] = [&"scout", &"sentinel", &"golem"]
	for index in unit_order.size():
		var center := production_summary_center(index)
		if Rect2(center + Vector2(-30, -22), Vector2(64, 92)).has_point(at_position):
			return unit_order[index]
	return &""


func production_timing_tooltip(event_offsets: PackedInt32Array) -> String:
	if event_offsets.is_empty():
		return "32秒内の召喚なし"
	var first_seconds := float(event_offsets[0]) * PRODUCTION_TICK_SECONDS
	if event_offsets.size() == 1:
		return "初回 %.1f秒 // 間隔は未観測" % first_seconds
	var intervals := PackedInt32Array()
	for index in range(1, event_offsets.size()):
		intervals.append(event_offsets[index] - event_offsets[index - 1])
	var minimum := intervals[0]
	var maximum := intervals[0]
	for interval in intervals:
		minimum = mini(minimum, interval)
		maximum = maxi(maximum, interval)
	if minimum == maximum:
		var interval_seconds := float(minimum) * PRODUCTION_TICK_SECONDS
		return (
			"初回 %.1f秒 // 観測間隔 %.1f秒" % [first_seconds, interval_seconds]
			if intervals.size() == 1
			else "初回 %.1f秒 // 間隔 %.1f秒" % [first_seconds, interval_seconds]
		)
	return "初回 %.1f秒 // 間隔 %.1f–%.1f秒" % [
		first_seconds,
		float(minimum) * PRODUCTION_TICK_SECONDS,
		float(maximum) * PRODUCTION_TICK_SECONDS,
	]


func production_summary_center(index: int) -> Vector2:
	return Vector2(size.x - 220.0 + index * 72.0, 28.0)


func production_summary_is_goal(unit_id: StringName) -> bool:
	var target_recipe_id := MvpContent.recipe_id_for_plan(display_plan_id())
	for recipe in MvpContent.recipes():
		if recipe.id == target_recipe_id:
			return recipe.unit_id == unit_id
	return false


func _set_glyph_tooltip(next_glyph: GlyphModel, next_title: String, next_context: String) -> void:
	if not GlyphPainterModel.can_draw(next_glyph):
		return
	tooltip_glyph = next_glyph.copy()
	tooltip_title = next_title
	tooltip_context = next_context


func _set_comparison_tooltip(
	candidate: GlyphModel,
	next_title: String,
	next_context: String,
	next_candidate_label: String = "工場出力"
) -> bool:
	_set_glyph_tooltip(candidate, next_title, next_context)
	var target := _goal_glyph()
	if not GlyphPainterModel.can_draw(target) or tooltip_glyph == null:
		return false
	tooltip_target_glyph = target.copy()
	tooltip_comparison_name = "%s // %s" % [next_title, next_context]
	tooltip_candidate_label = next_candidate_label
	return true


func _make_custom_tooltip(for_text: String):
	if for_text == "glyph_comparison" and tooltip_target_glyph != null and tooltip_glyph != null:
		var comparison := GlyphComparisonTooltipModel.new()
		comparison.configure(tooltip_target_glyph, tooltip_glyph, tooltip_comparison_name, tooltip_candidate_label)
		return comparison
	if for_text != "glyph_preview":
		var label := Label.new()
		label.text = for_text
		label.custom_minimum_size = Vector2(360, 42)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.64))
		return label
	var preview := GlyphTooltipModel.new()
	preview.configure(tooltip_glyph, tooltip_title, tooltip_context)
	return preview


func node_glyph_draw_scale(glyph: GlyphModel) -> float:
	if glyph != null and not glyph.combine_children.is_empty():
		return 0.9
	return 1.55


func visible_glyph_for_line(line_id: StringName) -> GlyphModel:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.lines.has(line_id):
		return null
	var glyph: GlyphModel = display_simulation.lines[line_id].payload
	if glyph == null or not glyph.structure_validation_errors().is_empty():
		return null
	return glyph


func display_glyph_for_line(line_id: StringName) -> GlyphModel:
	var actual := visible_glyph_for_line(line_id)
	if actual != null:
		return actual
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.lines.has(line_id):
		return null
	var line: FactoryLineModel = display_simulation.lines[line_id]
	var predicted: GlyphModel = cached_node_output_glyphs.get(line.from_node_id)
	if not GlyphPainterModel.can_draw(predicted):
		return null
	return predicted


func predicted_glyph_for_line(line_id: StringName) -> GlyphModel:
	if visible_glyph_for_line(line_id) != null:
		return null
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.lines.has(line_id):
		return null
	var line: FactoryLineModel = display_simulation.lines[line_id]
	var predicted: GlyphModel = cached_node_output_glyphs.get(line.from_node_id)
	if not GlyphPainterModel.can_draw(predicted):
		return null
	return predicted


func line_recipe_match_state(line_id: StringName) -> StringName:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.lines.has(line_id):
		return &"missing"
	var line: FactoryLineModel = display_simulation.lines[line_id]
	if not display_simulation.nodes.has(line.to_node_id):
		return &"invalid"
	var target: FactoryNodeModel = display_simulation.nodes[line.to_node_id]
	if target.kind != FactoryNodeModel.NodeKind.SUMMONER:
		return &"not_applicable"
	if line.payload != null:
		return _recipe_match_state_for_glyph(display_simulation, line.payload)
	var predicted: GlyphModel = cached_node_output_glyphs.get(line.from_node_id)
	if not GlyphPainterModel.can_draw(predicted):
		return &"empty"
	return _recipe_match_state_for_glyph(display_simulation, predicted)


func line_goal_match_state(line_id: StringName) -> StringName:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.lines.has(line_id):
		return &"missing"
	var line: FactoryLineModel = display_simulation.lines[line_id]
	if not display_simulation.nodes.has(line.to_node_id):
		return &"invalid"
	if display_simulation.nodes[line.to_node_id].kind != FactoryNodeModel.NodeKind.SUMMONER:
		return &"not_applicable"
	var glyph: GlyphModel = line.payload
	if not GlyphPainterModel.can_draw(glyph):
		glyph = cached_node_output_glyphs.get(line.from_node_id)
	if not GlyphPainterModel.can_draw(glyph):
		return &"empty"
	var target_recipe_id := MvpContent.recipe_id_for_plan(display_plan_id())
	for recipe in MvpContent.recipes():
		if recipe.id != target_recipe_id:
			continue
		return (
			&"match"
			if recipe.glyph.canonical_serialization() == glyph.canonical_serialization()
			else &"mismatch"
		)
	return &"invalid"


func _goal_glyph() -> GlyphModel:
	var target_recipe_id := MvpContent.recipe_id_for_plan(display_plan_id())
	for recipe in MvpContent.recipes():
		if recipe.id == target_recipe_id:
			return recipe.glyph
	return null


func display_plan_id() -> StringName:
	return pending_plan_id if editing else plan_id


func input_recipe_match_state(node_id: StringName, port: int) -> StringName:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.nodes.has(node_id):
		return &"missing"
	var node: FactoryNodeModel = display_simulation.nodes[node_id]
	if node.kind != FactoryNodeModel.NodeKind.SUMMONER:
		return &"not_applicable"
	if port < 0 or port >= node.input_buffers.size():
		return &"invalid"
	if node.input_buffers[port] == null:
		return &"empty"
	return _recipe_match_state_for_glyph(display_simulation, node.input_buffers[port])


func _recipe_match_state_for_glyph(
	display_simulation: FactorySimulation,
	glyph_value
) -> StringName:
	if not glyph_value is GlyphModel:
		return &"invalid"
	var result := display_simulation.recipe_match_result(glyph_value)
	if not result["ok"]:
		return &"invalid"
	return &"match" if result["is_match"] else &"mismatch"


func recipe_match_marker_symbol(match_state: StringName) -> StringName:
	if match_state == &"match":
		return &"check"
	if match_state == &"mismatch":
		return &"cross"
	return &""


func visible_input_glyph_for_node(node_id: StringName, port: int) -> GlyphModel:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.nodes.has(node_id):
		return null
	var node: FactoryNodeModel = display_simulation.nodes[node_id]
	if port < 0 or port >= node.input_buffers.size():
		return null
	var glyph_value = node.input_buffers[port]
	if not glyph_value is GlyphModel:
		return null
	var glyph: GlyphModel = glyph_value
	if not glyph.structure_validation_errors().is_empty():
		return null
	return glyph


func predicted_input_glyph_for_node(node_id: StringName, port: int) -> GlyphModel:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.nodes.has(node_id):
		return null
	var node: FactoryNodeModel = display_simulation.nodes[node_id]
	if port < 0 or port >= node.input_buffers.size():
		return null
	var line_ids := display_simulation.lines.keys()
	line_ids.sort()
	for line_id in line_ids:
		var line: FactoryLineModel = display_simulation.lines[line_id]
		if line.to_node_id != node_id or line.to_port != port:
			continue
		var predicted: GlyphModel = cached_node_output_glyphs.get(line.from_node_id)
		if GlyphPainterModel.can_draw(predicted):
			return predicted
	return null


func input_glyph_display_state(node_id: StringName, port: int) -> StringName:
	if visible_input_glyph_for_node(node_id, port) != null:
		return &"actual"
	if predicted_input_glyph_for_node(node_id, port) != null:
		return &"predicted"
	return &"empty"


func input_glyph_center(node_id: StringName, port: int) -> Vector2:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.nodes.has(node_id):
		return Vector2(-INF, -INF)
	var node: FactoryNodeModel = display_simulation.nodes[node_id]
	if port < 0 or port >= node.input_buffers.size():
		return Vector2(-INF, -INF)
	var center := node_local_position(node_id)
	var port_position := _input_port_position(node_id, port)
	var inward := port_position.direction_to(center)
	var inset := 28.0 if node.kind == FactoryNodeModel.NodeKind.COMBINER else 14.0
	return port_position + inward * inset


func input_glyph_at(at_position: Vector2) -> Dictionary:
	var display_simulation := _display_simulation()
	if display_simulation == null:
		return {}
	for node_id in _front_to_back_node_ids(display_simulation):
		var node: FactoryNodeModel = display_simulation.nodes[node_id]
		for port in node.input_buffers.size():
			var state := input_glyph_display_state(node_id, port)
			if state == &"empty":
				continue
			var center := input_glyph_center(node_id, port)
			if at_position.distance_to(center) > 13.0:
				continue
			var glyph := visible_input_glyph_for_node(node_id, port)
			if glyph == null:
				glyph = predicted_input_glyph_for_node(node_id, port)
			return {
				"node_id": node_id,
				"port": port,
				"glyph": glyph,
				"state": state,
			}
	return {}


func _visible_node_glyph(node: FactoryNodeModel) -> GlyphModel:
	var glyph := _visible_node_active_glyph(node)
	if glyph == null:
		for input_glyph in node.input_buffers:
			if input_glyph is GlyphModel:
				glyph = input_glyph
				break
	if glyph == null or not glyph.structure_validation_errors().is_empty():
		return null
	return glyph


func _visible_node_active_glyph(node: FactoryNodeModel) -> GlyphModel:
	var glyph: GlyphModel = node.output_buffer
	if glyph == null:
		glyph = node.processing_glyph
	if glyph == null or not glyph.structure_validation_errors().is_empty():
		return null
	return glyph


func _draw_node_input_glyphs(node: FactoryNodeModel, center: Vector2) -> void:
	for port in node.input_buffers.size():
		var glyph := visible_input_glyph_for_node(node.id, port)
		var is_predicted := false
		if glyph == null:
			glyph = predicted_input_glyph_for_node(node.id, port)
			is_predicted = glyph != null
		if glyph == null:
			continue
		var is_combiner := node.kind == FactoryNodeModel.NodeKind.COMBINER
		var glyph_center := input_glyph_center(node.id, port)
		var scale := 1.15 if is_combiner else 0.85
		if is_combiner:
			_draw_combiner_input_socket(glyph_center, is_predicted)
		_draw_mini_glyph(glyph, glyph_center, scale, 0.68 if is_predicted else 1.0)
		if node.id == hovered_input_glyph_node_id and port == hovered_input_glyph_port:
			draw_arc(glyph_center, 14.5, 0.0, TAU, 24, Color(GLYPH_COLOR, 0.78), 2.0, true)
		if node.kind == FactoryNodeModel.NodeKind.SUMMONER and not is_predicted:
			_draw_recipe_match_marker(glyph_center, input_recipe_match_state(node.id, port), 9.0)


func _draw_combiner_input_socket(center: Vector2, is_predicted: bool) -> void:
	draw_circle(center, 11.0, Color(PANEL_COLOR, 0.92))
	var color := Color(GLYPH_COLOR, 0.32 if is_predicted else 0.7)
	if not is_predicted:
		draw_arc(center, 11.0, 0.0, TAU, 20, color, 1.3, true)
		return
	for segment in 8:
		var start_angle := float(segment) * TAU / 8.0
		draw_arc(center, 11.0, start_angle, start_angle + TAU / 16.0, 3, color, 1.3, true)


func _draw_recipe_match_marker(
	center: Vector2,
	match_state: StringName,
	radius: float
) -> void:
	var symbol := recipe_match_marker_symbol(match_state)
	if symbol == &"":
		return
	var color := MATCH_COLOR if symbol == &"check" else WARNING_COLOR
	draw_arc(center, radius, 0.0, TAU, 24, color, 2.0, true)
	var badge_center := center + Vector2(radius * 0.72, -radius * 0.72)
	draw_circle(badge_center, 4.5, color)
	if symbol == &"check":
		draw_line(badge_center + Vector2(-2.2, 0.0), badge_center + Vector2(-0.5, 1.8), Color.WHITE, 1.4, true)
		draw_line(badge_center + Vector2(-0.5, 1.8), badge_center + Vector2(2.5, -2.0), Color.WHITE, 1.4, true)
	else:
		draw_line(badge_center + Vector2(-2.0, -2.0), badge_center + Vector2(2.0, 2.0), Color.WHITE, 1.4, true)
		draw_line(badge_center + Vector2(-2.0, 2.0), badge_center + Vector2(2.0, -2.0), Color.WHITE, 1.4, true)


func _draw_mini_glyph(
	glyph: GlyphModel,
	center: Vector2,
	scale: float,
	opacity: float = 1.0
) -> void:
	GlyphPainterModel.draw_glyph(self, glyph, center, scale, opacity)


func _draw_ports(node: FactoryNodeModel, center: Vector2) -> void:
	if node.kind != FactoryNodeModel.NodeKind.SUMMONER:
		var output_color := LINE_COLOR
		if is_guided_connection_pending() and node.id == &"ring_source":
			output_color = SELECTED_COLOR
		var output_position := _output_port_position(node.id)
		draw_circle(output_position, PORT_RADIUS, output_color)
		if output_validation_state(node.id) == &"missing" and connecting_from_node_id != node.id:
			_draw_validation_port_marker(output_position)
		if node.id == hovered_output_node_id:
			draw_arc(output_position, PORT_RADIUS + 5.0, 0.0, TAU, 24, Color(GLYPH_COLOR, 0.5), 2.2, true)
	for port in node.required_input_count():
		var position := _input_port_position(node.id, port)
		var input_color := LINE_COLOR
		if is_guided_connection_pending() and node.id == &"summoner":
			input_color = SELECTED_COLOR
		if connecting_from_node_id != &"":
			var target_state := connection_target_state(node.id, port)
			if target_state in [&"valid", &"already_connected"]:
				input_color = MATCH_COLOR if target_state == &"valid" else GLYPH_COLOR
				draw_arc(position, PORT_RADIUS + 5.0, 0.0, TAU, 24, Color(input_color, 0.32), 2.0, true)
			else:
				input_color = Color(LINE_COLOR, 0.2)
		if node.id == hovered_input_node_id and port == hovered_input_port:
			var hover_color := GLYPH_COLOR
			if connecting_from_node_id != &"":
				var target_state := connection_target_state(node.id, port)
				hover_color = {
					&"valid": MATCH_COLOR,
					&"already_connected": GLYPH_COLOR,
				}.get(target_state, WARNING_COLOR)
			draw_arc(position, PORT_RADIUS + 5.0, 0.0, TAU, 24, Color(hover_color, 0.52), 2.2, true)
		draw_circle(position, PORT_RADIUS, PANEL_COLOR)
		draw_arc(position, PORT_RADIUS, 0.0, TAU, 20, input_color, 2.0)
		if input_validation_state(node.id, port) == &"missing" and connecting_from_node_id == &"":
			_draw_validation_port_marker(position)


func input_validation_state(node_id: StringName, port: int) -> StringName:
	var expected_error := "missing_input:%s:%d" % [node_id, port]
	return &"missing" if cached_validation_errors.has(expected_error) else &"valid"


func output_validation_state(node_id: StringName) -> StringName:
	return &"missing" if cached_validation_errors.has("missing_output:%s" % node_id) else &"valid"


func node_validation_state(node_id: StringName) -> StringName:
	for error in cached_validation_errors:
		var parts := error.split(":")
		if parts.size() < 2 or parts[1] != String(node_id):
			continue
		if parts[0] in [
			"missing_source_primitive",
			"invalid_source_interval",
			"invalid_processing_ticks",
			"invalid_rotation_steps",
			"invalid_translation_offset",
			"missing_color_id",
		]:
			return &"configuration"
	return &"valid"


func validation_fault_at(at_position: Vector2) -> String:
	var display_simulation := _display_simulation()
	if display_simulation == null:
		return ""
	for node_id in display_simulation.nodes:
		var node: FactoryNodeModel = display_simulation.nodes[node_id]
		if (
			node.kind != FactoryNodeModel.NodeKind.SUMMONER
			and connecting_from_node_id != node_id
			and output_validation_state(node_id) == &"missing"
			and at_position.distance_to(_output_port_position(node_id)) <= PORT_RADIUS + 7.0
		):
			return "出力を接続"
		for port in node.required_input_count():
			if (
				input_validation_state(node_id, port) == &"missing"
				and connecting_from_node_id == &""
				and at_position.distance_to(_input_port_position(node_id, port)) <= PORT_RADIUS + 7.0
			):
				return "入力を接続"
		if node_validation_state(node_id) == &"configuration":
			var marker_center := node_local_position(node_id) + Vector2(34, -20)
			if at_position.distance_to(marker_center) <= 12.0:
				for error in cached_validation_errors:
					var parts := error.split(":")
					if parts.size() >= 2 and parts[1] == String(node_id):
						return local_validation_instruction(error)
	return ""


func local_validation_instruction(error: String) -> String:
	if error.begins_with("missing_source_primitive:") or error.begins_with("invalid_source_interval:"):
		return "素材を再選択"
	if error.begins_with("invalid_rotation_steps:"):
		return "回転角を再選択"
	if error.begins_with("missing_color_id:"):
		return "色を再選択"
	if error.begins_with("invalid_processing_ticks:"):
		return "設備設定を再選択"
	if error.begins_with("invalid_translation_offset:"):
		return "移動設定を再選択"
	return _validation_message([error])


func _draw_validation_port_marker(position: Vector2) -> void:
	for segment in 4:
		var start_angle := float(segment) * TAU / 4.0
		draw_arc(
			position,
			PORT_RADIUS + 5.0,
			start_angle,
			start_angle + TAU / 8.0,
			4,
			Color(WARNING_COLOR, 0.92),
			2.4,
			true
		)
	draw_line(position + Vector2(-3.0, -3.0), position + Vector2(3.0, 3.0), WARNING_COLOR, 1.8, true)
	draw_line(position + Vector2(-3.0, 3.0), position + Vector2(3.0, -3.0), WARNING_COLOR, 1.8, true)


func _draw_node_validation_marker(node_id: StringName, center: Vector2) -> void:
	if node_validation_state(node_id) != &"configuration":
		return
	var marker_center := center + Vector2(34.0, -20.0)
	draw_circle(marker_center, 8.0, Color(0.025, 0.045, 0.068, 0.96))
	draw_arc(marker_center, 8.0, 0.0, TAU, 20, WARNING_COLOR, 1.8, true)
	draw_line(marker_center + Vector2(0, -4), marker_center + Vector2(0, 2), WARNING_COLOR, 1.8, true)
	draw_circle(marker_center + Vector2(0, 5), 1.3, WARNING_COLOR)


func input_port_connectable(to_node_id: StringName, to_port: int) -> bool:
	return connection_target_state(to_node_id, to_port) in [&"valid", &"already_connected"]


func _path_reaches_node(current_id: StringName, sought_id: StringName, visited: Dictionary) -> bool:
	if current_id == sought_id:
		return true
	if visited.has(current_id):
		return false
	visited[current_id] = true
	var display_simulation := _display_simulation()
	for line in display_simulation.lines.values():
		if line.from_node_id == current_id and _path_reaches_node(line.to_node_id, sought_id, visited):
			return true
	return false


func _node_label(node: FactoryNodeModel) -> String:
	match node.kind:
		FactoryNodeModel.NodeKind.SOURCE:
			var meaning_glyph_id := StringName(node.config.get("meaning_glyph_id", ""))
			if meaning_glyph_id != &"":
				return "%s印" % MeaningGlyphsModel.label(meaning_glyph_id) if MeaningGlyphsModel.has(meaning_glyph_id) else "印未設定"
			var primitive := String(node.config.get("primitive_id", ""))
			if primitive not in ["ring", "spike"]:
				return "素材未設定"
			return "棘素材" if primitive == "spike" else "環素材"
		FactoryNodeModel.NodeKind.ROTATOR:
			var steps := int(node.config.get("steps", 0))
			if steps not in [1, 2, 3]:
				return "回転未設定"
			return "回転 +%d°" % (steps * 90)
		FactoryNodeModel.NodeKind.TRANSLATOR:
			return "位置移動"
		FactoryNodeModel.NodeKind.COLORIZER:
			var color_id := StringName(node.config.get("color_id", ""))
			if color_id not in [&"blue", &"red", &"white"]:
				return "色未設定"
			return "%s着色" % _color_name(color_id)
		FactoryNodeModel.NodeKind.COMBINER:
			var connection_mode := StringName(
				node.config.get("connection_mode", GlyphModel.CONNECTION_RADIAL)
			)
			match connection_mode:
				GlyphModel.CONNECTION_RADIAL:
					return "中心結合"
				GlyphModel.CONNECTION_PAIRWISE:
					return "相互結合"
				GlyphModel.CONNECTION_SIMPLE:
					return "単純結合"
			return "結合未設定"
		FactoryNodeModel.NodeKind.SUMMONER:
			return "召喚器"
	return MvpContent.node_name(node.kind)
func _scaled_position(reference_position: Vector2) -> Vector2:
	return Vector2(
		reference_position.x / REFERENCE_SIZE.x * size.x,
		reference_position.y / REFERENCE_SIZE.y * size.y
	)


func _reference_position(local_position: Vector2) -> Vector2:
	return Vector2(
		local_position.x / size.x * REFERENCE_SIZE.x,
		local_position.y / size.y * REFERENCE_SIZE.y
	)


func _display_positions() -> Dictionary:
	return preview_node_positions if editing else node_positions


func _display_simulation() -> FactorySimulation:
	return preview_simulation if editing else simulation


func _node_at(local_position: Vector2) -> StringName:
	var display_simulation := _display_simulation()
	if display_simulation == null:
		return &""
	for node_id in _front_to_back_node_ids(display_simulation):
		var center := node_local_position(node_id)
		if Rect2(center - NODE_HALF_SIZE, NODE_HALF_SIZE * 2.0).has_point(local_position):
			return node_id
	return &""


func _output_port_position(node_id: StringName) -> Vector2:
	var display_simulation := _display_simulation()
	if display_simulation == null or not display_simulation.nodes.has(node_id):
		return node_local_position(node_id) + Vector2(NODE_HALF_SIZE.x, 0)
	var center := node_local_position(node_id)
	var direction := Vector2.RIGHT
	var has_outgoing_line := false
	for line in display_simulation.lines.values():
		if line.from_node_id == node_id and display_simulation.nodes.has(line.to_node_id):
			direction = center.direction_to(node_local_position(line.to_node_id))
			has_outgoing_line = true
			break
	if not has_outgoing_line:
		var summoner_id := _summoner_node_id(display_simulation)
		if summoner_id != &"" and summoner_id != node_id:
			direction = center.direction_to(node_local_position(summoner_id))
	return center + _port_boundary_offset(display_simulation.nodes[node_id], direction)


func _input_port_position(node_id: StringName, port: int) -> Vector2:
	var display_simulation := _display_simulation()
	var node: FactoryNodeModel = display_simulation.nodes[node_id]
	var center := node_local_position(node_id)
	for line in display_simulation.lines.values():
		if line.to_node_id == node_id and line.to_port == port and display_simulation.nodes.has(line.from_node_id):
			var direction := center.direction_to(node_local_position(line.from_node_id))
			return center + _port_boundary_offset(node, direction)
	var radial_direction := Vector2.LEFT
	if connecting_from_node_id != &"" and connecting_from_node_id != node_id and display_simulation.nodes.has(connecting_from_node_id):
		radial_direction = center.direction_to(node_local_position(connecting_from_node_id))
	elif node.kind != FactoryNodeModel.NodeKind.SUMMONER:
		var summoner_id := _summoner_node_id(display_simulation)
		if summoner_id != &"":
			radial_direction = -center.direction_to(node_local_position(summoner_id))
	if radial_direction != Vector2.LEFT or node.required_input_count() > 1:
		var position := center + _port_boundary_offset(node, radial_direction)
		if node.required_input_count() > 1:
			var tangent := Vector2(-radial_direction.y, radial_direction.x).normalized()
			position += tangent * (-8.0 if port == 0 else 8.0)
		return position
	var y_offset := 0.0
	if node.required_input_count() == 2:
		y_offset = -13.0 if port == 0 else 13.0
	var x_offset := -40.0 if node.kind == FactoryNodeModel.NodeKind.SUMMONER else -NODE_HALF_SIZE.x
	return center + Vector2(x_offset, y_offset)


func _summoner_node_id(display_simulation: FactorySimulation) -> StringName:
	var ids := display_simulation.nodes.keys()
	ids.sort()
	for node_id in ids:
		if display_simulation.nodes[node_id].kind == FactoryNodeModel.NodeKind.SUMMONER:
			return node_id
	return &""


func _port_boundary_offset(node: FactoryNodeModel, direction: Vector2) -> Vector2:
	var normalized := direction.normalized()
	if normalized == Vector2.ZERO:
		normalized = Vector2.RIGHT
	if node.kind == FactoryNodeModel.NodeKind.SUMMONER:
		return normalized * 40.0
	var x_scale := INF if absf(normalized.x) < 0.001 else NODE_HALF_SIZE.x / absf(normalized.x)
	var y_scale := INF if absf(normalized.y) < 0.001 else NODE_HALF_SIZE.y / absf(normalized.y)
	return normalized * minf(x_scale, y_scale)


func _output_port_at(local_position: Vector2) -> StringName:
	var display_simulation := _display_simulation()
	if display_simulation == null:
		return &""
	for node_id in _front_to_back_node_ids(display_simulation):
		var node: FactoryNodeModel = display_simulation.nodes[node_id]
		if node.kind == FactoryNodeModel.NodeKind.SUMMONER:
			continue
		if local_position.distance_to(_output_port_position(node_id)) <= PORT_RADIUS + 4.0:
			return node_id
	return &""


func _input_port_at(local_position: Vector2) -> Dictionary:
	var display_simulation := _display_simulation()
	if display_simulation == null:
		return {}
	for node_id in _front_to_back_node_ids(display_simulation):
		var node: FactoryNodeModel = display_simulation.nodes[node_id]
		for port in node.required_input_count():
			if local_position.distance_to(_input_port_position(node_id, port)) <= PORT_RADIUS + 4.0:
				return {"node_id": node_id, "port": port}
	return {}


func _front_to_back_node_ids(display_simulation: FactorySimulation) -> Array:
	var node_ids := display_simulation.nodes.keys()
	node_ids.reverse()
	return node_ids


func _line_at(local_position: Vector2) -> StringName:
	var display_simulation := _display_simulation()
	if display_simulation == null:
		return &""
	for line_id in display_simulation.lines:
		var line: FactoryLineModel = display_simulation.lines[line_id]
		var start := _output_port_position(line.from_node_id)
		var finish := _input_port_position(line.to_node_id, line.to_port)
		var segment := finish - start
		if segment.length_squared() <= 0.001:
			continue
		var ratio := clampf((local_position - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
		if local_position.distance_to(start + segment * ratio) <= 8.0:
			return line_id
	return &""


func _connection_result_text(result: Dictionary) -> String:
	if result["ok"]:
		return "接続しました"
	match result["error"]:
		"cycle":
			return "接続できません: 回路が循環します"
		"invalid_port":
			return "接続できません: 入力ポートがありません"
		"occupied_port":
			return "接続できません: 入力はすでに接続されています"
		"occupied_output":
			return "接続できません: 出力はすでに接続されています。分岐器はMVP対象外です"
		"self_connection":
			return "接続できません: 同じ設備には接続できません"
		"invalid_payload":
			return "接続できません: ライン上の仕掛品データが破損しています"
		"missing_line", "missing_line_id":
			return "接続できません: ラインデータにIDがありません"
		_:
			return "接続できません: %s" % result["error"]


func _validation_message(errors: Array) -> String:
	if errors.is_empty():
		return "工場は稼働可能です"
	var error := String(errors[0])
	if error == "missing_source":
		return "素材源がありません"
	if error == "missing_summoner":
		return "召喚器がありません"
	if error.begins_with("missing_input:"):
		return "入力が未接続の設備があります"
	if error.begins_with("missing_output:"):
		return "出力が未接続の設備があります"
	if error == "mana_exceeded":
		return "工場魔力が上限を超えています"
	if error == "multiple_summoners":
		return "召喚器は現MVPでは1基だけ配置できます"
	if error == "cycle":
		return "配線が循環しています。循環するラインを解除してください"
	if error.begins_with("missing_from_node:") or error.begins_with("missing_to_node:"):
		return "接続先が存在しないラインがあります。壊れたラインを解除してください"
	if error.begins_with("invalid_port:"):
		return "存在しない入力ポートへのラインがあります。接続をやり直してください"
	if error.begins_with("occupied_input:"):
		return "1つの入力に複数ラインが接続されています"
	if error.begins_with("occupied_output:"):
		return "通常設備の出力が分岐しています。余分なラインを解除してください"
	if error.begins_with("missing_source_primitive:"):
		return "素材源「%s」の素材設定がありません" % error.get_slice(":", 1)
	if error.begins_with("invalid_source_interval:"):
		return "素材源「%s」の生成間隔が不正です" % error.get_slice(":", 1)
	if error.begins_with("invalid_processing_ticks:"):
		return "設備「%s」の処理時間が不正です" % error.get_slice(":", 1)
	if error.begins_with("invalid_rotation_steps:"):
		return "回転器「%s」の回転設定は90°・180°・270°から選んでください" % error.get_slice(":", 1)
	if error.begins_with("invalid_translation_offset:"):
		return "移動器「%s」の移動設定が不正です" % error.get_slice(":", 1)
	if error.begins_with("missing_color_id:"):
		return "着色器「%s」の色設定がありません" % error.get_slice(":", 1)
	if error.begins_with("missing_node_id:") or error.begins_with("node_key_mismatch:") or error.begins_with("invalid_node_kind:"):
		return "設備データのIDまたは種類が破損しています"
	if error.begins_with("missing_line_id:") or error.begins_with("line_key_mismatch:"):
		return "ラインデータのIDが破損しています"
	if error.begins_with("invalid_glyph:"):
		return "工場内の仕掛品データが破損しています。仕掛品を廃棄して再構築してください"
	if error.begins_with("invalid_recipe:"):
		return "取得済みシジルデータが破損しています。ランデータを再読み込みしてください"
	return "工場の配線を確認してください"


func _push_undo_snapshot() -> bool:
	var display_simulation := _display_simulation()
	if display_simulation == null:
		connection_message = "工場状態を保存できません // 工場データがありません"
		queue_redraw()
		return false
	var duplication := display_simulation.duplicate_state_result()
	if not duplication["ok"]:
		connection_message = "工場状態を保存できません // %s" % _validation_message(duplication["errors"])
		queue_redraw()
		return false
	undo_history.append({
		"simulation": duplication["state"],
		"positions": _display_positions().duplicate(true),
		"plan_id": display_plan_id(),
	})
	return true


func _restore_undo_snapshot(snapshot: Dictionary) -> void:
	if editing:
		preview_simulation = snapshot["simulation"]
		preview_node_positions = snapshot["positions"]
		pending_plan_id = snapshot.get("plan_id", pending_plan_id)
	else:
		simulation = snapshot["simulation"]
		node_positions = snapshot["positions"]
		plan_id = snapshot.get("plan_id", plan_id)


func _refresh_production_preview() -> void:
	factory_revision += 1
	setting_option_preview_cache.clear()
	var result := production_preview()
	if not result["ok"]:
		cached_production_valid = false
		cached_validation_errors.assign(result.get("errors", []))
		cached_production_counts.clear()
		cached_production_event_offsets = _empty_production_event_offsets()
		cached_production_discarded = 0
		cached_node_output_glyphs.clear()
		cached_production_preview = "32秒予測 // %s" % _validation_message(result.get("errors", []))
		factory_changed.emit()
		return
	var counts: Dictionary = result["counts"]
	var first_failure: Dictionary = result["first_failure"]
	cached_production_valid = true
	cached_validation_errors.clear()
	cached_production_counts = counts.duplicate()
	cached_production_event_offsets = result["event_offsets"].duplicate(true)
	cached_production_discarded = result["discarded"]
	cached_node_output_glyphs = result["node_outputs"].duplicate()
	if first_failure.is_empty():
		cached_production_preview = "32秒予測 // 斥候 %d  衛兵 %d  巨像 %d  不一致 0" % [
			counts[&"scout"],
			counts[&"sentinel"],
			counts[&"golem"],
		]
	else:
		cached_production_preview = "32秒 // 斥%d 衛%d 巨%d 不%d // %s" % [
			counts[&"scout"],
			counts[&"sentinel"],
			counts[&"golem"],
			result["discarded"],
			_preview_failure_summary(first_failure),
		]
	factory_changed.emit()


func _preview_failure_summary(event: Dictionary) -> String:
	var diagnostics: PackedStringArray = event.get("diagnostics", PackedStringArray())
	var reason := "原因不明" if diagnostics.is_empty() else _localize_preview_diagnostic(diagnostics[0])
	var recipe_id: StringName = event.get("closest_recipe_id", &"")
	if recipe_id == &"":
		return reason
	return "%s: %s" % [String(MvpContent.sigil_name(recipe_id)).trim_suffix("シジル"), reason]


func _localize_preview_diagnostic(diagnostic: String) -> String:
	for prefix in ["部品不足: ", "余分な部品: "]:
		if diagnostic.begins_with(prefix):
			var primitive_id := StringName(diagnostic.trim_prefix(prefix))
			return "%s %s" % [prefix.trim_suffix(": "), _primitive_name(primitive_id)]
	return diagnostic


func _apply_run_upgrades(target_simulation: FactorySimulation) -> void:
	for node in target_simulation.nodes.values():
		_apply_node_upgrades(node)
	for line in target_simulation.lines.values():
		_apply_line_upgrades(line)


func _apply_node_upgrades(node: FactoryNodeModel) -> void:
	for upgrade_id in run_upgrades:
		if upgrade_id == &"ring_speed" and node.kind == FactoryNodeModel.NodeKind.SOURCE:
			node.config["interval_ticks"] = maxi(int(round(float(node.config.get("interval_ticks", 18)) * 0.8)), 1)
		elif upgrade_id == &"processing_speed" and node.kind not in [FactoryNodeModel.NodeKind.SOURCE, FactoryNodeModel.NodeKind.SUMMONER]:
			node.config["processing_ticks"] = maxi(int(node.config.get("processing_ticks", 1)) - 1, 1)


func _apply_line_upgrades(line: FactoryLineModel) -> void:
	for upgrade_id in run_upgrades:
		if upgrade_id == &"line_speed":
			line.travel_ticks = maxi(line.travel_ticks - 1, 1)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = Color(0.18, 0.32, 0.46, 0.8)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
