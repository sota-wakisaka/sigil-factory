extends Control

const MvpContent := preload("res://src/game/mvp_content.gd")

const BACKGROUND_COLOR := Color("070a10")
const GRID_COLOR := Color(0.18, 0.26, 0.36, 0.2)
const GRID_SPACING := 32
const TICK_SECONDS := 0.2

@onready var factory_board: FactoryBoard = $FactoryBoard
@onready var plan_label: Label = $PlanLabel
@onready var output_label: Label = $OutputLabel
@onready var pause_button: Button = $Toolbar/PauseButton

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
	factory_board.summon_produced.connect(_on_summon_produced)
	_select_plan(MvpContent.PLAN_SCOUT)
	queue_redraw()


func _process(delta: float) -> void:
	if paused:
		return
	elapsed_since_tick += delta
	while elapsed_since_tick >= TICK_SECONDS:
		elapsed_since_tick -= TICK_SECONDS
		factory_board.advance_tick()


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
	factory_board.configure(plan_id)
	plan_label.text = "稼働術式: %s" % MvpContent.plan_name(plan_id)


func _toggle_pause() -> void:
	paused = not paused
	pause_button.text = "再開" if paused else "時間停止"
	plan_label.text = (
		"時間停止中 — 術式を選択してください"
		if paused
		else "稼働術式: %s" % MvpContent.plan_name(factory_board.plan_id)
	)


func _on_summon_produced(unit_id: StringName) -> void:
	produced_units[unit_id] = int(produced_units.get(unit_id, 0)) + 1
	output_label.text = "SCOUT %d   SENTINEL %d   GOLEM %d" % [
		produced_units[&"scout"],
		produced_units[&"sentinel"],
		produced_units[&"golem"],
	]

