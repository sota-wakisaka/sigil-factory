extends Control

const MvpContent := preload("res://src/game/mvp_content.gd")
const BattleSimulation := preload("res://src/battle/battle_simulation.gd")

const BACKGROUND_COLOR := Color("070a10")
const GRID_COLOR := Color(0.18, 0.26, 0.36, 0.2)
const GRID_SPACING := 32
const TICK_SECONDS := 0.2
const FORECAST_TICKS := 300

@onready var factory_board: FactoryBoard = $FactoryBoard
@onready var battle_board: BattleBoard = $BattleBoard
@onready var plan_label: Label = $PlanLabel
@onready var threat_label: Label = $ThreatLabel
@onready var status_label: Label = $StatusLabel
@onready var pause_button: Button = $Toolbar/PauseButton
@onready var cancel_button: Button = $Toolbar/CancelButton

var elapsed_since_tick := 0.0
var paused := false
var produced_units: Dictionary = {
	&"scout": 0,
	&"sentinel": 0,
	&"golem": 0,
}


func _ready() -> void:
	$Toolbar/ScoutButton.pressed.connect(
		func() -> void: _select_plan(MvpContent.PLAN_SCOUT)
	)
	$Toolbar/SentinelButton.pressed.connect(
		func() -> void: _select_plan(MvpContent.PLAN_SENTINEL)
	)
	$Toolbar/GolemButton.pressed.connect(
		func() -> void: _select_plan(MvpContent.PLAN_GOLEM)
	)
	pause_button.pressed.connect(_toggle_pause)
	cancel_button.pressed.connect(_cancel_edit)
	factory_board.summon_produced.connect(_on_summon_produced)
	battle_board.battle_finished.connect(_on_battle_finished)
	_select_plan(MvpContent.PLAN_SCOUT)
	_set_plan_buttons_enabled(false)
	_refresh_status()
	queue_redraw()


func _process(delta: float) -> void:
	if paused or battle_board.simulation.is_finished():
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


func _select_plan(plan_id: StringName) -> void:
	if paused:
		factory_board.preview_plan(plan_id)
		plan_label.text = "仮術式: %s // 未確定" % MvpContent.plan_name(plan_id)
	else:
		factory_board.configure(plan_id)
		plan_label.text = "稼働術式: %s" % MvpContent.plan_name(plan_id)


func _toggle_pause() -> void:
	if not paused:
		paused = true
		factory_board.begin_edit()
		_set_plan_buttons_enabled(true)
		cancel_button.disabled = false
		pause_button.text = "変更を確定"
		plan_label.text = "時間停止中 // 仕掛品 %d個" % factory_board.work_in_progress_count()
		return

	factory_board.commit_edit()
	_resume_after_edit()


func _cancel_edit() -> void:
	if not paused:
		return
	factory_board.cancel_edit()
	_resume_after_edit()


func _resume_after_edit() -> void:
	paused = false
	_set_plan_buttons_enabled(false)
	cancel_button.disabled = true
	pause_button.text = "時間停止"
	plan_label.text = "稼働術式: %s" % MvpContent.plan_name(factory_board.plan_id)


func _set_plan_buttons_enabled(enabled: bool) -> void:
	$Toolbar/ScoutButton.disabled = not enabled
	$Toolbar/SentinelButton.disabled = not enabled
	$Toolbar/GolemButton.disabled = not enabled


func _on_summon_produced(unit_id: StringName) -> void:
	produced_units[unit_id] = int(produced_units.get(unit_id, 0)) + 1
	battle_board.spawn_player(unit_id)


func _on_battle_finished(winner: int) -> void:
	paused = true
	pause_button.disabled = true
	cancel_button.disabled = true
	_set_plan_buttons_enabled(false)
	if winner == BattleSimulation.Side.PLAYER:
		status_label.text = "VICTORY // 敵リーダーを撃破"
	else:
		status_label.text = "DEFEAT // 自軍リーダーが崩壊"


func _refresh_status() -> void:
	var battle := battle_board.simulation
	var elapsed_seconds := float(battle.tick_index) * TICK_SECONDS
	threat_label.text = battle_board.forecast_text(FORECAST_TICKS, TICK_SECONDS)
	if battle.is_finished():
		return
	status_label.text = "%02d:%02d  |  自軍HP %.0f  敵HP %.0f  |  S %d  G %d  C %d" % [
		int(elapsed_seconds) / 60,
		int(elapsed_seconds) % 60,
		battle.player_leader_health,
		battle.enemy_leader_health,
		produced_units[&"scout"],
		produced_units[&"sentinel"],
		produced_units[&"golem"],
	]
