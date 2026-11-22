# level_0.gd
#
# (Moved here from levels/a_test.gd on 2026-11-06 - a_test is now for small
# one-off tests.)
#
# Practice run of the tutorial: the exact same waves as levels/tutorial.gd
# (it reuses them - edit a wave there and it changes here too), but with no
# dialogue, no tutorial cards, no challenges and nothing that holds the level
# up. Every ability is on from the start, and it just plays straight through
# to the end.
#
# How it gets there, by switching off pieces of TutorialLevel:
#   - talk() / ask() / say() / show_info() do nothing
#   - begin_challenge() does nothing, so there's no right-panel mission and
#     no wave ever repeats
#   - waves 3, 3b, 5a and 5b send their drops for PRACTICE_MIXED_DROP_SECONDS
#     instead of waiting for their challenge (anything left over - target
#     bubbles, green astroids, armored mediums - is cleared when the wave ends)
#   - nothing stops partway down the screen and waits to be shot, and the
#     bomb rings in waves 5a-5c keep falling and
#     leave off the bottom instead of parking until they're destroyed
#
# The badger boss test that used to live here is now levels/boss_test.gd.
extends TutorialLevel

# How long waves 3, 3b, 5a and 5b send their drops for.
const PRACTICE_MIXED_DROP_SECONDS := 21.0
# Bomb rings in waves 5a-5c fall at this speed (px/s) instead of stopping, so
# each ring is on screen for roughly 15-20 seconds.
const PRACTICE_BOMB_RING_SPEED := 20.0


# --- Everything on, no dialogue, no missions ---

func _set_abilities(_can_shoot: bool, _can_jump: bool, _can_absorb: bool) -> void:
	if player:
		player.shoot_enabled = true
		player.jump_enabled = true
		player.absorb_enabled = true


func talk(_lines, _options: Dictionary = {}) -> void:
	pass


func ask(_text: String, _choices: Array, _options: Dictionary = {}) -> int:
	return 0


func say(_text: String, _options: Dictionary = {}) -> void:
	pass


func show_info(_config: Dictionary) -> void:
	pass


func begin_challenge(_config: Dictionary) -> void:
	pass   # no missions - _challenge stays empty, so waves never repeat


func show_challenge() -> void:
	pass


# --- No stopgaps ---

## Nothing parks partway down the screen waiting to be shot.
func spawn_drift_wave(config: Dictionary) -> void:
	var c := config.duplicate()
	c.erase("stop_percent")
	super.spawn_drift_wave(c)


func _mixed_drops_time_limit() -> float:
	return PRACTICE_MIXED_DROP_SECONDS


## Bomb rings fall through and leave instead of waiting to be destroyed.
func run_bomb_ring_challenge(options: Dictionary = {}) -> void:
	var o := options.duplicate()
	var rings: Array = []
	for ring in o.get("rings", DEFAULT_BOMB_RINGS):
		var r: Dictionary = ring.duplicate()
		r["keep_moving"] = true
		r["speed"] = PRACTICE_BOMB_RING_SPEED
		rings.append(r)
	o["rings"] = rings
	await super.run_bomb_ring_challenge(o)
