# base_level.gd
class_name BaseLevel
extends Node2D

# How many choices the end-of-level popup offers at once (see
# _offer_run_powerup_choice()). If the player earned at least this many
# distinct power-ups this level, this many are picked at random from what
# they earned. Otherwise (including earning none at all) every power-up they
# did earn is offered, plus exactly one random gray power-up (see
# PlayerPowerUps.GRAY_POWERUPS) added on top - so a player who earned fewer
# than MAX_POWERUP_CHOICES always still gets one guaranteed extra choice,
# never a full top-up to MAX_POWERUP_CHOICES worth of gray power-ups.
const MAX_POWERUP_CHOICES := 3

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
@onready var powerup_choice_popup = $CanvasLayer/PowerupChoicePopup

var is_paused = false
var is_powerup_popup_active = false
var is_powerup_choice_active = false

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
	powerup_choice_popup.hide()
	powerup_choice_popup.powerup_chosen.connect(_on_run_powerup_chosen)
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
		multiplier_timer.wait_time = 5.0
	else:
		multiplier_timer.stop()
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

# ===== SQUAD HELPER =====
# Shared by any level that wants squad-based enemies (groups that fly down
# and attack together as one choreographed unit - see enemies/yellow_squad.gd
# for the actual behavior). Used by levels/squad_wave_level.gd, the shared
# base for any level built as a numbered list of waves (see that file for an
# example of building a whole level's enemy layout on top of this).
func spawn_squad(enemy_scene: PackedScene, start_pos: Vector2, end_pos: Vector2, start_delay: float = 0.0, circle_progress: float = 0.5, diagonal_vx: float = 0.0, squad_size: int = 4) -> BeeSquad:
	"""Spawn one BeeSquad and wire it into this level: `enemy_scene` fills
	its ranks, and it travels in a straight line from `start_pos` to
	`end_pos` (typically just off one edge of the screen to just off
	another - see levels/squad_wave_level.gd's side+percent helper),
	pausing to circle `circle_progress` of the way along that line (0.0-1.0;
	0.5 is halfway). `start_delay` parks it for that many seconds before it
	starts moving, so multiple squads in one wave can stagger their
	entrances, `diagonal_vx` adds sideways (perpendicular to the line of
	travel) drift to a member's solo departure after its own loop (0 = none),
	and `squad_size` is how many enemies fly in it. The squad's kills are
	wired straight into this level's own scoring (_on_enemy_died()), same as
	any other enemy."""
	var squad := BeeSquad.new()
	squad.enemy_scene = enemy_scene
	squad.start_pos = start_pos
	squad.end_pos = end_pos
	squad.start_delay = start_delay
	squad.circle_progress = circle_progress
	squad.diagonal_vx = diagonal_vx
	squad.squad_size = squad_size
	squad.enemy_died.connect(_on_enemy_died)
	add_child(squad)
	return squad


# ===== SOLO HELPER =====
# Shared by any level that wants a single bee-style enemy flying across
# the screen on its own instead of as part of a squad (see
# enemies/yellow_solo.gd). Used by levels/squad_wave_level.gd, alongside
# spawn_squad() above - see that file's WAVES FORMAT comment for the
# "solos" list.
func spawn_solo(enemy_scene: PackedScene, start_pos: Vector2, end_pos: Vector2, start_delay: float = 0.0) -> BeeSolo:
	"""Spawn one BeeSolo and wire it into this level: `enemy_scene` fills
	it, and it flies in a straight line from `start_pos` to `end_pos`
	(typically just off one edge of the screen to just off the opposite
	edge), weaving in a sine curve and looping halfway there exactly like a
	squad member does - see enemies/yellow_solo.gd. `start_delay` parks it
	for that many seconds before it starts, same purpose as spawn_squad()'s.
	Its kill is wired straight into this level's own scoring
	(_on_enemy_died()), same as any other enemy."""
	var solo := BeeSolo.new()
	solo.enemy_scene = enemy_scene
	solo.start_pos = start_pos
	solo.end_pos = end_pos
	solo.start_delay = start_delay
	solo.enemy_died.connect(_on_enemy_died)
	add_child(solo)
	return solo


# ===== HIVE SOLO HELPER =====
# Shared by any level that wants a hive-style enemy playing its own
# "stop and dance" pattern (see enemies/hive_solo.gd's header comment)
# instead of BeeSolo's straight start_pos->end_pos crossing. Used by
# levels/hive_level.gd.
func spawn_hive_solo(enemy_scene: PackedScene, start_x_percent: float = 0.5, pause_y: float = 60.0, start_delay: float = 0.0) -> HiveSolo:
	"""Spawn one HiveSolo and wire it into this level: `enemy_scene` fills
	it, spawns off-screen above the top edge, and flies down onto
	(`start_x_percent` * screen width, `pause_y`) before starting its
	stop-shake-travel dance (see enemies/hive_solo.gd). `start_delay` parks
	it off-screen for that many seconds before that entry begins, same
	purpose as spawn_solo()'s. Its kill is wired straight into this level's
	own scoring (_on_enemy_died()), same as any other enemy."""
	var solo := HiveSolo.new()
	solo.enemy_scene = enemy_scene
	solo.start_x_percent = start_x_percent
	solo.pause_y = pause_y
	solo.start_delay = start_delay
	solo.enemy_died.connect(_on_enemy_died)
	add_child(solo)
	return solo


# ===== BOSS HELPER =====
# Shared bookkeeping for a boss fight shaped like enemies/yellow_miniboss.gd's:
# the boss periodically retreats offscreen and invincible, the level spawns a
# wave of "add" enemies to fight in the meantime, and once every add is dead
# the boss comes back and picks up where it left off. The boss scene itself,
# and exactly which adds to spawn on each retreat, are still up to the level
# (see levels/squad_wave_level.gd's _spawn_boss_wave()/_on_boss_retreat_started())
# - this just tracks "how many adds are still alive" so every level with this
# kind of fight doesn't have to reimplement that counting from scratch.
var _active_boss: Node = null
var _boss_adds_remaining: int = 0

func spawn_boss(boss_scene: PackedScene, spawn_pos: Vector2) -> Node:
	"""Instantiate a boss scene, add it to the level, hook its `died` signal
	up to scoring same as any other enemy, and remember it as the active boss
	so resolve_boss_add_death() can call back into it later. Returns the boss
	instance so the caller can connect its own scene-specific signals (e.g.
	BeeMiniboss's `retreat_started`) - those aren't generic enough to wire
	up here."""
	var boss = boss_scene.instantiate()
	add_child(boss)
	if boss.has_signal("died"):
		boss.died.connect(_on_enemy_died)
	_active_boss = boss
	if boss.has_method("start"):
		boss.start(spawn_pos)
	return boss

func start_boss_add_wave(add_count: int) -> void:
	"""Call once the level has spawned this retreat's add enemies/squads -
	add_count is how many individual enemies need to die before the boss
	should come back (e.g. the sum of each spawned squad's own squad_size).
	resolve_boss_add_death() below counts them down."""
	_boss_adds_remaining = add_count

func resolve_boss_add_death(_value: int = 0) -> void:
	"""Connect this to each add's `died`/`enemy_died` signal. Once every add
	from the current retreat wave is gone, tells the boss to come back (if it
	has a resume_after_adds() method - same contract as
	enemies/yellow_miniboss.gd)."""
	_boss_adds_remaining -= 1
	if _boss_adds_remaining <= 0 and is_instance_valid(_active_boss) and _active_boss.has_method("resume_after_adds"):
		_active_boss.resume_after_adds()


# ===== ASTROID / DRIFT HELPER =====
# Shared by any level that wants a straight-line-drifting enemy (see
# enemies/astroid_enemy.gd - drift with a slow spin, no shooting or diving).
# Used directly by levels/astroid_level.gd, and via squad_wave_level.gd's
# "drift" wave pattern (see that file's header comment) by any level built on
# SquadWaveLevel. Lives here (not on astroid_enemy.gd itself) so it follows
# the same pattern as spawn_squad()/spawn_solo()/spawn_boss() above: every
# level gets it for free just by extending BaseLevel, with nothing to
# redefine locally.
func spawn_astroid(config: Dictionary) -> void:
	"""Spawns one astroid (or any enemy scene with a launch(start, end,
	speed) method) from a labeled config - keeps every call self-explanatory
	instead of relying on argument order.
	"scene" - which astroid_*.tscn to use (e.g. preload("res://enemies/astroid_medium.tscn"))
	"start" - Vector2 position where it appears
	"end" - Vector2 that sets its direction (it keeps traveling straight
	past this point - it doesn't stop there)
	"speed" - how fast it travels, in pixels/second
	Pushes a clear error (and skips the spawn) instead of letting Godot throw
	a raw "Invalid call" if "scene" is missing or the instantiated scene
	doesn't actually have a launch() method - this exact call has silently
	failed to reach the device before (see astroid_enemies_and_level notes on
	the launch() history), so it's worth guarding here."""
	var scene: PackedScene = config.get("scene")
	if scene == null:
		push_error("%s: spawn_astroid() called with no \"scene\" in its config" % scene_file_path)
		return
	var start_pos: Vector2 = config.get("start", Vector2.ZERO)
	var end_pos: Vector2 = config.get("end", Vector2.ZERO)
	var speed: float = config.get("speed", 20.0)

	var a = scene.instantiate()
	add_child(a)
	if not a.has_method("launch"):
		push_error("%s: %s has no launch(start, end, speed) method - spawn_astroid() only works with an enemy script like enemies/astroid_enemy.gd" % [scene_file_path, scene.resource_path])
		a.queue_free()
		return
	a.launch(start_pos, end_pos, speed)
	if a.has_signal("died"):
		a.died.connect(_on_enemy_died)


func _process(_delta):
	if get_tree().get_nodes_in_group("enemies").size() == 0 and playing:
		handle_wave_completion()

func handle_wave_completion():
	current_wave += 1

	if current_wave < max_waves:
		spawn_enemies()
		wave_cleared(current_wave)  # Optional callback
	else:
		# Stop _process() from calling this again before the scene actually
		# finishes changing (change_levels() below can go a frame or more
		# without pausing the tree - e.g. change_scene_to_file() itself is
		# deferred to the end of the frame, and the no-power-ups-earned path
		# through _offer_run_powerup_choice() doesn't pause at all). Without
		# this, "enemies == 0 and playing" would still be true on the very
		# next _process() call and this whole branch would fire again,
		# calling GameProgress.on_level_won() a second time with
		# pending_node_id already reset to -1 - corrupting current_node_id
		# and making the overworld (and any run power-ups picked afterward)
		# look like progress reset.
		playing = false
		change_levels()

# Virtual method - called when a wave is cleared
func wave_cleared(wave_number):
	# Child classes can override for wave-specific logic
	pass

# Virtual method - override for custom level progression
func change_levels():
	if GameProgress.is_active():
		# Launched from the overworld - award shop currency equal to this
		# level's final score (see stats.gd's currency section / the
		# overworld shop in levels/shop.gd), then offer a choice of power-ups
		# to keep for the rest of the run (see _offer_run_powerup_choice() -
		# whatever was earned this level, always topped up with at least one
		# guaranteed gray power-up choice), which reports the win back to
		# GameProgress once the player picks instead of following this
		# level's own hardcoded next-level logic below.
		Stats.add_currency(score)
		_offer_run_powerup_choice()
		return

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

func _offer_run_powerup_choice() -> void:
	"""Called at the end of a level that's part of an overworld run. If the
	player earned at least MAX_POWERUP_CHOICES distinct power-ups this level
	(see Stats.collected_powerups), offer that many of them (chosen at
	random) as a small choice popup. Otherwise - including earning none at
	all - offer every power-up they did earn PLUS exactly one random gray
	power-up (see PlayerPowerUps.GRAY_POWERUPS / get_random_gray_powerup()),
	so the player always has at least one guaranteed extra choice on top of
	whatever they earned. Either way, only the one power-up the player picks
	gets added to Stats.run_modifiers and carried into future levels."""
	var earned_ids: Array = _unique_collected_powerup_ids()
	earned_ids.shuffle()

	var offered_powerups: Array = []
	if earned_ids.size() >= MAX_POWERUP_CHOICES:
		var offered_ids: Array = earned_ids.slice(0, MAX_POWERUP_CHOICES)
		for powerup_id in offered_ids:
			offered_powerups.append(PlayerPowerUps.get_powerup_by_id(powerup_id))
	else:
		for powerup_id in earned_ids:
			offered_powerups.append(PlayerPowerUps.get_powerup_by_id(powerup_id))
		var gray_powerup: Dictionary = PlayerPowerUps.get_random_gray_powerup()
		if not gray_powerup.is_empty():
			offered_powerups.append(gray_powerup)

	if offered_powerups.is_empty():
		# Only possible if the player earned nothing AND GRAY_POWERUPS is
		# somehow empty - nothing to offer, so skip straight to reporting
		# the win like the old no-power-ups-earned behavior did.
		GameProgress.on_level_won()
		return

	is_powerup_choice_active = true
	get_tree().paused = true
	powerup_choice_popup.show_choices(offered_powerups)

func _unique_collected_powerup_ids() -> Array:
	"""Stats.collected_powerups can contain the same id more than once (the
	player collected it from multiple bubbles this level) - de-duplicate
	before offering it as a choice, so it doesn't take up more than one of
	the (up to 3) card slots."""
	var seen := {}
	var unique_ids: Array = []
	for powerup_id in Stats.collected_powerups:
		if not seen.has(powerup_id):
			seen[powerup_id] = true
			unique_ids.append(powerup_id)
	return unique_ids

func _on_run_powerup_chosen(powerup: Dictionary) -> void:
	Stats.choose_run_powerup(powerup.get("id", ""), powerup.get("stats", {}))
	is_powerup_choice_active = false
	# Unpause the tree BEFORE switching scenes (see _on_quit_pressed() for
	# why - loading the overworld while still paused would leave it unable
	# to respond to input).
	get_tree().paused = false
	GameProgress.on_level_won()

func _on_player_died():
	playing = false
	get_tree().call_group("enemies", "queue_free")
	game_over.show()
	await get_tree().create_timer(2).timeout
	game_over.hide()
	if GameProgress.is_active():
		# Losing mid-run resets the overworld progress and sends the player
		# all the way back to the title screen.
		GameProgress.on_level_lost()
	else:
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
		# or while a power-up popup already owns the pause).
		if playing and not is_paused and not is_powerup_popup_active and not is_powerup_choice_active:
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
	is_powerup_choice_active = false
	get_tree().paused = false
	playing = false
	get_tree().change_scene_to_file("res://levels/title_screen.tscn")
func timeout_multiplier_timer():
	score_multiplier = score_multiplier - 1
	multiplier_increase_tracker = 0
	ui.update_score_multiplier(score_multiplier)
	if score_multiplier >= 2:
		pass
	else:
		multiplier_timer.stop()
	
