extends RefCounted
class_name PlayerHealth

## Handles shield/damage/healing, death and revive, and the enemy-collision
## response (dash damage vs. taking damage vs. dash invincibility - see
## is_invincible()). Called from player.gd as e.g.
## PlayerHealth.take_damage(self, 1).
##
## set_shield() is NOT here - it has to stay directly on player.gd's own
## setter (the `set = set_shield` property) or it causes infinite
## recursion. See the comment on set_shield() in player.gd.

# After a hit the player can't be hurt again for this long, and blinks the
# whole time (the side-panel portrait also shows the nervous face for it).
const HIT_INVINCIBILITY_DURATION := 1.0
const HIT_BLINK_INTERVAL := 0.07     # seconds per half-blink
const HIT_BLINK_ALPHA := 0.25        # how see-through the ship gets on the "off" beat

static func take_damage(player: Player, damage_amount: int = 1) -> void:
	"""Take damage from enemies or hazards"""
	if not player.is_alive:
		return
	# Still blinking from the last hit - ignore.
	if player.is_hit_invincible:
		return

	player.shield -= damage_amount
	player.time_since_last_damage = 0.0

	# Visual feedback
	flash_damage(player)

	if player.is_alive:
		start_hit_invincibility(player)
		GameShell.on_player_hit(HIT_INVINCIBILITY_DURATION)

static func start_hit_invincibility(player: Player) -> void:
	"""Blink and ignore all damage for HIT_INVINCIBILITY_DURATION seconds."""
	player.is_hit_invincible = true
	if is_instance_valid(player._hit_blink_tween):
		player._hit_blink_tween.kill()
	# Blink by fading the ship in/out (alpha only, so it doesn't fight the
	# red hit flash / dash tint, which change the colour).
	var tween := player.create_tween()
	tween.set_loops()
	tween.tween_property(player, "modulate:a", HIT_BLINK_ALPHA, HIT_BLINK_INTERVAL)
	tween.tween_property(player, "modulate:a", 1.0, HIT_BLINK_INTERVAL)
	player._hit_blink_tween = tween
	# process_always = false so pausing the game pauses the countdown too.
	var timer := player.get_tree().create_timer(HIT_INVINCIBILITY_DURATION, false)
	timer.timeout.connect(func():
		if is_instance_valid(player) and tween == player._hit_blink_tween:
			end_hit_invincibility(player)
	)

static func end_hit_invincibility(player: Player) -> void:
	player.is_hit_invincible = false
	if is_instance_valid(player._hit_blink_tween):
		player._hit_blink_tween.kill()
	player._hit_blink_tween = null
	player.modulate.a = 1.0

static func flash_damage(player: Player) -> void:
	"""Visual feedback when taking damage"""
	var original_color = player.modulate
	player.modulate = Color.RED

	var timer = player.get_tree().create_timer(0.1)
	# Restore the colour but keep whatever alpha the hit blink is on.
	timer.timeout.connect(func(): player.modulate = Color(original_color, player.modulate.a))

static func heal(player: Player, amount: int) -> void:
	"""Heal the player"""
	if not player.is_alive:
		return

	var old_shield = player.shield
	player.shield = min(player.shield + amount, player.max_shield)

	if player.shield > old_shield:
		player.player_healed.emit(player.shield - old_shield)

		# Visual feedback
		player.modulate = Color.GREEN
		var timer = player.get_tree().create_timer(0.2)
		timer.timeout.connect(func(): player.modulate = player.player_color)

static func process_shield_regen(player: Player, delta: float) -> void:
	"""Process automatic shield regeneration"""
	if player.shield_regen_rate > 0 and player.shield < player.max_shield:
		player.time_since_last_damage += delta

		if player.time_since_last_damage >= player.shield_regen_delay:
			player.shield += int(player.shield_regen_rate * delta)
			player.shield = min(player.shield, player.max_shield)

static func die(player: Player) -> void:
	"""Handle player death"""
	if not player.is_alive:
		return

	player.is_alive = false
	player.hide()
	player.died.emit()

	# Custom death behavior
	custom_die(player)

static func custom_die(player: Player) -> void:
	"""Override this for custom death behavior"""
	pass

static func revive(player: Player) -> void:
	"""Revive the player"""
	if not player.is_alive:
		player.is_alive = true
		player.initialize_player()

static func on_area_entered(player: Player, area: Area2D) -> void:
	"""Handle collision with enemies"""
	if area.is_in_group("enemies"):
		handle_enemy_collision(player, area)

static func handle_enemy_collision(player: Player, area: Area2D) -> void:
	"""Handle collision with enemy"""

	# Check if we're dashing and should damage enemies instead of taking damage
	if player.is_dashing and player.do_dash_damage_to_enemies:
		var damage_dealt = false

		if area.has_method("take_damage"):
			area.take_damage(player.dash_damage_amount)
			damage_dealt = true
		elif area.has_method("explode"):
			area.explode()
			damage_dealt = true

		# Optional: Apply knockback to enemy
		if area.has_method("apply_knockback") and damage_dealt:
			var knockback_direction = (area.global_position - player.global_position).normalized()
			area.apply_knockback(knockback_direction, player.dash_speed * 0.5)

		# Optional: Add visual feedback for damaging enemies during dash
		if damage_dealt:
			if player.has_node("DashDamageParticles"):
				player.get_node("DashDamageParticles").global_position = area.global_position
				player.get_node("DashDamageParticles").emitting = true

			# Optional screen shake effect
			if player.get_tree().has_group("camera"):
				player.get_tree().call_group("camera", "add_trauma", 0.3)

		# Return early - player doesn't take damage during dash
		return

	# Dash invincibility (see is_invincible()) covers ship contact too, not
	# just enemy bullets - the ship just passes through harmlessly: no
	# damage to the player, and (unlike the do_dash_damage_to_enemies branch
	# above) no forced kill either, since the player isn't choosing to ram
	# it, just surviving contact with it.
	if is_invincible(player):
		return

	# Normal collision handling (player takes damage)
	if area.has_method("explode"):
		area.explode()

	# Take damage
	take_damage(player, 4.0)

static func is_invincible(player: Player) -> bool:
	"""True while the player should take no damage from enemy ship contact -
	either mid-dash with dash_invincible active, or during the brief grace
	window right after the dash ends (post_dash_invincibility_duration, see
	PlayerMovement.on_dash_end()/_begin_post_dash_grace()). Enemy bullets are
	handled separately/physically (collision layer toggle in
	player_movement.gd), but ship contact is detected through the player's
	own Area2D, so it needs this explicit check instead."""
	# Every dash is a jump now, so the ship is untouchable for the whole
	# dash (not just with dash_invincible) - see PlayerMovement.start_dash().
	return player.is_dashing or player.is_post_dash_invincible or player.is_landing_grace or player.is_hit_invincible
