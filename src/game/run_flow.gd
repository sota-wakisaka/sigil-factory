class_name RunFlow
extends RefCounted

enum Phase {
	ROUTE_SELECTION,
	STAGE_INFO,
	FACTORY_BUILD,
	BATTLE,
	FACTORY_RECONFIGURE,
	VICTORY,
	REWARD,
}

var phase := Phase.ROUTE_SELECTION
var route_number := 1


func advance() -> bool:
	match phase:
		Phase.ROUTE_SELECTION:
			phase = Phase.STAGE_INFO
		Phase.STAGE_INFO:
			phase = Phase.FACTORY_BUILD
		Phase.FACTORY_BUILD:
			phase = Phase.BATTLE
		Phase.VICTORY:
			phase = Phase.REWARD
		Phase.REWARD:
			route_number += 1
			phase = Phase.ROUTE_SELECTION
		_:
			return false
	return true


func pause_for_reconfiguration() -> bool:
	if phase != Phase.BATTLE:
		return false
	phase = Phase.FACTORY_RECONFIGURE
	return true


func resume_battle() -> bool:
	if phase != Phase.FACTORY_RECONFIGURE:
		return false
	phase = Phase.BATTLE
	return true


func mark_victory() -> bool:
	if phase != Phase.BATTLE:
		return false
	phase = Phase.VICTORY
	return true


func phase_name() -> String:
	match phase:
		Phase.ROUTE_SELECTION:
			return "ルート選択"
		Phase.STAGE_INFO:
			return "ステージ情報"
		Phase.FACTORY_BUILD:
			return "工場を構築"
		Phase.BATTLE:
			return "リアルタイム戦闘"
		Phase.FACTORY_RECONFIGURE:
			return "時間停止・工場再構成"
		Phase.VICTORY:
			return "敵リーダー撃破"
		Phase.REWARD:
			return "報酬獲得"
	return ""
