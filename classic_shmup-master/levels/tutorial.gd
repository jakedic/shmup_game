# tutorial.gd
#
# Tutorial level - started as a copy of levels/a_test.gd (same waves and
# dialogue), to be reworked into the real tutorial. Uses the level-flow
# tools (see base_level.gd's WAVE FLOW + DIALOGUE sections):
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
# field). Every wave plays once, in order; once wave 6 is cleared the level
# ends and goes to level_paths["next_level"].
extends SquadWaveLevel


# Enemy scenes (ENEMY_BEE, FLOWER, ...), dialogue faces (FACE_HAPPY,
# FACE_NERVOUS, ...) and speaker presets (FROG) are shared by every level -
# they're declared once in levels/squad_wave_level.gd.


# Options for the "What'll it be?" question in _wave_intro(), in the order
# they're listed there.
const CHOICE_START_TUTORIAL := 0
const CHOICE_FORGE_SIGNATURE := 1

# Tutorial card clips (Art assets/Tutorial). movement.ogv is a placeholder
# recording of the ship dodging astroids - replace the file to update it.
const TUTORIAL_MOVEMENT_VIDEO := "res://Art assets/Tutorial/movement.ogv"
# When each key is pressed in movement.ogv - [key, from, to] in seconds of
# the clip - so the W/A/S/D caps light up in sync with the ship. Nudge these
# if you re-record the clip.
const TUTORIAL_MOVEMENT_KEYS := [
	["A", 0.25, 0.85],   # left
	["D", 1.15, 1.85],   # back right
	["W", 2.00, 2.55],   # up
	["S", 2.95, 3.65],   # down
]

# Jump card clip (a later part of the same recording): two jumps with the
# full cooldown wait between them. Times are seconds of jump.ogv.
const TUTORIAL_JUMP_VIDEO := "res://Art assets/Tutorial/jump.ogv"
const TUTORIAL_JUMP_KEYS := [
	["L", 0.35, 0.55],   # first jump (lands at ~1.23)
	["L", 3.05, 3.25],   # second jump (lands at ~3.93)
]
# Landing + cooldown after each jump (landing pause 0.25 + dash_cooldown 1.5
# in stats.gd) - the L cap dims and refills during these.
const TUTORIAL_JUMP_COOLDOWNS := [
	["L", 1.23, 2.98],
	["L", 3.93, 5.68],
]

# Shooting card clip: holding SPACE and firing a stream of shots.
const TUTORIAL_SHOOT_VIDEO := "res://Art assets/Tutorial/shoot.ogv"
const TUTORIAL_SHOOT_KEYS := [
	["SPACE", 0.6, 2.75],
]

# Absorb card clip: a gray bee drifts in, K fires the absorb beam, the ship
# takes on its form.
const TUTORIAL_ABSORB_VIDEO := "res://Art assets/Tutorial/absorb.ogv"
const TUTORIAL_ABSORB_KEYS := [
	["K", 1.75, 1.95],
]

# Transformation card clip: the gray ship flashing as the form runs out, then
# reverting to normal. No keys - it's just showing the timer running down.
const TUTORIAL_RUNOUT_VIDEO := "res://Art assets/Tutorial/transform_runout.ogv"

# Bubble card clip: K gives up the gray form and shoots out a bubble, which
# then bounces around the level.
const TUTORIAL_BUBBLE_VIDEO := "res://Art assets/Tutorial/bubble.ogv"
const TUTORIAL_BUBBLE_KEYS := [
	["K", 0.85, 1.05],
]

# "Using Bubbles" card - one short clip per way to use a bubble:
#   bubble_jump.ogv    - jump next to a falling bubble; the landing charges it
#                        and it flies into a ring and sets off the bomb
#   bubble_shoot.ogv   - fire a bubble and shoot it: big explosion
#   bubble_combine.ogv - two bubbles merge (Penetrator Rounds), then shots go
#                        through a ring to hit the bomb
const TUTORIAL_BUBBLE_JUMP_VIDEO := "res://Art assets/Tutorial/bubble_jump.ogv"
const TUTORIAL_BUBBLE_SHOOT_VIDEO := "res://Art assets/Tutorial/bubble_shoot.ogv"
const TUTORIAL_BUBBLE_COMBINE_VIDEO := "res://Art assets/Tutorial/bubble_combine.ogv"

# Red Frog as a speaker preset for say()/talk().
const RED_FROG := {"speaker": "Red Frog", "portrait": FACE_RED}

# Which abilities the player has in each tutorial wave. Wave 0 (intro) is
# movement only, wave 1 adds jumping, wave 2 unlocks everything.
func _set_abilities(can_shoot: bool, can_jump: bool) -> void:
	if player:
		player.shoot_enabled = can_shoot
		player.jump_enabled = can_jump


# Intro - a pausing, center-screen conversation before anything spawns. Each
# line can set its own speaker/portrait; anything a line leaves out comes from
# the shared options (FROG here). No enemies in this wave, so once the player
# clicks through the last line the next wave starts right away.
func _wave_intro() -> void:
	_set_abilities(false, false)   # movement only - no shooting, no jumping
	await talk([
		{"text": "Corporate has me taking you through basic training today.", "portrait": FACE_RED,"speaker": "Red Frog"},
		{"text": "Listen, I don't pick the insurance plan I just deal with the consequences of it. One way or another we gotta get through this.","portrait": FACE_RED,"speaker": "Red Frog"},
		{"text": "We can either do this the hard way or the way that involves me forging a signature.","portrait": FACE_RED,"speaker": "Red Frog"},
	], FROG)

	# Player picks one of the options - `choice` is its position in the list
	# (0 = "Start Tutorial", 1 = "Forge Signature").
	var choice: int = await ask("What'll it be?", ["Start Tutorial", "Forge Signature and Lie to Corporate"], {"portrait": FACE_RED, "speaker": "Red Frog"})
	if choice == CHOICE_START_TUTORIAL:
		pass   # TODO: tutorial path - for now both choices carry on the same way
	elif choice == CHOICE_FORGE_SIGNATURE:
		pass   # TODO: forge-signature path - for now both choices carry on the same way

	await talk([
		{"text": "Begin the training module by having the trainee navigate through BLAH BLAH BLAH", "portrait": FACE_RED,"speaker": "Red Frog"},
		{"text": "Why don't you just try and avoid these astroids. Seems like a good warm-up.","portrait": FACE_RED,"speaker": "Red Frog"},
	], FROG)

	# Tutorial card: how to move. Pauses until the player closes it.
	await show_info({
		"title": "Movement",
		"video": TUTORIAL_MOVEMENT_VIDEO,
		"keys": [["W"], ["A", "S", "D"]],
		"key_timeline": TUTORIAL_MOVEMENT_KEYS,
	})

	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": 45, "start_delay": 0.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": 45, "start_delay": 0.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 45, "start_delay": 0.0})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.65, "speed": 45, "start_delay": 2.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.35, "speed": 45, "start_delay": 2.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": 45, "start_delay": 2.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": 45, "start_delay": 2.0})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": 45, "start_delay": 4.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": 45, "start_delay": 4.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 45, "start_delay": 4.0})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.65, "speed": 45, "start_delay": 6.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.35, "speed": 45, "start_delay": 6.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": 45, "start_delay": 6.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": 45, "start_delay": 6.0})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": 45, "start_delay": 8.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": 45, "start_delay": 8.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.85, "end_side": Side.BOTTOM, "end_percent": 0.85, "speed": 45, "start_delay": 8.75})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.15, "end_side": Side.BOTTOM, "end_percent": 0.15, "speed": 45, "start_delay": 8.75})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": 45, "start_delay": 9.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": 45, "start_delay": 9.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.75, "end_side": Side.BOTTOM, "end_percent": 0.75, "speed": 45, "start_delay": 10.25})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.25, "end_side": Side.BOTTOM, "end_percent": 0.25, "speed": 45, "start_delay": 10.25})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.7, "end_side": Side.BOTTOM, "end_percent": 0.7, "speed": 45, "start_delay": 11.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.3, "speed": 45, "start_delay": 11.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.65, "end_side": Side.BOTTOM, "end_percent": 0.65, "speed": 45, "start_delay": 11.75})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.35, "end_side": Side.BOTTOM, "end_percent": 0.35, "speed": 45, "start_delay": 11.75})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "speed": 45, "start_delay": 12.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.4, "speed": 45, "start_delay": 12.5})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.6, "end_side": Side.LEFT, "end_percent": 0.65, "speed": 45, "start_delay": 15.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.4, "end_side": Side.LEFT, "end_percent": 0.35, "speed": 45, "start_delay": 15.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.9, "end_side": Side.LEFT, "end_percent": 0.9, "speed": 45, "start_delay": 15.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.1, "end_side": Side.LEFT, "end_percent": 0.1, "speed": 45, "start_delay": 15.0})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.5, "end_side": Side.RIGHT, "end_percent": 0.5, "speed": 45, "start_delay": 15.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.775, "end_side": Side.RIGHT, "end_percent": 0.775, "speed": 45, "start_delay": 15.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.225, "end_side": Side.RIGHT, "end_percent": 0.225, "speed": 45, "start_delay": 15.0})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": 45, "start_delay": 17.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": 45, "start_delay": 17.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.3, "speed": 45, "start_delay": 17.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.4, "speed": 45, "start_delay": 17.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 45, "start_delay": 17.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "speed": 45, "start_delay": 17.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.7, "end_side": Side.BOTTOM, "end_percent": 0.7, "speed": 45, "start_delay": 17.0})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": 45, "start_delay": 19.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": 45, "start_delay": 19.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.3, "speed": 45, "start_delay": 19.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.4, "speed": 45, "start_delay": 19.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 45, "start_delay": 19.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "speed": 45, "start_delay": 19.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.7, "end_side": Side.BOTTOM, "end_percent": 0.7, "speed": 45, "start_delay": 19.5})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": 45, "start_delay": 22.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": 45, "start_delay": 22.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.3, "speed": 45, "start_delay": 22.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.4, "speed": 45, "start_delay": 22.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 45, "start_delay": 22.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "speed": 45, "start_delay": 22.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.7, "end_side": Side.BOTTOM, "end_percent": 0.7, "speed": 45, "start_delay": 22.0})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": 45, "start_delay": 24.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": 45, "start_delay": 24.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.3, "speed": 45, "start_delay": 24.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.4, "speed": 45, "start_delay": 24.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 45, "start_delay": 24.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "speed": 45, "start_delay": 24.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.7, "end_side": Side.BOTTOM, "end_percent": 0.7, "speed": 45, "start_delay": 24.5})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": 45, "start_delay": 26.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 45, "start_delay": 26.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": 45, "start_delay": 26.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": 45, "start_delay": 28.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 45, "start_delay": 28.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": 45, "start_delay": 28.5})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": 45, "start_delay": 30.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 45, "start_delay": 30.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": 45, "start_delay": 30.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": 45, "start_delay": 32.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 45, "start_delay": 32.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": 45, "start_delay": 32.5})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.9, "end_side": Side.RIGHT, "end_percent": 0.9, "speed": 45, "start_delay": 34.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.9, "end_side": Side.RIGHT, "end_percent": 0.5, "speed": 45, "start_delay": 34.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.9, "end_side": Side.RIGHT, "end_percent": 0.1, "speed": 45, "start_delay": 34.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.1, "end_side": Side.LEFT, "end_percent": 0.1, "speed": 45, "start_delay": 34.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.1, "end_side": Side.LEFT, "end_percent": 0.5, "speed": 45, "start_delay": 34.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.1, "end_side": Side.LEFT, "end_percent": 0.9, "speed": 45, "start_delay": 34.5})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.9, "end_side": Side.LEFT, "end_percent": 0.9, "speed": 45, "start_delay": 36.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.9, "end_side": Side.LEFT, "end_percent": 0.5, "speed": 45, "start_delay": 36.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.RIGHT, "start_percent": 0.9, "end_side": Side.LEFT, "end_percent": 0.1, "speed": 45, "start_delay": 36.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.1, "end_side": Side.RIGHT, "end_percent": 0.1, "speed": 45, "start_delay": 36.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.1, "end_side": Side.RIGHT, "end_percent": 0.5, "speed": 45, "start_delay": 36.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.LEFT, "start_percent": 0.1, "end_side": Side.RIGHT, "end_percent": 0.9, "speed": 45, "start_delay": 36.5})
	next_wave_after_last_spawn(6.0)
	


# Wave 1 - jump tutorial: Red Frog's lines, the Jump card, then astroid
# columns and the jump-only formations (two diagonal walls and a ring).
func _wave_1() -> void:
	_set_abilities(false, true)    # jumping unlocked, still no shooting
	await talk([
		{"text": "Ace pilots like yours truly don't really need special modifications, but why don't you show me what yours can do?", "portrait": FACE_RED,"speaker": "Red Frog"},
		{"text": "A frog jumping is a little on the nose for my taste, but I'm curious to see what you've been spending all that time working on.","portrait": FACE_RED,"speaker": "Red Frog"},
	], FROG)

	# Tutorial card: jumping + its cooldown. Pauses until the player closes it.
	await show_info({
		"title": "Jump",
		"video": TUTORIAL_JUMP_VIDEO,
		"keys": [["L"]],
		"key_timeline": TUTORIAL_JUMP_KEYS,
		"key_cooldowns": TUTORIAL_JUMP_COOLDOWNS,
		"text": "Press L to jump. After you land, the jump needs a moment to recharge before you can use it again.",
	})

	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": 45, "start_delay": 0.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": 45, "start_delay": 0.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.3, "speed": 45, "start_delay": 0.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.4, "speed": 45, "start_delay": 0.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 45, "start_delay": 0.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "speed": 45, "start_delay": 0.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.7, "end_side": Side.BOTTOM, "end_percent": 0.7, "speed": 45, "start_delay": 0.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": 45, "start_delay": 0.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": 45, "start_delay": 0.0})

	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": 45, "start_delay": 2.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": 45, "start_delay": 2.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.3, "speed": 45, "start_delay": 2.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.4, "speed": 45, "start_delay": 2.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 45, "start_delay": 2.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "speed": 45, "start_delay": 2.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.7, "end_side": Side.BOTTOM, "end_percent": 0.7, "speed": 45, "start_delay": 2.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": 45, "start_delay": 2.5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": 45, "start_delay": 2.5})

	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": 45, "start_delay": 5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": 45, "start_delay": 5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.3, "speed": 45, "start_delay": 5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.4, "speed": 45, "start_delay": 5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 45, "start_delay": 5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "speed": 45, "start_delay": 5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.7, "end_side": Side.BOTTOM, "end_percent": 0.7, "speed": 45, "start_delay": 5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": 45, "start_delay": 5})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": 45, "start_delay": 5})

	spawn_diagonal_astroid_wall({"from_corner": "top_right", "enemy": ASTROID_SMALL, "speed": 55.0, "spacing": 18.0, "start_delay": 9.0})
	spawn_diagonal_astroid_wall({"from_corner": "top_left", "enemy": ASTROID_SMALL, "speed": 55.0, "spacing": 18.0, "start_delay": 12.0})
	spawn_astroid_ring({"enemy": ASTROID_SMALL, "speed": 55.0, "spacing": 18.0, "start_delay": 16.0})


# Wave 2 - NOT timed (no next_wave_after_last_spawn), so the next loop only
# starts once every flower is gone. Shows dialogue in the MIDDLE of a wave:
# the wave function awaits a wait() and a talk() between spawns, and still
# counts as running the whole time, so the level never skips ahead.
func _wave_2() -> void:
	_set_abilities(true, false)    
	await talk([
		{"text": "Looks like you're out of jumping juice. Oh well. Not really sure how one jumps in the vacuum of space anyway.", "portrait": FACE_RED,"speaker": "Red Frog"},
		{"text": "Why don't we bring out the big guns or whatever pea shooter you scrapped together and blast some of these astroids away.","portrait": FACE_RED,"speaker": "Red Frog"},
	], FROG)

	# Tutorial card: shooting. Pauses until the player closes it.
	await show_info({
		"title": "Shoot",
		"video": TUTORIAL_SHOOT_VIDEO,
		"keys": [["J"]],
		"key_timeline": TUTORIAL_SHOOT_KEYS,
		"text": "Hold J to fire. Damaging enemies fills your multiplier.",
	})
	
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": 45, "start_delay": 0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": 45, "start_delay": 0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.3, "speed": 45, "start_delay": 0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.4, "speed": 45, "start_delay": 0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 45, "start_delay": 0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "speed": 45, "start_delay": 0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.7, "end_side": Side.BOTTOM, "end_percent": 0.7, "speed": 45, "start_delay": 0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": 45, "start_delay": 0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": 45, "start_delay": 0})
	
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 30, "start_delay": 2})
	
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 30, "start_delay": 6})
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": 30, "start_delay": 6})
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.4, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": 30, "start_delay": 6})
	
	spawn_diagonal_astroid_wall({"from_corner": "top_right", "enemy": ASTROID_SMALL, "speed": 30.0, "spacing": 18.0, "start_delay": 11.0})
	spawn_diagonal_astroid_wall({"from_corner": "top_left", "enemy": ASTROID_SMALL, "speed": 30.0, "spacing": 18.0, "start_delay": 15.0})
	
	# Golden astroid at 15s - Red Frog calls it out the moment it appears. It
	# stops a third of the way down and waits there until it's shot.
	await wait(30.0)
	spawn_drift_wave({"enemy": ASTROID_GOLDEN, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 30, "stop_percent": 0.33})
	say("A golden astroid! Those are super valuable. Let's shoot it and collect the debris.", RED_FROG)
	
func _wave_3() -> void:
	_set_abilities(false, false) 
	await talk([
		{"text": "Look's like that golden astroid did the trick. Absorbing an enemy ship and stealing their power. Not quite for me.", "portrait": FACE_RED,"speaker": "Red Frog"},
		{"text": "There is no equal to my brilliance so what would I even want to copy? Oh, I mean... but I'm sure you could use the boost.","portrait": FACE_RED,"speaker": "Red Frog"},
	], FROG)

	# Tutorial card: absorbing. Pauses until the player closes it.
	await show_info({
		"title": "Absorb",
		"video": TUTORIAL_ABSORB_VIDEO,
		"keys": [["K"]],
		"key_timeline": TUTORIAL_ABSORB_KEYS,
		"text": "At 4x multiplier, press K to fire an absorb beam. Hit an enemy with it to take on its form for a while.",
	})

	# Gray bee stops a third of the way down and waits to be absorbed (or shot).
	spawn_drift_wave({"enemy": GRAY_BEE, "start_side": Side.TOP, "start_percent": 0.25, "end_side": Side.BOTTOM, "end_percent": 0.25, "speed": 20, "stop_percent": 0.33})
	
# Wave 4 starts once the gray bee from wave 3 is gone. The absorb beam
# removes the bee the moment it hits, BEFORE the player transforms, so wait
# for the absorb to finish first, then only react if they actually took the
# gray form (if they shot the bee instead, this line is skipped).
func _wave_4() -> void:
	while player and player.currently_absorbing:
		await get_tree().process_frame
	if player and player.current_form != 'default':
		await talk([
			{"text": "Hmmmm, I was expecting something a little more dramatic but I guess your ship does seem a stronger faster now.", "portrait": FACE_RED,"speaker": "Red Frog"},
		], FROG)

	# Tutorial cards: transformations wear off, and trading one in for a
	# bubble. Shown either way (even if the bee got shot instead of absorbed).
	await show_info({
		"title": "Transformations",
		"video": TUTORIAL_RUNOUT_VIDEO,
		"text": "Transformations give you different boosts, but they're temporary. When your ship starts flashing, the transformation is about to run out.",
	})
	await show_info({
		"title": "Bubbles",
		"video": TUTORIAL_BUBBLE_VIDEO,
		"keys": [["K"]],
		"key_timeline": TUTORIAL_BUBBLE_KEYS,
		"text": "While transformed, press K to give up the transformation and shoot it out as a bubble. Bounce the bubble around the level off your ship.",
	})

	# 10 second breather before wave 5. Wave 4 has no enemies, so without
	# this the bomb rings would start the moment the last card closes.
	# (await wait() keeps the wave "running", so the level can't skip ahead.)
	await wait(10.0)


# Wave 5 - the bomb-ring encounter (same as levels/a_test.gd). The whole thing
# lives in base_level.gd's run_bomb_ring_challenge(): three bombs inside rings
# of armored astroids, with golden astroids and gray bees drifting down until
# every ring is gone. Combining two bubbles always grants Penetrator Rounds
# during it.
func _wave_5() -> void:
	_set_abilities(true, true)
	await talk([
		{"text": "Some weird astroid formations ahead. If I were taking this test, I'd hit the bombs in the center with a triple barrel flipturn switcheroo."},
		{"text": "Kinda advanced for you so you may need to get a bit creative."},
	], RED_FROG)

	# Tutorial card: the three things a bubble can do - intro line, then one
	# clip + description row per use (see info_card.gd's "sections").
	await show_info({
		"title": "Using Bubbles",
		"text": "There are three ways to utilize the bubble:",
		"sections": [
			{"video": TUTORIAL_BUBBLE_JUMP_VIDEO, "text": "Jump (L) on the bubble and it does damage to enemies for a short time."},
			{"video": TUTORIAL_BUBBLE_SHOOT_VIDEO, "text": "Shoot (J) the bubble to trigger a big explosion."},
			{"video": TUTORIAL_BUBBLE_COMBINE_VIDEO, "text": "Combine two bubbles to get a permanent buff."},
		],
	})

	await run_bomb_ring_challenge()
	say("Ha! Three bombs down. Not bad.", RED_FROG)
	await run_bomb_ring_challenge()
	
# Wave 6 - the final exam. Everything from the earlier waves, one after the
# other, building up:
#   1. Dodge + shoot  - staggered astroid columns with gaps to slip through,
#                       and medium astroids that split when shot.
#   2. Gold + absorb  - a golden astroid (shoot it for 4x) and a gray bee
#                       right behind it (absorb it with K for the gray form).
#   3. Jump           - two diagonal astroid walls that can only be jumped,
#                       then a big astroid ring to jump into and back out of.
#   4. Bombs          - two bomb rings (run_bomb_ring_challenge in
#                       base_level.gd) with golden astroid / gray bee supply
#                       drops. Bubble fusions grant a RANDOM power-up here
#                       ("fusion_powerup": ""), not just Penetrator Rounds.
# The phases overlap a little (each phase starts while the last one's
# stragglers are still on screen) so it feels like one continuous run.
func _wave_6() -> void:
	_set_abilities(true, true)
	await talk([
		{"text": "And check! Mandatory insurance requirements fullfilled. Now guess all that's left is for you to get out of this super dangerous astroid field."},
		{"text": "Hmmmm looks like the next section is even more dangerous. Use everything I taught..."},
		{"text": "Err I guess use all the stuff you already knew to not die which would force me to do even more paper work."},
	], RED_FROG)

	# --- 1. Dodge + shoot ---
	var gaps := [0.5, 0.3, 0.7, 0.2, 0.8]
	for row in gaps.size():
		for lane in [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]:
			if absf(lane - gaps[row]) < 0.15:
				continue   # leave a gap for the ship
			spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": lane, "end_side": Side.BOTTOM, "end_percent": lane, "speed": 45, "start_delay": row * 2.0})
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.6, "speed": 30, "start_delay": 3.0})
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.4, "speed": 30, "start_delay": 6.0})
	# Gray hive down the left side, right after the second medium astroid.
	spawn_drift_wave({"enemy": GRAY_HIVE, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": 25, "start_delay": 8.5})
	await wait(11.0)

	# --- 2. Jump ---
	spawn_diagonal_astroid_wall({"from_corner": "top_left", "enemy": ASTROID_SMALL, "speed": 40.0, "spacing": 18.0, "start_delay": 0.0})
	spawn_diagonal_astroid_wall({"from_corner": "top_right", "enemy": ASTROID_SMALL, "speed": 40.0, "spacing": 18.0, "start_delay": 5.0})
	# Two gray bees drifting down with the walls.
	spawn_drift_wave({"enemy": GRAY_BEE, "start_side": Side.TOP, "start_percent": 0.75, "end_side": Side.BOTTOM, "end_percent": 0.75, "speed": 25, "start_delay": 1.0})
	spawn_drift_wave({"enemy": GRAY_BEE, "start_side": Side.TOP, "start_percent": 0.25, "end_side": Side.BOTTOM, "end_percent": 0.25, "speed": 25, "start_delay": 6.0})
	# Big astroid ring with a bomb ring in its middle. Same start point, speed
	# and start_delay, so the bomb ring stays centered as they fall together;
	# keep_moving means it never stops and just leaves off the bottom.
	var big_ring_radius: float = get_viewport_rect().size.x * 0.5 - 10.0
	var ring_speed := 45.0
	var ring_delay := 10.0
	spawn_astroid_ring({"enemy": ASTROID_SMALL, "radius": big_ring_radius, "speed": ring_speed, "spacing": 18.0, "start_delay": ring_delay})
	spawn_bomb_ring({"center_percent": 0.5, "speed": ring_speed, "start_delay": ring_delay, "keep_moving": true, "start_y": -big_ring_radius - FORMATION_ENTRY_MARGIN})
	await wait(18.0)

	# --- 3. Bombs ---
	# Walls + medium astroids sweeping through while the bomb rings sit there.
	for i in 4:
		var corner: String = "top_left" if i % 2 == 0 else "top_right"
		spawn_diagonal_astroid_wall({"from_corner": corner, "enemy": ASTROID_SMALL, "speed": 40.0, "spacing": 18.0, "start_delay": 4.0 + i * 6.0})
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.15, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 30, "start_delay": 1.0})
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.85, "end_side": Side.BOTTOM, "end_percent": 0.5, "speed": 30, "start_delay": 7.0})
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": 30, "start_delay": 13.0})
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": 30, "start_delay": 19.0})
	# Two gray flowers to absorb.
	spawn_drift_wave({"enemy": GRAY_FLOWER, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8, "speed": 20, "start_delay": 5.0})
	spawn_drift_wave({"enemy": GRAY_FLOWER, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2, "speed": 20, "start_delay": 15.0})

func _wave_7() -> void:
	_set_abilities(true, true)
	await talk([
		{"text": "You made it?"},
		{"text": "I mean, you made it!"},
		{"text": "I knew you had it in you the whole time. If the whole time started five seconds ago."},
		{"text": "That's enough of that. I'm outta here. Have a great day or night or whatever time it is in space."},
	], RED_FROG)

func _ready() -> void:
	level_paths = {
		"next_level": "res://levels/test_menu.tscn"
	}
	waves = [_wave_intro, _wave_1, _wave_2, _wave_3, _wave_4, _wave_5, _wave_6, _wave_7]
	fallback_enemy = FLOWER
	super._ready()   # sets max_waves = waves.size(), so the level ends after _wave_6
