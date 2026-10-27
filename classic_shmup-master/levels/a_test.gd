# a_test.gd
#
# Scratch/test level - currently set up for testing the first boss (the
# badger, enemies/boss_badger.tscn). Everything about the boss - its attacks,
# the conveyor-belt arena it brings with it, scoring - lives in the boss's own
# scripts, so all a level does is spawn it:
#
#     var boss = BOSS_BADGER.instantiate()
#     add_child(boss)
#     boss.start()
#
# When the boss dies a fresh one comes in so you can keep testing (the
# arena from the first one stays). Pause -> Quit to leave.
extends SquadWaveLevel

const BOSS_BADGER := preload("res://enemies/boss_badger.tscn")


func _wave_boss() -> void:
	if current_wave > 0:
		say("Here it comes again!", FROG)
		await wait(2.0)
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
	max_waves = 999  # keep looping (see spawn_enemies() below)


func spawn_enemies() -> void:
	# Loop the waves forever.
	await waves[current_wave % waves.size()].call()
