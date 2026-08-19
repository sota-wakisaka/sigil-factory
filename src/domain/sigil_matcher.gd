class_name SigilMatcher
extends RefCounted


static func compare(actual: GlyphModel, target: GlyphModel) -> Dictionary:
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

	for target_component in target.components:
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

	for index in actual.components.size():
		if not used_actual_indices.has(index):
			_add_unique(
				diagnostics,
				"余分な部品: %s" % actual.components[index].primitive_id
			)

	return {
		"is_match": false,
		"diagnostics": diagnostics,
	}


static func _find_closest_component(
	target_component: GlyphComponentModel,
	actual_components: Array[GlyphComponentModel],
	used_indices: Dictionary
) -> int:
	var best_index := -1
	var best_score := 1_000_000
	for index in actual_components.size():
		if used_indices.has(index):
			continue
		var candidate := actual_components[index]
		if candidate.primitive_id != target_component.primitive_id:
			continue
		var score := _difference_score(candidate, target_component)
		if score < best_score:
			best_score = score
			best_index = index
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
	if actual.position != target.position:
		_add_unique(diagnostics, "位置が違います")
	if actual.rotation_step != target.rotation_step:
		_add_unique(diagnostics, "回転が違います")
	if actual.scale_step != target.scale_step:
		_add_unique(diagnostics, "倍率が違います")
	if actual.color_id != target.color_id:
		_add_unique(diagnostics, "色が違います")


static func _add_unique(values: PackedStringArray, value: String) -> void:
	if not values.has(value):
		values.append(value)
