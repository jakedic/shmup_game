# dylan_level.gd
# "Dylan Level" - an exact copy of Yellow Level (see levels/yellow_level.gd).
# All the actual wave-running, boss-fight, and enemy-spawning machinery lives
# in levels/squad_wave_level.gd - this file only defines WHAT spawns in each
# wave, as one function per wave.
#
# WANT TO CHANGE WHAT SPAWNS IN EACH WAVE? Edit the matching _wave_N()
# function below - each call is a spawn_squad_wave()/spawn_solo_wave()/
# spawn_drift_wave() with a labeled config Dictionary, so every field is
# named right at the call site. Add or remove a _wave_N() function and update
# the `waves` array in _ready() to match - the level picks up the new wave
# count automatically. See levels/squad_wave_level.gd's header comment for
# the full field reference per pattern, and how to add a whole new movement
# pattern later.
extends SquadWaveLevel

const ENEMY_BEE := preload("res://enemies/enemy_yellow.tscn")
const BEE_MINIBOSS := preload("res://enemies/yellow_miniboss.tscn")
const ASTROID_MEDIUM := preload("res://enemies/astroid_medium.tscn")
const ASTROID_SMALL := preload("res://enemies/astroid_small.tscn")


# Wave 1 - a few astroids drifting straight down to open the level with a
# calm, lower-pressure introduction before the bees start - nothing to shoot
# back, just something to dodge or pick off.
func _wave_1() -> void:
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.35, "speed": 40})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.55, "speed": 38, "start_delay": 1.0})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.75, "speed": 38, "start_delay": 2.0})


# Wave 2 - Two enemies towards the side to introduce these enemies to the player. The approach from the sides to give the player time to reach and approach them at their own pace
func _wave_2() -> void:
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.3})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.8, "start_delay": 1})


# Wave 3 - two groups of 3 enemys approach from the sides. each one delayed. This slowly increments the difficulty while still letting the player approach the enemies at their own pace
func _wave_3() -> void:
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .1, "end_side": Side.BOTTOM, "end_percent": .3})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .2, "end_side": Side.BOTTOM, "end_percent": .4, "start_delay": .3})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .1, "end_side": Side.BOTTOM, "end_percent": .3, "start_delay": .6})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .9, "end_side": Side.BOTTOM, "end_percent": .7, "start_delay": 2})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .8, "end_side": Side.BOTTOM, "end_percent": .6, "start_delay": 2.3})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .9, "end_side": Side.BOTTOM, "end_percent": .7, "start_delay": 2.6})


#Wave 4 - a string of enemies moving throughout the screen will present a small and managble challenge for the player who should now be used to enemies now, starts on right side as player will likely be there after killing/attempting to kill last enemy
func _wave_4() -> void:
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .1, "end_side": Side.BOTTOM, "end_percent": .1})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .3, "end_side": Side.BOTTOM, "end_percent": .3, "start_delay": .3})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .5, "end_side": Side.BOTTOM, "end_percent": .5, "start_delay": .6})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .7, "end_side": Side.BOTTOM, "end_percent": .7, "start_delay": .9})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .9, "end_side": Side.BOTTOM, "end_percent": .9, "start_delay": 1.2})


#Wave 5 - similar challenge to the previous wave, starts on left side as player will likely be there after killing/attempting to kill last enemy
func _wave_5() -> void:
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .9, "end_side": Side.BOTTOM, "end_percent": .9})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .7, "end_side": Side.BOTTOM, "end_percent": .7, "start_delay": .3})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .5, "end_side": Side.BOTTOM, "end_percent": .5, "start_delay": .6})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .3, "end_side": Side.BOTTOM, "end_percent": .3, "start_delay": .9})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .1, "end_side": Side.BOTTOM, "end_percent": .1, "start_delay": 1.2})


# Wave 6 - a single squad, straight down the middle, circling at the top portion of the screen to give the player time to understand the pattern. Other enemies should distract/protect the circle long enough for the player to see them dive after circling
func _wave_6() -> void:
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "start_delay": 1.0})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "start_delay": 1.0})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8})
	spawn_squad_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": LANE_CENTER, "end_side": Side.BOTTOM, "end_percent": LANE_CENTER, "circle_progress": .2, "start_delay": 1})

func _wave_7() -> void:
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.3, "end_side": Side.BOTTOM, "end_percent": 0.35, "speed": 65})
	spawn_drift_wave({"enemy": ASTROID_MEDIUM, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.65, "speed": 65})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.1, "speed": 60})
	spawn_drift_wave({"enemy": ASTROID_SMALL, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.9, "speed": 60})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .1, "end_side": Side.BOTTOM, "end_percent": .1, "start_delay": .3})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .3, "end_side": Side.BOTTOM, "end_percent": .3, "start_delay": .6})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .5, "end_side": Side.BOTTOM, "end_percent": .5, "start_delay": .9})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .7, "end_side": Side.BOTTOM, "end_percent": .7, "start_delay": 1.2})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .9, "end_side": Side.BOTTOM, "end_percent": .9, "start_delay": 1.5})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .9, "end_side": Side.BOTTOM, "end_percent": .9, "start_delay": 2.2})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .7, "end_side": Side.BOTTOM, "end_percent": .7, "start_delay": 2.5})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .5, "end_side": Side.BOTTOM, "end_percent": .5, "start_delay": 2.8})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .3, "end_side": Side.BOTTOM, "end_percent": .3, "start_delay": 3.1})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .1, "end_side": Side.BOTTOM, "end_percent": .1, "start_delay": 3.4})
# Wave 8 - multiple squad wave, just ramping up the challenge slightly
func _wave_8() -> void:
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "start_delay": 1.0})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "start_delay": 1.0})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8})
	spawn_squad_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": LANE_CENTER, "circle_progress": .2, "start_delay": 1})
	spawn_squad_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": LANE_CENTER, "circle_progress": .2, "start_delay": 1.5})
	spawn_squad_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": LANE_CENTER, "circle_progress": .5, "start_delay": 2.5})
	spawn_squad_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": LANE_CENTER, "circle_progress": .5, "start_delay": 3})


#not sure what wave this would be but this is an interesting pattern that would towards the end of the level
#pattern needs to be reworked does not work the way I thought it would
#func _wave_9() -> void:
	#spawn_squad_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": LANE_CENTER, "end_side": Side.BOTTOM, "end_percent": LANE_CENTER, "circle_progress": .2, "start_delay": .6})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "start_delay": .6})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "start_delay": 1.2})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "start_delay": 1.8})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "start_delay": 2.4})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "start_delay": 3})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "start_delay": 3.6})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "start_delay": 4.2})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "start_delay": 4.8})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "start_delay": 5.4})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "start_delay": 6})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": .1})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": 0.1, "start_delay": .6})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": 0.1, "start_delay": 1.2})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": 0.1, "start_delay": 1.8})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": 0.1, "start_delay": 2.4})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": 0.1, "start_delay": 3})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": 0.1, "start_delay": 3.6})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": 0.1, "start_delay": 4.2})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": 0.1, "start_delay": 4.8})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": 0.1, "start_delay": 5.4})
	#spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": 0.1, "start_delay": 6})


# Wave 4 - the end-of-level miniboss (see enemies/yellow_miniboss.gd).
func _wave_boss() -> void:
	_spawn_boss_wave()


func _ready() -> void:
	enemy_scenes = [ENEMY_BEE, ASTROID_MEDIUM, ASTROID_SMALL]
	level_paths = {
		"next_level": "res://levels/level_1.tscn"
	}
	waves = [ _wave_1, _wave_2, _wave_3, _wave_4, _wave_5, _wave_6,_wave_7, _wave_8, _wave_boss]
	boss_scene = BEE_MINIBOSS
	fallback_enemy = ENEMY_BEE
	super._ready()
