# a_test.gd
#
# Scratch/test level for trying out new enemies AND a worked example of the
# level-flow tools (see base_level.gd's WAVE FLOW + DIALOGUE sections):
#
#   next_wave_after_last_spawn(seconds) - next wave comes `seconds` after this
#                                         wave's last enemy spawns (or sooner
#                                         if the screen is cleared first)
#   say(text, options)                  - side-panel dialogue, game keeps going
#   await talk(lines, options)          - center dialogue, game pauses until
#                                         the player clicks through
#   await wait(seconds)                 - pause-aware delay inside a wave
#
# Built the same way as Yellow/Dylan Level - one function per wave, each spawn
# a labeled config (see levels/squad_wave_level.gd's header comment for every
# field). The intro conversation plays once, then the combat waves loop forever
# so you can keep watching. Pause -> Quit to leave.
extends SquadWaveLevel


# Enemy scenes (ENEMY_BEE, FLOWER, ...), dialogue faces (FACE_HAPPY,
# FACE_NERVOUS, ...) and speaker presets (FROG) are shared by every level -
# they're declared once in levels/squad_wave_level.gd.


# Intro - a pausing, center-screen conversation before anything spawns. Each
# line can set its own speaker/portrait; anything a line leaves out comes from
# the shared options (FROG here). No enemies in this wave, so once the player
# clicks through the last line the next wave starts right away.
func _wave_intro() -> void:
	await talk([
		{"text": "Okay... systems online. Let's see what this test zone has for us.", "portrait": FACE_HAPPY},
		{"text": "Hives and flowers on the scanner. Nothing I can't handle."},
		{"text": "(Press shoot to continue.)"},
	], FROG)


# Wave 1 - TIMED: the next wave comes 4 seconds after this wave's last enemy
# spawns (the flower with start_delay 10.0 -> wave 2 at ~14s), even if some of
# these are still alive. Kill everything sooner and wave 2 comes sooner.
# The side-panel lines play while you fight - the game never stops.
func _wave_1() -> void:
	say("Hive coming in from the top!", FROG)
	spawn_hive_wave({"enemy": ENEMY_HIVE, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.3})
	spawn_flower_squad_wave({"enemy": FLOWER, "start_percent": LANE_CENTER, "attack_heights": [0.0, 0.2, 0.4]})
	spawn_flower_wave({"enemy": FLOWER, "start_percent": 0.7, "start_delay": 10.0, "sway_width": 22.0, "sway_time": 1.6, "fall_speed": 40.0})
	say("Flower squad down the middle - watch the lasers.", FROG)
	next_wave_after_last_spawn(4.0)


# Wave 2 - NOT timed (no next_wave_after_last_spawn), so the next loop only
# starts once every flower is gone. Shows dialogue in the MIDDLE of a wave:
# the wave function awaits a wait() and a talk() between spawns, and still
# counts as running the whole time, so the level never skips ahead.
func _wave_2() -> void:
	spawn_flower_wave({"enemy": FLOWER, "start_percent": LANE_LEFT, "attack_heights": [0.15, 0.5]})
	spawn_flower_wave({"enemy": FLOWER, "start_percent": LANE_RIGHT, "start_delay": 2.5, "attack_heights": [0.3]})
	say("More flowers. Left, then right.", FROG)

	await wait(4.0)   # ...4 seconds of gameplay later (pausing doesn't count)

	await talk("Wait, there's more of them?! Here comes a whole bunch!", {"speaker": "Frog", "portrait": FACE_NERVOUS})
	spawn_flower_wave({"enemy": FLOWER, "start_percent": LANE_CENTER, "attack_heights": [0.1, 0.35, 0.6]})
	# Example of tweaking one flower's motion: wider, slower, lazier swing.
	spawn_flower_wave({"enemy": FLOWER, "start_percent": 0.35, "start_delay": 4.0, "sway_width": 55.0, "sway_time": 3.5, "fall_speed": 20.0})
	# ...and a quicker, tighter one.
	spawn_flower_wave({"enemy": FLOWER, "start_percent": 0.7, "start_delay": 6.0, "sway_width": 22.0, "sway_time": 1.6, "fall_speed": 40.0})
	# `await say(...)` waits for the line to finish before continuing - not
	# needed here, just showing a line with a custom on-screen time.
	say("Last batch. Clear these and we loop!", {"speaker": "Frog", "portrait": FACE_HAPPY, "duration": 3.0})


func _ready() -> void:
	level_paths = {
		"next_level": "res://levels/test_menu.tscn"
	}
	waves = [_wave_intro, _wave_1, _wave_2]
	fallback_enemy = FLOWER
	super._ready()
	max_waves = 999  # keep looping the waves (see spawn_enemies() below)


func spawn_enemies() -> void:
	# Play every wave once (intro included), then loop the combat waves
	# forever, skipping the intro.
	var index: int = current_wave
	if index >= waves.size():
		index = 1 + (current_wave - 1) % (waves.size() - 1)
	await waves[index].call()
