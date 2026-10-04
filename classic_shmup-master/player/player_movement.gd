extends RefCounted
class_name PlayerMovement

## Handles per-frame movement (acceleration/deceleration), the jump (dash)
## input - the "jump" action (L) jumps toward the held direction, or in
## place if none is held (double-tap-to-dash was removed) - and the dash
## itself (circular strafe motion, timers).
## Called from player.gd as e.g. PlayerMovement.handle_movement(self, delta).
##
## Dash invincibility (dash_invincible stat, see player/player_powerups.gd -
## yellow_dash_invincibility): covers BOTH enemy bullets (physics-level, via
## the collision layer/mask toggle below) and enemy ships (a plain flag
## checked in PlayerHealth.is_invincible()/handle_enemy_collision(), since
## ship contact is detected through the player's own Area2D rather than the
## collision layer trick). Optionally lingers for a bit after the dash ends
## too - see post_dash_invincibility_duration / on_dash_end() below.

const DASH_TINT_COLOR := Color(0.5, 0.8, 1.0, 0.7)  # blue tint used both for the plain dash and the invincibility flash
const INVINCIBILITY_FLASH_INTERVAL := 0.08  # seconds per half-blink

# Dash "jump" look: the ship grows by JUMP_SCALE_AMOUNT at the top of the
# arc (0.3 = 30% bigger) and shrinks back as it lands. The arc lasts the
# whole dash (dash_duration), so tune the timing there, in stats.gd.
const JUMP_SCALE_AMOUNT := 0.3

# How quickly mid-dash steering turns the ship toward the held direction.
# Higher = more responsive (was a hardcoded 2.0).
const DASH_STEER_RATE := 3.5

# Speed boost while in the air during a jump (1.15 = 15% faster than
# dash_speed). Duration is unchanged, so jumps also cover 15% more ground.
const JUMP_SPEED_MULTIPLIER := 1.15

# Brief invincibility right after landing a dash jump, so the landing
# shockwave gets a chance to kill whatever the ship came down on (or next
# to) before it can hurt the player. Kept short on purpose: when it ends,
# anything the ship is STILL touching hits it (see _check_landing()). The
# shockwave ring is ~90% of its full size by 0.2s.
const LANDING_GRACE_DURATION := 0.2

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

		# Smoothly transition to new direction. Works for in-place jumps too:
		# they start with no direction and steer toward whatever is held.
		player.dash_direction = player.dash_direction.lerp(modified_direction, DASH_STEER_RATE * delta)

		# Apply dash velocity with circular motion added
		player.current_velocity = (player.dash_direction * player.dash_speed * JUMP_SPEED_MULTIPLIER) - circle_offset
	elif not player.currently_absorbing:
		# Reset dash time when not dashing
		player.dash_time = 0

		if player.is_landing_paused:
			# Just landed a jump - stay put until the landing pause ends.
			player.current_velocity = Vector2.ZERO
			input = Vector2.ZERO
		# Normal movement with acceleration/deceleration
		elif input.length() > 0:
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
	"""Jump (dash) on the "jump" action (L). Jumps toward whatever direction
	is held at the moment L is pressed, or straight up in place if no
	direction is held."""
	if not player.is_alive or not player.can_dash or player.is_dashing:
		return
	if Input.is_action_just_pressed("jump"):
		var dir := Input.get_vector("left", "right", "up", "down")
		start_dash(player, dir)

static func ensure_jump_input() -> void:
	"""Make sure the "jump" action exists and is on L, and that L no longer
	triggers "revert" (removed - L used to be revert). This is also set in
	project.godot's Input Map; doing it here too means it still works even
	if the editor ever writes an older project.godot back over it."""
	if not InputMap.has_action("jump"):
		InputMap.add_action("jump", 0.5)
	var has_l := false
	for e in InputMap.action_get_events("jump"):
		if e is InputEventKey and e.physical_keycode == KEY_L:
			has_l = true
	if not has_l:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_L
		InputMap.action_add_event("jump", ev)
	if InputMap.has_action("revert"):
		for e in InputMap.action_get_events("revert"):
			if e is InputEventKey and e.physical_keycode == KEY_L:
				InputMap.action_erase_event("revert", e)

static func start_dash(player: Player, direction: Vector2) -> void:
	"""Start a dash in the given direction"""
	if not player.can_dash or player.is_dashing:
		return

	# Normalize diagonal dashes
	if direction.length() > 1:
		direction = direction.normalized()

	# No direction held -> jump straight up in place (still steerable
	# mid-air, same as any other jump).
	player.dash_in_place = direction == Vector2.ZERO
	player.dash_direction = direction
	player.is_dashing = true
	player.can_dash = false

	# Change to dash speed
	player.speed = player.dash_speed

	# The ship is "in the air" for the whole dash, so it always passes over
	# enemy bullets (physics toggle below) and enemy ships (see
	# PlayerHealth.is_invincible()). The dash_invincible power-up now only
	# adds the blue flash + post-landing grace period on top of this.
	player.set_collision_layer_value(1, false)  # Disable player collision layer
	player.set_collision_mask_value(2, false)   # Disable enemy bullet collision mask

	# Start dash duration timer
	player.dash_timer.start(player.dash_duration)

	# Visual feedback for dash
	on_dash_start(player)

static func on_dash_start(player: Player) -> void:
	"""Visual and audio effects for dash start"""
	if player.bullet_invincible_during_dash:
		# Blinking blue for as long as invincibility actually lasts (the
		# dash itself, then straight on into any post-dash grace period) -
		# a clearer "you're still safe" signal than a static tint,
		# especially once the grace period outlives the dash's own motion.
		_start_invincibility_flash(player)
	else:
		# Plain dash, no invincibility to signal - just the static tint.
		player.modulate = DASH_TINT_COLOR

	# Particle effect (if you have one)
	if player.has_node("DashParticles"):
		player.get_node("DashParticles").emitting = true

	_start_jump(player)

static func on_dash_end(player: Player) -> void:
	"""Clean up dash effects"""
	# Restore normal speed
	player.speed = player.original_speed
	player.is_dashing = false

	# The bullet side of dash invincibility (collision layer/mask) AND the
	# invincibility flash don't get restored/stopped here anymore -
	# _begin_post_dash_grace() below handles both, either immediately (no
	# grace period configured) or after post_dash_invincibility_duration
	# elapses. The ship side (is_post_dash_invincible) is entirely handled
	# there too.
	# Landing shockwave - hits enemies right under the ship immediately, so
	# killing what you land on spares you the landing hit below.
	if player.is_alive:
		_spawn_landing_shockwave(player)

	if player.bullet_invincible_during_dash and player.post_dash_invincibility_duration > LANDING_GRACE_DURATION:
		# Dash Invincibility power-up: its longer grace period already
		# covers the landing.
		_begin_post_dash_grace(player)
	else:
		if not player.bullet_invincible_during_dash:
			# Plain dash - drop the tint, nothing to keep signaling.
			player.modulate = player.player_color
		_begin_landing_grace(player)

	# Stop particle effects
	if player.has_node("DashParticles"):
		player.get_node("DashParticles").emitting = false

	# Land the jump (the tween is timed to finish right about now anyway -
	# this just guarantees an exact return to normal size).
	reset_jump(player)

	# Freeze in place for a moment after touching down.
	_begin_landing_pause(player)

	# Start cooldown timer
	player.dash_cooldown_timer.start(player.dash_cooldown)

	if is_instance_valid(player.get_node("Ship")):
		player.get_node("Ship").rotation = 0

static func _begin_landing_pause(player: Player) -> void:
	"""Hold the ship still for landing_pause_duration seconds after a jump
	lands (handle_movement() zeroes its velocity while is_landing_paused)."""
	if player.landing_pause_duration <= 0.0 or not player.is_alive:
		return
	player.is_landing_paused = true
	player.current_velocity = Vector2.ZERO
	# process_always = false so the pause doesn't tick down while the game
	# itself is paused.
	var timer = player.get_tree().create_timer(player.landing_pause_duration, false)
	timer.timeout.connect(func():
		if is_instance_valid(player):
			player.is_landing_paused = false
	)

static func _begin_landing_grace(player: Player) -> void:
	"""Stay untouchable (bullets + ships) for LANDING_GRACE_DURATION after
	touching down, then check for anything the ship is still on top of."""
	player.is_landing_grace = true
	var timer = player.get_tree().create_timer(LANDING_GRACE_DURATION)
	timer.timeout.connect(func():
		if not is_instance_valid(player):
			return
		player.is_landing_grace = false
		# A new dash already started - it owns the collision state now.
		if player.is_dashing:
			return
		_end_invincibility(player)
		_check_landing(player)
	)

static func _check_landing(player: Player) -> void:
	"""Runs when the landing grace ends. Anything the ship is still
	touching - an enemy the shockwave didn't kill, or one that drifted in
	during the grace - hits it now. (area_entered won't fire again for an
	enemy it was already overlapping, so check by hand.)"""
	for area in player.get_overlapping_areas():
		if not player.is_alive:
			return
		if is_instance_valid(area) and area.is_in_group("enemies"):
			# Skip anything the landing shockwave just killed.
			if "is_alive" in area and not area.is_alive:
				continue
			PlayerHealth.handle_enemy_collision(player, area)

static func _spawn_landing_shockwave(player: Player) -> void:
	"""Expanding ring at the landing spot that damages nearby enemies
	(see player/landing_shockwave.gd for damage/radius/timing)."""
	var parent = player.get_parent()
	if parent == null:
		return
	var wave := LandingShockwave.new()
	parent.add_child(wave)
	wave.global_position = player.global_position
	for area in player.get_overlapping_areas():
		wave.hit(area)

static func _start_jump(player: Player) -> void:
	"""Make the dash look like the ship jumping straight up: over the
	dash's duration, jump_height rises 0 -> 1 -> 0 along a parabola
	(fast lift-off, hang at the top, fast drop - like gravity), and the
	Ship sprite's scale follows it."""
	reset_jump(player)
	var tween := player.create_tween()
	tween.tween_method(
		func(t: float): _apply_jump(player, 4.0 * t * (1.0 - t)),
		0.0, 1.0, player.dash_duration)
	player._jump_tween = tween

static func _apply_jump(player: Player, height: float) -> void:
	player.jump_height = height
	var ship = player.get_node_or_null("Ship")
	if ship and player.ship_base_scale != Vector2.ZERO:
		ship.scale = player.ship_base_scale * (1.0 + JUMP_SCALE_AMOUNT * height)

static func reset_jump(player: Player) -> void:
	"""Stop any jump in progress and put the ship back on the ground."""
	if is_instance_valid(player._jump_tween):
		player._jump_tween.kill()
	player._jump_tween = null
	_apply_jump(player, 0.0)

static func _begin_post_dash_grace(player: Player) -> void:
	"""Keep dash invincibility (and its blue flash) alive for
	post_dash_invincibility_duration seconds after the dash itself has
	already ended - covers enemy bullets (collision layer/mask stays
	disabled a bit longer) and enemy ships (is_post_dash_invincible, read by
	PlayerHealth.is_invincible()). With no grace period configured (the
	default), invincibility just ends immediately, same as before this
	existed."""
	if player.post_dash_invincibility_duration <= 0.0:
		_end_invincibility(player)
		return

	player.is_post_dash_invincible = true
	# Flash keeps blinking uninterrupted straight through from the dash.
	var timer = player.get_tree().create_timer(player.post_dash_invincibility_duration)
	timer.timeout.connect(func():
		if not is_instance_valid(player):
			return
		# If another dash has already started by the time this fires, that
		# dash's own start_dash()/on_dash_end() pair owns the invincibility
		# state now - bail out so we don't yank it out from under a dash
		# that's still in progress.
		if player.is_dashing:
			return
		player.is_post_dash_invincible = false
		_end_invincibility(player)
	)

static func _end_invincibility(player: Player) -> void:
	"""Restore normal bullet collision and stop the invincibility flash -
	called the moment dash invincibility (dash + any grace period) is
	actually over."""
	_restore_bullet_collision(player)
	_stop_invincibility_flash(player)

static func _restore_bullet_collision(player: Player) -> void:
	"""Undo the collision layer/mask changes start_dash() made to hide the
	player from enemy bullets."""
	player.set_collision_layer_value(1, true)    # Re-enable player collision layer
	player.set_collision_mask_value(2, true)     # Re-enable enemy bullet collision mask

static func _start_invincibility_flash(player: Player) -> void:
	"""Blink the ship between blue and its normal color on a loop, for as
	long as dash invincibility is active. Safe to call while one is already
	running (kills it first) so start_dash() -> on_dash_start() can't ever
	stack two."""
	_stop_invincibility_flash(player)
	var tween := player.create_tween()
	tween.set_loops()
	tween.tween_property(player, "modulate", DASH_TINT_COLOR, INVINCIBILITY_FLASH_INTERVAL)
	tween.tween_property(player, "modulate", player.player_color, INVINCIBILITY_FLASH_INTERVAL)
	player._invincibility_flash_tween = tween

static func _stop_invincibility_flash(player: Player) -> void:
	"""Stop the blink loop (if any) and settle back on the player's normal
	color."""
	if is_instance_valid(player._invincibility_flash_tween):
		player._invincibility_flash_tween.kill()
	player._invincibility_flash_tween = null
	player.modulate = player.player_color

static func on_dash_timer_timeout(player: Player) -> void:
	"""Called when dash duration ends"""
	on_dash_end(player)

static func on_dash_cooldown_timeout(player: Player) -> void:
	"""Called when dash cooldown ends"""
	player.can_dash = true
