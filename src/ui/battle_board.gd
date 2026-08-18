class_name BattleBoard
extends Control

signal battle_finished(winner: int)

const MvpContent := preload("res://src/game/mvp_content.gd")
const BattleSimulation := preload("res://src/battle/battle_simulation.gd")

const PANEL_COLOR := Color(0.055, 0.035, 0.06, 0.96)
const LANE_COLOR := Color(0.34, 0.22, 0.38, 0.8)
const PLAYER_COLOR := Color(0.34, 0.86, 1.0, 1.0)
const ENEMY_COLOR := Color(1.0, 0.34, 0.42, 1.0)

var simulation: BattleSimulation
var finish_emitted := false


func _ready() -> void:
	reset_battle()


func reset_battle() -> void:
	simulation = MvpContent.build_battle()
	finish_emitted = false
	queue_redraw()


func spawn_player(unit_id: StringName) -> void:
	if simulation != null and not simulation.is_finished():
		simulation.spawn_player(unit_id)
		queue_redraw()


func advance_tick() -> void:
	if simulation == null or simulation.is_finished():
		return
	simulation.tick()
	if simulation.is_finished() and not finish_emitted:
		finish_emitted = true
		battle_finished.emit(simulation.winner())
	queue_redraw()


func forecast_text(horizon_ticks: int, tick_seconds: float) -> String:
	if simulation == null:
		return "予告情報なし"
	var threats := simulation.upcoming_threats(horizon_ticks)
	if threats.is_empty():
		return "予告: 敵影なし"
	var entries := PackedStringArray()
	for index in mini(threats.size(), 3):
		var threat: ThreatEventModel = threats[index]
		var seconds := maxf(float(threat.tick - simulation.tick_index) * tick_seconds, 0.0)
		entries.append("%s ×%d  %.0fs" % [threat.label, threat.count, seconds])
	return "予告: " + "  |  ".join(entries)


func _draw() -> void:
	draw_style_box(_panel_style(), Rect2(Vector2.ZERO, size))
	if simulation == null:
		return
	var lane_y := size.y * 0.55
	draw_line(Vector2(35, lane_y), Vector2(size.x - 35, lane_y), LANE_COLOR, 5.0, true)
	_draw_leader(Vector2(35, lane_y), true)
	_draw_leader(Vector2(size.x - 35, lane_y), false)
	for unit in simulation.units:
		_draw_unit(unit, lane_y)


func _draw_leader(center: Vector2, is_player: bool) -> void:
	var color := PLAYER_COLOR if is_player else ENEMY_COLOR
	var health := (
		simulation.player_leader_health
		if is_player
		else simulation.enemy_leader_health
	)
	var maximum := 600.0 if is_player else 800.0
	draw_circle(center, 18.0, color.darkened(0.35))
	draw_arc(center, 20.0, 0.0, TAU * clampf(health / maximum, 0.0, 1.0), 48, color, 4.0)


func _draw_unit(unit: BattleUnitModel, lane_y: float) -> void:
	var x := remap(unit.position, 0.0, 1000.0, 35.0, size.x - 35.0)
	var color := PLAYER_COLOR if unit.side == BattleSimulation.Side.PLAYER else ENEMY_COLOR
	var radius := 7.0
	match unit.spec.id:
		&"sentinel", &"brute":
			radius = 10.0
		&"golem":
			radius = 14.0
	var vertical_offset := float(posmod(unit.instance_id, 5) - 2) * 5.0
	draw_circle(Vector2(x, lane_y + vertical_offset), radius, color)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = Color(0.42, 0.2, 0.38, 0.8)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
