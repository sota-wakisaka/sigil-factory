extends SceneTree

const SealRendererModel := preload("res://src/sigil_v2/seal_renderer.gd")

var failures := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://experiments/seal_lab/seal_lab.tscn")
	var lab = scene.instantiate()
	root.add_child(lab)
	await process_frame
	await process_frame

	_expect(lab.fixtures.size() == 10, "Seal Lab should expose ten fixtures")
	_expect(lab.catalog_buttons.size() == 10, "catalog should expose all fixtures without changing the main scene")
	_expect(lab.large_views.size() == 2, "large comparison should show current and hypothetical together")
	_expect(lab.small_views.size() == 12, "LOD matrix should show three modes, two states, and two sizes")
	_expect(lab.selected_index == 9, "hero seal should be the default visual QA selection")
	_expect(lab.large_presentation == &"ceremonial", "large hero comparison should open in ceremonial mode")
	_expect(_hero_orbit_radii(lab).size() == 3, "hero seal should expose three distinct concentric orbit layers")
	_expect(SealRendererModel.circuit_uses_compact_proxy(48), "48px should use the compact circuit proxy")
	_expect(SealRendererModel.circuit_uses_compact_proxy(49), "49px should retain a circuit proxy")
	_expect(SealRendererModel.circuit_uses_compact_proxy(55), "55px should retain a circuit proxy")
	_expect(not SealRendererModel.circuit_uses_compact_proxy(56), "56px should stop using the compact circuit proxy")
	_expect(not SealRendererModel.circuit_uses_full_edges(48), "48px should not draw full circuit edges")
	_expect(not SealRendererModel.circuit_uses_full_edges(49), "49px should not draw full circuit edges")
	_expect(not SealRendererModel.circuit_uses_full_edges(55), "55px should not draw full circuit edges")
	_expect(SealRendererModel.circuit_uses_full_edges(56), "56px should draw full circuit edges")
	_expect(_views_share_compiled_plans(lab), "Seal Lab views should retain shared immutable plan references")

	var before_snapshots := _selected_snapshots(lab)
	var before_update_counts := _view_update_counts(lab)
	lab.set_grayscale(true)
	lab.set_large_presentation(&"editing")
	for progress in [0.1, 0.2, 0.35, 0.7, 1.0]:
		lab.set_animation_progress(progress)
	await process_frame
	_expect(lab.grayscale, "grayscale QA mode should be selectable")
	_expect(lab.large_presentation == &"editing", "large comparison should switch presentation without recompiling")
	_expect(is_equal_approx(lab.animation_progress, 1.0), "animation scrubber should preserve its exact comparison time")
	_expect(before_snapshots == _selected_snapshots(lab), "presentation, grayscale, and animation must not alter meaning plans")
	_expect(before_update_counts == _view_update_counts(lab), "visual-only updates must not configure views or copy commands")

	lab.select_fixture(7)
	await process_frame
	_expect(lab.selected_index == 7, "catalog selection should update the comparison fixture")
	_expect(lab.catalog_buttons[7].button_pressed, "selected fixture should retain a visible catalog state")
	_expect(not lab.catalog_buttons[9].button_pressed, "previous catalog selection should clear")

	lab.free()
	if failures == 0:
		print("All Seal Lab UI tests passed.")
	quit(failures)


func _selected_snapshots(lab) -> Array[String]:
	var selected: Dictionary = lab.compiled_fixtures[lab.selected_index]
	return [
		selected["current"]["plan"].command_snapshot(),
		selected["hypothetical"]["plan"].command_snapshot(),
	]


func _hero_orbit_radii(lab) -> Array[int]:
	var radii: Array[int] = []
	var plan = lab.compiled_fixtures[9]["current"]["plan"]
	for command in plan.commands:
		if StringName(command.get("kind", &"")) != &"orbit_signature":
			continue
		var radius := int(command.get("radius", 0))
		if not radii.has(radius):
			radii.append(radius)
	radii.sort()
	return radii


func _views_share_compiled_plans(lab) -> bool:
	for index in lab.catalog_views.size():
		var expected = lab.compiled_fixtures[index]["current"]["plan"]
		if lab.catalog_views[index].plan != expected:
			return false
	var selected: Dictionary = lab.compiled_fixtures[lab.selected_index]
	for entry in lab.large_views:
		if entry["view"].plan != selected[String(entry["state"])]["plan"]:
			return false
	for entry in lab.small_views:
		if entry["view"].plan != selected[String(entry["state"])]["plan"]:
			return false
	return true


func _view_update_counts(lab) -> Array[String]:
	var counts: Array[String] = []
	for view in lab.catalog_views:
		counts.append("%d:%d" % [view.configure_count, view.command_copy_count])
	for entry in lab.large_views:
		var view = entry["view"]
		counts.append("%d:%d" % [view.configure_count, view.command_copy_count])
	for entry in lab.small_views:
		var view = entry["view"]
		counts.append("%d:%d" % [view.configure_count, view.command_copy_count])
	return counts


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: " + message)
