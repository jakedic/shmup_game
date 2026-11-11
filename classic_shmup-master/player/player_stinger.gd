## "Stinger" yellow power-up (player/player_powerups.gd - yellow_stinger).
## Only offered once the player owns an invulnerability power-up (Safe
## Landing / Bubble Guard / Second Wind - see
## PlayerPowerUps.INVULNERABILITY_SOURCE_POWERUP_IDS).
##
## While it's owned (Stats "player"/"has_stinger"):
##   - every enemy the ship overlaps while invulnerable takes DAMAGE every
##     TICK_INTERVAL seconds,
##   - the jump cooldown timer is paused for as long as the ship is
##     invulnerable AND touching an enemy,
##   - every invulnerability lasts longer (Stats "player"/"invincibility_mult"
##     = 2 / 2.5 / 3 at levels 1 / 2 / 3 - applied in PlayerHealth).
##
## Called every frame from player.gd's _process() as STINGER.update(self, delta).
extends RefCounted

const DAMAGE := 1
const TICK_INTERVAL := 0.25   # seconds between stings on the same enemy

static func is_owned() -> bool:
	return bool(Stats.get_stat("player", "has_stinger"))

static func is_invulnerable(player: Player) -> bool:
	"""Invulnerable from an ability/hit - not mid-jump (the ship is in the
	air then; the landing shockwave handles what it lands on)."""
	if player.is_dashing:
		return false
	return player.is_charge_invincible or player.is_hit_invincible or player.is_post_dash_invincible

static func _touching_enemies(player: Player) -> Array:
	var out: Array = []
	for area in player.get_overlapping_areas():
		if not is_instance_valid(area) or area.is_queued_for_deletion():
			continue
		if not (area.is_in_group("enemies") or area.is_in_group("enemy")):
			continue
		if "is_alive" in area and not area.is_alive:
			continue
		out.append(area)
	return out

static func update(player: Player, delta: float) -> void:
	var cooldown: Timer = player.dash_cooldown_timer
	if not is_owned():
		if cooldown and cooldown.paused and bool(player.get_meta("stinger_paused_cooldown", false)):
			cooldown.paused = false
			player.set_meta("stinger_paused_cooldown", false)
		return

	var touching: Array = _touching_enemies(player) if is_invulnerable(player) else []

	# Jump cooldown only ticks while NOT (invulnerable and on an enemy).
	if cooldown:
		cooldown.paused = not touching.is_empty()
		player.set_meta("stinger_paused_cooldown", cooldown.paused)

	# Per-enemy sting timers (instance id -> seconds until next sting).
	var next: Dictionary = player.get_meta("stinger_next", {})
	var still: Dictionary = {}
	for enemy in touching:
		var id: int = enemy.get_instance_id()
		var left: float = float(next.get(id, 0.0)) - delta
		if left <= 0.0:
			if enemy.has_method("take_damage"):
				enemy.take_damage(DAMAGE, {"source": "stinger"})
			elif enemy.has_method("explode"):
				enemy.explode()
			left = TICK_INTERVAL
		still[id] = left
	player.set_meta("stinger_next", still)
