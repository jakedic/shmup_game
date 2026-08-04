extends RefCounted
class_name PlayerShooting

## Handles regular bullet shooting: single shot, multi-shot spread, and
## pulling live stats onto a freshly spawned bullet. Called from player.gd
## as e.g. PlayerShooting.shoot(self).

static func handle_shoot_input(player: Player, delta: float) -> void:
	"""Check for shoot input and handle shooting"""
	if player.current_form == 'yellow':
		# Yellow form replaces normal tap-fire with hold-to-charge/release-to-fire.
		PlayerChargeShot.handle_input(player, delta)
		return

	if Input.is_action_pressed("shoot"):
		shoot(player)

static func shoot(player: Player) -> void:
	"""Fire bullets based on current state"""
	if not player.can_shoot or not player.is_alive:
		return

	player.can_shoot = false
	player.get_node("GunCooldown").start()

	# Choose bullet type
	var bullet_type = get_current_bullet_type(player)

	# Fire bullets
	if player.can_multi_shoot and player.shot_count > 1:
		shoot_multiple(player, bullet_type)
	else:
		shoot_single(player, bullet_type)

	# Visual/sound effects
	on_shoot(player)

static func get_current_bullet_type(player: Player) -> PackedScene:
	"""Get the appropriate bullet scene based on absorption state"""
	if player.is_absorbing > 0:
		return player.bullet_yellow_scene if player.bullet_yellow_scene else player.bullet_scene
	return player.bullet_scene

static func shoot_single(player: Player, bullet_type: PackedScene) -> void:
	"""Shoot a single bullet"""
	var bullet = create_bullet(bullet_type)
	if bullet:
		launch_bullet(player, bullet, player.position + Vector2(0, -8))

static func shoot_multiple(player: Player, bullet_type: PackedScene) -> void:
	"""Shoot multiple bullets in a spread"""
	var base_direction = Vector2.UP
	var bullet_spawn = player.position + Vector2(0, -8)

	for i in range(player.shot_count):
		# Calculate spread angle
		var t = float(i) / max(1, player.shot_count - 1)
		var angle = player.shot_spread * (t - 0.5)  # Center the spread
		var direction = base_direction.rotated(deg_to_rad(angle))

		var bullet = create_bullet(bullet_type)
		if not bullet:
			continue

		# Add to the tree first so _ready() runs, THEN reapply the
		# Stats-driven values - same fix and same reason as launch_bullet().
		player.get_tree().root.add_child(bullet)
		configure_bullet(bullet)

		# Set bullet direction if supported
		if bullet.has_method("set_direction"):
			bullet.set_direction(direction)
		elif bullet.has_method("start"):
			# Pass direction to start method if it accepts it
			bullet.start(bullet_spawn, direction)
		else:
			bullet.start(bullet_spawn)

static func create_bullet(bullet_type: PackedScene) -> Node2D:
	"""Create a bullet instance"""
	if not bullet_type:
		return null
	return bullet_type.instantiate()

static func configure_bullet(bullet: Node2D) -> void:
	"""Apply the player's current bullet stats (from Stats) to a freshly
	spawned bullet, overriding whatever the bullet scene's script set as
	its own hardcoded defaults."""
	var b = Stats.get_category("bullet")
	if b.is_empty():
		return
	if bullet.has_method("set_damage"):
		bullet.set_damage(b.damage)
	if bullet.has_method("set_speed"):
		bullet.set_speed(b.speed)
	if bullet.has_method("set_pierce_count"):
		bullet.set_pierce_count(b.pierce_count if b.can_pierce else 0)
	if "max_distance" in bullet:
		bullet.max_distance = b.max_distance
	if "homing_enabled" in bullet:
		bullet.homing_enabled = b.homing_enabled
	if "homing_strength" in bullet:
		bullet.homing_strength = b.homing_strength

static func launch_bullet(player: Player, bullet: Node2D, spawn_pos: Vector2) -> void:
	"""Launch a bullet into the game"""
	player.get_tree().root.add_child(bullet)

	# The bullet's own _ready() just fired via add_child() above, and it
	# hardcodes fallback stats (see bullet.gd / bullet_yellow.gd) - those
	# would otherwise silently overwrite whatever configure_bullet() set
	# earlier (since that ran before the bullet was in the tree, i.e.
	# before _ready() existed to clobber it). Reapply now that _ready()
	# has already had its say, so the real Stats-driven values stick.
	configure_bullet(bullet)

	# Start the bullet
	if bullet.has_method("start"):
		bullet.start(spawn_pos)

	# Emit signal
	player.player_shot.emit(bullet)

static func on_shoot(player: Player) -> void:
	"""Handle visual and audio effects for shooting"""
	if player.has_recoil_animation:
		PlayerVisuals.animate_recoil(player)
