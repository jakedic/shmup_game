extends Control





func _on_start_button_pressed() -> void:
	GameProgress.start_new_run()
	get_tree().change_scene_to_file("res://levels/overworld.tscn")


func _on_tutorial_button_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/tutorial_screen.tscn")

