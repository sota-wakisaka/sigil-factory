class_name FactoryDirectionalOverlay
extends Control

var controller
var layer: StringName = &"connections"


func configure(next_controller, next_layer: StringName) -> void:
	controller = next_controller
	layer = next_layer
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(controller):
		return
	controller.draw_directional_overlay(self, layer)
