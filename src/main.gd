extends Control

const MvpContent := preload("res://src/game/mvp_content.gd")
const BattleSimulation := preload("res://src/battle/battle_simulation.gd")
const RunFlow := preload("res://src/game/run_flow.gd")

const BACKGROUND_COLOR := Color("070a10")
const GRID_COLOR := Color(0.18, 0.26, 0.36, 0.2)
const GRID_SPACING := 32
const TICK_SECONDS := 0.2
const FORECAST_TICKS := 300
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
@onready var cancel_button: Button = $Toolbar/CancelButton
@onready var debug_victory_button: Button = $DebugVictoryButton
@onready var phase_overlay: ColorRect = $PhaseOverlay
@onready var phase_kicker: Label = $PhaseOverlay/Center/Panel/Content/Kicker
@onready var phase_title: Label = $PhaseOverlay/Center/Panel/Content/Title
@onready var phase_body: Label = $PhaseOverlay/Center/Panel/Content/Body
@onready var phase_button: Button = $PhaseOverlay/Center/Panel/Content/AdvanceButton

var flow := RunFlow.new()
var elapsed_since_tick := 0.0
var produced_units: Dictionary = {&"scout": 0, &"sentinel": 0, &"golem": 0}


func _ready() -> void:
	$Toolbar/ScoutButton.pressed.connect(func() -> void: _select_plan(MvpContent.PLAN_SCOUT))
	$Toolbar/SentinelButton.pressed.connect(func() -> void: _select_plan(MvpContent.PLAN_SENTINEL))
	$Toolbar/GolemButton.pressed.connect(func() -> void: _select_plan(MvpContent.PLAN_GOLEM))
	pause_button.pressed.connect(_on_main_action)
	cancel_button.pressed.connect(_cancel_edit)
	debug_victory_button.pressed.connect(_complete_battle_placeholder)
	phase_button.pressed.connect(_advance_overlay)
	factory_board.summon_produced.connect(_on_summon_produced)
	battle_board.battle_finished.connect(_on_battle_finished)
	_select_plan(MvpContent.PLAN_SCOUT)
	_apply_phase()
	queue_redraw()


func _process(delta: float) -> void:
	if flow.phase != RunFlow.Phase.BATTLE or battle_board.simulation.is_finished():
		return
	elapsed_since_tick += delta
	while elapsed_since_tick >= TICK_SECONDS:
		elapsed_since_tick -= TICK_SECONDS
		factory_board.advance_tick()
		battle_board.advance_tick()
	_refresh_status()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	for x in range(0, int(size.x) + GRID_SPACING, GRID_SPACING):
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID_COLOR, 1.0)
	for y in range(0, int(size.y) + GRID_SPACING, GRID_SPACING):
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID_COLOR, 1.0)


func _advance_overlay() -> void:
	if not flow.advance():
		return
	if flow.phase == RunFlow.Phase.FACTORY_BUILD or flow.phase == RunFlow.Phase.ROUTE_SELECTION:
		_reset_stage()
	_apply_phase()


func _on_main_action() -> void:
	if flow.phase == RunFlow.Phase.FACTORY_BUILD:
		flow.advance()
		_apply_phase()
	elif flow.phase == RunFlow.Phase.BATTLE and flow.pause_for_reconfiguration():
		factory_board.begin_edit()
		_apply_phase()
	elif flow.phase == RunFlow.Phase.FACTORY_RECONFIGURE:
		factory_board.commit_edit()
		flow.resume_battle()
		_apply_phase()


func _select_plan(plan_id: StringName) -> void:
	if flow.phase == RunFlow.Phase.FACTORY_RECONFIGURE:
		factory_board.preview_plan(plan_id)
		plan_label.text = "仮術式: %s // %s // 未確定" % [MvpContent.plan_name(plan_id), MvpContent.plan_description(plan_id)]
	else:
		factory_board.configure(plan_id)
		var state := "構築中" if flow.phase == RunFlow.Phase.FACTORY_BUILD else "稼働術式"
		plan_label.text = "%s: %s // %s" % [state, MvpContent.plan_name(plan_id), MvpContent.plan_description(plan_id)]


func _cancel_edit() -> void:
	if flow.phase != RunFlow.Phase.FACTORY_RECONFIGURE:
		return
	factory_board.cancel_edit()
	flow.resume_battle()
	_apply_phase()


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
		status_label.text = "DEFEAT // 自軍リーダーが崩壊"
		debug_victory_button.text = "再挑戦"
		debug_victory_button.visible = true


func _enter_victory() -> void:
	if flow.mark_victory():
		status_label.text = "VICTORY // 敵リーダーを撃破"
		_apply_phase()


func _reset_stage() -> void:
	battle_board.reset_battle()
	factory_board.configure(MvpContent.PLAN_SCOUT)
	produced_units = {&"scout": 0, &"sentinel": 0, &"golem": 0}
	elapsed_since_tick = 0.0


func _apply_phase() -> void:
	_update_progress()
	phase_overlay.visible = false
	debug_victory_button.visible = false
	cancel_button.disabled = true
	_set_plan_buttons_enabled(false)
	match flow.phase:
		RunFlow.Phase.ROUTE_SELECTION:
			_show_overlay("RUN %02d" % flow.route_number, "ルートを選択", "進みたいルートを選択します。\n現在は内容を作らず、進行だけを確認する仮画面です。", "OK：このルートを選択")
		RunFlow.Phase.STAGE_INFO:
			_show_overlay("STAGE PREVIEW", "ステージ情報を確認", "敵の種類、地形、報酬候補などを確認する画面です。\n現在は情報を置かず、確認操作だけを用意しています。", "OK：工場構築へ")
		RunFlow.Phase.FACTORY_BUILD:
			_set_plan_buttons_enabled(true)
			pause_button.disabled = false
			pause_button.text = "構築完了・戦闘開始"
			threat_label.text = "ステージ情報をもとに、戦闘前の工場を構築します"
			status_label.text = "工場を選び、準備ができたら戦闘を開始してください"
			_select_plan(factory_board.plan_id)
		RunFlow.Phase.BATTLE:
			pause_button.disabled = false
			pause_button.text = "時間停止"
			debug_victory_button.text = "戦闘を完了（仮）"
			debug_victory_button.visible = true
			plan_label.text = "稼働術式: %s // %s" % [MvpContent.plan_name(factory_board.plan_id), MvpContent.plan_description(factory_board.plan_id)]
			_refresh_status()
		RunFlow.Phase.FACTORY_RECONFIGURE:
			_set_plan_buttons_enabled(true)
			pause_button.disabled = false
			pause_button.text = "変更を確定・戦闘再開"
			cancel_button.disabled = false
			plan_label.text = "時間停止中 // 工場・召喚門を再構成 // 仕掛品 %d個" % factory_board.work_in_progress_count()
			status_label.text = "術式を選び、変更を確定するとリアルタイム戦闘へ戻ります"
		RunFlow.Phase.VICTORY:
			pause_button.disabled = true
			_show_overlay("STAGE CLEAR", "敵リーダーを撃破", "戦闘に勝利しました。\n次に、このルートで得た報酬を確認します。", "OK：報酬を確認")
		RunFlow.Phase.REWARD:
			pause_button.disabled = true
			_show_overlay("REWARD", "シジル・リリック・能力などを獲得", "ランを強化する報酬を選ぶ画面です。\n現在は内容を作らず、獲得したものとして先へ進みます。", "OK：獲得して次のルートへ")


func _show_overlay(kicker: String, title: String, body: String, button_text: String) -> void:
	phase_kicker.text = kicker
	phase_title.text = title
	phase_body.text = body
	phase_button.text = button_text
	phase_overlay.visible = true


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
	$Toolbar/ScoutButton.disabled = not enabled
	$Toolbar/SentinelButton.disabled = not enabled
	$Toolbar/GolemButton.disabled = not enabled


func _refresh_status() -> void:
	var battle := battle_board.simulation
	var elapsed_seconds := float(battle.tick_index) * TICK_SECONDS
	threat_label.text = battle_board.forecast_text(FORECAST_TICKS, TICK_SECONDS)
	if battle.is_finished():
		return
	status_label.text = "%02d:%02d  |  自軍HP %.0f  敵HP %.0f  |  S %d  G %d  C %d" % [
		int(elapsed_seconds) / 60, int(elapsed_seconds) % 60,
		battle.player_leader_health, battle.enemy_leader_health,
		produced_units[&"scout"], produced_units[&"sentinel"], produced_units[&"golem"],
	]
