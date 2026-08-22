class_name RunePacket
extends RefCounted

const SCRIPT_PATH := "res://src/rune/rune_packet.gd"

const ATTRIBUTE_COUNT := 3
const RUNES_PER_ATTRIBUTE := 8
const RUNE_TYPE_COUNT := ATTRIBUTE_COUNT * RUNES_PER_ATTRIBUTE
const MAX_RUNES := 8

const ATTRIBUTES: Array[StringName] = [&"red", &"blue", &"green"]
const ATTRIBUTE_LABELS := ["赤", "青", "緑"]
const ATTRIBUTE_COLORS := [
	Color(0.96, 0.34, 0.34),
	Color(0.30, 0.64, 1.0),
	Color(0.30, 0.86, 0.54),
]
const RUNE_SYMBOLS := [
	"ᚠ", "ᚢ", "ᚦ", "ᚨ", "ᚱ", "ᚲ", "ᚷ", "ᚹ",
	"ᚺ", "ᚾ", "ᛁ", "ᛃ", "ᛇ", "ᛈ", "ᛉ", "ᛊ",
	"ᛏ", "ᛒ", "ᛖ", "ᛗ", "ᛚ", "ᛜ", "ᛞ", "ᛟ",
]

# The eight runes of every attribute occupy a 3x3 board whose center is a sink.
const POSITION_COORDS := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var _counts := PackedInt32Array()


func _init(next_counts: PackedInt32Array = PackedInt32Array()) -> void:
	_counts.resize(RUNE_TYPE_COUNT)
	_counts.fill(0)
	for index in mini(next_counts.size(), RUNE_TYPE_COUNT):
		_counts[index] = maxi(int(next_counts[index]), 0)


static func empty():
	return _create()


static func singleton(attribute_index: int, position_index: int):
	if not valid_address(attribute_index, position_index):
		return null
	var counts := PackedInt32Array()
	counts.resize(RUNE_TYPE_COUNT)
	counts.fill(0)
	counts[rune_id(attribute_index, position_index)] = 1
	return _create(counts)


static func from_rune_ids(rune_ids: Array):
	if rune_ids.size() > MAX_RUNES:
		return null
	var counts := PackedInt32Array()
	counts.resize(RUNE_TYPE_COUNT)
	counts.fill(0)
	for value in rune_ids:
		var id: int = int(value)
		if id < 0 or id >= RUNE_TYPE_COUNT:
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


func count_for(attribute_index: int, position_index: int) -> int:
	if not valid_address(attribute_index, position_index):
		return 0
	return int(_counts[rune_id(attribute_index, position_index)])


func count_for_id(id: int) -> int:
	return int(_counts[id]) if id >= 0 and id < RUNE_TYPE_COUNT else 0


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
	for attribute_index in ATTRIBUTE_COUNT:
		for position_index in RUNES_PER_ATTRIBUTE:
			var amount := count_for(attribute_index, position_index)
			if amount <= 0:
				continue
			var destination: Vector2i = Vector2i(POSITION_COORDS[position_index]) + direction
			# The center, the outside of the board, and an attribute boundary are sinks.
			var destination_index := position_index_for_coord(destination)
			if destination_index < 0:
				continue
			result[rune_id(attribute_index, destination_index)] += amount
	return _create(result)


func shifted_preview(direction: Vector2i) -> Dictionary:
	var output = shifted(direction)
	if output == null:
		return {"ok": false, "output": null, "removed": empty()}
	var removed_counts := PackedInt32Array()
	removed_counts.resize(RUNE_TYPE_COUNT)
	removed_counts.fill(0)
	for attribute_index in ATTRIBUTE_COUNT:
		for position_index in RUNES_PER_ATTRIBUTE:
			var amount := count_for(attribute_index, position_index)
			if amount <= 0:
				continue
			if position_index_for_coord(POSITION_COORDS[position_index] + direction) < 0:
				removed_counts[rune_id(attribute_index, position_index)] = amount
	return {
		"ok": true,
		"output": output,
		"removed": _create(removed_counts),
	}


func attuned(delta: int):
	if delta == 0:
		return copy()
	var result := PackedInt32Array()
	result.resize(RUNE_TYPE_COUNT)
	result.fill(0)
	for attribute_index in ATTRIBUTE_COUNT:
		var destination_attribute := posmod(attribute_index + delta, ATTRIBUTE_COUNT)
		for position_index in RUNES_PER_ATTRIBUTE:
			result[rune_id(destination_attribute, position_index)] += count_for(
				attribute_index,
				position_index
			)
	return _create(result)


func extracted(selector_kind: StringName, selector_value: int) -> Dictionary:
	var selected := PackedInt32Array()
	var remainder := PackedInt32Array()
	selected.resize(RUNE_TYPE_COUNT)
	remainder.resize(RUNE_TYPE_COUNT)
	selected.fill(0)
	remainder.fill(0)
	if selector_kind not in [&"attribute", &"position"]:
		return {"ok": false, "selected": null, "remainder": null}
	if (
		(selector_kind == &"attribute" and (selector_value < 0 or selector_value >= ATTRIBUTE_COUNT))
		or (selector_kind == &"position" and (selector_value < 0 or selector_value >= RUNES_PER_ATTRIBUTE))
	):
		return {"ok": false, "selected": null, "remainder": null}
	for id in RUNE_TYPE_COUNT:
		var matches := (
			attribute_for_id(id) == selector_value
			if selector_kind == &"attribute"
			else position_for_id(id) == selector_value
		)
		if matches:
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
	return "RUNE_PACKET_V1[%s]" % ",".join(fields)


func short_label() -> String:
	if is_empty():
		return "∅"
	var labels := PackedStringArray()
	for id in rune_ids_expanded():
		labels.append("%s%s" % [ATTRIBUTE_LABELS[attribute_for_id(id)], position_for_id(id) + 1])
	return " ".join(labels)


static func rune_id(attribute_index: int, position_index: int) -> int:
	return attribute_index * RUNES_PER_ATTRIBUTE + position_index


static func attribute_for_id(id: int) -> int:
	return int(id / RUNES_PER_ATTRIBUTE)


static func position_for_id(id: int) -> int:
	return posmod(id, RUNES_PER_ATTRIBUTE)


static func valid_address(attribute_index: int, position_index: int) -> bool:
	return (
		attribute_index >= 0
		and attribute_index < ATTRIBUTE_COUNT
		and position_index >= 0
		and position_index < RUNES_PER_ATTRIBUTE
	)


static func position_index_for_coord(coord: Vector2i) -> int:
	if coord == Vector2i.ZERO or absi(coord.x) > 1 or absi(coord.y) > 1:
		return -1
	return POSITION_COORDS.find(coord)


static func rune_symbol(id: int) -> String:
	return RUNE_SYMBOLS[id] if id >= 0 and id < RUNE_SYMBOLS.size() else "?"


static func attribute_color(attribute_index: int) -> Color:
	return ATTRIBUTE_COLORS[attribute_index] if attribute_index >= 0 and attribute_index < ATTRIBUTE_COLORS.size() else Color.WHITE
