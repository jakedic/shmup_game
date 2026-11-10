extends Control
const MenuKeys := preload("res://menu_keys.gd")   # W/S or arrows to scroll, J/Space/Enter for Back

const SCROLL_STEP := 24


func _ready() -> void:
	$Margin/VBoxContainer/BackButton.grab_focus()


func _input(event: InputEvent) -> void:
	var scroll: ScrollContainer = $Margin/VBoxContainer/ScrollContainer
	if event.is_action_pressed("down", true):
		scroll.scroll_vertical += SCROLL_STEP
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("up", true):
		scroll.scroll_vertical -= SCROLL_STEP
		get_viewport().set_input_as_handled()
	elif MenuKeys.is_confirm(event):
		get_viewport().set_input_as_handled()
		_on_back_button_pressed()


func _on_back_button_pressed() -> void:
	GameShell.change_scene("res://levels/title_screen.tscn")
