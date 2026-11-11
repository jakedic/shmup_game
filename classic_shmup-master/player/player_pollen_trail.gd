# player_pollen_trail.gd
## "Pollen Trail" yellow power-up (player/player_powerups.gd -
## yellow_pollen_trail): while the player moves, small patches of pollen
## residue (status_effects/pollen_residue.gd) are dropped behind the ship
## every DROP_SPACING px. Each patch gives every enemy passing through one
## 50% roll to become pollinated, and lasts BASE_DURATION x the power-up's
## level multiplier (Stats "pollen"/"trail_duration_mult": 0 = off,
## 1 / 1.25 / 1.5 at levels 1 / 2 / 3).
##
## Called every frame from player.gd's _process() as
## PlayerPollenTrail.update(self).
extends RefCounted

const POLLEN_RESIDUE_SCRIPT := preload("res://status_effects/pollen_residue.gd")

const DROP_SPACING := 12.0     # px of movement between patches
const PATCH_RADIUS := 10.0     # each trail patch is small - the trail is a line of them
const BASE_DURATION := 2.5     # seconds at level 1 (same as the yellow form's residue)


static func update(player: Node2D) -> void:
	var mult: float = float(Stats.get_stat("pollen", "trail_duration_mult"))
	if mult <= 0.0:
		player.set_meta("pollen_trail_last", null)
		return
	var pos: Vector2 = player.global_position
	var last = player.get_meta("pollen_trail_last", null)
	if last == null:
		player.set_meta("pollen_trail_last", pos)
		return
	if pos.distance_to(last) < DROP_SPACING:
		return
	player.set_meta("pollen_trail_last", pos)
	var patch: Node2D = POLLEN_RESIDUE_SCRIPT.new()
	patch.radius = PATCH_RADIUS
	patch.duration = BASE_DURATION * mult
	patch.show_outline = false
	GameShell.game_root().add_child(patch)
	patch.global_position = pos
