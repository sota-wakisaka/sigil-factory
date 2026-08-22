extends SceneTree

const MENU_SCENE := "res://src/main_menu.tscn"

var failures := 0


func _initialize() -> void:
	_expect(
		ProjectSettings.get_setting("application/run/main_scene") == MENU_SCENE,
		"the project should boot into the main menu"
	)
	await _change_scene(MENU_SCENE)
	_expect(current_scene != null and current_scene.name == "MainMenu", "the main menu should load")
	if current_scene == null:
		_finish()
		return

	current_scene.factory_button.pressed.emit()
	await scene_changed
	_expect(current_scene != null and current_scene.name == "RuneFactoryPrototype", "the Rune Factory button should open the factory")
	if current_scene != null:
		var factory_back: Button = current_scene.find_child("BackButton", true, false)
		_expect(factory_back != null and factory_back.visible, "the factory should expose a menu return button")
		if factory_back != null:
			factory_back.pressed.emit()
			await scene_changed

	_expect(current_scene != null and current_scene.name == "MainMenu", "the factory return should restore the menu")
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
	printerr("FAIL: %s" % message)
