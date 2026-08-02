extends RefCounted
class_name PlayerHealth

## Handles shield/damage/healing, death and revive, and the enemy-collision
## response (dash damage vs. taking damage). Called from player.gd as e.g.
## PlayerHealth.take_damage(self, 1).
##
## set_shield() is NOT here - it has to stay directly on player.gd's own
## setter (the `set = set_shield` property) or it causes infinite
## recursion. See the comment on set_shield() in player.gd.

static func take_damage(player: Player, damage_amount: int = 1) -> void:
	"""Take damage from enemies or hazards"""
	if not player.is_alive:
		return

	player.shield -= damage_amount
	player.time_since_last_damage = 0.0

	# Visual feedback
	flash_damage(player)

static func flash_damage(player: Player) -> void:
	"""Visual feedback when taking damage"""
	var original_color = player.modulate
	player.modulate = Color.RED

	var timer = player.get_tree().create_timer(0.1)
	timer.timeout.connect(func(): player.modulate = original_color)

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

	# Normal collision handling (player takes damage)
	if area.has_method("explode"):
		area.explode()

	# Take damage
	take_damage(player, int(player.max_shield / 2.0))
