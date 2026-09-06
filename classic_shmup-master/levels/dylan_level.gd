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
	# Wave 1 - a single solo enemy crossing left to right, on its own, to
	# show off how a solo works before mixing one in alongside squads.
	{"solos": [
		{"enemy": ENEMY_BEE, "start_side": Side.LEFT, "start_percent": 0.3, "end_side": Side.RIGHT, "end_percent": 0.3},
	]},
	# Wave 2 - a single squad, straight down the middle, circling a third of
	# the way down before continuing on to the bottom.
	{"squads": [
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": LANE_CENTER, "end_side": Side.BOTTOM, "end_percent": LANE_CENTER, "circle_progress": 0.3},
	]},
	# Wave 3 - two squads diving in diagonally from opposite top corners
	# toward the opposite bottom corners, plus a solo crossing the other way
	# through the middle of the action.
	{"squads": [
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": LANE_LEFT, "end_side": Side.BOTTOM, "end_percent": LANE_RIGHT, "start_delay": 0.0, "circle_progress": 0.4, "circle_hold_interval": 4.0},
		{"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": LANE_RIGHT, "end_side": Side.BOTTOM, "end_percent": LANE_LEFT, "start_delay": 1.5, "circle_progress": 0.4},
	],
	"solos": [
		{"enemy": ENEMY_BEE, "start_side": Side.RIGHT, "start_percent": 0.6, "end_side": Side.LEFT, "end_percent": 0.6, "start_delay": 1.0},
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
