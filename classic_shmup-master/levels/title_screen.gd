extends Control





func _on_start_button_pressed() -> void:
	GameProgress.start_new_run()
	get_tree().change_scene_to_file("res://levels/overworld.tscn")


func _on_tutorial_button_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/tutorial_screen.tscn")


func _on_test_button_pressed() -> void:
	# Dev/test-only shortcut - see levels/test_menu.gd. Jumps straight into
	# any level with any power-ups pre-applied, bypassing the overworld run
	# entirely (GameProgress is never touched here).
	get_tree().change_scene_to_file("res://levels/test_menu.tscn")

