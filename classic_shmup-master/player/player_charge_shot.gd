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

# Seconds of invulnerability the player gets the moment the charge shot
# becomes fully charged.
const FULL_CHARGE_INVINCIBILITY := 1.0

static func _update_charge(player: Player, delta: float) -> void:
	var was_full := player.charge_shot_time >= player.charge_shot_duration
	player.charge_shot_time += delta
	if not was_full and player.charge_shot_time >= player.charge_shot_duration:
		_grant_full_charge_invincibility(player)

	if player.charge_shot_time >= player.charge_shot_duration:
		# Fully charged - solid sky-blue, no more blinking. While the player
		# is intangible right after reaching full charge, leave the color
		# alone so the bright-yellow intangible flashing (PlayerVisuals.
		# update_form_tint()) reads clearly.
		player.modulate = player.player_color if player.is_charge_invincible else Color.SKY_BLUE
	else:
		# Still charging - blink between normal color and yellow.
		var phase = fmod(player.charge_shot_time, player.charge_flash_interval * 2.0)
		var flash_on = phase < player.charge_flash_interval
		player.modulate = Color.SKY_BLUE if flash_on else player.player_color

static func _grant_full_charge_invincibility(player: Player) -> void:
	"""FULL_CHARGE_INVINCIBILITY seconds of no damage (bullets or ship
	contact - see PlayerHealth.take_damage()/is_invincible()), counted from the
	moment the shot is fully charged whether or not it's released. A sky-blue
	ring pops out from the ship, and the ship flashes bright yellow for as
	long as it lasts (PlayerVisuals.update_form_tint())."""
	player.is_charge_invincible = true
	player._charge_invincible_token += 1
	var token := player._charge_invincible_token
	# process_always = false: pausing the game pauses the countdown too.
	player.get_tree().create_timer(FULL_CHARGE_INVINCIBILITY, false).timeout.connect(func():
		if is_instance_valid(player) and player._charge_invincible_token == token:
			player.is_charge_invincible = false
	)
	var ring := FullChargeRing.new()
	player.add_child(ring)


class FullChargeRing extends Node2D:
	## Quick sky-blue ring that grows and fades around the ship when the
	## charge shot is fully charged (the invulnerability cue).
	const LIFE := 0.35
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / LIFE, 0.0, 1.0)
		draw_arc(Vector2.ZERO, lerpf(8.0, 22.0, k), 0.0, TAU, 32, Color(0.53, 0.81, 0.92, 1.0 - k), 2.0)


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

	GameShell.game_root().add_child(bullet)
	# Lets pollen puffs notice this shot flying through them (see
	# bullets/bullet_pollen_puff.gd - they burst into pollen residue).
	bullet.add_to_group("yellow_charged_shot")

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
	GameShell.game_root().add_child(bullet)

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
