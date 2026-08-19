extends Control

const MvpContent := preload("res://src/game/mvp_content.gd")
const BattleSimulation := preload("res://src/battle/battle_simulation.gd")
const RunFlow := preload("res://src/game/run_flow.gd")
const SigilGhostControl := preload("res://src/ui/sigil_ghost.gd")

const BACKGROUND_COLOR := Color("070a10")
const GRID_COLOR := Color(0.18, 0.26, 0.36, 0.2)
const GRID_SPACING := 32
const TICK_SECONDS := 0.2
const FORECAST_TICKS := 120
const MAJOR_FORECAST_TICKS := 300
const FACTORY_CHANGE_TRACKING_TICKS := 75
const BATTLE_SPEEDS := [1.0, 2.0, 4.0]
const FLOW_STEPS := [
	"ルート選択", "ステージ情報", "工場構築", "リアルタイム戦闘",
	"時間停止・再構成", "敵リーダー撃破", "報酬獲得", "次のルート",
]

@onready var factory_board: FactoryBoard = $FactoryBoard
@onready var battle_board: BattleBoard = $BattleBoard
@onready var progress_label: Label = $ProgressLabel
@onready var plan_label: Label = $PlanLabel
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
@onready var reward_option: OptionButton = $PhaseOverlay/Center/Panel/Content/RewardOption
@onready var route_option: OptionButton = $PhaseOverlay/Center/Panel/Content/RouteOption
@onready var inspector_label: Label = $FactoryInspector/SelectionLabel
@onready var inspector_option: OptionButton = $FactoryInspector/SettingOption
@onready var sigil_ghost: SigilGhostControl = $FactoryInspector/SigilGhost

var flow := RunFlow.new()
var elapsed_since_tick := 0.0
var battle_speed_index := 0
var time_stop_count := 0
var factory_change_count := 0
var acquired_rewards: Array[StringName] = []
var selected_route_name := "中央ルート"
var produced_units: Dictionary = {&"scout": 0, &"sentinel": 0, &"golem": 0}
var pre_edit_production_counts: Dictionary = {}
var last_factory_change_summary := ""
var factory_change_battle_baseline: Dictionary = {}
var last_factory_change_battle_impact := ""


func _ready() -> void:
	$Toolbar/ScoutButton.pressed.connect(func() -> void: _select_plan(MvpContent.PLAN_SCOUT))
	$Toolbar/EmptyButton.pressed.connect(func() -> void: _select_plan(MvpContent.PLAN_EMPTY))
	$Toolbar/SentinelButton.pressed.connect(func() -> void: _select_plan(MvpContent.PLAN_SENTINEL))
	$Toolbar/GolemButton.pressed.connect(func() -> void: _select_plan(MvpContent.PLAN_GOLEM))
	$FactoryPalette/RingButton.pressed.connect(func() -> void: _add_factory_node(&"ring_source"))
	$FactoryPalette/SpikeButton.pressed.connect(func() -> void: _add_factory_node(&"spike_source"))
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
	phase_button.pressed.connect(_advance_overlay)
	factory_board.summon_produced.connect(_on_summon_produced)
	factory_board.selection_changed.connect(_refresh_factory_inspector)
	factory_board.factory_changed.connect(_refresh_empty_factory_guidance)
	inspector_option.item_selected.connect(_on_inspector_option_selected)
	battle_board.battle_finished.connect(_on_battle_finished)
	_select_plan(MvpContent.PLAN_SCOUT)
	_apply_phase()
	queue_redraw()


func _process(delta: float) -> void:
	if flow.phase != RunFlow.Phase.BATTLE or battle_board.simulation.is_finished():
		return
	elapsed_since_tick += delta * current_battle_speed()
	while elapsed_since_tick >= TICK_SECONDS:
		elapsed_since_tick -= TICK_SECONDS
		factory_board.advance_tick()
		battle_board.advance_tick()
	_refresh_status()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.ctrl_pressed and event.keycode == KEY_Z:
		_undo_factory_edit()
	elif event.keycode == KEY_DELETE:
		_delete_factory_node()
	elif event.keycode == KEY_SPACE and flow.phase in [RunFlow.Phase.FACTORY_BUILD, RunFlow.Phase.BATTLE, RunFlow.Phase.FACTORY_RECONFIGURE]:
		_on_main_action()
	elif event.keycode == KEY_F:
		_cycle_battle_speed()
	elif factory_board.interaction_enabled:
		match event.keycode:
			KEY_0: _select_plan(MvpContent.PLAN_EMPTY)
			KEY_1: _select_plan(MvpContent.PLAN_SCOUT)
			KEY_2: _select_plan(MvpContent.PLAN_SENTINEL)
			KEY_3: _select_plan(MvpContent.PLAN_GOLEM)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	for x in range(0, int(size.x) + GRID_SPACING, GRID_SPACING):
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID_COLOR, 1.0)
	for y in range(0, int(size.y) + GRID_SPACING, GRID_SPACING):
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID_COLOR, 1.0)


func _advance_overlay() -> void:
	if flow.phase == RunFlow.Phase.ROUTE_SELECTION:
		selected_route_name = route_option.get_item_text(route_option.selected)
	if flow.phase == RunFlow.Phase.REWARD:
		_acquire_selected_reward()
	if not flow.advance():
		return
	if flow.phase == RunFlow.Phase.FACTORY_BUILD or flow.phase == RunFlow.Phase.ROUTE_SELECTION:
		_reset_stage()
	_apply_phase()


func _on_main_action() -> void:
	if flow.phase == RunFlow.Phase.FACTORY_BUILD:
		if not _factory_is_valid("戦闘を開始できません"):
			return
		flow.advance()
		_apply_phase()
	elif flow.phase == RunFlow.Phase.BATTLE and flow.pause_for_reconfiguration():
		_capture_pre_edit_production()
		time_stop_count += 1
		factory_board.begin_edit()
		_apply_phase()
	elif flow.phase == RunFlow.Phase.FACTORY_RECONFIGURE:
		if not _factory_is_valid("変更を確定できません"):
			return
		factory_board.commit_edit()
		_update_factory_change_summary()
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
	sigil_ghost.show_recipe(MvpContent.recipe_id_for_plan(plan_id))
	if flow.phase == RunFlow.Phase.FACTORY_RECONFIGURE:
		factory_board.preview_plan(plan_id)
		plan_label.text = "仮術式: %s // %s // 未確定" % [MvpContent.plan_name(plan_id), MvpContent.plan_description(plan_id)]
		var discard_notice := factory_board.pending_discard_notice()
		if discard_notice != "":
			plan_label.text += " // " + discard_notice
	else:
		factory_board.configure(plan_id)
		var state := "構築中" if flow.phase == RunFlow.Phase.FACTORY_BUILD else "稼働術式"
		plan_label.text = "%s: %s // %s" % [state, MvpContent.plan_name(plan_id), MvpContent.plan_description(plan_id)]
	if plan_id == MvpContent.PLAN_EMPTY:
		plan_label.text = "構築ガイド // 環素材の右●をクリック → 召喚器の左○をクリック"


func _refresh_empty_factory_guidance() -> void:
	if flow.phase != RunFlow.Phase.FACTORY_BUILD or factory_board.plan_id != MvpContent.PLAN_EMPTY:
		return
	if factory_board.is_guided_connection_pending():
		plan_label.text = "構築ガイド // 環素材の右●をクリック → 召喚器の左○をクリック"
	elif factory_board.validation_result()["ok"]:
		plan_label.text = "構築完了 // 斥候を生産できます。戦闘開始へ進めます"


func _add_factory_node(template_id: StringName) -> void:
	if factory_board.add_node_from_palette(template_id) != &"":
		plan_label.text = "カスタム工場 // 設備を配置し、ポート同士を接続してください"


func _delete_factory_node() -> void:
	if factory_board.remove_selected_node():
		plan_label.text = "カスタム工場 // 選択した設備を削除しました"


func _undo_factory_edit() -> void:
	if factory_board.undo():
		plan_label.text = "カスタム工場 // 直前の編集を元に戻しました"


func _refresh_factory_inspector() -> void:
	var details := factory_board.selected_node_details()
	inspector_label.text = details["title"]
	inspector_option.clear()
	for option in details["options"]:
		inspector_option.add_item(option)
	inspector_option.disabled = details["options"].is_empty() or not factory_board.interaction_enabled
	if details["selected_index"] >= 0:
		inspector_option.select(details["selected_index"])


func _on_inspector_option_selected(index: int) -> void:
	if factory_board.configure_selected_node(index):
		plan_label.text = "カスタム工場 // 設備設定を変更しました"
		var discard_notice := factory_board.pending_discard_notice()
		if discard_notice != "":
			plan_label.text += " // " + discard_notice


func _cancel_edit() -> void:
	if flow.phase != RunFlow.Phase.FACTORY_RECONFIGURE:
		return
	factory_board.cancel_edit()
	pre_edit_production_counts.clear()
	last_factory_change_summary = "変更効果 // 変更を破棄したため生産構成は変更していません"
	flow.resume_battle()
	_apply_phase()


func _capture_pre_edit_production() -> void:
	var preview := factory_board.production_preview()
	pre_edit_production_counts = (
		preview["counts"].duplicate()
		if preview["ok"]
		else {}
	)


func _update_factory_change_summary() -> void:
	var preview := factory_board.production_preview()
	if pre_edit_production_counts.is_empty() or not preview["ok"]:
		last_factory_change_summary = ""
		pre_edit_production_counts.clear()
		return
	var labels := {
		&"scout": "斥候",
		&"sentinel": "衛兵",
		&"golem": "巨像",
	}
	var changes := PackedStringArray()
	for unit_id in [&"scout", &"sentinel", &"golem"]:
		var before := int(pre_edit_production_counts.get(unit_id, 0))
		var after := int(preview["counts"].get(unit_id, 0))
		if before != after:
			changes.append("%s %d→%d" % [labels[unit_id], before, after])
	last_factory_change_summary = (
		"変更効果 // 次の32秒: %s" % " / ".join(changes)
		if not changes.is_empty()
		else "変更効果 // 次の32秒の生産予測は変化なし"
	)
	pre_edit_production_counts.clear()


func _begin_factory_change_tracking() -> void:
	var battle := battle_board.simulation
	factory_change_battle_baseline = {
		"tick": battle.tick_index,
		"player_kills": battle.player_kills,
		"enemy_kills": battle.enemy_kills,
		"objective_health": battle.enemy_shield_health + battle.enemy_leader_health,
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
			- battle.enemy_leader_health
	)
	if elapsed_ticks >= FACTORY_CHANGE_TRACKING_TICKS:
		last_factory_change_battle_impact = "変更後15秒 // %s" % impact
		factory_change_battle_baseline.clear()
	else:
		last_factory_change_battle_impact = "変更追跡 %d/15秒 // %s" % [
			int(float(elapsed_ticks) * TICK_SECONDS),
			impact,
		]


func _factory_change_impact_text(enemy_defeated: int, allies_lost: int, objective_damage: float) -> String:
	return "敵撃破 +%d / 味方損失 +%d / 目標ダメージ %.0f" % [
		maxi(enemy_defeated, 0),
		maxi(allies_lost, 0),
		maxf(objective_damage, 0.0),
	]


func _refresh_battle_plan_label() -> void:
	plan_label.text = "稼働術式: %s // %s" % [
		MvpContent.plan_name(factory_board.plan_id),
		MvpContent.plan_description(factory_board.plan_id),
	]
	if last_factory_change_summary != "":
		plan_label.text += "\n" + last_factory_change_summary
	if last_factory_change_battle_impact != "":
		plan_label.text += "\n" + last_factory_change_battle_impact


func current_battle_speed() -> float:
	return BATTLE_SPEEDS[battle_speed_index]


func _cycle_battle_speed() -> void:
	if flow.phase != RunFlow.Phase.BATTLE:
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


func _on_summon_produced(unit_id: StringName) -> void:
	produced_units[unit_id] = int(produced_units.get(unit_id, 0)) + 1
	battle_board.spawn_player(unit_id)


func _on_battle_finished(winner: int) -> void:
	if winner == BattleSimulation.Side.PLAYER:
		_enter_victory()
	else:
		var reason := _defeat_reason()
		status_label.text = "DEFEAT // %s" % reason
		plan_label.text = "敗因分析 // %s // %s" % [reason, _defeat_advice()]
		debug_victory_button.text = "再挑戦"
		debug_victory_button.visible = true


func _enter_victory() -> void:
	if flow.mark_victory():
		status_label.text = "VICTORY // 敵リーダーを撃破"
		_apply_phase()


func _reset_stage() -> void:
	battle_board.reset_battle()
	factory_board.set_run_upgrades(acquired_rewards)
	factory_board.configure(MvpContent.PLAN_EMPTY)
	produced_units = {&"scout": 0, &"sentinel": 0, &"golem": 0}
	elapsed_since_tick = 0.0
	battle_speed_index = 0
	time_stop_count = 0
	factory_change_count = 0
	pre_edit_production_counts.clear()
	last_factory_change_summary = ""
	factory_change_battle_baseline.clear()
	last_factory_change_battle_impact = ""


func _apply_phase() -> void:
	_update_progress()
	phase_overlay.visible = false
	reward_option.visible = false
	route_option.visible = false
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
			_show_overlay(
				"RUN %02d" % flow.route_number,
				"ルートを選択",
				"進みたいルートを選択します。戦闘内容は現在共通です。\n所持強化: %s" % _reward_summary(),
				"OK：このルートを選択"
			)
		RunFlow.Phase.STAGE_INFO:
			_show_overlay(
				"STAGE PREVIEW",
				"ステージ情報を確認",
				"%s // 通常戦闘 // 制限時間 3:00 // 目標: 敵防壁と敵リーダーを撃破\n0:20 襲撃兵 → 斥候  |  1:00 群体兵 → 衛兵  |  1:54 装甲兵 → 巨像" % selected_route_name,
				"OK：工場構築へ"
			)
		RunFlow.Phase.FACTORY_BUILD:
			_set_plan_buttons_enabled(true)
			_set_factory_palette_enabled(true)
			factory_board.set_interaction_enabled(true)
			pause_button.disabled = false
			pause_button.text = "構築完了・戦闘開始"
			pause_button.tooltip_text = "配線が完成した工場を確定し、リアルタイム戦闘を開始します"
			threat_label.text = "ステージ情報をもとに、戦闘前の工場を構築します"
			status_label.text = "工場を選び、準備ができたら戦闘を開始してください"
			_select_plan(factory_board.plan_id)
		RunFlow.Phase.BATTLE:
			pause_button.disabled = false
			speed_button.disabled = false
			pause_button.text = "時間停止"
			pause_button.tooltip_text = "工場を再構成するため、工場と戦場の時間を停止します"
			debug_victory_button.text = "検証用: 戦闘をスキップ"
			debug_victory_button.visible = true
			_refresh_battle_plan_label()
			_refresh_status()
		RunFlow.Phase.FACTORY_RECONFIGURE:
			_set_plan_buttons_enabled(true)
			_set_factory_palette_enabled(true)
			factory_board.set_interaction_enabled(true)
			pause_button.disabled = false
			pause_button.text = "変更を確定・戦闘再開"
			pause_button.tooltip_text = "有効な工場変更を一括確定し、リアルタイム戦闘を再開します"
			cancel_button.disabled = false
			var work_summary := factory_board.work_in_progress_summary()
			plan_label.text = "時間停止中 // 工場・召喚門を再構成 // 仕掛品 %d個" % factory_board.work_in_progress_count()
			if work_summary != "":
				plan_label.text += "（%s）" % work_summary
			status_label.text = "術式を選び、変更を確定するとリアルタイム戦闘へ戻ります"
		RunFlow.Phase.VICTORY:
			pause_button.disabled = true
			_show_overlay("STAGE CLEAR", "敵リーダーを撃破", _battle_result_summary(), "OK：報酬を確認")
		RunFlow.Phase.REWARD:
			pause_button.disabled = true
			_prepare_reward_options()
			_show_overlay("REWARD", "ラン強化を1つ獲得", "選んだ強化は次のルート以降の工場へ適用されます。", "獲得して次のルートへ")


func _show_overlay(kicker: String, title: String, body: String, button_text: String) -> void:
	phase_kicker.text = kicker
	phase_title.text = title
	phase_body.text = body
	phase_button.text = button_text
	phase_overlay.visible = true


func _prepare_reward_options() -> void:
	reward_option.clear()
	reward_option.add_item("迅速な環 // 環素材の生成間隔 -20%")
	reward_option.set_item_metadata(0, &"ring_speed")
	reward_option.add_item("高速加工 // 加工器の処理時間 -1 tick")
	reward_option.set_item_metadata(1, &"processing_speed")
	reward_option.add_item("高速ライン // 輸送時間 -1 tick")
	reward_option.set_item_metadata(2, &"line_speed")
	reward_option.visible = true


func _prepare_route_options() -> void:
	route_option.clear()
	route_option.add_item("左ルート // シジル報酬傾向（仮）")
	route_option.add_item("中央ルート // リリック報酬傾向（仮）")
	route_option.add_item("右ルート // 能力報酬傾向（仮）")
	route_option.select(1)
	route_option.visible = true


func _acquire_selected_reward() -> void:
	if reward_option.item_count == 0:
		return
	var reward_id: StringName = reward_option.get_item_metadata(reward_option.selected)
	acquired_rewards.append(reward_id)


func _reward_summary() -> String:
	if acquired_rewards.is_empty():
		return "なし"
	var names := PackedStringArray()
	for reward_id in acquired_rewards:
		match reward_id:
			&"ring_speed": names.append("迅速な環")
			&"processing_speed": names.append("高速加工")
			&"line_speed": names.append("高速ライン")
	return " / ".join(names)


func _battle_result_summary() -> String:
	var battle := battle_board.simulation
	var elapsed_seconds := float(battle.tick_index) * TICK_SECONDS
	return "戦闘時間 %02d:%02d  //  撃破 %d体\n生産: 斥候 %d  衛兵 %d  巨像 %d  //  時間停止 %d回  再構成 %d回  廃棄・不一致 %d" % [
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
			"改善: 配線 // 成功召喚0・廃棄/不一致%d。完成見本と失敗差分を確認" % discarded
			if discarded > 0
			else "改善: 生産量 // 成功召喚0。配線を完成させ32秒予測を確認"
		)
	if discarded >= maxi(int(total_produced / 5), 2):
		return "改善: 配線 // 廃棄/不一致%d。完成見本と召喚失敗差分を確認" % discarded
	if factory_change_count == 0:
		return "改善: 判断・相性 // 再構成0回。群体兵で衛兵、装甲兵で巨像へ切替"
	if sentinel_count == 0:
		return "改善: 兵種相性 // 衛兵0。群体兵の60秒警告で衛兵術式へ切替"
	if golem_count == 0:
		return "改善: 兵種相性 // 巨像0。装甲兵の60秒警告で巨像術式へ切替"
	if battle_board.simulation.is_enemy_shield_active():
		return "改善: 生産量 // 防壁突破前。32秒予測で召喚数が増える構成を選択"
	return "改善: 対リーダー火力 // 装甲波以降の巨像生産を早める"


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
	$Toolbar/GolemButton.disabled = not enabled


func _set_factory_palette_enabled(enabled: bool) -> void:
	for button in $FactoryPalette.get_children():
		button.disabled = not enabled


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
