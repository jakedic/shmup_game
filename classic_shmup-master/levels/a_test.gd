# a_test.gd
#
# Scratch level for small, one-off tests. (The full tutorial practice run that
# used to live here moved to levels/level_0.gd on 2026-11-06.)
#
# CURRENT TEST: the rainbow astroid boss on its own
# (enemies/boss_rainbow_astroid.tscn - all its moves and timings are in
# enemies/boss_rainbow_astroid.gd). Beat it and the level ends (back to the
# Test menu). Same boss that ends level_0.
#
# Tests run here so far:
#   3b  Bubbles (absorb the 3 green bubbles)          - done 2026-11-06
#   5a  Using Bubbles: Shoot (cosmic storm)
#   5b  Using Bubbles: Jump (armored mediums)
#   Rainbow astroid boss                              - CURRENT (2026-11-24)
#
# To go back to testing a tutorial wave, point _test_wave() at it again
# (e.g. `await _wave_5b()`).
extends TutorialLevel

const BOSS_RAINBOW_ASTROID := preload("res://enemies/boss_rainbow_astroid.tscn")

# Start already in the gray form (as if you'd just absorbed a gray bee) -
# only used if _test_wave() calls _start_in_gray_form().
const START_TRANSFORMED := true


func _ready() -> void:
	super._ready()   # TutorialLevel sets up the full wave list + challenge hooks...
	waves = [_test_wave]   # ...then swap in just this test
	max_waves = waves.size()


func _test_wave() -> void:
	_set_abilities(true, true, true)   # shoot, jump and absorb all on
	clear_challenge()                  # no mission panel for the boss
	var boss = BOSS_RAINBOW_ASTROID.instantiate()
	add_child(boss)
	boss.start()


## Same end result as absorbing a gray bee, minus the beam / hitstop.
func _start_in_gray_form() -> void:
	if not player or player.current_form != 'default':
		return
	player.current_form = 'gray'
	player.transform_gray()
	GameShell.multiplier_on_ability_gained()
