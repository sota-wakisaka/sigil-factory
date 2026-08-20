extends SceneTree

const MENU_SCENE := "res://src/main_menu.tscn"
const MVP_SCENE := "res://src/main.tscn"
const SEAL_LAB_SCENE := "res://experiments/seal_lab/seal_lab.tscn"

var failures := 0


func _initialize() -> void:
	_expect(
		ProjectSettings.get_setting("application/run/main_scene") == MENU_SCENE,
		"the project should boot into the mode selection menu"
	)
	await _change_scene(MENU_SCENE)
	var menu = current_scene
	_expect(menu != null and menu.name == "MainMenu", "main menu scene should load")
	if menu == null:
		_finish()
		return
	_expect(menu.mvp_button.visible and menu.seal_lab_button.visible, "both mode choices should be visible")
	_expect(menu.destination_for(&"mvp") == MVP_SCENE, "MVP choice should target the existing game scene")
	_expect(menu.destination_for(&"seal_lab") == SEAL_LAB_SCENE, "Seal Lab choice should target the comparison scene")

	menu.mvp_button.pressed.emit()
	await scene_changed
	_expect(current_scene != null and current_scene.name == "Main", "MVP button should open the existing MVP")
	if current_scene != null:
		var mvp_back: Button = current_scene.get_node_or_null("MenuButton")
		_expect(mvp_back != null and mvp_back.visible, "MVP should expose a menu return button")
		if mvp_back != null:
			mvp_back.pressed.emit()
			await scene_changed

	_expect(current_scene != null and current_scene.name == "MainMenu", "MVP return should restore the menu")
	if current_scene != null:
		current_scene.seal_lab_button.pressed.emit()
		await scene_changed

	_expect(current_scene != null and current_scene.name == "SealLab", "Seal Lab button should open Seal Lab")
	if current_scene != null:
		_expect(
			current_scene.menu_button != null and current_scene.menu_button.visible,
			"Seal Lab should expose a menu return button"
		)
		if current_scene.menu_button != null:
			current_scene.menu_button.pressed.emit()
			await scene_changed

	_expect(current_scene != null and current_scene.name == "MainMenu", "Seal Lab return should restore the menu")
	_finish()


func _change_scene(path: String) -> void:
	var error := change_scene_to_file(path)
	_expect(error == OK, "scene request should be accepted: %s" % path)
	if error == OK:
		await scene_changed


func _finish() -> void:
	if failures == 0:
		print("Main menu navigation test passed.")
	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: " + message)
