# boss_test.gd
#
# Boss test level (moved here from a_test.gd) - for testing the first boss (the
# badger, enemies/boss_badger.tscn). Everything about the boss - its attacks,
# the conveyor-belt arena it brings with it, scoring - lives in the boss's own
# scripts, so all a level does is spawn it:
#
#     var boss = BOSS_BADGER.instantiate()
#     add_child(boss)
#     boss.start()
#
# One boss, one wave: once the head is killed (and its death animation has
# finished), the level ends like any other and goes back to the test menu.
extends SquadWaveLevel

const BOSS_BADGER := preload("res://enemies/boss_badger.tscn")


func _wave_boss() -> void:
	var boss = BOSS_BADGER.instantiate()
	add_child(boss)
	boss.start()


func _ready() -> void:
	level_paths = {
		"next_level": "res://levels/test_menu.tscn"
	}
	waves = [_wave_boss]
	fallback_enemy = FLOWER
	super._ready()
