# yellow_level.gd
# "Yellow Level" - the new first level of a run (see game_progress.gd's
# START_ID override), built to show off the squad- and solo-based bee
# enemy behavior (see enemies/yellow_squad.gd and enemies/yellow_solo.gd).
# All the actual wave-running, boss-fight, and enemy-spawning machinery lives
# in levels/squad_wave_level.gd - this file only defines WHAT spawns in each
# wave.
#
# WANT TO CHANGE WHAT SPAWNS IN EACH WAVE? Edit the wave functions below -
# add, remove, or edit a _wave_*() function (and its entry in `waves` in
# _ready()) and the level picks it up automatically (it even figures out how
# many waves there are on its own, from waves.size()). See
# levels/squad_wave_level.gd's header comment for the full format, including
# the side+percent fields used below to place enemies without needing exact
# screen coordinates, and how to add a whole new movement pattern later.
extends SquadWaveLevel

const ENEMY_BEE := preload("res://enemies/enemy_yellow.tscn")
const BEE_MINIBOSS := preload("res://enemies/yellow_miniboss.tscn")


func _wave_1() -> void:
	# A single solo enemy crossing left to right, on its own, to show off how
	# a solo works before mixing one in alongside squads.
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.LEFT, "start_percent": 0.3, "end_side": Side.RIGHT, "end_percent": 0.3})


func _wave_2() -> void:
	# A single squad, straight down the middle, circling a third of the way
	# down before continuing on to the bottom.
	spawn_squad_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": LANE_CENTER, "end_side": Side.BOTTOM, "end_percent": LANE_CENTER, "circle_progress": 0.3})


func _wave_3() -> void:
	# Two squads diving in diagonally from opposite top corners toward the
	# opposite bottom corners, plus a solo crossing the other way through the
	# middle of the action.
	spawn_squad_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": LANE_LEFT, "end_side": Side.BOTTOM, "end_percent": LANE_RIGHT, "start_delay": 0.0, "circle_progress": 0.4, "circle_hold_interval": 4.0})
	spawn_squad_wave({"enemy": ENEMY_BEE, "start_side": Side.TOP, "start_percent": LANE_RIGHT, "end_side": Side.BOTTOM, "end_percent": LANE_LEFT, "start_delay": 1.5, "circle_progress": 0.4})
	spawn_solo_wave({"enemy": ENEMY_BEE, "start_side": Side.RIGHT, "start_percent": 0.6, "end_side": Side.LEFT, "end_percent": 0.6, "start_delay": 1.0})


func _wave_boss() -> void:
	# The end-of-level miniboss (see enemies/yellow_miniboss.gd).
	_spawn_boss_wave()


func _ready() -> void:
	enemy_scenes = [ENEMY_BEE]
	level_paths = {
		"next_level": "res://levels/level_1.tscn"
	}
	waves = [_wave_1, _wave_2, _wave_3, _wave_boss]
	boss_scene = BEE_MINIBOSS
	fallback_enemy = ENEMY_BEE
	super._ready()
