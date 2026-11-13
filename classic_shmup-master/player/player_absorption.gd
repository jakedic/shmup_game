extends RefCounted
class_name PlayerAbsorption

## Handles the absorb projectile, reverting out of an absorbed form, the
## bubble shot (fired instead of absorbing while already transformed), and
## dispatching to the right transform_*() function once an absorb lands.
## Called from player.gd as e.g. PlayerAbsorption.absorb(self).

# Score multiplier the player must be at before they can fire an absorb.
const ABSORB_REQUIRED_MULTIPLIER := 4

static func is_absorb_ready(player: Player) -> bool:
	"""True when pressing absorb right now would fire the absorb beam (4x
	multiplier, off cooldown, untransformed, not already absorbing). Drives
	the flashing white border around the ship (absorb_ready_outline.gd)
	and the "hit the button" prompt in the side HUD (game_shell.gd)."""
	return is_instance_valid(player) and player.is_alive and player.absorb_enabled and player.can_absorb \
		and not player.currently_absorbing and player.current_form == 'default' \
		and player.score_multiplier >= ABSORB_REQUIRED_MULTIPLIER

static func handle_absorb_input(player: Player) -> void:
	"""Process absorption input"""
	# Absorbing is only allowed at ABSORB_REQUIRED_MULTIPLIER (max, 4x).
	if Input.is_action_pressed("absorb") and player.can_absorb and player.current_form == 'default' and player.score_multiplier >= ABSORB_REQUIRED_MULTIPLIER:
		absorb(player)
	if Input.is_action_pressed("absorb") and player.can_absorb and player.current_form != 'default':
		shoot_bubble(player)
		# Keeps half the points earned above 4x (see base_level.gd). Called
		# before revert, so revert's "ability ended" call is a no-op.
		GameShell.multiplier_on_ability_shot_out()
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
		# Freeze the whole game while the absorb beam is out. The beam
		# (bullets/absorb.gd) keeps running on its own and ends the freeze
		# through absorb_complete()/absorb_fail() below.
		_start_absorb_freeze(player)
	else:
		player.currently_absorbing = false

	# Visual/sound effects
	on_absorb(player)

static func create_absorption_projectile(player: Player) -> Node2D:
	"""Create absorption projectile instance"""
	if not player.absorb_scene:
		return null
	return player.absorb_scene.instantiate()

static func launch_absorption_projectile(player: Player, projectile: Node2D) -> void:
	"""Launch absorption projectile"""
	GameShell.game_root().add_child(projectile)

	if projectile.has_method("start"):
		projectile.start(PlayerShooting.muzzle(player), player)

static func on_absorb(player: Player) -> void:
	"""Handle visual and audio effects for absorption"""
	if player.has_recoil_animation:
		PlayerVisuals.animate_recoil(player)

static func revert_absorption(player: Player) -> void:
	if player.current_form != 'default':
		# Transformation over (timed out or reverted manually): multiplier
		# keeps the points earned above 4x (see base_level.gd). No-op if the
		# bubble shot-out already handled it.
		GameShell.multiplier_on_ability_ended()
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

static func set_form_for_test(player: Player, form: String) -> void:
	"""TEST TOOL (pause menu Test: Power-ups -> FORM page): switch straight
	into `form` ("default", "yellow", "gray", "gray_homing" = gray with the
	badger cigar's homing, "hive", "flower", "red"). Leaves the score
	multiplier alone and stops the form's timer, so a test form lasts until
	you pick another one."""
	if player.current_form != 'default':
		reset_to_default_form(player)
		player.current_form = 'default'
	var homing := form == "gray_homing"
	var base_form := "gray" if homing else form
	if base_form == "default" or base_form == "":
		return
	if homing:
		player.set_meta("gray_homing_next", true)
	player.current_form = base_form
	var fn := PlayerTransformations.get_transformation_function_name(base_form)
	if player.has_method(fn):
		player.call(fn)
	if player.transformation_timer:
		player.transformation_timer.stop()

static func _start_absorb_freeze(player: Player) -> void:
	player.absorb_froze_game = true
	player.get_tree().paused = true

static func _end_absorb_freeze(player: Player) -> void:
	if player.absorb_froze_game:
		player.absorb_froze_game = false
		player.get_tree().paused = false

static func absorb_complete(player: Player, hit_enemy_type: String) -> void:
	player.currently_absorbing = false
	_end_absorb_freeze(player)
	if hit_enemy_type:
		player.current_form = hit_enemy_type

		# Call the corresponding transformation function
		var transform_func_name = PlayerTransformations.get_transformation_function_name(hit_enemy_type)

		if player.has_method(transform_func_name):
			player.call(transform_func_name)

		# Absorbing keeps the multiplier and raises its cap to 8x while
		# transformed (see base_level.gd).
		GameShell.multiplier_on_ability_gained()

		emphasize_ability_acquired(player)

static func absorb_fail(player: Player) -> void:
	# The beam can report a miss more than once - only penalize the first.
	var was_absorbing: bool = player.currently_absorbing
	player.currently_absorbing = false
	_end_absorb_freeze(player)
	if was_absorbing:
		# Missed absorb costs multiplier points (see base_level.gd).
		GameShell.multiplier_on_absorb_miss()

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

	GameShell.game_root().add_child(overlay_layer)

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
	GameShell.game_root().add_child(bubble)

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

	# Up/down input changes launch speed. Set before start() so the bubble's
	# base_speed (its paddle-bounce speed cap) scales with it.
	if "speed" in bubble:
		bubble.speed *= get_bubble_launch_speed_mult()

	if bubble.has_method("start"):
		bubble.start(PlayerShooting.ship_center(player) + spawn_offset, launch_direction)

# Bubble launch angle comes from the left/right input held at the moment
# it's fired (not the ship's velocity, so leftover drift doesn't matter).
# A keyboard/d-pad press gives the full MAX_ANGLE; an analog stick tilts it
# in proportion to how far it's pushed. Below DEADZONE it goes straight.
const BUBBLE_LAUNCH_MAX_ANGLE_DEGREES := 60.0
const BUBBLE_LAUNCH_DEADZONE := 0.05

static func get_bubble_launch_direction(_player: Player, base_direction: Vector2) -> Vector2:
	"""Straight up (or down with gray_bubble_behind), tilted left/right by
	the horizontal input being held."""
	var x_input: float = clampf(Input.get_axis("left", "right"), -1.0, 1.0)
	var mag: float = absf(x_input)
	if mag <= BUBBLE_LAUNCH_DEADZONE:
		return base_direction
	var t: float = (mag - BUBBLE_LAUNCH_DEADZONE) / (1.0 - BUBBLE_LAUNCH_DEADZONE)
	var angle: float = deg_to_rad(BUBBLE_LAUNCH_MAX_ANGLE_DEGREES) * t
	return Vector2(signf(x_input) * sin(angle), signf(base_direction.y) * cos(angle))

# Bubble launch speed comes from the up/down input held when it's fired:
# up = up to 30% faster, down = up to 30% slower, neither = normal speed.
# Keyboard/d-pad gives the full amount; an analog stick scales with how far
# it's pushed (same DEADZONE as the angle).
const BUBBLE_LAUNCH_SPEED_CHANGE := 0.3

static func get_bubble_launch_speed_mult() -> float:
	var y_input: float = clampf(Input.get_axis("up", "down"), -1.0, 1.0)   # up = -1
	var mag: float = absf(y_input)
	if mag <= BUBBLE_LAUNCH_DEADZONE:
		return 1.0
	var t: float = (mag - BUBBLE_LAUNCH_DEADZONE) / (1.0 - BUBBLE_LAUNCH_DEADZONE)
	return 1.0 - signf(y_input) * BUBBLE_LAUNCH_SPEED_CHANGE * t

static func on_bubble_shot(player: Player) -> void:
	"""Handle visual effects for bubble shooting"""
	# Optional: Different recoil animation for bubbles
	if player.has_recoil_animation:
		PlayerVisuals.animate_recoil(player)

	# Optional: Visual feedback
	player.modulate = Color(0.8, 0.9, 1.0, 1.0)
	var timer = player.get_tree().create_timer(0.1)
	timer.timeout.connect(func(): player.modulate = player.player_color)
