# base_level.gd
class_name BaseLevel
extends Node2D

# Common variables for all levels
var score = 0
var playing = false
var wave = 0
var current_wave = 0
var max_waves = 3  # Default value, can be overridden
var score_multiplier = 1
var multiplier_increase_tracker = 0 #tracks when the multiplier should be increased
var multiplier_timer : Timer = Timer.new() #creates the multiplier timer variable
var auto_start_delay: float = 1.5 #how long the start popup stays up before the game auto-starts
var auto_start_timer : Timer = Timer.new() #timer that auto-triggers the game start
# Common UI elements (assumes similar structure in all levels)
@onready var start_button = $CanvasLayer/CenterContainer/Start
@onready var game_over = $CanvasLayer/CenterContainer/GameOver
@onready var ui = $CanvasLayer/UI
@onready var pause_menu = $CanvasLayer/PauseMenu
@onready var powerup_popup = $CanvasLayer/PowerupPopup

var is_paused = false
var is_powerup_popup_active = false

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
	pause_menu.hide()
	powerup_popup.hide()
	powerup_popup.continue_pressed.connect(_on_powerup_popup_continue_pressed)
	Stats.powerup_collected.connect(_on_powerup_collected)
	setup_enemy_anchor_animation()
	initialize_level()
	add_child(multiplier_timer)
	multiplier_timer.autostart = false # tells the timer not to start on creation
	multiplier_timer.wait_time = 5.0 # defines how long the timer is

	# Put the player in its proper starting state (full shield, start position)
	# right away, so it looks correct while the start popup is showing instead
	# of only snapping into place once the popup timer fires.
	if player and player.has_method("start"):
		player.start()

	add_child(auto_start_timer)
	auto_start_timer.one_shot = true
	auto_start_timer.wait_time = auto_start_delay
	auto_start_timer.timeout.connect(_on_auto_start_timeout)
	auto_start_timer.start()
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
	ui.update_score_multiplier(score_multiplier)
	camera.add_trauma(0.5)
	start_score_multipliplier_timer()
	multiplier_increase_tracker += 1
	if score_multiplier >= 4:
		multiplier_increase_tracker = 0
	if multiplier_increase_tracker > 4:
		score_multiplier += 1
		multiplier_increase_tracker = 0
	else:
		pass
		
	# Add this line to update the player's multiplier
	if player and player.has_method("update_multiplier"):
		player.update_multiplier(score_multiplier)

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

	# Power bubbles grant power-ups that persist for the whole level (see
	# stats.gd's level_modifiers tier) - clear them out here so a fresh
	# level/run always starts with none carried over from before.
	Stats.clear_level_modifiers()

	if player and player.has_method("start"):
		player.start()
	
	spawn_enemies()
	playing = true
	game_started()  # Optional callback

# Virtual method - called when a new game starts
func game_started():
	# Child classes can override for level-specific startup logic
	ui.update_score_multiplier(1)
	pass

func _on_start_pressed():
	# Guard against this firing twice (e.g. auto-start timer + a click both firing)
	if not start_button.visible or playing:
		return
	auto_start_timer.stop()
	start_button.hide()
	new_game()

func _on_auto_start_timeout():
	_on_start_pressed()

func _input(event):
	# Use the action you created in Input Map
	if event.is_action_pressed("start"):
		# Only start if we're at the start screen
		if start_button.visible and not playing:
			_on_start_pressed()

	if event.is_action_pressed("pause"):
		# Only allow pausing mid-game (not on the start popup, after death,
		# or while the power-up popup already owns the pause).
		if playing and not is_paused and not is_powerup_popup_active:
			pause_game()

func pause_game():
	# get_tree().paused = true automatically halts _process/_physics_process
	# for the player, enemies, bullets, etc. (they use the default
	# "pausable" process mode). The pause menu itself is set to "Always"
	# process mode in the scene, so its buttons keep working.
	is_paused = true
	get_tree().paused = true
	pause_menu.show()

func resume_game():
	is_paused = false
	pause_menu.hide()
	get_tree().paused = false

func _on_continue_pressed():
	resume_game()

func _on_powerup_collected(powerup_id: String) -> void:
	# Stats.add_powerup() already applied the power-up's stat changes by the
	# time this fires - this just looks up its name/description for display
	# and pauses the game until the player acknowledges it.
	var powerup: Dictionary = PlayerPowerUps.get_powerup_by_id(powerup_id)
	var accent_color: Color = PlayerPowerUps.get_accent_color_for_powerup_id(powerup_id)
	show_powerup_popup(powerup, accent_color)

func show_powerup_popup(powerup: Dictionary, accent_color: Color = PlayerPowerUps.DEFAULT_ACCENT_COLOR) -> void:
	# Same pattern as pause_game() - get_tree().paused = true halts
	# gameplay's _process/_physics_process, while the popup (process_mode
	# "Always", set in the level scene) keeps working so it can be dismissed.
	is_powerup_popup_active = true
	get_tree().paused = true
	powerup_popup.show_powerup(powerup, accent_color)

func _on_powerup_popup_continue_pressed() -> void:
	is_powerup_popup_active = false
	powerup_popup.hide()
	get_tree().paused = false

func _on_quit_pressed():
	# Unpause the tree BEFORE switching scenes, otherwise the title
	# screen loads in a paused state and its Start button won't respond.
	is_paused = false
	is_powerup_popup_active = false
	get_tree().paused = false
	playing = false
	get_tree().change_scene_to_file("res://levels/title_screen.tscn")
func timeout_multiplier_timer():
	score_multiplier = score_multiplier - 1
	multiplier_increase_tracker = 0
	ui.update_score_multiplier(score_multiplier)
	print(score_multiplier)
	if score_multiplier >= 2:
		pass
	else:
		multiplier_timer.stop()
	
