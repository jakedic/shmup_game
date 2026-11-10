extends Control
const TestOptions := preload("res://test_options.gd")
const MenuKeys := preload("res://menu_keys.gd")   # W/S or arrows to move, J/Space/Enter to pick


func _ready() -> void:
	# Back at the title = no longer in a Test-menu launch (see
	# TestOptions.launched_from_test_menu).
	TestOptions.launched_from_test_menu = false
	MenuKeys.focus_first(_buttons())
	_opened_msec = Time.get_ticks_msec()


var _opened_msec := 0


func _buttons() -> Array:
	return [$StartButton, $TutorialButton, $TestButton]


func _input(event: InputEvent) -> void:
	if MenuKeys.is_confirm(event) and MenuKeys.too_soon(_opened_msec):
		get_viewport().set_input_as_handled()
		return
	MenuKeys.handle_buttons(event, _buttons())





func _on_start_button_pressed() -> void:
	GameProgress.start_new_run()
	GameShell.change_scene("res://levels/overworld.tscn")


func _on_tutorial_button_pressed() -> void:
	GameShell.change_scene("res://levels/tutorial_screen.tscn")


func _on_test_button_pressed() -> void:
	# Dev/test-only shortcut - see levels/test_menu.gd. Jumps straight into
	# any level with any power-ups pre-applied, bypassing the overworld run
	# entirely (GameProgress is never touched here).
	GameShell.change_scene("res://levels/test_menu.tscn")

