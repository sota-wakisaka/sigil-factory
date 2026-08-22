class_name FactoryFlowAudio
extends Node

const SAMPLE_RATE := 22050

var connection_player: AudioStreamPlayer
var disconnect_player: AudioStreamPlayer
var arrival_player: AudioStreamPlayer
var matched_connection_stream: AudioStreamWAV
var mismatch_connection_stream: AudioStreamWAV
var disconnect_stream: AudioStreamWAV
var arrival_streams: Dictionary = {}
var connection_play_count := 0
var disconnect_play_count := 0
var arrival_play_count := 0
var playback_enabled := true


func _exit_tree() -> void:
	for player in [connection_player, disconnect_player, arrival_player]:
		if player == null:
			continue
		player.stop()
		player.stream = null
	arrival_streams.clear()
	matched_connection_stream = null
	mismatch_connection_stream = null
	disconnect_stream = null


func configure() -> void:
	if connection_player != null:
		return
	playback_enabled = DisplayServer.get_name() != "headless"
	matched_connection_stream = _make_tone([620.0, 930.0], 0.14, 0.28)
	mismatch_connection_stream = _make_tone([270.0, 210.0], 0.16, 0.25)
	disconnect_stream = _make_tone([360.0, 190.0], 0.11, 0.22)
	arrival_streams = {
		&"circle": _make_tone([740.0, 1110.0], 0.12, 0.20),
		&"triangle": _make_tone([820.0, 1230.0], 0.10, 0.18),
		&"square": _make_tone([520.0, 780.0], 0.14, 0.22),
	}
	connection_player = _make_player("ConnectionSE", -14.0)
	disconnect_player = _make_player("DisconnectSE", -17.0)
	arrival_player = _make_player("ArrivalSE", -19.0)


func play_connection(matched: bool) -> void:
	if connection_player == null:
		return
	if playback_enabled:
		connection_player.stream = matched_connection_stream if matched else mismatch_connection_stream
		connection_player.play()
	connection_play_count += 1


func play_disconnect() -> void:
	if disconnect_player == null:
		return
	if playback_enabled:
		disconnect_player.stream = disconnect_stream
		disconnect_player.play()
	disconnect_play_count += 1


func play_arrival(material_kind: StringName) -> void:
	if arrival_player == null or not arrival_streams.has(material_kind):
		return
	if playback_enabled:
		arrival_player.stream = arrival_streams[material_kind]
		arrival_player.play()
	arrival_play_count += 1


func streams_ready() -> bool:
	if (
		matched_connection_stream == null
		or mismatch_connection_stream == null
		or disconnect_stream == null
	):
		return false
	for material_kind in [&"circle", &"triangle", &"square"]:
		if not arrival_streams.has(material_kind):
			return false
		var stream: AudioStreamWAV = arrival_streams[material_kind]
		if stream.data.is_empty():
			return false
	return (
		not matched_connection_stream.data.is_empty()
		and not mismatch_connection_stream.data.is_empty()
		and not disconnect_stream.data.is_empty()
	)


func _make_player(player_name: String, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.volume_db = volume_db
	add_child(player)
	return player


static func _make_tone(frequencies: Array, duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_count := maxi(int(ceil(float(SAMPLE_RATE) * duration)), 1)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for sample_index in sample_count:
		var time := float(sample_index) / float(SAMPLE_RATE)
		var attack := minf(time / 0.012, 1.0)
		var release := minf((duration - time) / 0.055, 1.0)
		var envelope := maxf(attack * release, 0.0) * exp(-2.2 * time / duration)
		var wave := 0.0
		for frequency in frequencies:
			wave += sin(TAU * float(frequency) * time)
		wave /= maxf(float(frequencies.size()), 1.0)
		var sample := clampi(roundi(wave * envelope * amplitude * 32767.0), -32767, 32767)
		data.encode_s16(sample_index * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
