# hive_level.gd
# "Hive Level" - a minimal dev/test level for the hive enemy's custom
# stop-and-dance movement (see enemies/hive_solo.gd's header comment for the
# full pattern description). Spawns exactly one HiveEnemy so its movement can
# be watched in isolation, then returns to the title screen once it's gone.
#
# Not built on levels/squad_wave_level.gd (no wave table/boss behavior here
# yet) - just extends BaseLevel directly, like any other level. Shows up
# automatically in the dev Test menu (levels/test_menu.gd), same as every
# other level that extends BaseLevel.
extends BaseLevel

const ENEMY_HIVE := preload("res://enemies/enemy_hive.tscn")

func _ready() -> void:
	enemy_scenes = [ENEMY_HIVE]
	level_paths = {
		"next_level": "res://levels/title_screen.tscn"
	}
	max_waves = 1
	super._ready()

func spawn_enemies() -> void:
	spawn_hive_solo(ENEMY_HIVE, 0.4)
