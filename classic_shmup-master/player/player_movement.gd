extends RefCounted
class_name PlayerMovement

## Handles per-frame movement (acceleration/deceleration), the double-tap
## dash detection, and the dash itself (circular strafe motion, timers).
## Called from player.gd as e.g. PlayerMovement.handle_movement(self, delta).

static func handle_movement(player: Player, delta: float) -> void:
	"""Process player movement with smooth acceleration"""
	var input = Input.get_vector("left", "right", "up", "down")

	# If dashing, override input with dash direction
	if player.is_dashing:
		# Get the dash direction (initial direction when dash started)
		var base_dash_dir = player.dash_direction

		# Track dash time for circular motion
		player.dash_time += delta

		# Create perpendicular vector (90 degrees)
		var perpendicular_dir = base_dash_dir.rotated(PI / 2)

		# Create a vector that will rotate in a circle
		var circle_vector = Vector2(player.circle_radius, 0)

		# Rotate it over time
		var rotation_angle = player.dash_time * player.circle_speed
		circle_vector = circle_vector.rotated(rotation_angle)

		# Rotate this circle to align with our perpendicular plane
		var circle_offset = circle_vector.rotated(perpendicular_dir.angle())

		# Apply player input to modify dash direction
		var modified_direction = (base_dash_dir + input * player.steering_influence).normalized()

		# Smoothly transition to new direction
		player.dash_direction = player.dash_direction.lerp(modified_direction, 2.0 * delta)

		# Apply dash velocity with circular motion added
		player.current_velocity = (player.dash_direction * player.dash_speed) - circle_offset
	elif not player.currently_absorbing:
		# Reset dash time when not dashing
		player.dash_time = 0

		# Normal movement with acceleration/deceleration
		if input.length() > 0:
			player.current_velocity = player.current_velocity.lerp(input * player.speed, player.acceleration * delta)
		else:
			player.current_velocity = player.current_velocity.lerp(Vector2.ZERO, player.deceleration * delta)

	# Update animations (skip animation during dash for different effect)
	if not player.is_dashing:
		update_movement_animation(player, input.x)
	else:
		# Special dash animation
		player.get_node("Ship").frame = 1  # Forward frame during dash
		player.get_node("Ship/Boosters").animation = "forward"

	# Apply movement
	player.position += player.current_velocity * delta

	# Enforce screen boundaries
	clamp_to_screen(player)

static func can_player_dash(player: Player) -> bool:
	"""Check if player can dash"""
	return player.can_dash and player.is_alive and not player.is_dashing

static func update_movement_animation(player: Player, x_input: float) -> void:
	"""Update ship animation based on movement direction"""
	if x_input > 0:
		player.get_node("Ship").frame = 2
		player.get_node("Ship/Boosters").animation = "right"
	elif x_input < 0:
		player.get_node("Ship").frame = 0
		player.get_node("Ship/Boosters").animation = "left"
	else:
		player.get_node("Ship").frame = 1
		player.get_node("Ship/Boosters").animation = "forward"

static func clamp_to_screen(player: Player) -> void:
	"""Keep player within screen boundaries"""
	player.position = player.position.clamp(Vector2(8, 8), player.screensize - Vector2(8, 8))

static func setup_dash_timers(player: Player) -> void:
	"""Set up timers for dash duration and cooldown"""
	player.dash_timer = Timer.new()
	player.dash_timer.name = "DashTimer"
	player.dash_timer.one_shot = true
	player.dash_timer.timeout.connect(func(): on_dash_timer_timeout(player))
	player.add_child(player.dash_timer)

	player.dash_cooldown_timer = Timer.new()
	player.dash_cooldown_timer.name = "DashCooldownTimer"
	player.dash_cooldown_timer.one_shot = true
	player.dash_cooldown_timer.timeout.connect(func(): on_dash_cooldown_timeout(player))
	player.add_child(player.dash_cooldown_timer)

static func update_doubletap_timers(player: Player, delta: float) -> void:
	"""Update all double-tap detection timers"""
	if player.doubletap_time_left > 0:
		player.doubletap_time_left -= delta
	if player.doubletap_time_right > 0:
		player.doubletap_time_right -= delta
	if player.doubletap_time_up > 0:
		player.doubletap_time_up -= delta
	if player.doubletap_time_down > 0:
		player.doubletap_time_down -= delta

static func handle_dash_input(player: Player) -> void:
	"""Handle dash input based on double-tap detection"""
	if not player.is_alive or not player.can_dash or player.is_dashing:
		return

	# Check for double-tap in each direction
	if Input.is_action_just_pressed("left"):
		if player.doubletap_time_left > 0:
			start_dash(player, Vector2.LEFT)
		else:
			player.doubletap_time_left = Player.DOUBLETAP_DELAY

	if Input.is_action_just_pressed("right"):
		if player.doubletap_time_right > 0:
			start_dash(player, Vector2.RIGHT)
		else:
			player.doubletap_time_right = Player.DOUBLETAP_DELAY

	if Input.is_action_just_pressed("up"):
		if player.doubletap_time_up > 0:
			start_dash(player, Vector2.UP)
		else:
			player.doubletap_time_up = Player.DOUBLETAP_DELAY

	if Input.is_action_just_pressed("down"):
		if player.doubletap_time_down > 0:
			start_dash(player, Vector2.DOWN)
		else:
			player.doubletap_time_down = Player.DOUBLETAP_DELAY

	# Also check for double-tap using held direction + opposite press
	# (Alternative method: tap direction, release, tap same direction quickly)
	var input = Input.get_vector("left", "right", "up", "down")
	if input != Vector2.ZERO and input != player.last_direction_input:
		# Check if this is a quick return to the same direction
		if player.last_direction_input != Vector2.ZERO and input.dot(player.last_direction_input) > 0.7:
			# This detects quick direction changes (like left-right-left)
			pass
	player.last_direction_input = input

static func start_dash(player: Player, direction: Vector2) -> void:
	"""Start a dash in the given direction"""
	if not player.can_dash or player.is_dashing:
		return

	# Normalize diagonal dashes
	if direction.length() > 1:
		direction = direction.normalized()

	player.dash_direction = direction
	player.is_dashing = true
	player.can_dash = false

	# Change to dash speed
	player.speed = player.dash_speed

	if player.bullet_invincible_during_dash:
		# Disable collision with enemy bullets
		player.set_collision_layer_value(1, false)  # Disable player collision layer
		player.set_collision_mask_value(2, false)   # Disable enemy bullet collision mask

	# Start dash duration timer
	player.dash_timer.start(player.dash_duration)

	# Visual feedback for dash
	on_dash_start(player)

static func on_dash_start(player: Player) -> void:
	"""Visual and audio effects for dash start"""
	# Visual effect
	player.modulate = Color(0.5, 0.8, 1.0, 0.7)  # Blue tint during dash

	# Particle effect (if you have one)
	if player.has_node("DashParticles"):
		player.get_node("DashParticles").emitting = true

static func on_dash_end(player: Player) -> void:
	"""Clean up dash effects"""
	# Restore normal speed
	player.speed = player.original_speed
	player.is_dashing = false

	if player.bullet_invincible_during_dash:
		player.set_collision_layer_value(1, true)    # Re-enable player collision layer
		player.set_collision_mask_value(2, true)     # Re-enable enemy bullet collision mask

	# Restore normal appearance
	player.modulate = player.player_color

	# Stop particle effects
	if player.has_node("DashParticles"):
		player.get_node("DashParticles").emitting = false

	# Start cooldown timer
	player.dash_cooldown_timer.start(player.dash_cooldown)

	if is_instance_valid(player.get_node("Ship")):
		player.get_node("Ship").rotation = 0

static func on_dash_timer_timeout(player: Player) -> void:
	"""Called when dash duration ends"""
	on_dash_end(player)

static func on_dash_cooldown_timeout(player: Player) -> void:
	"""Called when dash cooldown ends"""
	player.can_dash = true
