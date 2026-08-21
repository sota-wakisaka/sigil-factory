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
var route_id: StringName = MvpContent.ROUTE_MIXED
var route_number := 1


func _ready() -> void:
	reset_battle()


func reset_battle(next_route_id: StringName = MvpContent.ROUTE_MIXED, next_route_number: int = 1) -> void:
	route_id = next_route_id if next_route_id in MvpContent.ROUTE_IDS else MvpContent.ROUTE_MIXED
	route_number = maxi(next_route_number, 1)
	simulation = MvpContent.build_battle(route_id, route_number)
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
	return "敵予告: " + "  |  ".join(entries)


func major_change_text(
	horizon_ticks: int,
	near_horizon_ticks: int,
	tick_seconds: float
) -> String:
	if simulation == null:
		return ""
	for threat in simulation.upcoming_major_changes(horizon_ticks):
		var lead_ticks: int = threat.tick - simulation.tick_index
		if lead_ticks <= near_horizon_ticks:
			continue
		var seconds := maxf(float(lead_ticks) * tick_seconds, 0.0)
		return "編成警告 %.0fs: %s" % [
			seconds,
			threat.label,
		]
	return ""


func wave_status_text() -> String:
	if simulation == null:
		return "待機中"
	var upcoming := simulation.upcoming_threats(120)
	if upcoming.is_empty():
		return "%s // 前線整理" % MvpContent.route_name(route_id)
	return "%s // %s" % [MvpContent.route_name(route_id), upcoming[0].label]


func capacity_status_text() -> String:
	if simulation == null:
		return "戦場容量 --"
	var player_count := simulation.active_unit_count(BattleSimulation.Side.PLAYER)
	var enemy_count := simulation.active_unit_count(BattleSimulation.Side.ENEMY)
	var text := "戦場容量 青%d/%d  赤%d/%d" % [
		player_count,
		BattleSimulation.MAX_UNITS_PER_SIDE,
		enemy_count,
		BattleSimulation.MAX_UNITS_PER_SIDE,
	]
	var player_rejected := int(simulation.rejected_spawns.get(BattleSimulation.Side.PLAYER, 0))
	var enemy_rejected := int(simulation.rejected_spawns.get(BattleSimulation.Side.ENEMY, 0))
	if player_rejected + enemy_rejected > 0:
		text += " // 上限拒否 青%d 赤%d" % [player_rejected, enemy_rejected]
	return text


func _draw() -> void:
	draw_style_box(_panel_style(), Rect2(Vector2.ZERO, size))
	if simulation == null:
		return
	draw_string(
		ThemeDB.fallback_font,
		Vector2(18, 28),
		wave_status_text(),
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x - 36.0,
		14,
		Color(0.9, 0.62, 0.7)
	)
	var lane_y := size.y * 0.55
	draw_line(Vector2(35, lane_y), Vector2(size.x - 35, lane_y), LANE_COLOR, 5.0, true)
	if simulation.is_enemy_shield_active():
		_draw_enemy_shield(lane_y)
	_draw_leader(Vector2(35, lane_y), true)
	_draw_leader(Vector2(size.x - 35, lane_y), false)
	for unit in simulation.units:
		_draw_unit(unit, lane_y)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(18, size.y - 36.0),
		capacity_status_text(),
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x - 36.0,
		11,
		Color(0.48, 0.58, 0.7)
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(18, size.y - 16.0),
		"青: ○斥候  □衛兵  ◇巨像    赤: ○襲撃  △群体  ■装甲",
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x - 36.0,
		12,
		Color(0.62, 0.68, 0.78)
	)


func _draw_leader(center: Vector2, is_player: bool) -> void:
	var color := PLAYER_COLOR if is_player else ENEMY_COLOR
	var health := (
		simulation.player_leader_health
		if is_player
		else simulation.enemy_leader_health
	)
	var maximum := (
		BattleSimulation.PLAYER_LEADER_MAX_HEALTH
		if is_player
		else BattleSimulation.ENEMY_LEADER_MAX_HEALTH
	)
	draw_circle(center, 18.0, color.darkened(0.35))
	draw_arc(center, 20.0, 0.0, TAU * clampf(health / maximum, 0.0, 1.0), 48, color, 4.0)


func _draw_enemy_shield(lane_y: float) -> void:
	var shield_x := remap(
		BattleSimulation.ENEMY_SHIELD_POSITION,
		0.0,
		1000.0,
		35.0,
		size.x - 35.0
	)
	var color := Color.WHITE if simulation.enemy_shield_flash_ticks > 0 else Color(0.82, 0.36, 0.92, 0.9)
	draw_line(Vector2(shield_x, lane_y - 72), Vector2(shield_x, lane_y + 72), color, 4.0, true)
	var bar := Rect2(Vector2(shield_x - 48.0, lane_y - 100.0), Vector2(96.0, 8.0))
	var ratio := clampf(
		simulation.enemy_shield_health / BattleSimulation.ENEMY_SHIELD_MAX_HEALTH,
		0.0,
		1.0
	)
	draw_rect(bar, Color(0.12, 0.08, 0.16, 1.0), true)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), color, true)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(shield_x - 24.0, lane_y - 108.0),
		"敵防壁",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color(0.9, 0.72, 1.0)
	)
	if simulation.enemy_shield_flash_ticks > 0:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(shield_x - 34.0, lane_y + 94.0),
			"防壁 -%.0f" % simulation.last_enemy_shield_damage,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color(1.0, 0.82, 0.36)
		)


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
	var center := Vector2(x, lane_y + vertical_offset)
	var display_color := Color.WHITE if unit.hit_flash_ticks > 0 else color
	_draw_unit_shape(unit.spec.id, center, radius, display_color)
	if unit.side == BattleSimulation.Side.PLAYER and unit.summon_flash_ticks > 0:
		draw_arc(center, radius + 6.0, 0.0, TAU, 24, Color(0.58, 0.92, 1.0, 0.85), 2.0)
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-12.0, radius + 17.0),
			"召喚",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			Color(0.58, 0.92, 1.0)
		)
	var health_ratio := clampf(unit.health / unit.spec.max_health, 0.0, 1.0)
	var health_bar := Rect2(center + Vector2(-radius, -radius - 5.0), Vector2(radius * 2.0, 2.0))
	draw_rect(health_bar, Color(0.08, 0.06, 0.09, 1.0), true)
	draw_rect(
		Rect2(health_bar.position, Vector2(health_bar.size.x * health_ratio, health_bar.size.y)),
		color.lightened(0.18),
		true
	)
	if unit.weakness_flash_ticks > 0:
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-18.0, -radius - 9.0),
			"弱点!",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			Color(1.0, 0.78, 0.25)
		)


func _draw_unit_shape(unit_id: StringName, center: Vector2, radius: float, color: Color) -> void:
	match unit_id:
		&"sentinel":
			draw_rect(Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)), color, true)
		&"golem":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -radius),
				center + Vector2(radius, 0),
				center + Vector2(0, radius),
				center + Vector2(-radius, 0),
			]), color)
		&"swarm":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -radius),
				center + Vector2(radius, radius),
				center + Vector2(-radius, radius),
			]), color)
		&"brute":
			draw_rect(Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)), color, true)
		_:
			draw_circle(center, radius, color)


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
