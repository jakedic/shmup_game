# base_level.gd
class_name BaseLevel
extends Node2D

# Common variables for all levels
var score = 0
var playing = false
var wave = 0
var current_wave = 0
var max_waves = 3  # Default value, can be overridden
var score_multiplier = 2
var multiplier_increase_tracker = 0 #tracks when the multiplier should be increased
var multiplier_timer : Timer = Timer.new() #creates the multiplier timer variable
# Common UI elements (assumes similar structure in all levels)
@onready var start_button = $CanvasLayer/CenterContainer/Start
@onready var game_over = $CanvasLayer/CenterContainer/GameOver
@onready var ui = $CanvasLayer/UI

# Common nodes
@onready var enemy_anchor = $EnemyAnchor
@onready var camera = $Camera2D
@onready var player = $Player

# Override these in child classes
var enemy_scenes = []  # Array of enemy scenes to spawn
var level_paths = {}   # Dictionary of level paths for progression
var spawn_pattern = null  # Function to override for custom spawn patterns

func _ready():
	game_over.hide()
	start_button.show()
	setup_enemy_anchor_animation()
	initialize_level()
	add_child(multiplier_timer)
	multiplier_timer.autostart = false # tells the timer not to start on creation
	multiplier_timer.wait_time = 5.0 # defines how long the timer is
func start_score_multipliplier_timer():#this creates a function that checks if the score multiplier should start counting dowwn
	if score_multiplier >= 2:
		multiplier_timer.start()
		print(score_multiplier)
		multiplier_timer.wait_time = 5.0
	else:
		multiplier_timer.stop()
		print("timer does nothing")
		print(score_multiplier)
	multiplier_timer.timeout.connect(timeout_multiplier_timer)
# Virtual method - override in child classes
func initialize_level():
	# Child classes can override to set up level-specific data
	pass


func setup_enemy_anchor_animation():
	# Create the bobbing animation for enemy anchor
	var tween_x = create_tween().set_loops().set_parallel(false).set_trans(Tween.TRANS_SINE)
	tween_x.tween_property(enemy_anchor, "position:x", enemy_anchor.position.x + 3, 1.0)
	tween_x.tween_property(enemy_anchor, "position:x", enemy_anchor.position.x - 3, 1.0)
	
	var tween_y = create_tween().set_loops().set_parallel(false).set_trans(Tween.TRANS_BACK)
	tween_y.tween_property(enemy_anchor, "position:y", enemy_anchor.position.y + 3, 1.5).set_ease(Tween.EASE_IN_OUT)
	tween_y.tween_property(enemy_anchor, "position:y", enemy_anchor.position.y - 3, 1.5).set_ease(Tween.EASE_IN_OUT)

# Virtual method - override for custom spawn patterns
func spawn_enemies():
	# Default spawn pattern - 9x3 grid with random enemy selection
	for x in range(9): 
		for y in range(3):
			spawn_enemy_at_position(x, y)

func spawn_enemy_at_position(x, y):
	if enemy_scenes.size() == 0:
		push_error("No enemy scenes defined in level!")
		return
	
	# Randomly select an enemy from available scenes
	var enemy_scene = enemy_scenes[randi() % enemy_scenes.size()]
	var e = enemy_scene.instantiate()
	
	# Default position calculation
	var pos = Vector2(x * (16 + 8) + 24, 16 * 3 + y * 40)
	
	add_child(e)
	if e.has_method("start"):
		e.start(pos)
	
	# Set common properties
	e.anchor = enemy_anchor
	if e.has_signal("died"):
		e.died.connect(_on_enemy_died)

func _on_enemy_died(value):
	score += value * score_multiplier
	ui.update_score(score)
	camera.add_trauma(0.5)
	start_score_multipliplier_timer()
	multiplier_increase_tracker += 1
	if multiplier_increase_tracker > 5:
		score_multiplier += 1
		multiplier_increase_tracker = 0
	else:
		pass

func _process(_delta):
	if get_tree().get_nodes_in_group("enemies").size() == 0 and playing:
		handle_wave_completion()

func handle_wave_completion():
	current_wave += 1
	
	if current_wave < max_waves:
		spawn_enemies()
		wave_cleared(current_wave)  # Optional callback
	else:
		change_levels()

# Virtual method - called when a wave is cleared
func wave_cleared(wave_number):
	# Child classes can override for wave-specific logic
	pass

# Virtual method - override for custom level progression
func change_levels():
	if level_paths.has("next_level"):
		get_tree().change_scene_to_file(level_paths["next_level"])
	else:
		# Default behavior - go to next level numerically
		var current_scene = get_tree().current_scene.scene_file_path
		var level_num = current_scene.get_file().trim_suffix(".tscn").substr(6).to_int()
		var next_level = "res://levels/level_%d.tscn" % (level_num + 1)
		
		if ResourceLoader.exists(next_level):
			get_tree().change_scene_to_file(next_level)
		else:
			# If no next level exists, go to victory screen or title
			get_tree().change_scene_to_file("res://levels/title_screen.tscn")

func _on_player_died():
	playing = false
	get_tree().call_group("enemies", "queue_free")
	game_over.show()
	await get_tree().create_timer(2).timeout
	game_over.hide()
	get_tree().change_scene_to_file("res://levels/title_screen.tscn")
	start_button.show()

func new_game():
	score = 0
	current_wave = 0
	ui.update_score(score)
	
	if player and player.has_method("start"):
		player.start()
	
	spawn_enemies()
	playing = true
	game_started()  # Optional callback

# Virtual method - called when a new game starts
func game_started():
	# Child classes can override for level-specific startup logic
	pass

func _on_start_pressed():
	start_button.hide()
	new_game()

func _input(event):
	# Use the action you created in Input Map
	if event.is_action_pressed("start"):
		# Only start if we're at the start screen
		if start_button.visible and not playing:
			_on_start_pressed()
func timeout_multiplier_timer():
	score_multiplier = score_multiplier - 1
	multiplier_increase_tracker = 0
	print(score_multiplier)
	if score_multiplier >= 2:
		pass
	else:
		multiplier_timer.stop()
	
