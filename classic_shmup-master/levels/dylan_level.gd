# dylan_level.gd
# "Dylan Level" - an exact copy of Yellow Level (see levels/yellow_level.gd).
# All the actual wave-running, boss-fight, and squad-spawning machinery lives
# in levels/squad_wave_level.gd - this file only defines WHAT spawns in each
# wave.
#
# WANT TO CHANGE WHAT SPAWNS IN EACH WAVE? Edit the WAVES table below - add,
# remove, or edit wave entries and the level picks it up automatically (it
# even figures out how many waves there are on its own). See
# levels/squad_wave_level.gd's header comment for the full format, including
# how to control how many enemies fly in a squad (the `squad_size` field).
extends SquadWaveLevel

const ENEMY_YELLOW := preload("res://enemies/enemy_yellow.tscn")
const YELLOW_MINIBOSS := preload("res://enemies/yellow_miniboss.tscn")

const WAVES: Array = [
	# Wave 1 - a single squad, straight down the middle.
	{"squads": [
		{"enemy": ENEMY_YELLOW, "lane": LANE_CENTER, "start_delay": 0.0, "drift": NO_DRIFT, "squad_size": 2},
	]},
	# Wave 2 - two squads, one from the left, one from the right.
	{"squads": [
		{"enemy": ENEMY_YELLOW, "lane": LANE_LEFT, "start_delay": 0.0, "drift": DRIFT_RIGHT},
		{"enemy": ENEMY_YELLOW, "lane": LANE_RIGHT, "start_delay": 1.5, "drift": DRIFT_LEFT},
	]},
	# Wave 3 - three squads, each drifting diagonally as they dive.
	{"squads": [
		{"enemy": ENEMY_YELLOW, "lane": LANE_LEFT, "start_delay": 0.0, "drift": DRIFT_RIGHT},
		{"enemy": ENEMY_YELLOW, "lane": LANE_CENTER, "start_delay": 1.5, "drift": DRIFT_LEFT},
		{"enemy": ENEMY_YELLOW, "lane": LANE_RIGHT, "start_delay": 3.0, "drift": DRIFT_RIGHT},
	]},
	# Wave 4 - the end-of-level miniboss (see enemies/yellow_miniboss.gd).
	{"is_boss_wave": true},
]


func _ready() -> void:
	enemy_scenes = [ENEMY_YELLOW]
	level_paths = {
		"next_level": "res://levels/level_1.tscn"
	}
	waves = WAVES
	boss_scene = YELLOW_MINIBOSS
	fallback_enemy = ENEMY_YELLOW
	super._ready()
