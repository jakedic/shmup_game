## "Pollen Haven" yellow power-up (player/player_powerups.gd -
## yellow_pollen_haven). Only offered once the player owns a power-up that
## leaves pollen residue (PlayerPowerUps.RESIDUE_SOURCE_POWERUP_IDS).
##
## While the ship stands in any pollen residue patch (group "pollen_residue",
## status_effects/pollen_residue.gd) it's invulnerable (the same blue-blink
## intangible state as Safe Landing - PlayerHealth.grant_intangible()). After
## stepping out it stays invulnerable for Stats "player"/"haven_linger"
## seconds (0 / 0.5 / 1 at levels 1 / 2 / 3).
##
## Called every frame from player.gd's _process() as POLLEN_HAVEN.update(self).
extends RefCounted

# While inside, invulnerability is topped up in short slices so it ends
# almost right away (level 1) once the ship leaves the residue.
const HOLD := 0.12
const REFRESH_BELOW := 0.08

static func is_in_residue(player: Node2D) -> bool:
	for patch in player.get_tree().get_nodes_in_group("pollen_residue"):
		if not is_instance_valid(patch) or patch.is_queued_for_deletion():
			continue
		if player.global_position.distance_to(patch.global_position) <= float(patch.radius):
			return true
	return false

static func update(player: Player) -> void:
	if not bool(Stats.get_stat("player", "has_pollen_haven")):
		player.set_meta("pollen_haven_inside", false)
		return
	var was_inside: bool = player.get_meta("pollen_haven_inside", false)
	var inside := is_in_residue(player)
	player.set_meta("pollen_haven_inside", inside)
	if inside:
		var now := Time.get_ticks_msec() / 1000.0
		var until := float(player.get_meta("intangible_until", 0.0))
		if not player.is_charge_invincible or until - now < REFRESH_BELOW:
			PlayerHealth.grant_intangible(player, HOLD)
	elif was_inside:
		PlayerHealth.grant_intangible(player, float(Stats.get_stat("player", "haven_linger")))
