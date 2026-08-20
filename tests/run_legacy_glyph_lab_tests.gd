extends SceneTree

const LegacyContentModel := preload("res://experiments/seal_lab/legacy_glyph_lab_content.gd")
const GlyphPainterModel := preload("res://src/ui/glyph_painter.gd")

const V2_LAB_SCENE := "res://experiments/seal_lab/seal_lab.tscn"
const LEGACY_LAB_SCENE := "res://experiments/seal_lab/legacy_glyph_lab.tscn"
const MENU_SCENE := "res://src/main_menu.tscn"

var failures := 0


func _initialize() -> void:
	var fixtures := LegacyContentModel.fixtures()
	var expected_leaf_counts := [2, 4, 6, 8, 10, 12]
	_expect(fixtures.size() == expected_leaf_counts.size(), "legacy comparison should expose six complexity steps")
	for index in fixtures.size():
		var fixture: Dictionary = fixtures[index]
		var glyph = fixture["glyph"]
		_expect(GlyphPainterModel.can_draw(glyph), "legacy fixture %d should use a drawable MVP Glyph" % (index + 1))
		_expect(glyph.components.size() == expected_leaf_counts[index], "legacy fixture leaf count should increase by step")
		_expect(not glyph.has_complete_overlap(), "legacy fixture should not hide identical material in a complete overlap")
		_expect(int(fixture["combine_count"]) == glyph.components.size() - 1, "legacy fixture should use binary Combine only")
		_expect(int(fixture["depth"]) >= 1, "legacy fixture should retain visible Combine hierarchy")

	await _change_scene(LEGACY_LAB_SCENE)
	var lab = current_scene
	_expect(lab != null and lab.name == "LegacyGlyphLab", "legacy comparison scene should load")
	if lab == null:
		_finish()
		return
	_expect(lab.fixtures.size() == 6, "legacy lab should show all six fixtures")
	_expect(lab.catalog_buttons.size() == 6, "legacy catalog should expose all complexity steps")
	_expect(lab.lod_views.size() == 3, "legacy lab should compare three display sizes")
	_expect(lab.selected_index == 5, "the twelve-material fixture should open by default")
	_expect(lab.large_view.glyph.canonical_serialization() == fixtures[5]["glyph"].canonical_serialization(), "large preview should use the actual MVP canonical Glyph")
	for view in lab.lod_views:
		_expect(view.glyph.canonical_serialization() == fixtures[5]["glyph"].canonical_serialization(), "all LOD views should show the same canonical Glyph")

	lab.select_fixture(2)
	await process_frame
	_expect(lab.selected_index == 2 and lab.catalog_buttons[2].button_pressed, "catalog selection should update the legacy preview")
	_expect(lab.large_view.glyph.components.size() == 6, "selected preview should update to the six-material fixture")

	lab.v2_button.pressed.emit()
	await scene_changed
	_expect(current_scene != null and current_scene.name == "SealLab", "legacy lab should return to the V2 Seal Lab")
	if current_scene != null:
		current_scene.legacy_button.pressed.emit()
		await scene_changed
	_expect(current_scene != null and current_scene.name == "LegacyGlyphLab", "V2 Seal Lab should open the MVP-method comparison")
	if current_scene != null:
		current_scene.menu_button.pressed.emit()
		await scene_changed
	_expect(current_scene != null and current_scene.name == "MainMenu", "legacy lab should return to the main menu")
	_finish()


func _change_scene(path: String) -> void:
	var error := change_scene_to_file(path)
	_expect(error == OK, "scene request should be accepted: %s" % path)
	if error == OK:
		await scene_changed


func _finish() -> void:
	if failures == 0:
		print("All legacy Glyph Lab tests passed.")
	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: " + message)
