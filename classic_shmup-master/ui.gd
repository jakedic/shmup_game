extends MarginContainer

# The HUD now lives in the side panels around the play area (see
# game_shell.gd). This node stays in every level so existing references
# ($CanvasLayer/UI, the player's shield_changed connection) keep working, but
# it hides itself and forwards everything to GameShell.

@onready var shield_bar = $VBoxContainer/HBoxContainer/ShieldBar
@onready var score_counter = $VBoxContainer/HBoxContainer/ScoreCounter
@onready var score_multiplier = $VBoxContainer/HBoxContainer2/Label

func _ready():
	hide()
	GameShell.hud_attach()

func _exit_tree():
	GameShell.hud_detach()

func update_score(value):
	score_counter.display_digits(value)
	GameShell.update_score(value)

func update_shield(max_value, value):
	shield_bar.max_value = max_value
	shield_bar.value = value
	GameShell.update_shield(max_value, value)

func update_score_multiplier(value):
	#score_multiplier.display_digits(value)
	score_multiplier.text = str(value)+"x"
	GameShell.update_score_multiplier(value)

func update_multiplier_progress(kills, kills_needed, at_max):
	GameShell.update_multiplier_progress(kills, kills_needed, at_max)

func set_multiplier_timer(timer):
	GameShell.set_multiplier_timer(timer)
