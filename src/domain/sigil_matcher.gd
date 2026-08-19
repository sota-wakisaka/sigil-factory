class_name SigilMatcher
extends RefCounted


static func compare(actual: GlyphModel, target: GlyphModel) -> Dictionary:
	if actual == null:
		return _invalid_result(PackedStringArray(["入力グリフがありません"]))
	if target == null:
		return _invalid_result(PackedStringArray(["シジル定義がありません"]))
	var actual_structure_diagnostics := _structure_diagnostics(
		actual.structure_validation_errors(),
		"入力グリフ構造が不正です"
	)
	if not actual_structure_diagnostics.is_empty():
		return _invalid_result(actual_structure_diagnostics)
	var target_structure_diagnostics := _structure_diagnostics(
		target.structure_validation_errors(),
		"シジル定義エラー"
	)
	if not target_structure_diagnostics.is_empty():
		return _invalid_result(target_structure_diagnostics)
	var actual_overlaps := actual.complete_overlap_primitive_ids()
	if not actual_overlaps.is_empty():
		return {
			"is_match": false,
			"diagnostics": PackedStringArray([
				"完全重複した部品があります: %s" % ", ".join(actual_overlaps),
			]),
		}
	var target_overlaps := target.complete_overlap_primitive_ids()
	if not target_overlaps.is_empty():
		return {
			"is_match": false,
			"diagnostics": PackedStringArray([
				"シジル定義エラー: 完全重複: %s" % ", ".join(target_overlaps),
			]),
		}
	var actual_serialization := actual.canonical_serialization()
	var target_serialization := target.canonical_serialization()
	var hashes_match := actual_serialization.sha256_text() == target_serialization.sha256_text()
	if hashes_match and actual_serialization == target_serialization:
		return {
			"is_match": true,
			"diagnostics": PackedStringArray(),
		}

	var diagnostics := PackedStringArray()
	if actual.canonical_keys() == target.canonical_keys():
		_add_unique(diagnostics, "合成階層が違います")
	var used_actual_indices: Dictionary = {}
	var target_components: Array[GlyphComponentModel] = target.components.duplicate()
	target_components.sort_custom(
		func(first: GlyphComponentModel, second: GlyphComponentModel) -> bool:
			return first.canonical_key() < second.canonical_key()
	)

	for target_component in target_components:
		var actual_index := _find_closest_component(
			target_component,
			actual.components,
			used_actual_indices
		)
		if actual_index < 0:
			_add_unique(diagnostics, "部品不足: %s" % target_component.primitive_id)
			continue

		used_actual_indices[actual_index] = true
		_append_component_differences(
			actual.components[actual_index],
			target_component,
			diagnostics
		)

	var actual_indices := range(actual.components.size())
	actual_indices.sort_custom(
		func(first: int, second: int) -> bool:
			return actual.components[first].canonical_key() < actual.components[second].canonical_key()
	)
	for index in actual_indices:
		if not used_actual_indices.has(index):
			_add_unique(
				diagnostics,
				"余分な部品: %s" % actual.components[index].primitive_id
			)

	return {
		"is_match": false,
		"diagnostics": _ordered_diagnostics(diagnostics),
	}


static func _structure_diagnostics(
	structure_errors: PackedStringArray,
	prefix: String
) -> PackedStringArray:
	var diagnostics := PackedStringArray()
	for structure_error in structure_errors:
		if not (
			structure_error.begins_with("invalid_component:")
			or structure_error.begins_with("invalid_child:")
			or structure_error.begins_with("cyclic_structure:")
		):
			continue
		diagnostics.append("%s: %s" % [prefix, structure_error])
	return diagnostics


static func _invalid_result(diagnostics: PackedStringArray) -> Dictionary:
	return {"is_match": false, "diagnostics": diagnostics}


static func _find_closest_component(
	target_component: GlyphComponentModel,
	actual_components: Array[GlyphComponentModel],
	used_indices: Dictionary
) -> int:
	var best_index := -1
	var best_score := 1_000_000
	var best_key := ""
	for index in actual_components.size():
		if used_indices.has(index):
			continue
		var candidate := actual_components[index]
		if candidate.primitive_id != target_component.primitive_id:
			continue
		var score := _difference_score(candidate, target_component)
		var candidate_key := candidate.canonical_key()
		if score < best_score or (score == best_score and candidate_key < best_key):
			best_score = score
			best_index = index
			best_key = candidate_key
	return best_index


static func _difference_score(
	actual: GlyphComponentModel,
	target: GlyphComponentModel
) -> int:
	var score := 0
	score += int(actual.position != target.position)
	score += int(actual.rotation_step != target.rotation_step)
	score += int(actual.scale_step != target.scale_step)
	score += int(actual.color_id != target.color_id)
	return score


static func _append_component_differences(
	actual: GlyphComponentModel,
	target: GlyphComponentModel,
	diagnostics: PackedStringArray
) -> void:
	if actual.color_id != target.color_id:
		_add_unique(diagnostics, "色が違います")
	if actual.rotation_step != target.rotation_step:
		_add_unique(diagnostics, "回転が違います")
	if actual.scale_step != target.scale_step:
		_add_unique(diagnostics, "倍率が違います")
	if actual.position != target.position:
		_add_unique(diagnostics, "位置が違います")


static func _ordered_diagnostics(values: PackedStringArray) -> PackedStringArray:
	var ordered: Array[String] = []
	for value in values:
		ordered.append(value)
	ordered.sort_custom(
		func(first: String, second: String) -> bool:
			var first_priority := _diagnostic_priority(first)
			var second_priority := _diagnostic_priority(second)
			if first_priority != second_priority:
				return first_priority < second_priority
			return first < second
	)
	return PackedStringArray(ordered)


static func _diagnostic_priority(value: String) -> int:
	if value.begins_with("部品不足:"):
		return 0
	if value.begins_with("余分な部品:"):
		return 1
	if value == "色が違います":
		return 2
	if value == "回転が違います":
		return 3
	if value == "倍率が違います":
		return 4
	if value == "位置が違います":
		return 5
	if value == "合成階層が違います":
		return 6
	return 7


static func _add_unique(values: PackedStringArray, value: String) -> void:
	if not values.has(value):
		values.append(value)
