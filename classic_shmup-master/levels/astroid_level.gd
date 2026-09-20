# astroid_level.gd
#
# Simple demo/test level for the astroid enemies (see enemies/astroid_enemy.gd
# for how they work). No waves, no squads - just spawns a few astroids with
# explicit start points, end points, and speeds, then goes back to the Test
# menu once every astroid is gone.
#
# TO ADD ASTROIDS TO ANY LEVEL: call the inherited spawn_astroid() (defined
# once on BaseLevel - see base_level.gd's ASTROID HELPER section) with a
# labeled config Dictionary - see spawn_enemies() below for examples. Every
# field is spelled out by name right in the call, so it's obvious what each
# value does without needing to look anything up.
extends BaseLevel

const ASTROID_MEDIUM := preload("res://enemies/astroid_medium.tscn")
const ASTROID_SMALL := preload("res://enemies/astroid_small.tscn")

func _ready():
	enemy_scenes = [ASTROID_MEDIUM, ASTROID_SMALL]
	level_paths = {
		"next_level": "res://levels/test_menu.tscn"
	}
	max_waves = 1

	super._ready()

func spawn_enemies():
	spawn_astroid({
		"scene": ASTROID_MEDIUM,
		"start": Vector2(70, -20),
		"end": Vector2(90, 340),
		"speed": 18.0,
	})
	spawn_astroid({
		"scene": ASTROID_MEDIUM,
		"start": Vector2(170, -20),
		"end": Vector2(140, 340),
		"speed": 18.0,
	})
	spawn_astroid({
		"scene": ASTROID_SMALL,
		"start": Vector2(40, -20),
		"end": Vector2(60, 340),
		"speed": 26.0,
	})
	spawn_astroid({
		"scene": ASTROID_SMALL,
		"start": Vector2(120, -20),
		"end": Vector2(120, 340),
		"speed": 26.0,
	})
	spawn_astroid({
		"scene": ASTROID_SMALL,
		"start": Vector2(200, -20),
		"end": Vector2(180, 340),
		"speed": 26.0,
	})
