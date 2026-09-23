extends RefCounted
class_name PlayerAbsorption

## Handles the absorb projectile, reverting out of an absorbed form, the
## bubble shot (fired instead of absorbing while already transformed), and
## dispatching to the right transform_*() function once an absorb lands.
## Called from player.gd as e.g. PlayerAbsorption.absorb(self).

static func handle_absorb_input(player: Player) -> void:
	"""Process absorption input"""
	if Input.is_action_pressed("absorb") and player.can_absorb and player.current_form == 'default' and player.score_multiplier >= 1:
		absorb(player)
	if Input.is_action_pressed("absorb") and player.can_absorb and player.current_form != 'default':
		shoot_bubble(player)
		revert_absorption(player)
	if Input.is_action_pressed("revert") and not player.is_dashing:
		revert_absorption(player)

static func absorb(player: Player) -> void:
	"""Fire absorption projectile"""
	player.current_velocity = Vector2.ZERO
	if not player.can_absorb or not player.is_alive:
		return

	player.can_absorb = false
	player.currently_absorbing = true
	player.get_node("GunCooldown").start()
	player.get_node("AbsorbCooldown").start()

	# Create absorption projectile
	var boomerang = create_absorption_projectile(player)
	if boomerang:
		launch_absorption_projectile(player, boomerang)

	# Visual/sound effects
	on_absorb(player)

static func create_absorption_projectile(player: Player) -> Node2D:
	"""Create absorption projectile instance"""
	if not player.absorb_scene:
		return null
	return player.absorb_scene.instantiate()

static func launch_absorption_projectile(player: Player, projectile: Node2D) -> void:
	"""Launch absorption projectile"""
	player.get_tree().root.add_child(projectile)

	if projectile.has_method("start"):
		projectile.start(player.position + Vector2(0, -8), player)

static func on_absorb(player: Player) -> void:
	"""Handle visual and audio effects for absorption"""
	if player.has_recoil_animation:
		PlayerVisuals.animate_recoil(player)

static func revert_absorption(player: Player) -> void:
	if player.current_form != 'default':
		# Reset to default form
		reset_to_default_form(player)
		player.current_form = 'default'

static func reset_to_default_form(player: Player) -> void:
	# Stop the transformation timer
	if player.transformation_timer:
		player.transformation_timer.stop()

	# In case yellow's charge shot was mid-charge when this form ended
	# (e.g. the auto-revert timer fired), cancel it cleanly rather than
	# leaving is_charging_shot true and the flash color stuck on.
	PlayerChargeShot.cancel_charge(player)

	# Undo whichever transformation modifier is currently active. This
	# restores exactly whatever the player's stats were before transforming
	# (including any permanent progression upgrades) - no hand-written
	# "reset to hardcoded defaults" needed, and nothing gets lost.
	Stats.remove_modifier("transform_" + player.current_form)
	player.bullet_scene = load("res://bullets/bullet.tscn")

	# Reset visual appearance
	player.modulate = player.player_color
	PlayerVisuals.update_sprite(player)

static func absorb_complete(player: Player, hit_enemy_type: String) -> void:
	player.currently_absorbing = false
	if hit_enemy_type:
		player.current_form = hit_enemy_type

		# Call the corresponding transformation function
		var transform_func_name = PlayerTransformations.get_transformation_function_name(hit_enemy_type)

		if player.has_method(transform_func_name):
			player.call(transform_func_name)

		emphasize_ability_acquired(player)

static func absorb_fail(player: Player) -> void:
	player.currently_absorbing = false

# ===== Ability-acquired emphasis (brief pause + screen darken) =====

const ABILITY_ACQUIRED_PAUSE_DURATION := 0.15  # seconds the game freezes for
const ABILITY_ACQUIRED_DARKEN_ALPHA := 0.45  # how dark the screen-wide overlay gets (0 = invisible, 1 = fully black)

static func emphasize_ability_acquired(player: Player) -> void:
	"""Brief hitstop + screen darken right after a transformation lands, so
	the moment reads as "you got something" instead of blending into normal
	play. Pure script, no scene changes needed: builds a full-screen
	CanvasLayer + ColorRect on the fly, pauses the tree, waits out the pause
	on a timer explicitly told to keep running while paused, then unpauses
	and cleans the overlay up. Everything else (enemies, other timers,
	player input) freezes along with the pause - that's the point."""
	if not is_instance_valid(player) or not player.is_inside_tree():
		return

	var overlay_layer := CanvasLayer.new()
	overlay_layer.layer = 100  # draw above the level's own CanvasLayer (UI, popups, etc.)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, ABILITY_ACQUIRED_DARKEN_ALPHA)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchor to fill the whole screen regardless of viewport size, rather than
	# relying on a hardcoded size.
	overlay.anchor_left = 0
	overlay.anchor_top = 0
	overlay.anchor_right = 1
	overlay.anchor_bottom = 1
	overlay.offset_left = 0
	overlay.offset_top = 0
	overlay.offset_right = 0
	overlay.offset_bottom = 0
	overlay_layer.add_child(overlay)

	player.get_tree().root.add_child(overlay_layer)

	player.get_tree().paused = true
	# process_always = true so this timer still ticks down while the tree is
	# paused - otherwise it would never fire and the pause would be permanent.
	await player.get_tree().create_timer(ABILITY_ACQUIRED_PAUSE_DURATION, true).timeout
	player.get_tree().paused = false

	if is_instance_valid(overlay_layer):
		overlay_layer.queue_free()

# ===== Bubble shot (fired instead of absorbing while already transformed) =====

static func shoot_bubble(player: Player) -> void:
	"""Shoot a bubble projectile (used when trying to absorb while having an ability)"""
	if not player.can_shoot or not player.is_alive or not player.can_absorb:
		return

	player.can_shoot = false
	player.can_absorb = false
	player.get_node("GunCooldown").start()
	player.get_node("AbsorbCooldown").start()

	# Create bubble projectile
	var bubble = create_bubble(player)
	if bubble:
		# Pass the current enemy type to the bubble
		if bubble.has_method("set_enemy_type"):
			bubble.set_enemy_type(player.current_form)
		launch_bubble(player, bubble)

	# Visual/sound effects
	on_bubble_shot(player)

const DEFAULT_BUBBLE_SCENE: PackedScene = preload("res://bullets/bubble.tscn")

static func create_bubble(player: Player) -> Node2D:
	"""Create bubble projectile instance"""
	var bubble: Node2D
	if not player.bubble_scene:
		# No scene assigned on the Player node - fall back to the standard
		# bubble scene (res://bullets/bubble.tscn, which uses Bubble_asset.png).
		bubble = DEFAULT_BUBBLE_SCENE.instantiate()
	else:
		bubble = player.bubble_scene.instantiate()
	apply_bubble_stats(bubble)
	return bubble

static func apply_bubble_stats(bubble: Node2D) -> void:
	"""Apply the player's current bubble stats (from Stats) to the bubble."""
	var bub = Stats.get_category("bubble")
	if bub.is_empty():
		return
	bubble.damage = bub.damage
	bubble.speed = bub.speed
	bubble.bubble_lifetime = bub.lifetime
	if "hit_points" in bubble:
		bubble.hit_points = bub.hit_points

static func create_simple_bubble() -> Node2D:
	"""Kept for callers like Player.create_simple_bubble() - now just
	returns an instance of the standard bubble scene (Bubble_asset.png)."""
	return DEFAULT_BUBBLE_SCENE.instantiate()

static func launch_bubble(player: Player, bubble: Node2D) -> void:
	"""Launch bubble projectile"""
	player.get_tree().root.add_child(bubble)

	# Normally the bubble launches upward/in front of the player. If the
	# player has picked up the gray_bubble_behind power-up, flip both the
	# spawn offset and base direction so it launches downward/behind them
	# instead. See stats.gd's "bubble" category and player_powerups.gd's
	# GRAY_POWERUPS.
	var spawn_offset := Vector2(0, -8)
	var base_direction := Vector2(0, -1)
	if Stats.get_stat("bubble", "launch_behind"):
		spawn_offset = Vector2(0, 8)
		base_direction = Vector2(0, 1)

	var launch_direction := get_bubble_launch_direction(player, base_direction)

	if bubble.has_method("start"):
		bubble.start(player.position + spawn_offset, launch_direction)

# How strongly the ship's current velocity steers the bubble's launch angle
# away from straight up/down (0 = ship velocity ignored entirely, 1 = as
# strong an influence on the final direction as the base up/down direction
# itself). Kept modest so a fast dash sends the bubble off at a noticeable
# angle without making a near-stationary shot's direction hard to predict.
const BUBBLE_LAUNCH_VELOCITY_INFLUENCE := 0.6

static func get_bubble_launch_direction(player: Player, base_direction: Vector2) -> Vector2:
	"""Blend the base launch direction (straight up, or down with the
	gray_bubble_behind power-up) with the ship's current velocity, so
	drifting or dashing sideways while firing sends the bubble off at an
	angle instead of always straight up/down."""
	if player.current_velocity.length() <= 0.01:
		return base_direction
	var velocity_direction := player.current_velocity.normalized()
	return (base_direction + velocity_direction * BUBBLE_LAUNCH_VELOCITY_INFLUENCE).normalized()

static func on_bubble_shot(player: Player) -> void:
	"""Handle visual effects for bubble shooting"""
	# Optional: Different recoil animation for bubbles
	if player.has_recoil_animation:
		PlayerVisuals.animate_recoil(player)

	# Optional: Visual feedback
	player.modulate = Color(0.8, 0.9, 1.0, 1.0)
	var timer = player.get_tree().create_timer(0.1)
	timer.timeout.connect(func(): player.modulate = player.player_color)
