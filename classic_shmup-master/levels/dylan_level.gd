# dylan_level.gd
# "Dylan Level" - an exact copy of Yellow Level (see levels/yellow_level.gd).
# All the actual wave-running, boss-fight, and squad/solo-spawning machinery
# lives in levels/squad_wave_level.gd - this file only defines WHAT spawns in
# each wave.
#
# WANT TO CHANGE WHAT SPAWNS IN EACH WAVE? Edit the WAVES table below - add,
# remove, or edit wave entries and the level picks it up automatically (it
# even figures out how many waves there are on its own). See
# levels/squad_wave_level.gd's header comment for the full format, including
# the side+percent fields used below to place squads/solos without needing
# exact screen coordinates.
extends SquadWaveLevel

const ENEMY_BEE := preload("res://enemies/enemy_yellow.tscn")
const BEE_MINIBOSS := preload("res://enemies/yellow_miniboss.tscn")

const WAVES: Array = [

	# Wave 1 - Two enemies towards the side to introduce these enemies to the player. The approach from the sides to give the player time to reach and approach them at their own pace
	{"solos": [
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.3},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.9, "end_side": Side.BOTTOM, "end_percent": 0.8, "start_delay": 1},
	]},
	# Wave 2 - two groups of 3 enemys approach from the sides. each one delayed. This slowly increments the difficulty while still letting the player approach the enemies at their own pace
	{"solos": [
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .1, "end_side": Side.BOTTOM, "end_percent": .3 },
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .2, "end_side": Side.BOTTOM, "end_percent": .4, "start_delay": .3 },
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .1, "end_side": Side.BOTTOM, "end_percent": .3, "start_delay": .6 },
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .9, "end_side": Side.BOTTOM, "end_percent": .7, "start_delay": 2 },
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .8, "end_side": Side.BOTTOM, "end_percent": .6, "start_delay": 2.3 },
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .9, "end_side": Side.BOTTOM, "end_percent": .7, "start_delay": 2.6 }
	]},
	
	#Wave 3 - a string of enemies moving throughout the screen will present a small and managble challenge for the player who should now be used to enemies now, starts on right side as player will likely be there after killing/attempting to kill last enemy
		{"solos": [
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .1, "end_side": Side.BOTTOM, "end_percent": .1 },
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .3, "end_side": Side.BOTTOM, "end_percent": .3 ,"start_delay": .3},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .5, "end_side": Side.BOTTOM, "end_percent": .5 ,"start_delay": .6},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .7, "end_side": Side.BOTTOM, "end_percent": .7 ,"start_delay": .9},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .9, "end_side": Side.BOTTOM, "end_percent": .9 ,"start_delay": 1.2},
		]},
	#Wave 4 - similar challenge to the previous wave, starts on left side as player will likely be there after killing/attempting to kill last enemy
	{"solos": [
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .9, "end_side": Side.BOTTOM, "end_percent": .9 },
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .7, "end_side": Side.BOTTOM, "end_percent": .7 ,"start_delay": .3},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .5, "end_side": Side.BOTTOM, "end_percent": .5 ,"start_delay": .6},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .3, "end_side": Side.BOTTOM, "end_percent": .3 ,"start_delay": .9},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": .1, "end_side": Side.BOTTOM, "end_percent": .1 ,"start_delay": 1.2},
		]},
	# Wave 5 - a single squad, straight down the middle, circling at the top portion of the screen to give the player time to understand the pattern. Other enemies should distract/protect the circle long enough for the player to see them dive after circling
	{"solos": [
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.5, "end_side": Side.BOTTOM, "end_percent": 0.5, "start_delay": 1.0},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.6, "end_side": Side.BOTTOM, "end_percent": 0.6, "start_delay": 1.0},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.2, "end_side": Side.BOTTOM, "end_percent": 0.2},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.8, "end_side": Side.BOTTOM, "end_percent": 0.8},
		],
	"squads": [
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": LANE_CENTER, "end_side": Side.BOTTOM, "end_percent": LANE_CENTER, "circle_progress": .2, "start_delay": 1},
	]},
	#not sure what wave this would be but this is an interesting pattern that would towards the end of the level
		{"squads": [
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": LANE_CENTER, "end_side": Side.BOTTOM, "end_percent": LANE_CENTER, "circle_progress": .2, "start_delay": .6},
		],
	"solos": [
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "start_delay": .6},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "start_delay": 1.2},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "start_delay": 1.8},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "start_delay": 2.4},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "start_delay": 3},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "start_delay": 3.6},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "start_delay": 4.2},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "start_delay": 4.8},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "start_delay": 5.4},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 0.1, "end_side": Side.BOTTOM, "end_percent": 0.9, "start_delay": 6},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": .1},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": 0.1, "start_delay": .6},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": 0.1, "start_delay": 1.2},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": 0.1, "start_delay": 1.8},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": 0.1, "start_delay": 2.4},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": 0.1, "start_delay": 3},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": 0.1, "start_delay": 3.6},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": 0.1, "start_delay": 4.2},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": 0.1, "start_delay": 4.8},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": 0.1, "start_delay": 5.4},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": 1, "end_side": Side.BOTTOM, "end_percent": 0.1, "start_delay": 6},
	]},
	# Wave 4 - the end-of-level miniboss (see enemies/yellow_miniboss.gd).
	{"is_boss_wave": true},
]


func _ready() -> void:
	enemy_scenes = [ENEMY_BEE]
	level_paths = {
		"next_level": "res://levels/level_1.tscn"
	}
	waves = WAVES
	boss_scene = BEE_MINIBOSS
	fallback_enemy = ENEMY_BEE
	super._ready()
