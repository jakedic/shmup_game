# a_test.gd
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
#   - waves 3 / 3b send a fixed number of golden astroid + gray bee drops
#     instead of waiting for an absorb / 5 bubble bounces
#   - nothing stops partway down the screen and waits to be shot (the golden
#     astroid in wave 2), and the bomb rings in waves 5a-5c keep falling and
#     leave off the bottom instead of parking until they're destroyed
#
# The badger boss test that used to live here is now levels/boss_test.gd.
extends TutorialLevel

# Golden astroid + gray bee drops in waves 3 and 3b (one drop every
# SUPPLY_INTERVAL seconds, so 2 = about 22 seconds a wave).
const PRACTICE_SUPPLY_DROPS := 2
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


## A fixed number of drops instead of "until the challenge is done".
func _supply_until_challenge_done(random_astroids: bool = false) -> void:
	_random_astroid_timer = 0.0
	for i in PRACTICE_SUPPLY_DROPS:
		var gold_lane: float = SUPPLY_LANES.pick_random()
		spawn_drift_wave({"enemy": ASTROID_GOLDEN, "start_percent": gold_lane, "speed": 35})
		await _wait_while_challenge_pending(SUPPLY_BEE_DELAY, random_astroids)
		if not is_inside_tree():
			return
		var bee_lane: float = SUPPLY_LANES.pick_random()
		while is_equal_approx(bee_lane, gold_lane):
			bee_lane = SUPPLY_LANES.pick_random()
		spawn_drift_wave({"enemy": GRAY_BEE, "start_percent": bee_lane, "speed": 30})
		await _wait_while_challenge_pending(SUPPLY_INTERVAL - SUPPLY_BEE_DELAY, random_astroids)
		if not is_inside_tree():
			return


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
