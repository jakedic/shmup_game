# hive_level.gd
# "Hive Level" - a minimal dev/test level for the hive enemy. Two waves:
#   wave 1 - one solo hive (enemies/hive_solo.gd): slow creep down, stopping
#            every third of the screen to shake and fire a 3-wall spread.
#   wave 2 - a hive squad (enemies/hive_squad.gd): two hives side by side
#            that merge a third of the way down, shake out of sync, and fire
#            an 8-way wall volley.
# Returns to the title screen once both waves are gone.
#
# Extends BaseLevel directly (not SquadWaveLevel). Shows up automatically in
# the dev Test menu (levels/test_menu.gd), like every other BaseLevel.
extends BaseLevel

const ENEMY_HIVE := preload("res://enemies/enemy_hive.tscn")

func _ready() -> void:
	enemy_scenes = [ENEMY_HIVE]
	level_paths = {
		"next_level": "res://levels/title_screen.tscn"
	}
	max_waves = 2
	super._ready()

func spawn_enemies() -> void:
	# BaseLevel calls this once at the start (current_wave = 0) and again
	# each time every enemy is gone (current_wave already incremented).
	# This level extends BaseLevel directly, so it passes exact start/end
	# positions (x, y) - levels built on SquadWaveLevel use side+percent
	# instead (see spawn_hive_wave() in levels/squad_wave_level.gd).
	var size: Vector2 = get_viewport_rect().size
	match current_wave:
		0: spawn_hive_solo(ENEMY_HIVE, Vector2(size.x * 0.4, -40), Vector2(size.x * 0.4, size.y + 40))
		1: spawn_hive_squad(ENEMY_HIVE, Vector2(size.x * 0.5, -40), Vector2(size.x * 0.5, size.y + 40))
