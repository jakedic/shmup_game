# a_test.gd
#
# Scratch level for small, one-off tests. (The full tutorial practice run that
# used to live here moved to levels/level_0.gd on 2026-11-06.)
#
# CURRENT TEST: one wave of the tutorial on its own - see _test_wave() below,
# which runs the real wave function from levels/tutorial.gd (same dialogue,
# cards, challenge and spawns). Edit the wave in tutorial.gd and it changes
# here too.
#
# Waves played through so far:
#   3b  Bubbles (absorb the 3 green bubbles)          - done 2026-11-06
#   5a  Using Bubbles: Shoot (cosmic storm)           - CURRENT
#       (was "Using Bubbles: Jump" with bomb rings until 2026-11-06)
#
# Differences from playing it inside the tutorial:
#   - You start already in the gray form (as if you'd just absorbed a gray
#     bee), so you have a bubble to shoot right away. Set START_TRANSFORMED to
#     false to start untransformed and earn it from the supply drops instead.
#   - It's the only wave. Fail the challenge and it replays; finish it and the
#     level ends (back to the Test menu).
extends TutorialLevel

const START_TRANSFORMED := true


func _ready() -> void:
	super._ready()   # TutorialLevel sets up the full wave list + challenge hooks...
	waves = [_test_wave]   # ...then swap in just this test
	max_waves = waves.size()


## Swap the wave call here to test a different one (e.g. _wave_3b, _wave_5b).
func _test_wave() -> void:
	if START_TRANSFORMED:
		_start_in_gray_form()
	await _wave_5a()


## Same end result as absorbing a gray bee, minus the beam / hitstop.
func _start_in_gray_form() -> void:
	if not player or player.current_form != 'default':
		return
	player.current_form = 'gray'
	player.transform_gray()
	GameShell.multiplier_on_ability_gained()
