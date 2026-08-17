extends RefCounted
class_name PlayerChargeShot

## Yellow form's charge shot: hold "shoot" to charge up (flashing yellow,
## then solid yellow once fully charged), release to fire a single
## powerful, piercing bullet. Releasing before it's fully charged no longer
## just cancels the shot - it fires a slow, harmless "pollen puff" instead
## (bullets/bullet_pollen_puff.gd), guaranteed to inflict "pollinated" on
## whatever it touches. See _release_charge()/_fire_pollen_puff() below.
##
## Called from PlayerShooting.handle_shoot_input() only while
## player.current_form == 'yellow'. charge_shot_duration/charge_flash_interval
## are synced from Stats on player.gd (same as absorb_cooldown etc, see
## stats.gd + transform_yellow()); damage/speed/pierce come straight from
## Stats.get_category("bullet") via PlayerShooting.configure_bullet(), same
## as a normal shot. The pollen puff similarly pulls its own stats from
## Stats.get_category("pollen_puff"). cancel_charge() is called from
## PlayerAbsorption.reset_to_default_form() so a charge can't get stuck
## if the form ends mid-charge (e.g. the auto-revert timer fires) - that
## path stays a true no-shot cancel, not a puff, since the player didn't
## choose to release it.

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
	else:
		# Released too early - consolation prize instead of nothing.
		_fire_pollen_puff(player)

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

static func _fire_pollen_puff(player: Player) -> void:
	"""Consolation prize for releasing the charge shot too early: a larger,
	slow-moving, pulsating pollen puff (bullets/bullet_pollen_puff.gd) that
	deals no damage but is guaranteed to inflict "pollinated". Configured
	from Stats.get_category("pollen_puff"), same pattern as
	PlayerPollenShot._spawn_one() uses for the "pollen" category."""
	if not player.bullet_pollen_puff_scene:
		return

	var bullet: Node2D = player.bullet_pollen_puff_scene.instantiate()
	if not bullet:
		return

	player.can_shoot = false
	player.get_node("GunCooldown").start()

	# Add to the tree first so _ready() runs, then apply the live
	# Stats-driven values - same reason as _fire_charged_shot() above: the
	# bullet's own _ready() hardcodes fallback stats that would otherwise
	# clobber whatever we set beforehand.
	player.get_tree().root.add_child(bullet)

	var p: Dictionary = Stats.get_category("pollen_puff")
	if bullet.has_method("set_damage"):
		bullet.set_damage(p.get("damage", 0))
	if bullet.has_method("set_speed"):
		bullet.set_speed(p.get("speed", 45.0))
	if "max_distance" in bullet:
		bullet.max_distance = p.get("max_distance", 260.0)
	if "pulse_amplitude" in bullet:
		bullet.pulse_amplitude = p.get("pulse_amplitude", 0.25)
	if "pulse_frequency" in bullet:
		bullet.pulse_frequency = p.get("pulse_frequency", 3.0)
	if "status_effect_chance" in bullet:
		bullet.status_effect_chance = p.get("status_effect_chance", 1.0)

	if bullet.has_method("start"):
		bullet.start(player.position + Vector2(0, -8))

	player.player_shot.emit(bullet)
	PlayerShooting.on_shoot(player)
