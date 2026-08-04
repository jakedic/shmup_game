extends RefCounted
class_name PlayerChargeShot

## Yellow form's charge shot: hold "shoot" to charge up (flashing yellow,
## then solid yellow once fully charged), release to fire a single
## powerful, piercing bullet. Releasing before it's fully charged cancels
## the shot instead of firing early.
##
## Called from PlayerShooting.handle_shoot_input() only while
## player.current_form == 'yellow'. charge_shot_duration/charge_flash_interval
## are synced from Stats on player.gd (same as absorb_cooldown etc, see
## stats.gd + transform_yellow()); damage/speed/pierce come straight from
## Stats.get_category("bullet") via PlayerShooting.configure_bullet(), same
## as a normal shot. cancel_charge() is called from
## PlayerAbsorption.reset_to_default_form() so a charge can't get stuck
## if the form ends mid-charge (e.g. the auto-revert timer fires).

static func handle_input(player: Player, delta: float) -> void:
	if Input.is_action_just_pressed("shoot") and player.can_shoot and player.is_alive and not player.is_charging_shot:
		_start_charge(player)

	if not player.is_charging_shot:
		return

	if Input.is_action_pressed("shoot"):
		_update_charge(player, delta)

	if Input.is_action_just_released("shoot"):
		_release_charge(player)

static func _start_charge(player: Player) -> void:
	player.is_charging_shot = true
	player.charge_shot_time = 0.0

static func _update_charge(player: Player, delta: float) -> void:
	player.charge_shot_time += delta

	if player.charge_shot_time >= player.charge_shot_duration:
		# Fully charged - solid yellow hue, no more blinking.
		player.modulate = Color.SKY_BLUE
	else:
		# Still charging - blink between normal color and yellow.
		var phase = fmod(player.charge_shot_time, player.charge_flash_interval * 2.0)
		var flash_on = phase < player.charge_flash_interval
		player.modulate = Color.SKY_BLUE if flash_on else player.player_color

static func _release_charge(player: Player) -> void:
	var was_fully_charged = player.charge_shot_time >= player.charge_shot_duration

	player.is_charging_shot = false
	player.charge_shot_time = 0.0
	player.modulate = player.player_color

	if was_fully_charged:
		_fire_charged_shot(player)
	# else: released too early - charge is simply lost, no shot fires.

static func cancel_charge(player: Player) -> void:
	"""Abort any in-progress charge without firing (used when the yellow
	form ends mid-charge). Safe to call even if not currently charging."""
	if not player.is_charging_shot:
		return
	player.is_charging_shot = false
	player.charge_shot_time = 0.0
	player.modulate = player.player_color

static func _fire_charged_shot(player: Player) -> void:
	var bullet_type = player.bullet_yellow_scene if player.bullet_yellow_scene else player.bullet_scene
	var bullet = PlayerShooting.create_bullet(bullet_type)
	if not bullet:
		return

	player.can_shoot = false
	player.get_node("GunCooldown").start()

	player.get_tree().root.add_child(bullet)

	# Configured exactly like a normal shot - damage/speed/pierce/max_distance
	# all come from Stats.get_category("bullet"), i.e. whatever the active
	# transform_yellow modifier currently has them set to. No separate
	# "charge shot" stats to keep in sync with the normal ones; bump the
	# numbers in transform_yellow() and both automatically match.
	PlayerShooting.configure_bullet(bullet)

	if bullet.has_method("start"):
		bullet.start(player.position + Vector2(0, -8))

	player.player_shot.emit(bullet)
	PlayerShooting.on_shoot(player)
