class_name RunePacket
extends RefCounted

const SCRIPT_PATH := "res://src/rune/rune_packet.gd"

const RUNE_TYPE_COUNT := 24
const MAX_RUNES := 8
const RUNE_BOARD_RADIUS := 3
const SINK_RING_RADIUS := 4

# The twenty-four live cells form a Manhattan diamond around a central sink.
# A one-cell move from the live outer edge always lands on the visible sink ring.
const RUNE_COORDS: Array[Vector2i] = [
	Vector2i(0, -3),
	Vector2i(-1, -2), Vector2i(0, -2), Vector2i(1, -2),
	Vector2i(-2, -1), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1),
	Vector2i(-3, 0), Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(-2, 1), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
	Vector2i(-1, 2), Vector2i(0, 2), Vector2i(1, 2),
	Vector2i(0, 3),
]
const RUNE_SYMBOLS := [
	"ᚠ", "ᚢ", "ᚦ", "ᚨ", "ᚱ", "ᚲ", "ᚷ", "ᚹ",
	"ᚺ", "ᚾ", "ᛁ", "ᛃ", "ᛇ", "ᛈ", "ᛉ", "ᛊ",
	"ᛏ", "ᛒ", "ᛖ", "ᛗ", "ᛚ", "ᛜ", "ᛞ", "ᛟ",
]
const RUNE_COLOR := Color(0.48, 0.84, 1.0)
const SINK_COLOR := Color(1.0, 0.42, 0.46)

var _counts := PackedInt32Array()


func _init(next_counts: PackedInt32Array = PackedInt32Array()) -> void:
	_counts.resize(RUNE_TYPE_COUNT)
	_counts.fill(0)
	for index in mini(next_counts.size(), RUNE_TYPE_COUNT):
		_counts[index] = maxi(int(next_counts[index]), 0)


static func empty():
	return _create()


static func singleton(rune_index: int):
	if not valid_rune_id(rune_index):
		return null
	var counts := PackedInt32Array()
	counts.resize(RUNE_TYPE_COUNT)
	counts.fill(0)
	counts[rune_index] = 1
	return _create(counts)


static func from_rune_ids(rune_ids: Array):
	if rune_ids.size() > MAX_RUNES:
		return null
	var counts := PackedInt32Array()
	counts.resize(RUNE_TYPE_COUNT)
	counts.fill(0)
	for value in rune_ids:
		var id := int(value)
		if not valid_rune_id(id):
			return null
		counts[id] += 1
	return _create(counts)


func copy():
	return _create(_counts.duplicate())


func counts_copy() -> PackedInt32Array:
	return _counts.duplicate()


func total_count() -> int:
	var total := 0
	for count in _counts:
		total += int(count)
	return total


func is_empty() -> bool:
	return total_count() == 0


func count_for(rune_index: int) -> int:
	return int(_counts[rune_index]) if valid_rune_id(rune_index) else 0


func count_for_id(id: int) -> int:
	return count_for(id)


func rune_ids_expanded() -> Array[int]:
	var result: Array[int] = []
	for id in RUNE_TYPE_COUNT:
		for _copy_index in int(_counts[id]):
			result.append(id)
	return result


func shifted(direction: Vector2i):
	if direction not in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		return null
	var result := PackedInt32Array()
	result.resize(RUNE_TYPE_COUNT)
	result.fill(0)
	for id in RUNE_TYPE_COUNT:
		var amount := count_for(id)
		if amount <= 0:
			continue
		var destination_id := rune_id_for_coord(coord_for_id(id) + direction)
		if destination_id >= 0:
			result[destination_id] += amount
	return _create(result)


func shifted_preview(direction: Vector2i) -> Dictionary:
	var output = shifted(direction)
	if output == null:
		return {"ok": false, "output": null, "removed": empty(), "direction": Vector2i.ZERO}
	var removed_counts := PackedInt32Array()
	removed_counts.resize(RUNE_TYPE_COUNT)
	removed_counts.fill(0)
	for id in RUNE_TYPE_COUNT:
		var amount := count_for(id)
		if amount > 0 and rune_id_for_coord(coord_for_id(id) + direction) < 0:
			removed_counts[id] = amount
	return {
		"ok": true,
		"output": output,
		"removed": _create(removed_counts),
		"direction": direction,
	}


func extracted(selector_kind: StringName, selector_value: int) -> Dictionary:
	var selected := PackedInt32Array()
	var remainder := PackedInt32Array()
	selected.resize(RUNE_TYPE_COUNT)
	remainder.resize(RUNE_TYPE_COUNT)
	selected.fill(0)
	remainder.fill(0)
	if selector_kind != &"ring" or selector_value < 1 or selector_value > RUNE_BOARD_RADIUS:
		return {"ok": false, "selected": null, "remainder": null}
	for id in RUNE_TYPE_COUNT:
		if ring_for_id(id) == selector_value:
			selected[id] = _counts[id]
		else:
			remainder[id] = _counts[id]
	return {
		"ok": true,
		"selected": _create(selected),
		"remainder": _create(remainder),
	}


func merged(other):
	if other == null or total_count() + other.total_count() > MAX_RUNES:
		return null
	var result := _counts.duplicate()
	for id in RUNE_TYPE_COUNT:
		result[id] += other.count_for_id(id)
	return _create(result)


func matches(other) -> bool:
	return other != null and _counts == other._counts


static func _create(counts: PackedInt32Array = PackedInt32Array()):
	# Loading through the script resource keeps command-line startup independent
	# from Godot's generated global class cache after a fresh checkout/cherry-pick.
	var script := load(SCRIPT_PATH) as GDScript
	return script.new(counts) if script != null else null


func canonical_code() -> String:
	var fields := PackedStringArray()
	for id in RUNE_TYPE_COUNT:
		if _counts[id] > 0:
			fields.append("%d:%d" % [id, _counts[id]])
	return "RUNE_PACKET_V2[%s]" % ",".join(fields)


func short_label() -> String:
	if is_empty():
		return "∅"
	var labels := PackedStringArray()
	for id in rune_ids_expanded():
		labels.append("%s%02d" % [rune_symbol(id), id + 1])
	return " ".join(labels)


static func valid_rune_id(id: int) -> bool:
	return id >= 0 and id < RUNE_TYPE_COUNT


static func coord_for_id(id: int) -> Vector2i:
	return RUNE_COORDS[id] if valid_rune_id(id) else Vector2i(999, 999)


static func rune_id_for_coord(coord: Vector2i) -> int:
	return RUNE_COORDS.find(coord)


static func ring_for_id(id: int) -> int:
	var coord := coord_for_id(id)
	return absi(coord.x) + absi(coord.y) if valid_rune_id(id) else -1


static func is_sink_coord(coord: Vector2i) -> bool:
	var distance := absi(coord.x) + absi(coord.y)
	return coord == Vector2i.ZERO or distance == SINK_RING_RADIUS


static func is_display_coord(coord: Vector2i) -> bool:
	return absi(coord.x) + absi(coord.y) <= SINK_RING_RADIUS


static func rune_symbol(id: int) -> String:
	return RUNE_SYMBOLS[id] if valid_rune_id(id) else "?"


static func rune_color(_id: int = -1) -> Color:
	return RUNE_COLOR
