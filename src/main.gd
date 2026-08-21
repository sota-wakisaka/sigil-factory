extends Control

const MvpContent := preload("res://src/game/mvp_content.gd")
const BattleSimulation := preload("res://src/battle/battle_simulation.gd")
const RunFlow := preload("res://src/game/run_flow.gd")
const SigilGhostControl := preload("res://src/ui/sigil_ghost.gd")
const FactorySelectionIndicatorControl := preload("res://src/ui/factory_selection_indicator.gd")
const MeaningRewardButtonControl := preload("res://src/ui/meaning_reward_button.gd")
const MeaningGlyphsModel := preload("res://src/domain/meaning_glyphs.gd")
const StageThreatTimelineControl := preload("res://src/ui/stage_threat_timeline.gd")
const RunUpgradeStripControl := preload("res://src/ui/run_upgrade_strip.gd")
const BattleResultSigilStripControl := preload("res://src/ui/battle_result_sigil_strip.gd")

const MAIN_MENU_SCENE := "res://src/main_menu.tscn"

const BACKGROUND_COLOR := Color("070a10")
const GRID_COLOR := Color(0.18, 0.26, 0.36, 0.2)
const GRID_SPACING := 32
const TICK_SECONDS := 0.2
const FORECAST_TICKS := 120
const MAJOR_FORECAST_TICKS := 300
const FACTORY_CHANGE_TRACKING_TICKS := 75
const ACTION_ERROR_HOLD_TICKS := 15
const BATTLE_SPEEDS := [1.0, 2.0, 4.0]
const FLOW_STEPS := [
	"ルート選択", "ステージ情報", "工場構築", "リアルタイム戦闘",
	"時間停止・再構成", "敵リーダー撃破", "報酬獲得", "次のルート",
]

enum WorkspaceView {
	FACTORY,
	BATTLE,
}

@onready var factory_board: FactoryBoard = $FactoryBoard
@onready var battle_board: BattleBoard = $BattleBoard
@onready var progress_label: Label = $ProgressLabel
@onready var plan_label: Label = $PlanLabel
@onready var factory_state = $FactoryState
@onready var threat_label: Label = $ThreatLabel
@onready var status_label: Label = $StatusLabel
@onready var pause_button: Button = $Toolbar/PauseButton
@onready var speed_button: Button = $Toolbar/SpeedButton
@onready var cancel_button: Button = $Toolbar/CancelButton
@onready var debug_victory_button: Button = $DebugVictoryButton
@onready var phase_overlay: ColorRect = $PhaseOverlay
@onready var phase_kicker: Label = $PhaseOverlay/Center/Panel/Content/Kicker
@onready var phase_title: Label = $PhaseOverlay/Center/Panel/Content/Title
@onready var phase_body: Label = $PhaseOverlay/Center/Panel/Content/Body
@onready var phase_button: Button = $PhaseOverlay/Center/Panel/Content/AdvanceButton
@onready var reward_choices: HBoxContainer = $PhaseOverlay/Center/Panel/Content/RewardChoices
@onready var route_choices: HBoxContainer = $PhaseOverlay/Center/Panel/Content/RouteChoices
@onready var stage_timeline: StageThreatTimelineControl = $PhaseOverlay/Center/Panel/Content/StageTimeline
@onready var run_upgrade_strip: RunUpgradeStripControl = $PhaseOverlay/Center/Panel/Content/RunUpgradeStrip
@onready var battle_result_sigil_strip: BattleResultSigilStripControl = $PhaseOverlay/Center/Panel/Content/BattleResultSigilStrip
@onready var inspector_label: FactorySelectionIndicatorControl = $FactoryInspector/SelectionLabel
@onready var inspector_option: FactorySettingOption = $FactoryInspector/SettingOption
@onready var sigil_ghost: SigilGhostControl = $FactoryInspector/SigilGhost
@onready var factory_tab: Button = $WorkspaceTabs/FactoryTab
@onready var battle_tab: Button = $WorkspaceTabs/BattleTab

var flow := RunFlow.new()
var elapsed_since_tick := 0.0
var battle_speed_index := 0
var time_stop_count := 0
var factory_change_count := 0
var acquired_rewards: Array[StringName] = []
var defeat_active := false
var selected_route_id: StringName = MvpContent.ROUTE_MIXED
var selected_route_name := MvpContent.route_name(MvpContent.ROUTE_MIXED)
var produced_units: Dictionary = {&"scout": 0, &"sentinel": 0, &"golem": 0}
var produced_recipes: Dictionary = {}
var pre_edit_production_snapshot: Dictionary = {}
var last_factory_change_summary := ""
var factory_change_battle_baseline: Dictionary = {}
var last_factory_change_battle_impact := ""
var workspace_view := WorkspaceView.FACTORY
var action_error_message := ""
var action_error_hold_ticks := 0


func _ready() -> void:
	$MenuButton.pressed.connect(_return_to_main_menu)
	factory_tab.pressed.connect(func() -> void: _show_workspace(WorkspaceView.FACTORY))
	battle_tab.pressed.connect(func() -> void: _show_workspace(WorkspaceView.BATTLE))
	$Toolbar/ScoutButton.pressed.connect(func() -> void: _select_plan(MvpContent.PLAN_SCOUT))
	$Toolbar/EmptyButton.pressed.connect(func() -> void: _select_plan(MvpContent.PLAN_EMPTY))
	$Toolbar/SentinelButton.pressed.connect(func() -> void: _select_plan(MvpContent.PLAN_VIGIL))
	$Toolbar/StarButton.pressed.connect(func() -> void: _select_plan(MvpContent.PLAN_STELLAR))
	$Toolbar/GolemButton.pressed.connect(func() -> void: _select_plan(MvpContent.PLAN_FORTRESS))
	$FactoryPalette/RingButton.pressed.connect(func() -> void: _add_factory_node(&"ring_source"))
	$FactoryPalette/SpikeButton.pressed.connect(func() -> void: _add_factory_node(&"spike_source"))
	$FactoryPalette/MeaningButton.pressed.connect(func() -> void: _add_factory_node(&"meaning_source"))
	$FactoryPalette/RotateButton.pressed.connect(func() -> void: _add_factory_node(&"rotator"))
	$FactoryPalette/ColorButton.pressed.connect(func() -> void: _add_factory_node(&"colorizer"))
	$FactoryPalette/CombineButton.pressed.connect(func() -> void: _add_factory_node(&"combiner"))
	$FactoryPalette/SummonButton.pressed.connect(func() -> void: _add_factory_node(&"summoner"))
	$FactoryPalette/DeleteButton.pressed.connect(_delete_factory_node)
	$FactoryPalette/UndoButton.pressed.connect(_undo_factory_edit)
	pause_button.pressed.connect(_on_main_action)
	speed_button.pressed.connect(_cycle_battle_speed)
	cancel_button.pressed.connect(_cancel_edit)
	debug_victory_button.pressed.connect(_complete_battle_placeholder)
	for button in reward_choices.get_children():
		button.pressed.connect(_select_reward.bind(button))
	for button in route_choices.get_children():
		button.pressed.connect(_select_route.bind(button))
	phase_button.pressed.connect(_advance_overlay)
	factory_board.summon_produced.connect(_on_summon_produced)
	factory_board.selection_changed.connect(_refresh_factory_inspector)
	factory_board.factory_changed.connect(_refresh_factory_validation_state)
	factory_board.factory_changed.connect(_refresh_factory_goal_candidate)
	factory_board.factory_changed.connect(_refresh_factory_palette_state)
	factory_board.factory_changed.connect(_refresh_factory_inspector)
	factory_board.factory_changed.connect(inspector_option._clear_option_preview)
	factory_board.selection_changed.connect(_refresh_factory_palette_state)
	factory_board.selection_changed.connect(inspector_option._clear_option_preview)
	inspector_option.item_selected.connect(_on_inspector_option_selected)
	inspector_option.option_preview_requested.connect(_on_inspector_option_preview_requested)
	inspector_option.option_preview_cleared.connect(_on_inspector_option_preview_cleared)
	battle_board.battle_finished.connect(_on_battle_finished)
	_select_plan(MvpContent.PLAN_SCOUT)
	_apply_phase()
	queue_redraw()


func _return_to_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _show_workspace(next_view: WorkspaceView) -> void:
	workspace_view = next_view
	var show_factory := workspace_view == WorkspaceView.FACTORY
	factory_board.visible = show_factory
	battle_board.visible = not show_factory
	$FactoryPalette.visible = show_factory
	$FactoryInspector.visible = show_factory
	factory_tab.set_pressed_no_signal(show_factory)
	battle_tab.set_pressed_no_signal(not show_factory)
	$Toolbar/EmptyButton.visible = show_factory
	$Toolbar/ScoutButton.visible = show_factory
	$Toolbar/SentinelButton.visible = show_factory
	$Toolbar/StarButton.visible = show_factory
	$Toolbar/GolemButton.visible = show_factory
	speed_button.visible = not show_factory
	threat_label.visible = not show_factory
	status_label.visible = not show_factory
	plan_label.visible = not show_factory
	factory_state.visible = show_factory


func _process(delta: float) -> void:
	if flow.phase != RunFlow.Phase.BATTLE or battle_board.simulation.is_finished():
		return
	elapsed_since_tick += delta * current_battle_speed()
	while elapsed_since_tick >= TICK_SECONDS:
		elapsed_since_tick -= TICK_SECONDS
		factory_board.advance_tick()
		_refresh_factory_goal_candidate()
		battle_board.advance_tick()
		if action_error_hold_ticks > 0:
			action_error_hold_ticks -= 1
	_refresh_status()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.ctrl_pressed and event.keycode == KEY_Z:
		_undo_factory_edit()
	elif event.keycode == KEY_ESCAPE and factory_board.interaction_enabled:
		factory_board.cancel_pending_connection()
	elif event.keycode == KEY_DELETE:
		_delete_factory_node()
	elif event.keycode == KEY_SPACE and defeat_active:
		_advance_overlay()
	elif event.keycode == KEY_SPACE and flow.phase in [RunFlow.Phase.FACTORY_BUILD, RunFlow.Phase.BATTLE, RunFlow.Phase.FACTORY_RECONFIGURE]:
		_on_main_action()
	elif event.keycode == KEY_F:
		_cycle_battle_speed()
	elif factory_board.interaction_enabled:
		match event.keycode:
			KEY_0: _select_plan(MvpContent.PLAN_EMPTY)
			KEY_1: _select_plan(MvpContent.PLAN_SCOUT)
			KEY_2: _select_plan(MvpContent.PLAN_VIGIL)
			KEY_3: _select_plan(MvpContent.PLAN_STELLAR)
			KEY_4: _select_plan(MvpContent.PLAN_FORTRESS)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	for x in range(0, int(size.x) + GRID_SPACING, GRID_SPACING):
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID_COLOR, 1.0)
	for y in range(0, int(size.y) + GRID_SPACING, GRID_SPACING):
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID_COLOR, 1.0)


func _advance_overlay() -> void:
	if defeat_active:
		defeat_active = false
		flow.phase = RunFlow.Phase.FACTORY_BUILD
		_reset_stage()
		_apply_phase()
		return
	if flow.phase == RunFlow.Phase.REWARD:
		_acquire_selected_reward()
	if not flow.advance():
		return
	if flow.phase == RunFlow.Phase.FACTORY_BUILD or flow.phase == RunFlow.Phase.ROUTE_SELECTION:
		_reset_stage()
	_apply_phase()


func _on_main_action() -> void:
	if defeat_active:
		return
	if flow.phase == RunFlow.Phase.FACTORY_BUILD:
		if not _factory_is_valid("戦闘を開始できません"):
			return
		flow.advance()
		_apply_phase()
	elif flow.phase == RunFlow.Phase.BATTLE:
		if not factory_board.begin_edit():
			action_error_message = factory_board.connection_message
			action_error_hold_ticks = ACTION_ERROR_HOLD_TICKS
			_refresh_status()
			return
		action_error_message = ""
		action_error_hold_ticks = 0
		if not flow.pause_for_reconfiguration():
			factory_board.cancel_edit()
			return
		_capture_pre_edit_production()
		time_stop_count += 1
		_apply_phase()
	elif flow.phase == RunFlow.Phase.FACTORY_RECONFIGURE:
		if not _factory_is_valid("変更を確定できません"):
			return
		var candidate_snapshot := factory_board.production_snapshot().duplicate(true)
		var production_comparison := factory_board.compare_production_snapshots(
			pre_edit_production_snapshot,
			candidate_snapshot
		)
		factory_board.commit_edit()
		_update_factory_change_summary(production_comparison)
		_begin_factory_change_tracking()
		factory_change_count += 1
		flow.resume_battle()
		_apply_phase()


func _factory_is_valid(prefix: String) -> bool:
	var result := factory_board.validation_result()
	if result["ok"]:
		return true
	status_label.text = "%s // %s" % [prefix, result["message"]]
	return false


func _select_plan(plan_id: StringName) -> void:
	if flow.phase == RunFlow.Phase.FACTORY_RECONFIGURE:
		if not factory_board.preview_plan(plan_id):
			_sync_plan_ui(factory_board.display_plan_id())
			return
		_sync_plan_ui(plan_id)
		var feedback := "◇ %s  • 未確定" % MvpContent.plan_name(plan_id)
		var discard_notice := factory_board.pending_discard_notice()
		if discard_notice != "":
			feedback += " // " + discard_notice
		_set_factory_feedback(feedback)
	else:
		if flow.phase == RunFlow.Phase.FACTORY_BUILD:
			if not factory_board.apply_plan(plan_id):
				_sync_plan_ui(factory_board.display_plan_id())
				_refresh_factory_validation_state()
				return
			_sync_plan_ui(plan_id)
			_refresh_factory_validation_state()
		else:
			factory_board.configure(plan_id)
			_sync_plan_ui(plan_id)
			_set_factory_feedback("◇ %s" % MvpContent.plan_name(plan_id))


func _sync_plan_ui(plan_id: StringName) -> void:
	sigil_ghost.show_recipe(MvpContent.recipe_id_for_plan(plan_id))
	_refresh_factory_goal_tools()
	for button in [$Toolbar/EmptyButton, $Toolbar/ScoutButton, $Toolbar/SentinelButton, $Toolbar/StarButton, $Toolbar/GolemButton]:
		button.set_plan_selected(button.plan_id == plan_id)
	_refresh_factory_goal_candidate()


func _refresh_plan_button_forecasts() -> void:
	for button in [$Toolbar/EmptyButton, $Toolbar/ScoutButton, $Toolbar/SentinelButton, $Toolbar/StarButton, $Toolbar/GolemButton]:
		var snapshot := factory_board.plan_production_snapshot(button.plan_id)
		var count := 0
		if bool(snapshot.get("ok", false)):
			for unit_count in snapshot.get("counts", {}).values():
				count += int(unit_count)
		var mana := int(snapshot.get("mana", 0))
		var production_text := "配線後に生産予測" if button.manual_layout else "%d体/32秒" % count
		var first_tick := -1
		if not button.manual_layout:
			first_tick = _first_production_tick(snapshot)
			if first_tick >= 0:
				production_text += " // 初着%.1f秒" % (float(first_tick) * TICK_SECONDS)
		button.set_forecast_context("戦闘 %s\n魔力 %d/%d // %s" % [
			MvpContent.recipe_combat_trait(button.recipe_id),
			mana,
			MvpContent.FACTORY_MANA_MAX,
			production_text,
		], mana, -1 if button.manual_layout else count, first_tick, int(snapshot.get("horizon_ticks", 160)))


func _first_production_tick(snapshot: Dictionary) -> int:
	var first_tick := -1
	for offsets_value in snapshot.get("event_offsets", {}).values():
		var offsets: PackedInt32Array = offsets_value
		if offsets.is_empty():
			continue
		if first_tick < 0 or offsets[0] < first_tick:
			first_tick = offsets[0]
	return first_tick


func _set_factory_feedback(message: String) -> void:
	plan_label.text = message
	factory_state.configure(message)


func _refresh_factory_validation_state() -> void:
	if flow.phase == RunFlow.Phase.FACTORY_BUILD:
		if factory_board.plan_id == MvpContent.PLAN_EMPTY and factory_board.is_guided_connection_pending():
			_set_factory_feedback("◇ 配線待ち")
			return
		var result := factory_board.validation_result()
		if result["ok"]:
			_set_factory_feedback("✓ 構築可能")
		else:
			_set_factory_feedback("◇ 未接続 // %s" % result["message"])
	elif flow.phase == RunFlow.Phase.FACTORY_RECONFIGURE:
		var feedback := "◇ 未確定"
		var discard_notice := factory_board.pending_discard_notice()
		if discard_notice != "":
			feedback += " // " + discard_notice
		_set_factory_feedback(feedback)


func _add_factory_node(template_id: StringName) -> void:
	var preferred_meaning_glyph_id := &""
	if template_id == &"meaning_source":
		preferred_meaning_glyph_id = factory_board.first_missing_meaning_source(
			_required_meaning_source_ids()
		)
	factory_board.add_node_from_palette(template_id, preferred_meaning_glyph_id)


func _delete_factory_node() -> void:
	factory_board.remove_selected_node()


func _undo_factory_edit() -> void:
	if factory_board.undo():
		_sync_plan_ui(factory_board.display_plan_id())


func _refresh_factory_inspector() -> void:
	var details := factory_board.selected_node_details()
	inspector_label.visible = details["selected"]
	inspector_label.configure(details["selected"], details["kind"], details["title"])
	inspector_option.clear()
	var option_enabled: Array = details.get("option_enabled", [])
	for option_index in details["options"].size():
		var option: String = details["options"][option_index]
		inspector_option.add_item(option)
		if option_index < option_enabled.size():
			inspector_option.set_item_disabled(option_index, not bool(option_enabled[option_index]))
	inspector_option.visible = details["selected"] and not details["options"].is_empty()
	inspector_option.disabled = details["options"].is_empty() or not factory_board.interaction_enabled
	inspector_option.select(details["selected_index"])
	inspector_option.configure_visual(details["kind"], details["selected_index"], details["title"])


func _refresh_factory_goal_candidate() -> void:
	var candidate := factory_board.final_summoner_candidate()
	sigil_ghost.show_candidate(candidate["glyph"], candidate["state"])


func _refresh_factory_goal_tools() -> void:
	var relevant := {}
	var required_meaning_ids: Array[StringName] = []
	_collect_goal_equipment(sigil_ghost.glyph, relevant, required_meaning_ids)
	relevant[&"summoner"] = true
	for button in $FactoryPalette.get_children():
		if button.equipment_kind == &"meaning_source":
			button.set_preview_glyph(MeaningGlyphsModel.glyph(
				factory_board.first_missing_meaning_source(required_meaning_ids)
			))
		if button.equipment_kind in [&"delete", &"undo"]:
			button.set_goal_state(&"irrelevant")
		else:
			var goal_state: StringName = &"irrelevant"
			if relevant.has(button.equipment_kind):
				if button.equipment_kind == &"meaning_source":
					goal_state = factory_board.meaning_source_presence(required_meaning_ids)
					if goal_state == &"missing" and button.availability_reason in [&"mana", &"summoner_limit"]:
						goal_state = &"blocked"
				elif factory_board.goal_equipment_present(button.equipment_kind):
					goal_state = &"present"
				elif button.availability_reason in [&"mana", &"summoner_limit"]:
					goal_state = &"blocked"
				else:
					goal_state = &"missing"
			button.set_goal_state(goal_state)


func _required_meaning_source_ids() -> Array[StringName]:
	var relevant := {}
	var required_ids: Array[StringName] = []
	_collect_goal_equipment(sigil_ghost.glyph, relevant, required_ids)
	return required_ids


func _collect_goal_equipment(
	glyph: GlyphModel,
	relevant: Dictionary,
	required_meaning_ids: Array[StringName]
) -> void:
	if glyph == null:
		return
	var canonical := glyph.canonical_serialization()
	for meaning_glyph_id in MeaningGlyphsModel.IDS:
		if MeaningGlyphsModel.glyph(meaning_glyph_id).canonical_serialization() == canonical:
			relevant[&"meaning_source"] = true
			if meaning_glyph_id not in required_meaning_ids:
				required_meaning_ids.append(meaning_glyph_id)
			return
	if not glyph.combine_children.is_empty():
		relevant[&"combiner"] = true
	for component in glyph.components:
		match component.primitive_id:
			&"ring": relevant[&"ring_source"] = true
			&"spike": relevant[&"spike_source"] = true
		if component.rotation_degrees != 0:
			relevant[&"rotator"] = true
		if component.color_id != &"white":
			relevant[&"colorizer"] = true
	for child in glyph.combine_children:
		_collect_goal_equipment(child, relevant, required_meaning_ids)


func _on_inspector_option_selected(index: int) -> void:
	if not factory_board.configure_selected_node(index):
		_refresh_factory_inspector()


func _on_inspector_option_preview_requested(index: int) -> void:
	var candidate := factory_board.setting_option_candidate(index)
	if not bool(candidate.get("active", false)):
		_refresh_factory_goal_candidate()
		return
	var forecast_state: StringName = (
		&"invalid"
		if candidate.get("validity", &"invalid") == &"invalid"
		else candidate.get("output_state", &"no_output")
	)
	sigil_ghost.show_candidate(
		candidate.get("glyph"),
		&"hypothetical",
		forecast_state,
		_setting_option_forecast_context(candidate)
	)


func _setting_option_forecast_context(candidate: Dictionary) -> String:
	var parts := PackedStringArray()
	var counts: Dictionary = candidate.get("counts", {})
	var recipe_ids: Dictionary = candidate.get("recipe_ids", {})
	var event_offsets: Dictionary = candidate.get("event_offsets", {})
	for unit_id: StringName in [&"scout", &"sentinel", &"golem"]:
		var count := int(counts.get(unit_id, 0))
		if count <= 0:
			continue
		var recipe_id := StringName(recipe_ids.get(unit_id, ""))
		var recipe_label := String(MvpContent.sigil_name(recipe_id)).trim_suffix("シジル")
		var timing: PackedInt32Array = event_offsets.get(unit_id, PackedInt32Array())
		var first_label := ""
		if not timing.is_empty():
			first_label = "・初回%.1f秒" % (float(timing[0]) * TICK_SECONDS)
		parts.append("%s→%s %d体%s" % [
			recipe_label,
			MvpContent.unit_name(unit_id),
			count,
			first_label,
		])
	var discarded := int(candidate.get("discarded", 0))
	if discarded > 0:
		parts.append("不一致%d" % discarded)
	return "32秒: %s" % ("召喚なし" if parts.is_empty() else " / ".join(parts))


func _on_inspector_option_preview_cleared() -> void:
	_refresh_factory_goal_candidate()


func _cancel_edit() -> void:
	if flow.phase != RunFlow.Phase.FACTORY_RECONFIGURE:
		return
	factory_board.cancel_edit()
	_sync_plan_ui(factory_board.plan_id)
	pre_edit_production_snapshot.clear()
	last_factory_change_summary = "変更効果 // 変更を破棄したため生産構成は変更していません"
	flow.resume_battle()
	_apply_phase()


func _capture_pre_edit_production() -> void:
	var preview := factory_board.production_snapshot()
	pre_edit_production_snapshot = (
		preview.duplicate(true)
		if preview.get("ok", false)
		else {}
	)
	factory_board.set_production_comparison_baseline(preview)


func _update_factory_change_summary(comparison: Dictionary) -> void:
	if pre_edit_production_snapshot.is_empty() or comparison.get("validity", &"invalid") != &"valid":
		last_factory_change_summary = ""
		pre_edit_production_snapshot.clear()
		return
	var labels := {
		&"scout": "斥候",
		&"sentinel": "衛兵",
		&"golem": "巨像",
	}
	var changes := PackedStringArray()
	var timing_changed := false
	var recipe_changed := false
	for unit_id in [&"scout", &"sentinel", &"golem"]:
		var unit_difference: Dictionary = comparison["units"].get(unit_id, {})
		if unit_difference.is_empty():
			continue
		var before := int(unit_difference.get("before", 0))
		var after := int(unit_difference.get("after", 0))
		var count_state: StringName = unit_difference.get("count_state", &"unchanged")
		var timing_state: StringName = unit_difference.get("timing_state", &"unchanged")
		var recipe_state: StringName = unit_difference.get("recipe_state", &"unchanged")
		if count_state != &"unchanged":
			changes.append("%s %d→%d" % [labels[unit_id], before, after])
		if timing_state != &"unchanged":
			timing_changed = true
		if recipe_state != &"unchanged":
			recipe_changed = true
	var discarded: Dictionary = comparison.get("discarded", {})
	var discarded_changed: bool = discarded.get("state", &"unchanged") != &"unchanged"
	if changes.is_empty():
		if recipe_changed and timing_changed and discarded_changed:
			changes.append("シジル・召喚時刻・不一致変更")
		elif recipe_changed and timing_changed:
			changes.append("シジル・召喚時刻変更")
		elif recipe_changed and discarded_changed:
			changes.append("シジル・不一致変更")
		elif recipe_changed:
			changes.append("使用シジル変更")
		elif timing_changed and discarded_changed:
			changes.append("召喚時刻・不一致変更")
		elif timing_changed:
			changes.append("召喚時刻変更")
		elif discarded_changed:
			changes.append("不一致 %d→%d" % [
				int(discarded.get("before", 0)),
				int(discarded.get("after", 0)),
			])
	else:
		if recipe_changed:
			changes.append("シジル変更")
		if discarded_changed:
			changes.append("不一致変更")
	if not bool(comparison.get("changed", false)):
		last_factory_change_summary = "変更効果 // 次の32秒の生産予測は変化なし"
	elif changes.is_empty():
		last_factory_change_summary = "変更効果 // 32秒予測を更新"
	else:
		last_factory_change_summary = "変更効果 // 次の32秒: %s" % " / ".join(changes)
	pre_edit_production_snapshot.clear()


func _begin_factory_change_tracking() -> void:
	var battle := battle_board.simulation
	factory_change_battle_baseline = {
		"tick": battle.tick_index,
		"player_kills": battle.player_kills,
		"enemy_kills": battle.enemy_kills,
		"objective_health": battle.enemy_shield_health + battle.enemy_leader_health,
		"recipe_damage": battle.player_damage_by_recipe.duplicate(true),
	}
	last_factory_change_battle_impact = ""


func _refresh_factory_change_tracking() -> void:
	if factory_change_battle_baseline.is_empty():
		return
	var battle := battle_board.simulation
	var elapsed_ticks: int = maxi(
		battle.tick_index - int(factory_change_battle_baseline["tick"]),
		0
	)
	var impact := _factory_change_impact_text(
		battle.player_kills - int(factory_change_battle_baseline["player_kills"]),
		battle.enemy_kills - int(factory_change_battle_baseline["enemy_kills"]),
		float(factory_change_battle_baseline["objective_health"])
			- battle.enemy_shield_health
			- battle.enemy_leader_health,
		_recipe_damage_delta(factory_change_battle_baseline.get("recipe_damage", {}))
	)
	if elapsed_ticks >= FACTORY_CHANGE_TRACKING_TICKS:
		last_factory_change_battle_impact = "変更後15秒 // %s" % impact
		factory_change_battle_baseline.clear()
	else:
		last_factory_change_battle_impact = "変更追跡 %d/15秒 // %s" % [
			int(float(elapsed_ticks) * TICK_SECONDS),
			impact,
		]


func _factory_change_impact_text(
	enemy_defeated: int,
	allies_lost: int,
	objective_damage: float,
	recipe_damage: Dictionary = {}
) -> String:
	var impact := "敵撃破 +%d / 味方損失 +%d / 目標ダメージ %.0f" % [
		maxi(enemy_defeated, 0),
		maxi(allies_lost, 0),
		maxf(objective_damage, 0.0),
	]
	var recipe_labels := PackedStringArray()
	for recipe in MvpContent.recipes():
		var damage := float(recipe_damage.get(recipe.id, 0.0))
		if damage <= 0.0:
			continue
		recipe_labels.append("%s +%.0f" % [
			String(MvpContent.sigil_name(recipe.id)).trim_suffix("シジル"),
			damage,
		])
	if not recipe_labels.is_empty():
		impact += " / シジル打撃 " + "・".join(recipe_labels)
	return impact


func _recipe_damage_delta(before: Dictionary) -> Dictionary:
	var result := {}
	for recipe in MvpContent.recipes():
		var damage := (
			float(battle_board.simulation.player_damage_by_recipe.get(recipe.id, 0.0))
			- float(before.get(recipe.id, 0.0))
		)
		if damage > 0.0:
			result[recipe.id] = damage
	return result


func _refresh_battle_plan_label() -> void:
	plan_label.text = "稼働術式: %s" % _active_factory_operation_text()
	if last_factory_change_summary != "":
		plan_label.text += "\n" + last_factory_change_summary
	if last_factory_change_battle_impact != "":
		plan_label.text += "\n" + last_factory_change_battle_impact


func _active_factory_operation_text() -> String:
	var entries := factory_board.production_operation_entries()
	if entries.is_empty():
		return "%s // 生産なし" % MvpContent.plan_name(factory_board.plan_id)
	var labels := PackedStringArray()
	for entry in entries:
		var sigil_label := MvpContent.sigil_name(entry["recipe_id"]).trim_suffix("シジル")
		labels.append("%s → %s %d/32秒" % [
			sigil_label,
			MvpContent.unit_name(entry["unit_id"]),
			entry["count"],
		])
	return " / ".join(labels)


func current_battle_speed() -> float:
	return BATTLE_SPEEDS[battle_speed_index]


func _cycle_battle_speed() -> void:
	if flow.phase != RunFlow.Phase.BATTLE or defeat_active:
		return
	battle_speed_index = (battle_speed_index + 1) % BATTLE_SPEEDS.size()
	_update_speed_button()
	_refresh_status()


func _update_speed_button() -> void:
	speed_button.text = "早送り ×%d" % int(current_battle_speed())


func _complete_battle_placeholder() -> void:
	if flow.phase != RunFlow.Phase.BATTLE:
		return
	if battle_board.simulation.is_finished() and battle_board.simulation.winner() != BattleSimulation.Side.PLAYER:
		flow.phase = RunFlow.Phase.FACTORY_BUILD
		_reset_stage()
		_apply_phase()
		return
	_enter_victory()


func _on_summon_produced(unit_id: StringName, recipe_id: StringName) -> void:
	produced_units[unit_id] = int(produced_units.get(unit_id, 0)) + 1
	produced_recipes[recipe_id] = int(produced_recipes.get(recipe_id, 0)) + 1
	battle_board.spawn_player(unit_id, recipe_id)


func _on_battle_finished(winner: int) -> void:
	if winner == BattleSimulation.Side.PLAYER:
		_enter_victory()
	else:
		var reason := _defeat_reason()
		defeat_active = true
		pause_button.disabled = true
		speed_button.disabled = true
		debug_victory_button.visible = false
		battle_result_sigil_strip.configure(
			produced_recipes,
			battle_board.simulation.player_damage_by_recipe
		)
		_show_overlay("RUN %02d // DEFEAT" % flow.route_number, reason, _defeat_advice(), "工場を再構築")


func _enter_victory() -> void:
	if flow.mark_victory():
		status_label.text = "VICTORY // 敵リーダーを撃破"
		_apply_phase()


func _reset_stage() -> void:
	defeat_active = false
	battle_board.reset_battle(selected_route_id, flow.route_number)
	factory_board.set_run_upgrades(acquired_rewards)
	factory_board.configure(MvpContent.PLAN_EMPTY)
	produced_units = {&"scout": 0, &"sentinel": 0, &"golem": 0}
	produced_recipes.clear()
	elapsed_since_tick = 0.0
	battle_speed_index = 0
	action_error_message = ""
	action_error_hold_ticks = 0
	time_stop_count = 0
	factory_change_count = 0
	pre_edit_production_snapshot.clear()
	last_factory_change_summary = ""
	factory_change_battle_baseline.clear()
	last_factory_change_battle_impact = ""


func _apply_phase() -> void:
	_update_progress()
	phase_overlay.visible = false
	reward_choices.visible = false
	route_choices.visible = false
	stage_timeline.visible = false
	run_upgrade_strip.visible = false
	battle_result_sigil_strip.visible = false
	debug_victory_button.visible = false
	speed_button.disabled = true
	_update_speed_button()
	cancel_button.disabled = true
	_set_plan_buttons_enabled(false)
	_set_factory_palette_enabled(false)
	factory_board.set_interaction_enabled(false)
	_refresh_factory_inspector()
	match flow.phase:
		RunFlow.Phase.ROUTE_SELECTION:
			_prepare_route_options()
			run_upgrade_strip.configure(acquired_rewards)
			_show_overlay(
				"RUN %02d" % flow.route_number,
				"ルートを選択",
				"敵編成が異なるルートを選択します。",
				"OK：このルートを選択"
			)
		RunFlow.Phase.STAGE_INFO:
			var durability_percent := roundi((MvpContent.route_durability_multiplier(flow.route_number) - 1.0) * 100.0)
			var durability_text := "標準耐久" if durability_percent == 0 else "敵部隊耐久 +%d%%" % durability_percent
			stage_timeline.configure(selected_route_id, flow.route_number)
			stage_timeline.visible = true
			_show_overlay(
				"RUN %02d // STAGE" % flow.route_number,
				"ステージ情報を確認",
				"%s // %s // 制限 3:00 // 敵防壁とリーダーを撃破" % [selected_route_name, durability_text],
				"OK：工場構築へ"
			)
		RunFlow.Phase.FACTORY_BUILD:
			_show_workspace(WorkspaceView.FACTORY)
			_refresh_plan_button_forecasts()
			_set_plan_buttons_enabled(true)
			_set_factory_palette_enabled(true)
			factory_board.set_interaction_enabled(true)
			pause_button.disabled = false
			pause_button.configure_action("start", "戦闘開始", "配線が完成した工場を確定し、リアルタイム戦闘を開始します")
			threat_label.text = ""
			status_label.text = ""
			_select_plan(factory_board.plan_id)
		RunFlow.Phase.BATTLE:
			_show_workspace(WorkspaceView.BATTLE)
			pause_button.disabled = false
			speed_button.disabled = false
			pause_button.configure_action("pause", "時間停止", "工場を再構成するため、工場と戦場の時間を停止します")
			debug_victory_button.text = "検証用: 戦闘をスキップ"
			debug_victory_button.visible = true
			_refresh_battle_plan_label()
			_refresh_status()
		RunFlow.Phase.FACTORY_RECONFIGURE:
			_show_workspace(WorkspaceView.FACTORY)
			_set_plan_buttons_enabled(true)
			_set_factory_palette_enabled(true)
			factory_board.set_interaction_enabled(true)
			pause_button.disabled = false
			pause_button.configure_action("resume", "確定・再開", "有効な工場変更を一括確定し、リアルタイム戦闘を再開します")
			cancel_button.disabled = false
			_set_factory_feedback("Ⅱ")
			status_label.text = ""
		RunFlow.Phase.VICTORY:
			pause_button.disabled = true
			battle_result_sigil_strip.configure(
				produced_recipes,
				battle_board.simulation.player_damage_by_recipe
			)
			_show_overlay("RUN %02d // CLEAR" % flow.route_number, "敵リーダーを撃破", _battle_result_summary(), "OK：報酬を確認")
		RunFlow.Phase.REWARD:
			pause_button.disabled = true
			if _prepare_reward_options():
				_show_overlay("RUN %02d // REWARD" % flow.route_number, "ラン強化を1つ獲得", "", "獲得して次のルートへ")
				_refresh_reward_selection_context()
			else:
				_show_overlay("RUN %02d // REWARD" % flow.route_number, "ラン強化は完成", "3種類の工場強化が最大になりました。", "次のルートへ")


func _show_overlay(kicker: String, title: String, body: String, button_text: String) -> void:
	phase_kicker.text = kicker
	phase_title.text = title
	phase_body.text = body
	phase_button.text = button_text
	phase_overlay.visible = true


func _prepare_reward_options() -> bool:
	var buttons := reward_choices.get_children()
	var selected_available := false
	var baseline := factory_board.production_snapshot()
	for button in buttons:
		button.set_level(acquired_rewards.count(button.reward_id))
		var prospective: Dictionary = (
			{}
			if button.disabled
			else factory_board.prospective_upgrade_snapshot(button.reward_id)
		)
		button.set_forecast_context(
			"" if button.disabled else _reward_forecast_summary(
				baseline,
				prospective
			)
		)
		button.set_forecast_visual(
			{}
			if button.disabled
			else _reward_forecast_visual(baseline, prospective)
		)
		var should_select: bool = not selected_available and not bool(button.disabled)
		button.set_reward_selected(should_select)
		selected_available = selected_available or should_select
	reward_choices.visible = true
	return selected_available


func _reward_forecast_summary(before: Dictionary, after: Dictionary) -> String:
	var comparison := factory_board.compare_production_snapshots(before, after)
	if comparison.get("validity", &"invalid") != &"valid":
		return "現在工場32秒 // 予測できません"
	var entries := PackedStringArray()
	for unit_id: StringName in [&"scout", &"sentinel", &"golem"]:
		var difference: Dictionary = comparison.get("units", {}).get(unit_id, {})
		if difference.get("count_state", &"unchanged") != &"unchanged":
			entries.append("%s %d→%d" % [
				MvpContent.unit_name(unit_id),
				int(difference.get("before", 0)),
				int(difference.get("after", 0)),
			])
		elif difference.get("timing_state", &"unchanged") != &"unchanged":
			var before_offsets: PackedInt32Array = difference.get("before_offsets", PackedInt32Array())
			var after_offsets: PackedInt32Array = difference.get("after_offsets", PackedInt32Array())
			if not before_offsets.is_empty() and not after_offsets.is_empty():
				if before_offsets[0] != after_offsets[0]:
					entries.append("%s 初着%.1f→%.1f秒" % [
						MvpContent.unit_name(unit_id),
						float(before_offsets[0]) * TICK_SECONDS,
						float(after_offsets[0]) * TICK_SECONDS,
					])
				else:
					entries.append("%s 召喚時刻変更" % MvpContent.unit_name(unit_id))
		if difference.get("recipe_state", &"unchanged") != &"unchanged":
			var next_recipe := StringName(difference.get("after_recipe_id", ""))
			entries.append(
				"%sへ変更" % MvpContent.sigil_name(next_recipe).replace("シジル", "")
				if next_recipe != &""
				else "%sの生産終了" % MvpContent.unit_name(unit_id)
			)
	var discarded: Dictionary = comparison.get("discarded", {})
	if discarded.get("state", &"unchanged") != &"unchanged":
		entries.append("不一致 %d→%d" % [
			int(discarded.get("before", 0)),
			int(discarded.get("after", 0)),
		])
	if entries.is_empty():
		return "現在工場32秒 // 変化なし"
	return "現在工場32秒 // " + " / ".join(entries)


func _reward_forecast_visual(before: Dictionary, after: Dictionary) -> Dictionary:
	var comparison := factory_board.compare_production_snapshots(before, after)
	if comparison.get("validity", &"invalid") != &"valid":
		return {"visible": true, "valid": false}
	var fallback := {}
	for unit_id: StringName in [&"scout", &"sentinel", &"golem"]:
		var difference: Dictionary = comparison.get("units", {}).get(unit_id, {})
		var recipe_id := StringName(difference.get("after_recipe_id", ""))
		if recipe_id == &"":
			recipe_id = StringName(difference.get("before_recipe_id", ""))
		var glyph := _recipe_glyph(recipe_id)
		var state := {
			"visible": true,
			"valid": true,
			"glyph": glyph,
			"before": int(difference.get("before", 0)),
			"after": int(difference.get("after", 0)),
			"timing_changed": difference.get("timing_state", &"unchanged") != &"unchanged",
		}
		if int(state["before"]) > 0 or int(state["after"]) > 0:
			fallback = state
		if (
			difference.get("count_state", &"unchanged") != &"unchanged"
			or difference.get("timing_state", &"unchanged") != &"unchanged"
			or difference.get("recipe_state", &"unchanged") != &"unchanged"
		):
			return state
	return fallback if not fallback.is_empty() else {"visible": true, "valid": true, "before": 0, "after": 0}


func _recipe_glyph(recipe_id: StringName) -> GlyphModel:
	for recipe in MvpContent.recipes():
		if recipe.id == recipe_id:
			return recipe.glyph.copy()
	return null


func _select_reward(selected_button: MeaningRewardButtonControl) -> void:
	if selected_button.disabled:
		return
	for button in reward_choices.get_children():
		button.set_reward_selected(button == selected_button)
	_refresh_reward_selection_context()


func _refresh_reward_selection_context() -> void:
	for button in reward_choices.get_children():
		if button.button_pressed and not button.disabled:
			phase_body.text = "次ルート以降の工場へ適用"
			return
	phase_body.text = "獲得できる強化がありません"


func _prepare_route_options() -> void:
	route_choices.visible = true
	var selected_button = null
	for button in route_choices.get_children():
		var selected: bool = button.route_id == selected_route_id
		button.set_route_selected(selected)
		if selected:
			selected_button = button
	if selected_button == null and route_choices.get_child_count() > 0:
		_select_route(route_choices.get_child(0))


func _select_route(selected_button) -> void:
	for button in route_choices.get_children():
		button.set_route_selected(button == selected_button)
	selected_route_id = selected_button.route_id
	selected_route_name = MvpContent.route_name(selected_route_id)


func _acquire_selected_reward() -> void:
	for button in reward_choices.get_children():
		if button.button_pressed and not button.disabled:
			acquired_rewards.append(button.reward_id)
			return


func _reward_summary() -> String:
	if acquired_rewards.is_empty():
		return "なし"
	var names := PackedStringArray()
	for entry in [
		{&"id": &"ring_speed", &"label": "集束"},
		{&"id": &"processing_speed", &"label": "交差"},
		{&"id": &"line_speed", &"label": "先見"},
	]:
		var level := acquired_rewards.count(entry[&"id"])
		if level > 0:
			names.append("%s %d/3" % [entry[&"label"], level])
	return " / ".join(names)


func _battle_result_summary() -> String:
	var battle := battle_board.simulation
	var elapsed_seconds := float(battle.tick_index) * TICK_SECONDS
	var summary := "戦闘時間 %02d:%02d  //  撃破 %d体\n生産: 斥候 %d  衛兵 %d  巨像 %d  //  時間停止 %d回  再構成 %d回  廃棄・不一致 %d" % [
		int(elapsed_seconds) / 60,
		int(elapsed_seconds) % 60,
		battle.player_kills,
		produced_units[&"scout"],
		produced_units[&"sentinel"],
		produced_units[&"golem"],
		time_stop_count,
		factory_change_count,
		factory_board.simulation.discarded_glyphs,
	]
	return summary


func _produced_sigil_summary() -> String:
	var labels := PackedStringArray()
	for recipe in MvpContent.recipes():
		var count := int(produced_recipes.get(recipe.id, 0))
		if count <= 0:
			continue
		labels.append("%s %d" % [
			String(MvpContent.sigil_name(recipe.id)).trim_suffix("シジル"),
			count,
		])
	return " / ".join(labels)


func _sigil_damage_summary() -> String:
	var labels := PackedStringArray()
	for recipe in MvpContent.recipes():
		var damage := float(battle_board.simulation.player_damage_by_recipe.get(recipe.id, 0.0))
		if damage <= 0.0:
			continue
		labels.append("%s %.0f" % [
			String(MvpContent.sigil_name(recipe.id)).trim_suffix("シジル"),
			damage,
		])
	return " / ".join(labels)


func _defeat_reason() -> String:
	var battle := battle_board.simulation
	if battle.player_leader_health <= 0.0:
		return "前線を維持できず、自軍リーダーが崩壊しました"
	if battle.is_enemy_shield_active():
		return "時間内に敵防壁を突破できませんでした"
	return "防壁突破後、敵リーダーへの火力が不足しました"


func _defeat_advice() -> String:
	var scout_count := int(produced_units.get(&"scout", 0))
	var sentinel_count := int(produced_units.get(&"sentinel", 0))
	var golem_count := int(produced_units.get(&"golem", 0))
	var total_produced := scout_count + sentinel_count + golem_count
	var discarded := factory_board.simulation.discarded_glyphs
	if total_produced == 0:
		return (
			"召喚 0体 // 不一致 %d" % discarded
			if discarded > 0
			else "召喚 0体 // 工場出力なし"
		)
	if discarded >= maxi(int(total_produced / 5), 2):
		return "召喚 %d体 // 不一致 %d" % [total_produced, discarded]
	if factory_change_count == 0:
		return "再構成 0回 // 生産 斥候%d  衛兵%d  巨像%d" % [scout_count, sentinel_count, golem_count]
	if sentinel_count == 0:
		return "生産 斥候%d  衛兵0  巨像%d" % [scout_count, golem_count]
	if golem_count == 0:
		return "生産 斥候%d  衛兵%d  巨像0" % [scout_count, sentinel_count]
	if battle_board.simulation.is_enemy_shield_active():
		return "敵防壁 残りHP %.0f // 召喚 %d体" % [battle_board.simulation.enemy_shield_health, total_produced]
	return "敵リーダー 残りHP %.0f // 召喚 %d体" % [battle_board.simulation.enemy_leader_health, total_produced]


func _update_progress() -> void:
	var active_index := 0
	match flow.phase:
		RunFlow.Phase.ROUTE_SELECTION: active_index = 0 if flow.route_number == 1 else 7
		RunFlow.Phase.STAGE_INFO: active_index = 1
		RunFlow.Phase.FACTORY_BUILD: active_index = 2
		RunFlow.Phase.BATTLE: active_index = 3
		RunFlow.Phase.FACTORY_RECONFIGURE: active_index = 4
		RunFlow.Phase.VICTORY: active_index = 5
		RunFlow.Phase.REWARD: active_index = 6
	var labels := PackedStringArray()
	for index in FLOW_STEPS.size():
		labels.append("[%s]" % FLOW_STEPS[index] if index == active_index else FLOW_STEPS[index])
	progress_label.text = "  ›  ".join(labels)


func _set_plan_buttons_enabled(enabled: bool) -> void:
	$Toolbar/EmptyButton.disabled = not enabled
	$Toolbar/ScoutButton.disabled = not enabled
	$Toolbar/SentinelButton.disabled = not enabled
	$Toolbar/StarButton.disabled = not enabled
	$Toolbar/GolemButton.disabled = not enabled


func _set_factory_palette_enabled(enabled: bool) -> void:
	if not enabled:
		for button in $FactoryPalette.get_children():
			button.set_availability(false, &"locked")
		_refresh_factory_goal_tools()
		return
	_refresh_factory_palette_state()


func _refresh_factory_palette_state() -> void:
	for button in $FactoryPalette.get_children():
		match button.equipment_kind:
			&"delete":
				var delete_available := factory_board.interaction_enabled and factory_board.selected_node_id != &""
				button.set_availability(delete_available, &"selection" if factory_board.interaction_enabled else &"locked")
			&"undo":
				button.set_availability(factory_board.can_undo(), &"undo_empty" if factory_board.interaction_enabled else &"locked")
			_:
				var availability := factory_board.palette_availability(button.equipment_kind)
				button.set_availability(availability["available"], availability["reason"])
	_refresh_factory_goal_tools()


func _refresh_status() -> void:
	var battle := battle_board.simulation
	_refresh_factory_change_tracking()
	if flow.phase == RunFlow.Phase.BATTLE:
		_refresh_battle_plan_label()
	var remaining_seconds := maxf(
		float(battle.battle_duration_ticks - battle.tick_index) * TICK_SECONDS,
		0.0
	)
	var near_forecast := battle_board.forecast_text(FORECAST_TICKS, TICK_SECONDS)
	var major_forecast := battle_board.major_change_text(
		MAJOR_FORECAST_TICKS,
		FORECAST_TICKS,
		TICK_SECONDS
	)
	threat_label.text = (
		near_forecast
		if major_forecast == ""
		else "%s  //  %s" % [major_forecast, near_forecast]
	)
	if action_error_hold_ticks > 0:
		threat_label.text = action_error_message
	if battle.is_finished():
		return
	var enemy_objective := "敵防壁HP %.0f" % battle.enemy_shield_health if battle.is_enemy_shield_active() else "敵リーダーHP %.0f" % battle.enemy_leader_health
	var player_unit_count := 0
	var enemy_unit_count := 0
	for unit in battle.units:
		if unit.side == BattleSimulation.Side.PLAYER:
			player_unit_count += 1
		else:
			enemy_unit_count += 1
	status_label.text = "残り %02d:%02d ×%d | リーダーHP %.0f %s | 戦場 %d対%d | 生産 斥候%d 衛兵%d 巨像%d" % [
		int(remaining_seconds) / 60, int(remaining_seconds) % 60,
		int(current_battle_speed()),
		battle.player_leader_health, enemy_objective,
		player_unit_count, enemy_unit_count,
		produced_units[&"scout"], produced_units[&"sentinel"], produced_units[&"golem"],
	]
