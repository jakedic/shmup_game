extends MarginContainer

@onready var shield_bar = $VBoxContainer/HBoxContainer/ShieldBar
@onready var score_counter = $VBoxContainer/HBoxContainer/ScoreCounter
@onready var score_multiplier = $VBoxContainer/HBoxContainer/ScoreMultiplier

func update_score(value):
	score_counter.display_digits(value)
	

func update_shield(max_value, value):
	shield_bar.max_value = max_value
	shield_bar.value = value

func update_score_multiplier(value):
	score_multiplier.display_digits(value)
