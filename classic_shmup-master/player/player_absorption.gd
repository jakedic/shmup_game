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
		else:
			print("No transformation function found for: ", hit_enemy_type)

static func absorb_fail(player: Player) -> void:
	player.currently_absorbing = false

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

static func create_bubble(player: Player) -> Node2D:
	"""Create bubble projectile instance"""
	var bubble: Node2D
	if not player.bubble_scene:
		# Create a simple bubble if no scene is assigned
		bubble = create_simple_bubble()
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
	bubble.travel_distance = bub.travel_distance
	bubble.bubble_lifetime = bub.lifetime
	if "hit_points" in bubble:
		bubble.hit_points = bub.hit_points

static func create_simple_bubble() -> Node2D:
	"""Fallback bubble creation if no bubble scene is assigned"""
	var bubble = Area2D.new()

	# Add sprite
	var sprite = Sprite2D.new()
	sprite.texture = preload("res://Mini Pixel Pack 3/Projectiles/Player_charged_donut_shot (16 x 16).png")  # Add your bubble texture
	sprite.hframes = 4  # Set horizontal frames to 4
	sprite.frame = 0    # Start with first frame
	sprite.scale = Vector2(3.0, 3.0)
	bubble.add_child(sprite)

	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 8
	collision.shape = shape
	bubble.add_child(collision)

	# Add bubble script
	bubble.set_script(preload("res://bullets/bubble.gd"))

	return bubble

static func launch_bubble(player: Player, bubble: Node2D) -> void:
	"""Launch bubble projectile"""
	player.get_tree().root.add_child(bubble)

	# Launch in the direction the player is facing or default up
	var shoot_direction = Vector2.UP

	# Optional: Shoot in direction of movement or mouse
	if player.current_velocity.length() > 0:
		shoot_direction = player.current_velocity.normalized()

	if bubble.has_method("start"):
		bubble.start(player.position + Vector2(0, -8), Vector2(0, -1))

static func on_bubble_shot(player: Player) -> void:
	"""Handle visual effects for bubble shooting"""
	# Optional: Different recoil animation for bubbles
	if player.has_recoil_animation:
		PlayerVisuals.animate_recoil(player)

	# Optional: Visual feedback
	player.modulate = Color(0.8, 0.9, 1.0, 1.0)
	var timer = player.get_tree().create_timer(0.1)
	timer.timeout.connect(func(): player.modulate = player.player_color)
