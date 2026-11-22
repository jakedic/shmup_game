# player_pollen_trail.gd
## "Pollen Trail" yellow power-up (player/player_powerups.gd -
## yellow_pollen_trail): while the player is moving, a patch of pollen
## residue (status_effects/pollen_residue.gd) drops about once every
## DROP_INTERVAL seconds of movement. Each patch lands where the ship was
## LAG seconds ago rather than under the ship, so it tends to sit just behind
## the player's path. Standing still pauses the countdown (it doesn't reset).
##
## Each patch gives every enemy passing through one 50% roll to become
## pollinated, and lasts BASE_DURATION x the power-up's level multiplier
## (Stats "pollen"/"trail_duration_mult": 0 = off, 1 / 1.25 / 1.5 at
## levels 1 / 2 / 3).
##
## Called every frame from player.gd's _process() as
## PlayerPollenTrail.update(self).
extends RefCounted

const POLLEN_RESIDUE_SCRIPT := preload("res://status_effects/pollen_residue.gd")

const DROP_INTERVAL := 1.0     # seconds of movement between patches
const LAG := 0.3               # patch goes where the ship was this long ago
const PATCH_RADIUS := 20.0     # one patch per second now, so each is bigger than the old trail dots
const BASE_DURATION := 2.5     # seconds at level 1 (same as the yellow form's residue)
const MOVE_EPSILON := 0.5      # px per frame below which the ship counts as standing still

const META := "pollen_trail_state"


static func update(player: Node2D) -> void:
	var mult: float = float(Stats.get_stat("pollen", "trail_duration_mult"))
	if mult <= 0.0:
		if player.has_meta(META):
			player.remove_meta(META)
		return

	var delta: float = player.get_process_delta_time()
	var pos: Vector2 = player.global_position
	var st: Dictionary = player.get_meta(META, {})
	if st.is_empty():
		st = {"clock": 0.0, "timer": 0.0, "last_pos": pos, "history": []}
		player.set_meta(META, st)

	st.clock += delta
	var history: Array = st.history
	history.append([st.clock, pos])
	# Keep a little more than LAG seconds of positions.
	while history.size() > 2 and history[1][0] < st.clock - LAG:
		history.pop_front()

	var moved: bool = pos.distance_to(st.last_pos) > MOVE_EPSILON
	st.last_pos = pos
	if not moved:
		return

	st.timer += delta
	if st.timer < DROP_INTERVAL:
		return
	st.timer -= DROP_INTERVAL

	var patch: Node2D = POLLEN_RESIDUE_SCRIPT.new()
	patch.radius = PATCH_RADIUS
	patch.duration = BASE_DURATION * mult
	GameShell.game_root().add_child(patch)
	patch.global_position = _position_at(history, st.clock - LAG)


static func _position_at(history: Array, t: float) -> Vector2:
	"""Ship position at time t, interpolated from the recorded history
	(oldest entry if t is older than anything kept)."""
	if history[0][0] >= t:
		return history[0][1]
	for i in range(1, history.size()):
		if history[i][0] >= t:
			var a: Array = history[i - 1]
			var b: Array = history[i]
			var span: float = maxf(b[0] - a[0], 0.0001)
			return (a[1] as Vector2).lerp(b[1], (t - a[0]) / span)
	return history[history.size() - 1][1]
