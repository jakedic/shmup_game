# player_base.gd
extends Area2D
class_name Player

# NOTE ON STRUCTURE:
# This script holds the player's state (signals, exported properties,
# stats, timers) plus its core lifecycle (_process, initialize_player,
# stat syncing). Almost every behavior method below is a one-line
# delegate into a focused helper script:
#   player/player_movement.gd       - PlayerMovement   (move, dash)
#   player/player_shooting.gd       - PlayerShooting    (bullets)
#   player/player_absorption.gd     - PlayerAbsorption  (absorb, bubble, revert)
#   player/player_health.gd         - PlayerHealth      (shield, damage, death)
#   player/player_visuals.gd        - PlayerVisuals     (sprite/tween effects)
#   player/player_powerups.gd       - PlayerPowerUps    (power-bubble power-ups)
#   transformations/player_transformations.gd - PlayerTransformations
#
# Methods that other scripts call by name (start, absorb_complete,
# absorb_fail, update_multiplier, transform_yellow, transform_red) and the
# three methods wired up directly in player.tscn (_on_area_entered,
# _on_gun_cooldown_timeout, _on_absorb_cooldown_timeout) are kept here as
# real methods for that reason - they just forward to the helper scripts.

signal shield_changed(max_shield: int, current_shield: int)
signal died
signal player_shot(bullet: Node2D)
signal player_absorbed(enemy_type: int)
signal player_healed(amount: int)

# ===== CUSTOMIZABLE PROPERTIES =====
@export var player_name: String = "Player"

#Transformation Timer Properties
var transformation_timer: Timer
var transformation_duration: float = 5.0

# ===== GAMEPLAY STATS =====
# These are no longer hand-set here. They're synced from the Stats autoload
# (res://stats.gd), which resolves default -> progression -> active
# modifiers (transformations) into one dictionary per category.
# See _sync_player_stats() / _on_stats_changed() below.
var speed: float
var acceleration: float
var deceleration: float
var max_shield: int
var shield_regen_rate: float
var shield_regen_delay: float
var shoot_cooldown: float
var can_multi_shoot: bool
var shot_count: int
var shot_spread: float
var absorb_cooldown: float
var dash_speed: float
var dash_duration: float
var dash_cooldown: float
var spin_speed: float
var circle_radius: float
var circle_speed: float
var steering_influence: float
var bullet_invincible_during_dash: bool
var do_dash_damage_to_enemies: bool
var dash_damage_amount: int

# ===== YELLOW POWER-UP: POLLEN SHOT =====
# Secondary fire granted by the "Pollen Shot" power-up (see
# player/player_powerups.gd + player/player_pollen_shot.gd). Unrelated to
# the normal bullet: while has_pollen_shot is true, holding "shoot" also
# fires a pair of weak, wiggling pollen balls from the ship's sides, on
# their own cooldown (pollen_cooldown_remaining, ticked down in _process).
var has_pollen_shot: bool = false
var pollen_cooldown_remaining: float = 0.0

# Scene/visual references stay as exports - they aren't numeric stats.
@export var bullet_scene: PackedScene
@export var bullet_yellow_scene: PackedScene
@export var bullet_pollen_scene: PackedScene
@export var bullet_pollen_puff_scene: PackedScene
@export var absorb_scene: PackedScene
@export var max_absorption_level: int = 2  # Maximum enemy types that can be absorbed
var currently_absorbing=false

#Bubble properties
@export var bubble_scene: PackedScene  # The bubble projectile scene

# ===== YELLOW FORM: CHARGE SHOT =====
# While in yellow form, holding "shoot" charges up a single powerful,
# piercing bullet instead of firing normally. Releasing early (before fully
# charged) doesn't just cancel the shot - it fires a slow, harmless "pollen
# puff" (bullet_pollen_puff_scene) instead, guaranteed to inflict
# "pollinated" on whatever it touches. See player/player_charge_shot.gd -
# _release_charge().
# Damage/speed/pierce/max_distance are NOT duplicated here - the charged
# bullet is configured the exact same way a normal bullet is, straight
# from Stats.get_category("bullet") (see player/player_charge_shot.gd),
# so the transform_yellow modifier is the one place that defines both. The
# pollen puff similarly pulls its own stats from Stats.get_category("pollen_puff").
# charge_shot_duration/charge_flash_interval ARE synced from Stats below,
# same as absorb_cooldown etc., so they're tunable the same way as any
# other transformation parameter (see stats.gd + transform_yellow()).
var charge_shot_duration: float
var charge_flash_interval: float

var is_charging_shot: bool = false
var charge_shot_time: float = 0.0

var dash_time = 0.0

# Double-tap detection variables
const DOUBLETAP_DELAY = 0.25
var doubletap_time_left = 0.0
var doubletap_time_right = 0.0
var doubletap_time_up = 0.0
var doubletap_time_down = 0.0
var last_direction_input = Vector2.ZERO
var dash_timer: Timer
var dash_cooldown_timer: Timer
var is_dashing: bool = false
var can_dash: bool = true
var dash_direction: Vector2 = Vector2.ZERO
var original_speed: float

# Visual properties
@export var default_sprite_texture: Texture2D
@export var yellow_sprite_texture: Texture2D
@export var player_color: Color = Color.WHITE
@export var has_recoil_animation: bool = true
@export var recoil_distance: float = 1.0
@export var recoil_duration: float = 0.1

# Simple dictionary to define form properties
var current_form_data: Dictionary = {}
var yellow_form = preload("res://transformations/yellow.tres")
var default_form = preload("res://transformations/default.tres")
var current_form='default'
var form_path
var form_resource
# Sound properties (add these if you have sound)
# @export var shoot_sound: AudioStream
# @export var absorb_sound: AudioStream
# @export var hit_sound: AudioStream

# ===== INTERNAL VARIABLES =====
var shield: int:
	set = set_shield

var can_shoot: bool = true
var can_absorb: bool = true
var is_absorbing: int = 0
var current_velocity: Vector2 = Vector2.ZERO
var time_since_last_damage: float = 0.0
var is_alive: bool = true
var score_multiplier: int = 1

@onready var screensize = get_viewport_rect().size

# ===== INITIALIZATION =====
func start():
	initialize_player()

func initialize_player():
	"""Initialize all player systems"""

	is_alive = true
	show()

	# Pull current stats from the central Stats system and stay subscribed
	# so transformations (add_modifier/remove_modifier) update us live.
	if not Stats.stats_changed.is_connected(_on_stats_changed):
		Stats.stats_changed.connect(_on_stats_changed)
	_sync_player_stats()

	# Set initial position
	reset_position()

	# Set initial shield
	shield = max_shield

	# Apply visual properties
	apply_visuals()

	setup_dash_timers()
	original_speed = speed
	can_dash = true
	is_dashing = false

	# Set up transformation timer
	setup_transformation_timer()
	add_to_group("player")


func _on_stats_changed(category: String):
	"""Called whenever Stats recomputes a category (progression change,
	transformation applied/removed, etc.)"""
	if category == "player":
		_sync_player_stats()
	elif category == "bullet":
		pass # bullets pull their own stats at spawn time, see create_bullet()

func _sync_player_stats():
	"""Copy the resolved player stats into local fields used by the
	per-frame movement/shooting/dash code."""
	var s = Stats.get_category("player")
	speed = s.speed
	acceleration = s.acceleration
	deceleration = s.deceleration
	max_shield = s.max_shield
	if shield > max_shield:
		shield = max_shield  # never top the player back up just from a stat change
	shield_regen_rate = s.shield_regen_rate
	shield_regen_delay = s.shield_regen_delay
	shoot_cooldown = max(0.05, s.shoot_cooldown)
	can_multi_shoot = s.can_multi_shoot
	shot_count = s.shot_count
	shot_spread = s.shot_spread
	absorb_cooldown = s.absorb_cooldown
	dash_speed = s.dash_speed
	dash_duration = s.dash_duration
	dash_cooldown = s.dash_cooldown
	spin_speed = s.spin_speed
	circle_radius = s.circle_radius
	circle_speed = s.circle_speed
	steering_influence = s.steering_influence
	bullet_invincible_during_dash = s.dash_invincible
	do_dash_damage_to_enemies = s.dash_damages_enemies
	dash_damage_amount = s.dash_damage_amount
	charge_shot_duration = s.charge_shot_duration
	charge_flash_interval = s.charge_flash_interval
	has_pollen_shot = s.has_pollen_shot

	if is_instance_valid(self) and has_node("GunCooldown"):
		$GunCooldown.wait_time = shoot_cooldown
	if is_instance_valid(self) and has_node("AbsorbCooldown"):
		$AbsorbCooldown.wait_time = absorb_cooldown
	if not is_dashing:
		original_speed = speed

func reset_position():
	"""Reset player to starting position"""
	position = Vector2(screensize.x / 2, screensize.y - 64)

func apply_visuals():
	"""Apply visual properties like color and texture"""
	PlayerVisuals.apply_visuals(self)

# ===== MOVEMENT SYSTEM =====
func _process(delta):
	if not is_alive:
		return

	process_input(delta)
	process_shield_regen(delta)

	# Update double-tap timers
	update_doubletap_timers(delta)

	if is_dashing and is_instance_valid($Ship):
		$Ship.rotation += deg_to_rad(spin_speed) * delta


func process_input(delta):
	"""Process all player input"""
	handle_absorb_input()
	handle_movement(delta)
	handle_shoot_input(delta)
	handle_pollen_shot_input(delta)
	handle_dash_input()

func handle_movement(delta):
	PlayerMovement.handle_movement(self, delta)

func can_player_dash() -> bool:
	return PlayerMovement.can_player_dash(self)

func update_movement_animation(x_input: float):
	PlayerMovement.update_movement_animation(self, x_input)

func clamp_to_screen():
	PlayerMovement.clamp_to_screen(self)

func setup_dash_timers():
	PlayerMovement.setup_dash_timers(self)

func update_doubletap_timers(delta: float):
	PlayerMovement.update_doubletap_timers(self, delta)

func handle_dash_input():
	PlayerMovement.handle_dash_input(self)

func start_dash(direction: Vector2):
	PlayerMovement.start_dash(self, direction)

func on_dash_start():
	PlayerMovement.on_dash_start(self)

func on_dash_end():
	PlayerMovement.on_dash_end(self)

func _on_dash_timer_timeout():
	"""Called when dash duration ends"""
	PlayerMovement.on_dash_timer_timeout(self)

func _on_dash_cooldown_timeout():
	"""Called when dash cooldown ends"""
	PlayerMovement.on_dash_cooldown_timeout(self)

# ===== SHOOTING SYSTEM =====
func handle_shoot_input(delta: float):
	PlayerShooting.handle_shoot_input(self, delta)

func shoot():
	PlayerShooting.shoot(self)

func get_current_bullet_type() -> PackedScene:
	return PlayerShooting.get_current_bullet_type(self)

func shoot_single(bullet_type: PackedScene):
	PlayerShooting.shoot_single(self, bullet_type)

func shoot_multiple(bullet_type: PackedScene):
	PlayerShooting.shoot_multiple(self, bullet_type)

func create_bullet(bullet_type: PackedScene) -> Node2D:
	return PlayerShooting.create_bullet(bullet_type)

func configure_bullet(bullet: Node2D):
	PlayerShooting.configure_bullet(bullet)

func launch_bullet(bullet: Node2D, spawn_pos: Vector2):
	PlayerShooting.launch_bullet(self, bullet, spawn_pos)

func on_shoot():
	PlayerShooting.on_shoot(self)

func handle_pollen_shot_input(delta: float):
	PlayerPollenShot.handle_input(self, delta)

# ===== ABSORPTION SYSTEM =====
func handle_absorb_input():
	PlayerAbsorption.handle_absorb_input(self)

func absorb():
	PlayerAbsorption.absorb(self)

func create_absorption_projectile() -> Node2D:
	return PlayerAbsorption.create_absorption_projectile(self)

func update_multiplier(new_multiplier: int):
	score_multiplier = new_multiplier

func launch_absorption_projectile(projectile: Node2D):
	PlayerAbsorption.launch_absorption_projectile(self, projectile)

func on_absorb():
	PlayerAbsorption.on_absorb(self)

func revert_absorption():
	PlayerAbsorption.revert_absorption(self)

func reset_to_default_form():
	PlayerAbsorption.reset_to_default_form(self)

func setup_transformation_timer():
	"""Set up the timer for automatic transformation reversion"""
	PlayerTransformations.setup_transformation_timer(self)

func _on_transformation_timer_timeout():
	"""Called when transformation duration expires"""
	PlayerTransformations.on_transformation_timer_timeout(self)

func get_transformation_function_name(enemy_type: String) -> String:
	return PlayerTransformations.get_transformation_function_name(enemy_type)

func absorb_complete(hit_enemy_type: String):
	# Called by bullets/absorb.gd and bullets/bubble.gd via has_method()/call(),
	# so this needs to stay a real method on the player's own script.
	PlayerAbsorption.absorb_complete(self, hit_enemy_type)

func absorb_fail():
	# Called by bullets/absorb.gd via has_method()/call() - see note above.
	PlayerAbsorption.absorb_fail(self)

# ===== POWER-UPS (granted by power bubbles) =====
func apply_random_powerup(enemy_type: String) -> Dictionary:
	# Called by bullets/bubble.gd via has_method()/call() when a power
	# bubble (formed from two bubbles colliding) is touched, so this needs
	# to stay a real method on the player's own script - see note above.
	return PlayerPowerUps.apply_random_powerup(self, enemy_type)

# Shoot Bubble
func shoot_bubble():
	"""Shoot a bubble projectile (used when trying to absorb while having an ability)"""
	PlayerAbsorption.shoot_bubble(self)

func create_bubble() -> Node2D:
	return PlayerAbsorption.create_bubble(self)

func _apply_bubble_stats(bubble: Node2D):
	PlayerAbsorption.apply_bubble_stats(bubble)

func create_simple_bubble() -> Node2D:
	return PlayerAbsorption.create_simple_bubble()

func launch_bubble(bubble: Node2D):
	PlayerAbsorption.launch_bubble(self, bubble)

func on_bubble_shot():
	PlayerAbsorption.on_bubble_shot(self)

# ===== HELPER METHODS =====
# These write PERMANENT (progression-tier) changes via Stats, so they
# persist across transformations and levels instead of being silently
# overwritten the next time _sync_player_stats() runs. For a TEMPORARY
# change, use Stats.add_modifier()/remove_modifier() directly instead.
func set_speed(new_speed: float):
	"""Permanently change player speed"""
	Stats.set_progression_stat("player", "speed", new_speed)

func set_shoot_cooldown(new_cooldown: float):
	"""Permanently change shooting cooldown"""
	Stats.set_progression_stat("player", "shoot_cooldown", new_cooldown)

func set_absorb_cooldown(new_cooldown: float):
	"""Permanently change absorption cooldown"""
	Stats.set_progression_stat("player", "absorb_cooldown", new_cooldown)

func set_max_shield(new_max_shield: int):
	"""Permanently change maximum shield"""
	Stats.set_progression_stat("player", "max_shield", new_max_shield)

func set_bullet_type(new_bullet_scene: PackedScene, is_yellow: bool = false):
	"""Change bullet type"""
	if is_yellow:
		bullet_yellow_scene = new_bullet_scene
	else:
		bullet_scene = new_bullet_scene

func set_multi_shot(enabled: bool, count: int = 1, spread: float = 10.0):
	"""Permanently configure multi-shot"""
	Stats.set_progression_stat("player", "can_multi_shoot", enabled)
	Stats.set_progression_stat("player", "shot_count", count)
	Stats.set_progression_stat("player", "shot_spread", spread)

func set_absorption_level(level: int):
	"""Set absorption level (0 = normal, 1+ = absorbed enemy types)"""
	is_absorbing = clamp(level, 0, max_absorption_level)
	update_sprite()

func is_at_full_shield() -> bool:
	"""Check if player is at full shield"""
	return shield >= max_shield

func get_absorption_level() -> int:
	"""Get current absorption level"""
	return is_absorbing

# ===== TIMER SIGNALS =====
# Wired up directly in player.tscn, so these two must stay real methods here.
func _on_gun_cooldown_timeout():
	can_shoot = true

func _on_absorb_cooldown_timeout():
	can_absorb = true

func play_simple_transition_effect():
	"""Play a simple transformation effect"""
	PlayerTransformations.play_simple_transition_effect(self)

# ===== TRANSFORMATION FUNCTIONS =====
# Dispatched to by name (has_method/call) from PlayerAbsorption.absorb_complete()
# and from bullets/bubble.gd, so transform_yellow/transform_red must stay real
# methods on the player's own script rather than moving fully into
# PlayerTransformations.

func transform_yellow():
	PlayerTransformations.transform_yellow(self)

func transform_red():
	PlayerTransformations.transform_red(self)

# ===== SHIELD/HEALTH SYSTEM =====
func set_shield(value: int):
	"""Setter function for shield.
	NOTE: this one can't delegate to PlayerHealth like the others. Godot
	only treats a bare assignment to `shield` as a direct backing-field
	write (no re-trigger) when it happens literally inside this function,
	the property's declared setter. If this called out to a helper script
	that did `player.shield = ...` from outside, that write would be seen
	as external and would re-invoke this setter -> infinite recursion."""
	shield = clamp(value, 0, max_shield)
	shield_changed.emit(max_shield, shield)

	if shield <= 0 and is_alive:
		die()

func take_damage(damage_amount: int = 1):
	"""Take damage from enemies or hazards"""
	PlayerHealth.take_damage(self, damage_amount)

func flash_damage():
	"""Visual feedback when taking damage"""
	PlayerHealth.flash_damage(self)

func heal(amount: int):
	"""Heal the player"""
	PlayerHealth.heal(self, amount)

func process_shield_regen(delta: float):
	PlayerHealth.process_shield_regen(self, delta)

func die():
	"""Handle player death"""
	PlayerHealth.die(self)

func custom_die():
	"""Override this for custom death behavior"""
	PlayerHealth.custom_die(self)

func revive():
	"""Revive the player"""
	PlayerHealth.revive(self)

# ===== VISUAL SYSTEM =====
func update_sprite():
	"""Update ship sprite based on absorption state"""
	PlayerVisuals.update_sprite(self)

func animate_recoil():
	"""Play the ship recoil animation when shooting"""
	PlayerVisuals.animate_recoil(self)

# ===== COLLISION HANDLING =====
func _on_area_entered(area):
	"""Handle collision with enemies. Wired up directly in player.tscn, so
	this must stay a real method on the player's own script."""
	PlayerHealth.on_area_entered(self, area)

func handle_enemy_collision(area: Area2D):
	"""Handle collision with enemy"""
	PlayerHealth.handle_enemy_collision(self, area)
