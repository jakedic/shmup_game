# a_test.gd
#
# Scratch/test level for trying out new enemies. Uses the level-flow tools
# (see base_level.gd's WAVE FLOW + DIALOGUE sections):
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
# field). The waves loop forever so you can keep testing. Pause -> Quit to leave.
extends SquadWaveLevel


# Enemy scenes (ENEMY_BEE, FLOWER, ASTROID_GOLDEN, GRAY_BEE, ...), dialogue
# faces and speaker presets (FROG) are shared by every level - they're
# declared once in levels/squad_wave_level.gd.

# THREE BOMB RINGS - the whole encounter lives in base_level.gd (see its BOMB
# RINGS section and run_bomb_ring_challenge()) so any level can reuse it; the
# tutorial runs the same thing as its wave 5. Three bombs sit inside rings of
# 2-armor astroids while golden astroids and gray bees keep drifting down.
# Pop a bubble next to a ring, or combine two bubbles for Penetrator Rounds
# (forced during the encounter) and shoot through the ring. Jumping onto a
# bomb works too, but burns you once you land.
func _wave_bomb_rings() -> void:
	say("Three bombs behind walls of armor. Find a way to set them off!", FROG)
	await run_bomb_ring_challenge()
	say("All three bombs down!", FROG)


# TUTORIAL WAVE 6 (remix) - started as a copy of the enemy spawns from
# levels/tutorial.gd's _wave_6(), now reworked for testing. Three phases,
# overlapping a little:
#   1. Dodge + shoot  - astroid rows with a moving gap, angled medium
#                       astroids, then a gray hive down the left side
#   2. Jump           - two diagonal astroid walls with a gray bee drifting
#                       down alongside each, then the big astroid ring with a
#                       bomb ring riding down in its middle (doesn't stop)
#   3. Bombs          - two bomb rings, plus a handful of diagonal walls and
#                       medium astroids to shake it up, and two gray flowers
#                       to absorb. Bubble fusions grant a random power-up.
func _wave_tutorial_6() -> void:
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



func _ready() -> void:
	level_paths = {
		"next_level": "res://levels/test_menu.tscn"
	}
	# Add _wave_bomb_rings back to this list to test the three-ring version too.
	waves = [_wave_tutorial_6]
	fallback_enemy = FLOWER
	super._ready()
	max_waves = 999  # keep looping the waves (see spawn_enemies() below)


func spawn_enemies() -> void:
	# Loop the waves forever.
	await waves[current_wave % waves.size()].call()
