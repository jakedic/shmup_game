extends Control

@onready var resume_button: Button = $Panel/VBoxContainer/Resume
@onready var panel: Panel = $Panel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var game = get_tree().current_scene
		if game == null or not game.get("playing"):
			return

		if get_tree().paused:
			resume_game()
		else:
			pause_game()

func pause_game() -> void:
	get_tree().paused = true
	show()
	resume_button.grab_focus()

func resume_game() -> void:
	get_tree().paused = false
	hide()

func _on_resume_pressed() -> void:
	resume_game()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://levels/title_screen.tscn")
