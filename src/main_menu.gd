class_name SigilFactoryMainMenu
extends Control

const MVP_SCENE := "res://src/main.tscn"
const SIGIL_LAB_SCENE := "res://experiments/sigil_lab/sigil_lab.tscn"

const BACKGROUND := Color("050912")
const GRID := Color(0.18, 0.34, 0.48, 0.12)
const ACCENT := Color(0.34, 0.78, 1.0, 0.95)

@onready var mvp_button: Button = $Center/Content/Choices/MvpButton
@onready var sigil_lab_button: Button = $Center/Content/Choices/SigilLabButton


func _ready() -> void:
	mvp_button.pressed.connect(_open_scene.bind(MVP_SCENE))
	sigil_lab_button.pressed.connect(_open_scene.bind(SIGIL_LAB_SCENE))
	mvp_button.grab_focus()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND, true)
	for x in range(0, int(size.x) + 1, 40):
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID, 1.0)
	for y in range(0, int(size.y) + 1, 40):
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID, 1.0)
	var center := Vector2(size.x * 0.5, 122.0)
	for radius in [44.0, 58.0, 72.0]:
		draw_arc(center, radius, 0.0, TAU, 72, Color(ACCENT, 0.08), 1.0, true)
	for index in 8:
		var direction := Vector2.UP.rotated(float(index) * TAU / 8.0)
		draw_line(center + direction * 46.0, center + direction * 70.0, Color(ACCENT, 0.11), 1.0, true)


func destination_for(mode: StringName) -> String:
	return SIGIL_LAB_SCENE if mode == &"sigil_lab" else MVP_SCENE


func _open_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
